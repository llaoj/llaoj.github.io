---
layout: post
title: "谈一下生产 kubernetes 集群环境的机器配置"
categories: diary
---

网上关于构建生产环境 kubernetes 集群机器配置的文章很少, 我做了大量的调研整理如下,

### cpu 和 memory 配置

**master 节点**

|node 规模|master 规格|
|-|-|
|1~5 nodes|4cpu 8g, 不建议2cpu 4g|
|6~20 nodes|4cpu 16g|
|21~100 nodes|8cpu 32g|
|100~200 nodes|16cpu 64g|

这样的配置能保证 master 节点的负载维持一个较低的水平

**node 节点**

node 节点的配置, 请注意,

1. 尽量不要使用小规格机器, 如果一个容器基本可以占用一个小规格机器, 剩余资源很难利用, 那么就会存在浪费.
2. 可以选择稍大规格的机器, 拉镜像的效率高, 拉一次可以多容器使用
3. 确定集群的使用的**总核数**以及**容错率**
4. 确定 cpu:memory 比例, 对于使用内存比较多的应用, 如Java类应用，建议考虑使用 `1:8` 的机型

```
针对第3点, 比如,
集群总核数有160核，
可以容忍10%的错误, 那么最小选择10台 16cpu 机器，并且高峰运行的负荷不要超过 160*90%=144cpu; 
如果容错率是20%，那么最小选择5台32cpu 机器，并且高峰运行的负荷不要超过 160*80%=128cpu.
这样就算有一台机器出现故障，剩余机器仍可以支持现有业务正常运行

或者, 
如果你选择 40cpu 机器, 希望容错率是20%, 那么应该部署 200cpu 的集群, 包括5台 40cpu 机器, 高峰运行负荷不要超过  200cpu*80%=160cpu
```

### 存储配置

1. 推荐用 ssd 盘
2. 对于 node 节点, 推荐挂载数据盘, 用于存放 docker 镜像. 避免后续镜像过多存储不够用的问题, 运行一段时间之后, 可能有很多无用的镜像, 可以先下线这台机器, 重新构建数据盘之后再上线机器.
3. 磁盘大小: 要根据 node 节点上运行的 pod 数量, 综合 docker 镜像, 容器日志, 系统日志, 其他应用日志, pod 临时数据, 系统预留等一起考虑. 操作系统一般占用约 3g 左右空间, 推荐预留 8g+ 空间. 其他给 kubernetes 相关使用. 
4. 推荐对系统盘和数据盘都做 raid1 (推荐) 或 raid5
   
```
raid1 的数据安全性高, 写快, 磁盘容量损失50%磁盘容量, 适合保存安全性要求比较高的数据, 
raid5 数据读快写慢, 错误恢复成本高, 节省磁盘容量.
```

### 网卡配置

基本上, 现在服务器有千兆和万兆网卡两种, 传输速率分别是, `1000m bit/s` 和 `10g bit/s`.

- 千兆网卡的下载速度是 `1000m/8 ~= 125m`
- 万兆网卡的下载速度是 `10000m/8 ~= 1250m`

如果使用多网卡bond能提高带宽, 建议根据实际业务的量来规划网卡的选择.

### 最后, 举个例子

**仅供参考:** 对于100~200个节点的集群,

|面|数量|cpu mem|storage|网卡|
|-|-|-|-|-|
|master|3|16cpu 64g|ssd `2*400g 2*960g` raid1|2*万兆双口网卡; 业务网络用2口做bond1; 存储网络用2口做bond4 lacp|
|node|100-200|40cpu 256g|ssd `2*400g 2*960g` raid1|同上|

### 推荐阅读

- [RAID磁盘阵列是什么](https://zhuanlan.zhihu.com/p/51170719)
- [高可靠推荐配置](https://help.aliyun.com/document_detail/94292.html?spm=a2c4g.11186623.6.1305.46dd6133r0IU9L)
- [ECS选型](https://help.aliyun.com/document_detail/98886.html?spm=a2c4g.11186623.6.1304.75c619b3OtPhzO)