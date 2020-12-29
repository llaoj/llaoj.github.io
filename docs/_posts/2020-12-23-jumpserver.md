---
layout: post
title: "手动搭建jumpserver-v2.6.1"
categories: diary
---

- [环境](#环境)
- [为什么手动搭建呢?](#为什么手动搭建呢)
- [第一步, 下载安装包](#第一步-下载安装包)
- [第二步, 预配置](#第二步-预配置)
- [第三步, 安装并配置docker & docker-compose](#第三步-安装并配置docker--docker-compose)
- [第四步, 部署命令](#第四步-部署命令)
- [第五步, 验证](#第五步-验证)

### 环境

|-|版本|
|-|-|
|os|centos 7.7.1908|
|jumperserver|v2.6.1|
|docker|Community 19.03.13|

### 为什么手动搭建呢?

jumpserver很流行, 免费开源, 最近公司也要搭建堡垒机, 所以就准备也搭建一套jumpserver. 但官方只提供了自动化搭建的脚本, 几个命令就搞定了. 除了基础的服务器配置要求之外, 还要求一台纯净的centos机器, 显然我不满足, 我司资源有限, 没有太多机器. 只能在一台安装了docker和java环境的机器上安装,
因为对官方的脚本不了解, 使用官方提供的自动化脚本害怕会影响其他服务, 或者出现很多阻碍, 所以决定, 阅读自动化脚本, 自己手动安装.

### 第一步, 下载安装包

```
wget https://github.com/jumpserver/installer/releases/download/v2.6.1/jumpserver-installer-v2.6.1.tar.gz
tar -xf jumpserver-installer-v2.6.1.tar.gz
cd jumpserver-installer-v2.6.1

# 这一步是设置 docker image 的大仓库
export DOCKER_IMAGE_PREFIX=docker.mirrors.ustc.edu.cn
```

### 第二步, 预配置

```
mkdir /opt/jumpserver
cp -r config_init /opt/jumpserver/config
cp config-example.txt /opt/jumpserver/config/config.txt
```

下面需要仔细阅读`/opt/jumpserver/config/config.txt`配置文件, 根据自己的实际情况进行配置

包括如下:

- 是否启用ipv6, 默认是否, `USE_IPV6=0`
- 设置`SECRET_KEY=`, 可以使用`ip a | tail -10 | base64 | head -c 49`命令生成
- 设置`BOOTSTRAP_TOKEN=`, 可以使用`ifconfig | tail -10 | base64 | head -c 16`命令生成 
- 设置持久化卷存储目录`VOLUME_DIR=`, 比如`VOLUME_DIR=/data/jumpserver`
- 设置mysql信息, 为了避免不必要的麻烦, 使用自带的mysql和redis. 
  
最后总结, 需要注意修改的配置如下:

```
USE_IPV6=0

### 持久化目录, 安装启动后不能再修改, 除非移动原来的持久化到新的位置
VOLUME_DIR=/data/jumpserver
...
# Core 配置
### 启动后不能再修改，否则密码等等信息无法解密
SECRET_KEY=MjogZXRoMDogPEJST0FEQ0FTVCxNVUxUSUNBU1QsVVAsTE9XR
BOOTSTRAP_TOKEN=ICAgICAgICBUWCBw
...
## 是否使用外部MYSQL和REDIS
USE_EXTERNAL_MYSQL=0
USE_EXTERNAL_REDIS=0
...
## MySQL数据库配置
DB_ENGINE=mysql
DB_HOST=mysql
DB_PORT=3306
DB_USER=root
DB_PASSWORD=随机26位字符
DB_NAME=jumpserver

## Redis配置
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=随机26位字符
...
# Mysql 容器配置
MYSQL_ROOT_PASSWORD=同上DB_PASSWORD
MYSQL_DATABASE=jumpserver
```

### 第三步, 安装并配置docker & docker-compose

具体安装这一步我就不介绍了, 原来我机器上已经安装了. 注意安装时候不要低于jumpserver要求的版本:

```
DOCKER_VERSION=18.06.2-ce
DOCKER_COMPOSE_VERSION=1.27.4
```

下面是关于docker的配置:

修改`/etc/docker/daemon.json`文件, 如下:

```
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "data-root": "/data/docker",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "registry-mirrors" : ["https://thd69qis.mirror.aliyuncs.com"]
}

```

重点关注`data-root`, `log-driver`, `log-opts` 三个配置, 其中`data-root`位docker的存储目录, 会存一些镜像和容器相关的文件, 选择主机上比较大的一块盘, 其他的按照自己情况来配置. 改完别忘了重启docker.

### 第四步, 部署命令

由于我们没有使用提供的ipv6,lb,xpack, 所以我们只需要部署以下三个yaml. 他们分别提供了应用,网络和任务的部署清单.

jms-start.sh
```
#!/bin/bash

export VERSION="v2.6.1"
export CONFIG_DIR=/opt/jumpserver/config
export CONFIG_FILE=$CONFIG_DIR/config.txt
export HTTP_PORT=8080
export HTTPS_PORT=8443
export SSH_PORT=2222
export VOLUME_DIR=/data/jumpserver
export DOCKER_SUBNET=192.168.250.0/24
export REDIS_PASSWORD=上面配置的REDIS_PASSWORD值

docker-compose -f ./compose/docker-compose-app.yml \
-f ./compose/docker-compose-network.yml \
-f ./compose/docker-compose-task.yml \
-f ./compose/docker-compose-mysql.yml \
-f ./compose/docker-compose-redis.yml up -d
```

### 第五步, 验证

浏览器访问`http://host-ip:8080`
