---
layout: post
title: "手动给kubernetes部署metrics-server组件"
categories: diary
---

metrics-server是k8s的一个重要组件, 他能从`kubelet`获取`node`和`pod`的资源情况并通过`apiserver`提供给其他服务, 比如`kubectl top`/`HPA`/`VPA`等, 今天就安装一下.

### 1 环境

|-|version|
|-|-|
|kubernetes|v1.17|
|metrics-server|v0.3.6|
|addon-resizer|1.8.11|

### 2 安装时参考的文档

kubenetes github repo 中 [kubernetes/cluster/addons/metrics-server/](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/metrics-server)

我安装之前阅读了很多这方面的官方文档和博客, 虽然不是什么特别难特别复杂的操作, 毕竟自己做的少, 还是害怕错过什么细节, 导致安装失败. 影响集群的运行. 谋定而后动嘛 : )

### 3 `metrics-server`资源消耗分析

每个node, `metrics-server`会消耗`1m CPU + 3M memory`.

具体来说, `metrics-server`会从node和pod收集高达10种指标, 从k8s 1.6开始, 它支持5000个node 和 30个pod/node. 假设它1分钟收集一次指标, 那么每秒就是25000个指标
```
10 x 5000 x 30 / 60 = 25000 metrics per second by average
```

从`metrics-server v0.5`开始, 默认配置资源请求:

```
100m core of CPU
300MiB of memory
```
它说支持的集群规模如下:

|Quantity|Namespace threshold|Cluster threshold|
|-|-|-|
|#Nodes|n/a|100|
|#Pods|7000|7000|
|#Deployments + HPA|100|100|

### 4 给`metrics-server`配置垂直伸缩

细心的话, 会发现, 上面对集群规模的描述, 以及对`metrics-server`组件资源占用的分析都是基于node节点数量分析的, 但是单节点上pod数量同样也会影响`metrics-server`资源消耗.

上面说的每个节点上的pod数量默认限定为30个, 如果在一个存在大量pods的集群中, 在达到阈值时可能会出现OOM. 所以, kebernetes官方建议我们使用`addon-resizer`作为`metrics-server`的sidecar, 去watch `metrics-server` 并根据集群节点数量动态配置pod的资源配额. 这样就能让`kubernetes`有效的保证`metics-server`有合理的资源可以使用.

这个自动配额的计算方式是这样的:
```
cup = base-cpu + n * extra-cup
memory = base-memory + n * extra-memory
```

其中:

`base-cpu`和`base-memory`是我们初始给`addon-resizer`设定的一个`cup`和`memory`初始值. 您可以通过上面介绍的`metrics-server`资源消耗情况进行计算得出. 如果不知道自己在干啥, 可以按照100个node标准配置: `base-cpu=100m base-memory=300M`

`extra-cup`和`extra-memory`也是我们设定值, 它表示每增加一个节点`cpu`和`memory`所需要提高值. 同样, 如果不知道自己在干啥, 设置`extra-cpu=1m extra-memory=3M`就可以.

`n`代表集群节规模, 需要先定义一个最小集群规模(`minClusterSize`: 整数), 如果是这个规模以内的集群`n = minClusterSize`, 如果是最小规模以上的集群`n = node-num * 1.5`, `node-num`(节点数量)会自动被发现.

最后, 计算出来的`cpu`&`memory`会与阈值(`threshold`)进行比较, 超过阈值就会更新`deployment`配置. 配置的阈值是一个整数,代表的是一个百分比, 比如, `threshold=5`, 表示超过现在`cup`&`memory`配置值的5%就会更新`deployment`配置.

>这部分的参数配置请查看下面: 修改addon-resizer启动参数

### 5 部署

先将[kubernetes/cluster/addons/metrics-server/](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/metrics-server)仓库中yaml文件下载到本地.

接下来, 修改`metrics-server`和`addon-resizer`镜像仓库:

```
-        image: k8s.gcr.io/metrics-server-amd64:v0.3.6
+        # image: k8s.gcr.io/metrics-server-amd64:v0.3.6
+        image: registry.cn-hangzhou.aliyuncs.com/google_containers/metrics-server-amd64:v0.3.6
+        imagePullPolicy: IfNotPresent
...
-        image: k8s.gcr.io/addon-resizer:1.8.11
+        # image: k8s.gcr.io/addon-resizer:1.8.11
+        image: registry.cn-hangzhou.aliyuncs.com/google_containers/addon-resizer:1.8.11
+        imagePullPolicy: IfNotPresent
```

修改`metrics-server`启动参数:

```
         command:
         - /metrics-server
         - --metric-resolution=30s
+        - --kubelet-insecure-tls
         # These are needed for GKE, which doesn't support secure communication yet.
         # Remove these lines for non-GKE clusters, and when GKE supports token-based auth.
-        - --kubelet-port=10255
-        - --deprecated-kubelet-completely-insecure=true
+        # - --kubelet-port=10255
+        # - --deprecated-kubelet-completely-insecure=true
         - --kubelet-preferred-address-types=InternalIP
```

修改`addon-resizer`启动参数:

```
           command:
           - /pod_nanny
           - --config-dir=/etc/config
-          - --cpu={{ base_metrics_server_cpu }}
-          - --extra-cpu=0.5m
-          - --memory={{ base_metrics_server_memory }}
-          - --extra-memory={{ metrics_server_memory_per_node }}Mi
+          - --cpu=20m
+          - --extra-cpu=1m
+          - --memory=60Mi
+          - --extra-memory=3Mi
           - --threshold=5
           - --deployment=metrics-server-v0.3.6
           - --container=metrics-server
@@ -99,7 +104,7 @@ spec:
           - --estimator=exponential
           # Specifies the smallest cluster (defined in number of nodes)
           # resources will be scaled to.
-          - --minClusterSize={{ metrics_server_min_cluster_size }}
+          - --minClusterSize=5
           # Use kube-apiserver metrics to avoid periodically listing nodes.
           - --use-metrics=true
```

官方配置`ClusterRole`时忘掉了一个权限, 找到权限配置部分, 增加配置:

```
   resources:
   - pods
   - nodes
+  - nodes/stats
   - namespaces
```

>我配置好的yaml文件都放在这里 [my-share/deploy-metrics-server](https://github.com/llaoj/my-share/tree/master/deploy-metrics-server), 大家需要可以去看.

然后执行部署:

```
kubectl apply -f ./
```

### 6 验证

```
kubectl top nodes

kubectl top pods
```

### 7 参考的文档

- kubernetes的官方文档, [Resource metrics pipeline](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-metrics-pipeline/)
- metrics-server 组件介绍, [kubernetes-sigs/metrics-server](https://github.com/kubernetes-sigs/metrics-server)
- addon-resizer 组件介绍, [kubernetes/autoscaler](https://github.com/kubernetes/autoscaler/tree/master/addon-resizer)
