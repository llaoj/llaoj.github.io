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

下面这个脚本提供了etcdctl连接etcd所需要的断点、证书相关的信息, 能快速或许并调用命令查看, 这个脚本需要在master节点上执行:

```shell
#!/bin/bash

ENDPOINTS=$(pgrep kube-apiserver | grep -P 'etcd-servers=(.*?)\s' -o | awk -F= '{print $2}')
CACERT=$(pgrep kube-apiserver | grep -P 'etcd-cafile=(.*?)\s' -o | awk -F= '{print $2}')
CERT=$(pgrep kube-apiserver | grep -P 'etcd-certfile=(.*?)\s' -o | awk -F= '{print $2}')
KEY=$(pgrep kube-apiserver | grep -P 'etcd-keyfile=(.*?)\s' -o | awk -F= '{print $2}')

ETCDCTL_API=3 etcdctl --endpoints="$ENDPOINTS" --cacert="$CACERT" --key="$KEY" --cert="$CERT" "$@"
```	

或者, 使用这个命令一键下载脚本:

```sh
curl -o ./etcdctl.sh {{<baseurl>}}posts/2208/kubernetes-etcdctl-usage/etcdctl.sh \
  && chmod +x ./etcdctl.sh
```

好了, 我们已经把证书都提前配置好了. 下面可以直接使用`etcdctl.sh`命令了, 比如:

```shell
./etcdctl.sh --prefix=true get /...
```