

执行`journalctl -f`, 得到如下错误:

```
kubelet[468]: E0114 18:06:10.836028     468 summary_sys_containers.go:47] \
Failed to get system container stats for "/system.slice/docker.service": \
failed to get cgroup stats for "/system.slice/docker.service": \
failed to get container info for "/system.slice/docker.service": \
unknown container "/system.slice/docker.service"
```

分析日志, 首先是kubelet报错, 它获取容器和cgroup的分析数据失败.