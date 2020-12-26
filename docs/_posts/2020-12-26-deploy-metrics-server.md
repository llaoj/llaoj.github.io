---
layout: post
title: "手动部署metrics-server组件"
categories: diary
---

metrics-server是k8s的一个重要组件, 他能从`kubelet`获取`node`和`pod`的资源情况并通过`apiserver`提供给其他服务, 比如`kubectl top`/`HPA`/`VPA`等, 今天就安装一下.

### 环境

|-|version|
|-|-|
|kubernetes|v1.17|
|metrics-server|v0.4.1|

### 安装的参考文档

kubenetes github repo 中 [kubernetes/cluster/addons/metrics-server/](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/metrics-server)

我安装之前阅读了很多这方面的官方文档和博客, 虽然不是什么特别难特别复杂的操作, 毕竟自己做的少, 还是害怕错过什么细节, 导致安装失败. 影响集群的运行. 建议大家也这样 : )

### `metrics-server`的垂直伸缩

**非常重要:** 如果你维护的是一个很大的集群, 必须要注意.

每个node, `metrics-server`会消耗`1m CPU + 3M memory`.

具体来说, `metrics-server`会从node和pod收集高达10种指标, 从k8s 1.6开始, 它支持5000个node 和 30个pod/node. 假设它1分钟收集一次指标, 那么每秒就是25000个指标
```
10 x 5000 x 30 / 60 = 25000 metrics per second by average
```

`metrics-server`默认的配置支持的集群规模阈值如下:

|Quantity|Namespace threshold|Cluster threshold|
|-|-|-|
|#Nodes|n/a|100|
|#Pods|7000|7000|
|#Deployments + HPA|100|100|

**注意** 上面说的每个节点上的pod数量限定30个, 如果你的node中存在超过30个pod, 在达到边界值时可能会出现OOM. 所以, kebernetes官方建议我们使用`addon-resizer`作为`metrics-server`的sidecar, 去watch `metrics-server` 并根据集群节点数量动态配置pod的资源配额.

这个配额的计算方式是这样的:
```
cup = base-cpu + n * extra-cup
memory = base-memory + n * extra-memory
```
其中,`base-cpu`和`base-memory`是我们初始给`addon-resizer`设定的一个`cup`和`memory`初始值. 推荐按照100个node标准配置: `base-cpu=100m base-memory=300M`

`extra-cup`和`extra-memory`也是我们设定值, 它表示每增加一个节点`cpu`和`memory`所需要提高值. 上面也说了,对于`metrics-server`来说是 `extra-cpu=1m extra-memory=3M`

当然你也可以给`metrics-server`配置sidecar: , 具体可以参考[kubernetes的github仓库](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/metrics-server)中`metrics-server addons`的内容. 它可以实现自动的垂直伸缩. 无须手动根据集群规模调整资源配额.


### 参考的文档

- kubernetes的官方文档, [Resource metrics pipeline](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-metrics-pipeline/)

- addon-resizer 组件官方介绍, [addon-resizer](https://github.com/kubernetes/autoscaler/tree/master/addon-resizer)