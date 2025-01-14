---
title: "在虚拟机上安装APISIX集群"
description: ""
date: "2025-01-14"
menu: "main"
tags:
- "etcd"
categories:
- "technology"
---

我们会在下面三台服务器上部署, 服务器列表:
- 10.61.129.19
- 10.61.129.20
- 10.61.129.21

下面的所有操作需要在上述三台服务器上操作.

## 前置条件-ETCD集群

参考[安装高可用ETCD集群(非https)](/posts/2025/install-etcd-cluster/)完成etcd集群的安装.

## 安装apisix可执行文件

我们使用官方提供的rpm包安装.

```sh
yum install -y https://repos.apiseven.com/packages/centos/apache-apisix-repo-1.0-1.noarch.rpm
yum install apisix-3.2.0 -y
```

安装完成之后, 我们要知道安装的位置, 一些常用的文件夹地址.

```sh
$ ls /usr/local/apisix/
apisix  conf  deps  logs
```
主要包含: 
- `/usr/local/apisix/apisix`: 主要包含apisix运行使用的lua脚本
- `/usr/local/apisix/conf`: apisix配置文件存放位置
  - `/usr/local/apisix/conf/config.yaml`: apisix配置文件, 你的个性化配置都写在这里.
  - `/usr/local/apisix/conf/config-default.yaml`: apisix默认配置, 如果config.yaml中没有配置的项目, 会使用这里的配置.

## 编辑配置文件

```sh
cat > /usr/local/apisix/conf/config.yaml <<EOF
deployment:
  role: traditional
  role_traditional:
    config_provider: etcd
  etcd:
    user: root
    password: etcNq@YfPd21de
    host:
      - "http://10.61.129.19:2379"
      - "http://10.61.129.20:2379"
      - "http://10.61.129.21:2379"
  admin:
    admin_key:
      - name: admin
        key: dahdd9f034335f136f87ad84b625c8f1
        role: admin
    allow_admin:
      - 0.0.0.0/0

apisix:
  node_listen: 80
  ssl:
    enable: true
    listen: 
      - port: 443
        enable_http2: true
  enable_admin: true
  stream_proxy:
    tcp:
      - 3306
      - 30000-32767
EOF
```

**说明:** 
1. admin.admin_key.key: 是通过api调用apisix管理接口的认证token. 为了安全, 注意不要泄露, 不要使用固定的. 要经常更换.
2. stream_proxy.tcp: 预先配置了一些端口, 让apisix提前监听这些端口. 是为了后期可以通过apisix api直接添加端口监听配置, 而不用重启apisix.
  
## 启动apisix服务

配置开机自启动, 并启动apisix.

```sh
systemctl enable apisix
systemctl start apisix
```

## [可选]部署apisix-dashboard服务

这个服务是apisix提供的一个比较简陋的UI管理界面, 配置apisix使用起来方便, 建议安装.

```sh
# 因为网络防火墙的原因, github上的rpm包下载很慢, 我将其转移到了国内.
# 使用下面的rpm包速度更快
yum install -y https://llaoj.oss-cn-beijing.aliyuncs.com/files/github.com/apache/apisix-dashboard/releases/download/v3.0.1/apisix-dashboard-3.0.1-0.el7.x86_64.rpm
```
这样dashboard被安装在`/usr/local/apisix/dashboard/`目录中.  
`/usr/local/apisix/dashboard/conf`中存了配置文件.

### 修改配置文件

对照内容修改配置文件`/usr/local/apisix/dashboard/conf/conf.yaml`.

```sh
conf:
  # 默认只能本机127.0.0.1
  # 修改为可以被其他主机访问
  allow_list:
    - 0.0.0.0/0
  etcd:
    endpoints:
      - 10.61.129.19:2379
      - 10.61.129.20:2379
      - 10.61.129.21:2379
    # 因为我们部署的etcd是有账号密码的
    # 配置etcd访问的用户名和密码
    username: "root"
    password: "etcNq@YfPd21de"
```

Dashboard默认提供了两个用户(账号/密码): `admin/admin` 和 `user/user`. 你可以在conf.yaml中修改.

### 启动系统服务

```sh
systemctl enable apisix-dashboard
systemctl start apisix-dashboard
```

其实dashboard可以只部署在一台vm上. 但是如果想做高可用, 3台服务器都可部署apisix-dashboard.

## 总结

使用rpm包安装apisix, 关键在配置, 读懂每个配置项目的意义, 很重要! 然后知道常用的目录的位置和存储的内容.  
安装软件不要只是单纯的安装然后可以访问就完成了. 对该软件的架构和配置都要有一定的理解. 这样后面的配置更新/架构升级等, 才能做到游刃有余.  

最后, 完整的结果信息:
- apisix api地址: http://10.61.129.19:9180,http://10.61.129.20:9180,http://10.61.129.20:9180
  - api key: dahdd9f034335f136f87ad84b625c8f1
- dashboard: http://10.61.129.19:9000
  - 账号/密码:
    - admin/admin
    - user/user
- L7层http: 80端口, 10.61.129.19-21三个地址都可以访问
- L7层https: 443端口, 10.61.129.19-21三个地址都可以访问

## 后续

我们部署了三个apisix实例, 并没有提供三个实例的负载均衡. 需要你配置一个外部负载均衡器来完成这个功能.