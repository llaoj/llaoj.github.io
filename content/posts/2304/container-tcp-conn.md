---
title: "通过shell脚本扫描从Kubernetes节点往外的tcp请求"
description: "由于Kubernetes中部署的服务队外发起的tcp请求很难监控, 最近数据库运维在排查来自集群的大量数据库请求, 网络层只能看到来自哪个Kubernetes节点主机. 所以写了下面这个脚本来定时扫描."
summary: "由于Kubernetes中部署的服务队外发起的tcp请求很难监控, 最近数据库运维在排查来自集群的大量数据库请求, 网络层只能看到来自哪个Kubernetes节点主机. 所以写了下面这个脚本来定时扫描."
date: "2023-04-04"
bookToC: false
draft: false
tags:
- kubernetes
categories:
- "technology"
---

由于Kubernetes中部署的服务队外发起的tcp请求很难监控, 最近数据库运维在排查来自集群的大量数据库请求, 网络层只能看到来自哪个Kubernetes节点主机. 所以写了下面这个脚本来定时扫描.

```sh
#! /bin/bash

set -ex

filter=$1
test -n "$filter"
echo "过滤字符串: $filter"

resultDir="/tmp/container_tcp_conn"
test ! -d "$resultDir" && mkdir $resultDir
cd $resultDir || return

if command -v docker >/dev/null 2>&1; then
    whichPid="docker inspect -f {{.State.Pid}} {}"
else
    whichPid="crictl inspect {} | jq .info.pid"
fi

cantainer_tcp_conn() {
    containers=$(crictl ps | awk '{print $1}' | grep -v CONTAINER)
    for container in $containers; do
        pid=$(echo "$container" | xargs -I {} /bin/sh -c "$whichPid")
        output=$(crictl inspect "$container" | grep "logPath" | awk -F "/" '{print $5"_"$6}')
        {
            printf "[%s] start scanning...\n" "$(date +'%Y-%m-%d %H:%M:%S')"
            nsenter -t "$pid" -n ss -natup | grep "$filter" || true
        } >>"$output"
    done
}

cantainer_tcp_conn
```

解释一下:

> 1. 为了避免疯狂输出文件, 必须添加过滤字符串
> 2. 根据节点是否有docker命令来选择获取pid的方式
> 3. 每次扫描都会记录时间
> 4. 进入容器的网络namespace使用ss命令获取tcp连接信息

你可以这样执行上面的脚本:

```sh
./container_tcp_conn.sh ip地址:端口号
```

把它部署到cron中每分钟/几分钟定期扫描, 应该就能发现请求的容器. 比如:

```
*/2 20 * * * /root/container_tcp_conn.sh 10.206.97.239:3317 >/dev/null 2>&1
```

最后, 通过执行下面的命令, 你应该就能看到具体是哪个pod哪个容器请求的你关注的主机和端口号:

```sh
grep -rn "关键词" /tmp/container_tcp_conn
```