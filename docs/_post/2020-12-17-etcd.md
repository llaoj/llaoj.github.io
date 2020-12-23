layout: page
title: "常见mq产品对比"
permalink: /mq/

## etcd 介绍

- 诞生于CoreOS
- v3版本的etcd: 每秒1w的写入速度
- Raft一致性算法选举leader
- quorum=(n+1)/2
  - 允许超过半数节点故障

## 属性介绍
- 全局版本号
  - leader切换 term值就会+1
  - revision数据发生变更就+1