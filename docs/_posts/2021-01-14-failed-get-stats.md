---
layout: post
title: "解决 unknown container /system.slice/docker.service 问题"
categories: diary
---

### 环境

|-|版本|
|-|-|
|os|Ubuntu 18.04.3 LTS|
|kubernetes|v1.17.0|
|docker|19.03.5|

### 问题描述

执行`journalctl -f`, 得到如下错误(摘要):

```
kubelet[468]: E0114 18:06:10.836028     468 summary_sys_containers.go:47]
Failed to get system container stats for "/system.slice/docker.service":
failed to get cgroup stats for "/system.slice/docker.service":
failed to get container info for "/system.slice/docker.service":
unknown container "/system.slice/docker.service"
```

docker 的 cgroup driver 配置为`systemd`

`cat /etc/docker/daemon.json`

{% highlight json %}
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "registry-mirrors" : ["https://thd69qis.mirror.aliyuncs.com"]
}
{% endhighlight %}

kubelet 的 cgroup driver 配置也为`systemd`

```
$ ps -ef | grep kubelet

root       468     1  2 Jan10 ?        03:33:47 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --cgroup-driver=systemd --network-plugin=cni --pod-infra-container-image=k8s.gcr.io/pause:3.1 --resolv-conf=/run/systemd/resolve/resolv.conf
```

可以看到这两个的配置是相同的.

### 分析问题

我阅读了大量的文档, 可以说没有一个能说明白报错的原因.

首先, 这个问题来自 kubelet, 它尝试从`docker.service`获取统计信息, 但是失败了. 

但是, 我发现`docker.service`是存在的.

```
$ cd /sys/fs/cgroup/systemd/system.slice/docker.service
$ ls

cgroup.clone_children  cgroup.procs  notify_on_release  tasks
```

```
$ systemd-cgls

Working directory /sys/fs/cgroup/systemd/system.slice/docker.service:
├─1058 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
└─1253 runc --version
```

这台机器之前因为欠费被停机过一次, 我分析是和 docker 和 kubelet 的启动顺序有关系, 导致获取 docker 的 cgroup 配置失败. 根据官方介绍, 因该先启动 docker 再启动 kubelet, 服务器重启时可能没有按照这个顺序来做. 

### 解决问题

问题搞清楚了, 下面就从两个方面解决这个问题

**1 [可选] 配置kubelet在docker之后启动**

在`/etc/systemd/system/kubelet.service.d/10-kubeadm.conf`文件(不同操作系统位置可能不同)中增加:

```
After=docker.service
ExecStartPre=/bin/sleep 10
```

修改之后为(仅供参考):

```
$ /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
After=docker.service
ExecStartPre=/bin/sleep 10
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
```

这样服务器重启, 就不会出现这样的问题了.

**2 重启kubelet**

如果配置了第一步, 先执行:

`systemctl daemon-reload`

最后执行:

`systemctl restart kubelet`

重启之后, 报错消失.

### 参考链接

[kubernetes/kubeadm/issues/2077](https://github.com/kubernetes/kubeadm/issues/2077)