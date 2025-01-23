---
title: "安装高可用ETCD集群(非https)"
description: "安装1个etcd集群要求:- 三台服务器- 开启auth认证- 使用http, 不使用https加密- 开启用户名/密码认证,因为我们部署的是内部的可信的服务, 而且只局限在三台服务器中使用, 给apisix做存储使用. 为了简化部署, 减少管理证书的复杂性. 我没有开启https. 注意, 这里的PEER ADDRS是集群内部不同的ETCD实例之间通讯的地址, 使用的是端口2380. 而CLIENT ADDRS/ENDPOINT是指ETCD对外提供服务的地址, 监听2379端口."
date: "2025-01-14"
menu: "main"
tags:
- "etcd"
categories:
- "technology"
---

安装1个etcd集群要求:
- 三台服务器
- 开启auth认证
- 使用http, 不使用https加密
- 开启用户名/密码认证

因为我们部署的是内部的可信的服务, 而且只局限在三台服务器中使用, 给apisix做存储使用. 为了简化部署, 减少管理证书的复杂性. 我没有开启https.

## 服务器情况

服务器三台, IP地址分别为: 10.61.129.19-21. centos7.9的操作系统.

## 本节需要在每一台服务器上执行

### 部署可执行文件

将etcd安装在`/data/etcd/`目录中.

```sh
yum install -y wget
cd /tmp
wget https://llaoj.oss-cn-beijing.aliyuncs.com/files/github.com/etcd-io/etcd/releases/download/v3.5.16/etcd-v3.5.16-linux-amd64.tar.gz
tar zxf etcd-v3.5.16-linux-amd64.tar.gz 
mkdir /data/etcd/{bin,conf,data,log} -p
mv etcd-v3.5.16-linux-amd64/{etcd,etcdctl} /data/etcd/bin/
cd /data/etcd/conf/
```

### 部署配置文件

因为是三台服务, 要根据每台服务器的IP地址修改配置文件, 下面的脚本可以动态发现IP地址, 一键执行.

```sh
NODE_IP=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
ETCD_NAME=etcd-${NODE_IP//./-}

cat > /data/etcd/conf/etcd.conf <<EOF
[Member]
ETCD_NAME="$ETCD_NAME"
ETCD_DATA_DIR="/data/etcd/data" 
ETCD_LISTEN_PEER_URLS="http://$NODE_IP:2380"
ETCD_LISTEN_CLIENT_URLS="http://$NODE_IP:2379"

[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://$NODE_IP:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://$NODE_IP:2379"
ETCD_INITIAL_CLUSTER="etcd-10-61-129-19=http://10.61.129.19:2380,etcd-10-61-129-20=http://10.61.129.20:2380,etcd-10-61-129-21=http://10.61.129.21:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-token"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF
```

### 部署系统服务

下面的命令可以直接执行, 无需修改.

```sh
cat > /usr/lib/systemd/system/etcd.service <<EOF
[Unit]
Description=Etcd Server
After=network-online.target
Wants=network-online.target
 
[Service]
Type=notify
EnvironmentFile=/data/etcd/conf/etcd.conf
ExecStart=/data/etcd/bin/etcd --log-outputs=/data/etcd/log/etcd.log --log-level=info --auto-compaction-retention=1 --quota-backend-bytes=8388608000
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
 
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable etcd.service
systemctl restart etcd.service
systemctl status etcd
```

刚开始启动服务，先启动的服务会卡一下，等待其他ETCD服务启动之后, 集群就正常了.

至此, 部署基本完成, 还需要使用etcdctl对etcd进行一些简单的配置.

## 本节只需要执行一次

### 集群状态查询

查看所有端点的列表:

```sh
/data/etcd/bin/etcdctl -w table \
  --endpoints="http://10.61.129.19:2379,http://10.61.129.20:2379,http://10.61.129.21:2379" \
  endpoint status

# 输出
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|         ENDPOINT         |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| http://10.61.129.19:2379 | c7cd61fc0d86bc44 |  3.5.16 |   20 kB |      true |      false |         5 |         18 |                 18 |        |
| http://10.61.129.20:2379 | 46574707029bb1c9 |  3.5.16 |   20 kB |     false |      false |         5 |         18 |                 18 |        |
| http://10.61.129.21:2379 | 3baf5e1353c7e837 |  3.5.16 |   20 kB |     false |      false |         5 |         18 |                 18 |        |
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

查看集群中所有的成员

```sh
/data/etcd/bin/etcdctl -w table \
  --endpoints="http://10.61.129.19:2379,http://10.61.129.20:2379,http://10.61.129.21:2379" \
  member list

# 输出
+------------------+---------+-------------------+--------------------------+--------------------------+------------+
|        ID        | STATUS  |       NAME        |        PEER ADDRS        |       CLIENT ADDRS       | IS LEARNER |
+------------------+---------+-------------------+--------------------------+--------------------------+------------+
| 3baf5e1353c7e837 | started | etcd-10-61-129-21 | http://10.61.129.21:2380 | http://10.61.129.21:2379 |      false |
| 46574707029bb1c9 | started | etcd-10-61-129-20 | http://10.61.129.20:2380 | http://10.61.129.20:2379 |      false |
| c7cd61fc0d86bc44 | started | etcd-10-61-129-19 | http://10.61.129.19:2380 | http://10.61.129.19:2379 |      false |
+------------------+---------+-------------------+--------------------------+--------------------------+------------+
```

> 注意, 这里的PEER ADDRS是集群内部不同的ETCD实例之间通讯的地址, 使用的是端口2380. 而CLIENT ADDRS/ENDPOINT是指ETCD对外提供服务的地址, 监听2379端口.

### [可选]开启身份验证

刚安装的集群默认是关闭认证的, 查看认证状态:

```sh
/data/etcd/bin/etcdctl \
  --endpoints="http://10.61.129.19:2379,http://10.61.129.20:2379,http://10.61.129.21:2379" \
  auth status

Authentication Status: false
AuthRevision: 1
```

下面我们开启auth认证, 下面的这一步是可选的. 不操作也行.

1. 创建root用户

执行后, 会提示输出密码，并确认密码.

```sh
/data/etcd/bin/etcdctl \
  --endpoints="http://10.61.129.19:2379,http://10.61.129.20:2379,http://10.61.129.21:2379" \
  user add root
```

2. 给用户并赋予root角色

etcd默认存在一个root权限, 具有最高权限. 我们使用该角色.

```sh
/data/etcd/bin/etcdctl \
  --endpoints="http://10.61.129.19:2379,http://10.61.129.20:2379,http://10.61.129.21:2379" \
  user grant-role root root
```

3. 开启身份认证

```sh
/data/etcd/bin/etcdctl \
  --endpoints="http://10.61.129.19:2379,http://10.61.129.20:2379,http://10.61.129.21:2379" \
  auth enable
```

开启认证之后, 上面的etcdctl命令需要增加`--user=root --password='password'`选项, 才可以访问. 否则会提示没有权限.

4. 使用账号密码查询身份认证状态

我们使用刚创建的root用户来查询etcd的认证状态

```sh
/data/etcd/bin/etcdctl \
  --endpoints="http://10.61.129.19:2379,http://10.61.129.20:2379,http://10.61.129.21:2379" \
  --user=root --password='password' \
  auth status
```

至此, 所有部署完成.

## 总结

就是先在每个节点上安装可执行文件, 配置好配置文件, 然后使用系统服务的方式启动. 等三台服务器都安装启动完毕, 就算安装成功了.   
最后需要使用etcdctl与etcd集群交互, 来开启auth认证. 其实这一步不执行也行, 就是安全性稍微高一点.