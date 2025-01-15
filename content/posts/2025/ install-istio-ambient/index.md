---
title: "国内网络环境安装Istio Ambient"
description: ""
date: "2025-01-15"
menu: "main"
tags:
- "harbor"
categories:
- "technology"
---

这篇文章的主要目的是解决国内安装istio ambient速度比较慢、甚至是失败的问题. 因为国内防火墙的原因, 有些资源是拉不到或者速度很慢的.

安装之前需要有一套kubernetes集群, 集群的版本为`1.28, 1.29, 1.30, 1.31`

## 下载Istio CLI

截止目前最新的Istio稳定版本为: `1.24.2`, 我们今天就安装它.
Istio通过istioctl来配置/安装的. 现在我们需要下载它, 以及一些样例应用:

```sh
# 目前只支持1.24.2版本
curl -s {{<baseurl>}}posts/2025/install-istio-ambient/download-istio.sh | bash -s -- 1.24.2
cd istio-1.24.2
export PATH=$PWD/bin:$PATH
```

使用下面的命令检查一下版本, 现在Istio还没有安装:

```sh
istioctl version
Istio is not present in the cluster: no running Istio pods in namespace "istio-system"
client version: 1.24.2
```
