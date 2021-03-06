---
layout: post
title: "复盘: 一次istiod和istio-ingressgateway服务宕机故障"
categories: diary
---

### 我的环境

|-|version|
|-|-|
|kubernetes|v1.17|
|istio|1.7.3|

### 简单说下这个事

这次故障非常严重, 经过这次事件我深深认识到作为一个运维人员的不容易, 早上老大我在公司楼下等电梯, 老大给我打电话问我在哪? 公司所有服务全部挂了. 我第一反应是完蛋了. 集群故障了. 心想怎么电梯还不来?

打开电脑, 我就开始检查集群. 

### 第一步, 看看pod是不是都在运行

{% highlight shell %}
kubectl get pods -n istio-system -o wide
{% endhighlight %}

输出pod状态全都是`running`, 我傻眼了. 心想这问题应该不那么容易解决了. 背后发汗...

### 第二步, 集群内部测试服务之间通不通

为了精确定位问题, 我先进入一个pod中的容器, 去请求另一个pod提供个svc, 看看是不是通的. 

{% highlight shell %}
kubectl exec -it pod-name -c container-name -- bash
$ curl http://svc-name:port/
{% endhighlight %}

结果请求正常响应. 我傻眼了. 这下事情更不简单了. 应该不是`kubernetes`的问题. 问题定位到了`istio`

### 第三步, 查看日志.

第一步我说过, gateway运行状态是`status`, 我只能看日志了. 看看有没有问题.

{% highlight shell %}
kubectl logs -f --since 5m istio-ingressgateway-59dffbcfcb-55lds -n istio-system
{% endhighlight %}

`istio-ingressgateway`的主要报错日志摘要, 如下:

```
warning	envoy config	StreamAggregatedResources gRPC config stream closed: 14, upstream connect error or disconnect/reset before headers. reset reason: local reset

warning	envoy config	StreamAggregatedResources gRPC config stream closed: 14, no healthy upstream

warning	envoy config	Unable to establish new stream

warn	cache	resource:default request:68bf97bc-9e8d-41b1-8b17-6d9368b00aa9 CSR failed with error: rpc error: code = Unavailable desc = connection error: desc = "transport: Error while dialing dial tcp 10.96.5.249:15012: connect: connection refused", retry in 3200 millisec

error	citadelclient	Failed to create certificate: rpc error: code = Unavailable desc = connection error: desc = "transport: Error while dialing dial tcp 10.96.5.249:15012: connect: connection refused"
```

其中, `10.96.5.249` 是 `istiod` `service` 的 `CLUSTER-IP`, 通过日志能分析出来: 上游`istiod`挂了, 连接建立失败.


`istiod`的主要报错日志摘要, 如下:

```
info	validationController	Not ready to switch validation to fail-closed: dummy invalid config not rejected

info	validationController	validatingwebhookconfiguration istiod-istio-system (failurePolicy=Ignore, resourceVersion=83150152) is up-to-date. No change required.

info	validationController	Reconcile(enter): retry dry-run creation of invalid config
```

`kube-apiserver`的主要报错日志摘要, 如下:

```
Failed calling webhook, failing open validation.istio.io: failed calling webhook "validation.istio.io": Post https://istiod.istio-system.svc:443/validate?timeout=30s: dial tcp 10.96.5.249:443: connect: connection refused

failed calling webhook "validation.istio.io": Post https://istiod.istio-system.svc:443/validate?timeout=30s: dial tcp 10.96.5.249:443: connect: connection refused

Failed calling webhook, failing closed sidecar-injector.istio.io: failed calling webhook "sidecar-injector.istio.io": Post https://istiod.istio-system.svc:443/inject?timeout=30s: dial tcp 10.96.5.249:443: connect: connection refused

rejected by webhook "validation.istio.io": &errors.StatusError{ErrStatus:v1.Status{TypeMeta:v1.TypeMeta{Kind:"", APIVersion:""}, ListMeta:v1.ListMeta{SelfLink:"", ResourceVersion:"", Continue:"", RemainingItemCount:(*int64)(nil)}, Status:"Failure", Message:"admission webhook \"validation.istio.io\" denied the request: configuration is invalid: gateway must have at least one server", Reason:"", Details:(*v1.StatusDetails)(nil), Code:400}}
```
很明显了. `istiod`挂了, `webhook`请求不通, 但是, 可惜的是`istiod`的状态依然是`running`.

### 第四步, 重启istiod

{% highlight shell %}
kubectl rollout deploy/istiod -n istio-system
{% endhighlight %}

这个命令执行之后, `istiod`被调度到**另外一台机器上**, 我的服务都恢复了.

### 分析

- 1 资源问题
  
老大给我说昨天晚上收到了阿里云的一条短信, 说集群中有一台机器的cpu负载报警了, 正好就是`istiod`和`istio-ingressgateway`所在的那台机器, 所以我分析是机器负载过高引起的. 谷歌之后, 我找到了有人也这么说. 查阅istio官方对于内置 `kubernetes`的`docker destop`的要求是`4 cpus, 8g memory`, 虽然这台机器刚好满足要求, 但是毕竟是线上环境而且又部署了很多其他的业务服务. 资源不够用是必然. 最后, 经过查日志, 发现是这台机器上的一个业务pod提供了一个下载文件的接口, 一个文件150M, 当时有人下载, 资源耗尽,结果istiod和istio-ingressgateway应该是oom了.

- 2 健康检查

我`describe`了`istiod`配置清单, 里面只定义了`readinessProbe`, 并没有定义`livenessProbe`, 也就是说, 如果服务挂了顶多不给它分配流量了, 但是不能重启这个实例. **可悲的是, 我只启动了一个实例, 所以, 对外服务全部挂了.**  以后关键服务即便请求不高也要做高可用.

### 后面要做的事

- 给`istiod` 增加 `livenessProbe` 配置, 如下

{% highlight yaml %}
  livenessProbe:
    failureThreshold: 3
    httpGet:
      path: /ready
      port: 8080
      scheme: HTTP
    initialDelaySeconds: 1
    periodSeconds: 3
    successThreshold: 1
    timeoutSeconds: 5
{% endhighlight %}

- 提高`istiod`&`istio-ingressgateway`组件resource request中的`cpu`&`memory`配置
- 根据集群负载, 增加istio相关组件的实例数量提高容错能力(>=2)
- 服务加入集群前, 综合评估所用资源, 给所有服务都加上资源的限制
- [可选]istio相关组件和业务pod做node上的隔离
- 优化所部署的服务的资源消耗, 提高机器资源利用率
