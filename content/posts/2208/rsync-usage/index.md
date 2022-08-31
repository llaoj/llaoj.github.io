---
title: "使用rsync在主机之间同步目录"
description: ""
summary: ""
date: "2022-08-30"
bookToC: true
draft: false
tags:
- rsync
categories:
- "technology"
---

## rsync安装

在传输双方的服务器上都安装rsync软件. 如果服务器上有rsync可以跳过.

先检查有没有安装rsync:

```shell
rsync -v
```

如果没有安装, 使用下面的命令安装:

```shell
# Debian
sudo apt-get install rsync

# Red Hat
sudo yum install rsync

# Arch Linux
sudo pacman -S rsync
```

## 启动rsync守护进程

rsync使用最多的是ssh模式. 在现代的公司中, 出于安全的原因, 很多ssh是被禁止使用的. 所以, 我们可以使用rsync的守护进程模式. 一起看看怎么用吧.

rsync守护进程部署在传输双方(发送方或者接受方)的任何一端都可以的. 

下面的配置和命令中, 我以发送方(`10.138.228.201`)和接收方(`10.206.38.30`)为例.

我选择接收方, 先部署配置文件. 配置文件地址: `/etc/rsyncd.conf`. 配置文件[官方参考手册](https://linux.die.net/man/5/rsyncd.conf)

以下是一个参考的配置, 每一项配置我都增加了备注说明:

```shell
# 指定rsync以什么用户/组传输文件
# 默认nobody,如果使用了系统不存在的用户和组
# 需要先手动创建用户和组
# 它会是生成的文件所属的用户和组
# 也可以把它们配置到模块中
uid = root
gid = root

# 选择yes可以在操作模块时chroot到同步目录中
# 优势是面对安全威胁能提供额外保护
# 缺点是使用chroot需要root权限,
# 以及在传输符号连接或保存用户名/组时会有些问题
use chroot = no

# 指定监听端口
# 默认873
port = 873

# 最大连接数
max connections = 200
# 超时时间
timeout = 600

# 进程pid所在的文件
pid file = /var/run/rsyncd.pid
# 多连接时所用的锁
lock file = /var/run/rsyncd.lock
# 出错的日志文件
log file = /var/log/rsyncd.log

# 忽略错误
ignore errors = true
read only = false
# 是否允许查看module列表
list = false

# 允许的客户端IP
hosts allow = 10.138.228.201
hosts deny = 0.0.0.0/32

# rsync认证用的用户
auth users = rsync
# 认证用户对应的密码文件
secrets file = /etc/rsyncd.secrets

# 排除目录,空格分隔
# 可以配置到特定的模块上
# 如果没有需要排除的目录可以不用写
# exclude=tmp etc

# 模块的定义,它是暴露的一个目录
[test]
# 需要同步的目录
# 该目录必须要是存在的,如果没有请创建
path = /opt/test/
# 模块的备注说明,展示用
comment = test
```

然后配置认证用户密码文件, 文件路径在上述配置文件中指定`/etc/rsyncd.secrets`:

```shell
echo "rsync:6j_ioU1xA" > /etc/rsyncd.secrets
# rsync对密钥文件的权限有要求
# 仅文件拥有者可以读写
chmod 600 /etc/rsyncd.secrets
```

通过shell运行以下命令启动守护进程:

```shell
rsync --daemon
```

查看是否启动成功, 且已经开始监听端口:

```shell
$ ss -apnl | grep 873
tcp    LISTEN     0      5         *:873          *:*       users:(("rsync",pid=20945,fd=4))
tcp    LISTEN     0      5      [::]:873       [::]:*       users:(("rsync",pid=20945,fd=5))
```

启动成功~

## 开始传输

登录到发送方, 使用下面的命令开始传输目录文件:

```shell
# 创建密码文件避免手输密码
echo "6j_ioU1xA" > /etc/rsync.password
chmod 600 /etc/rsync.password
# 开始同步文件到10.206.38.30
rsync -avzP /opt/test/ rsync@10.206.38.30::test --password-file=/etc/rsync.password
```

参数说明:

```shell
-a, --archive               存档模式,等同于 -rlptgoD (no -H,-A,-X)
-r, --recursive             递归进入文件夹
-l, --links                 拷贝符号连接到符号连接
-p, --perms                 文件权限保持一致
-t, --times                 文件修改时间保持一致
-g, --group                 组保持一致
-o, --owner                 用户保持一致 
-D                          等同于 --devices --specials
    --devices               设备文件保持一致
    --specials              特殊文件保持一致
-v, --verbose               显示更多的输出信息
-z, --compress              传输期间压缩文件
-P                          等同于 --partial --progress
    --progress              显示传输进度
    --partial               保留部分传输(没传输完成)的文件
```

执行完成之后, 文件就会从当前机器拷贝到`10.206.38.30`上了.

创建一个定时同步的任务, 每隔2小时同步一次:

```shell
cat >> /var/spool/cron/root <<EOF

# export dce hostpath to vm
0 */2 * * * /bin/rsync -avzP /opt/test/ rsync@10.206.38.30::storage --password-file=/etc/rsync.password > /tmp/rsync-`date +"\%Y\%m\%d"`.log 2>&1
EOF
```