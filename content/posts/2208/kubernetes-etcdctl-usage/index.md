---
title: "使用etcdctl查看kubernetes存储的内容"
description: ""
summary: ""
date: "2022-08-29"
bookToC: false
draft: false
tags:
- etcd
categories:
- "technology"
---

下面这个脚本提供了etcdctl连接etcd所需要的端点、证书相关的信息. 这个脚本需要在master节点上执行:

```sh
curl -o ./etcdctl.sh {{<baseurl>}}posts/2208/kubernetes-etcdctl-usage/etcdctl.sh \
  && chmod +x ./etcdctl.sh
```

好了, 我们已经把证书都提前配置好了. 下面可以直接使用`etcdctl.sh`命令了, 比如:

```shell
# 获取所有的Key
./etcdctl.sh get --keys-only --from-key ""
# 获取指定Key的内容
./etcdctl.sh get /registry/clusterroles/cluster-admin | auger decode
```