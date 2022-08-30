---
title: "使用etcdctl查看kubernetes存储的内容"
description: ""
summary: ""
date: "2022-08-29"
bookToC: true
draft: false
tags:
- etcd
categories:
- "technology"
---

下面这个脚本提供了etcdctl连接etcd所需要的断点、证书相关的信息, 能快速或许并调用命令查看, 这个脚本需要在master节点上执行:

```shell
#!/bin/bash

ENDPOINTS=$(ps -ef | grep kube-apiserver | grep -P 'etcd-servers=(.*?)\s' -o | awk -F= '{print $2}')
CACERT=$(ps -ef | grep kube-apiserver | grep -P 'etcd-cafile=(.*?)\s' -o | awk -F= '{print $2}')
CERT=$(ps -ef | grep kube-apiserver | grep -P 'etcd-certfile=(.*?)\s' -o | awk -F= '{print $2}')
KEY=$(ps -ef | grep kube-apiserver | grep -P 'etcd-keyfile=(.*?)\s' -o | awk -F= '{print $2}')

alias etcdctl='ETCDCTL_API=3 etcdctl --endpoints=${ENDPOINTS} --cacert=${CACERT} --key=${KEY} --cert=${CERT} -w=json'
```	

好了下面可以直接使用`etcdctl`命令了, 比如:

```shell
etcdctl --prefix=true get /...
```