---
layout: post
title: "debian 10 buster更换国内清华apt软件源 提高安装速度"
categories: diary
---

国内访问国外的软件源速度非常慢, 可以替换成国内的, 清华源,163源做的都比较好. 下面使用清华源替换. debian 的软件源配置文件是 `/etc/apt/sources.list`。先将系统自带的该文件做个备份:

{% highlight shell %}
cp /etc/apt/sources.list /etc/apt/sources.list.bak
{% endhighlight %}

### 方法1: 一个命令

{% highlight shell %}
sed -i 's#http://deb.debian.org#http://mirrors.tuna.tsinghua.edu.cn#g' /etc/apt/sources.list
{% endhighlight %}

### 方法2: 将文件替换成下面内容

将该文件替换为下面内容, 即可使用 TUNA 的软件源镜像

{% highlight shell %}
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ buster main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-updates main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-updates main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-backports main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-backports main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security buster/updates main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security buster/updates main contrib non-free
{% endhighlight %}

如果遇到无法拉取 https 源的情况，请先使用 http 源并安装：

{% highlight shell %}
$ sudo apt install apt-transport-https ca-certificates
{% endhighlight %}

### 测试一下

{% highlight shell %}
root@bda4c66d6be9:/go# apt update
Hit:1 http://mirrors.tuna.tsinghua.edu.cn/debian buster InRelease
Hit:2 http://mirrors.tuna.tsinghua.edu.cn/debian buster-updates InRelease
Hit:3 http://security.debian.org/debian-security buster/updates InRelease
Reading package lists... Done
Building dependency tree
Reading state information... Done
2 packages can be upgraded. Run 'apt list --upgradable' to see them.
{% endhighlight %}

可以看到已经切换为清华源了.

### 参考链接

[mirrors.tuna.debian](https://mirrors.tuna.tsinghua.edu.cn/help/debian/)