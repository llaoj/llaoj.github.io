---
title: "解决执行kubectl命令没有权限"
description: ""
date: "2025-01-08"
menu: "main"
tags:
- "kubernetes"
categories:
- "technology"
---

## 问题描述

反应执行kubectl命令没有权限:

```
$ kubectl get pod -A
Error from server (Forbidden): pods is forbidden: User "kubernetes-admin" cannot list resource "pods" in API group "" at the cluster scope
```
## 解决思路

首先要了解几个文件夹的作用: 

- `/root/.kube/config`: kubectl默认使用的认证文件.
- `/etc/kubernetes/`: 存放kubernetes相关的配置文件、认证文件等.
- `/etc/kubernetes/pki`: 存放kubernetes相关组件的证书密钥文件.

首先通过`ls -lh /root/.kube/config`查看该文件的创建时间.  
然后通过`ls -lh /etc/kubernetes/`查看里面的文件的创建时间, 如果差别挺大, 说明可能是当证书更新/轮转的时候, 没有同步更新`/root/.kube/config`.  
此时, 我们通过将`/etc/kubernetes/super-admin.conf`(名称不一定固定)复制到`/root/.kube/config`即可.

```sh
cp /etc/kubernetes/super-admin.conf /root/.kube/config
```

问题解决!