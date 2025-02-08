---
title: "使用nginx代理harbor并开启ipv4&ipv6双栈"
description: "使用代理服务器部署nginx服务, 代理到harbor所在到服务器上. 用nginx代理harbor. 用户通过nginx服务器的地址访问harbor.
同时, 开通ipv4和ipv6双栈."
date: "2025-02-08"
menu: "main"
tags:
- "harbor"
categories:
- "technology"
---

## 需求

使用代理服务器部署nginx服务, 代理到harbor所在到服务器上. 用nginx代理harbor. 用户通过nginx服务器的地址访问harbor.
同时, 开通ipv4和ipv6双栈.

## 思路

1. 服务器支持双栈: 首先确保涉及的服务器都支持双栈
2. 应用层支持双栈之docker, 因为我们的服务都是跑在docker上的. 所以要配置docker支持双栈. 具体方法参考: https://docs.docker.com/engine/daemon/ipv6/
3. 应用层支持双栈之harbor, 配置harbor支持双栈.
4. 应用层支持双栈之nginx, 这篇文章会详细说.

这篇文章会详细说明第4部的操作方法.

## 实现方法

我们使用docker启动nginx实例:

```sh
docker run -d \
  --restart always \
  --name harborproxy \
  -v /data/nginx/conf.d:/etc/nginx/conf.d \
  -p 30258:30258 \
  --add-host harbor.example.com:<ipv4地址> \
  --add-host harbor.example.com:<ipv6地址> \
  nginx:latest
```

解释: 
- `--add-host`是用来修改容器中的/etc/hosts文件的参数.
- `/data/nginx/conf.d:/etc/nginx/conf.d`映射主机目录到容器中, 我们只需要在主机`/data/nginx/conf.d`目录中写好配置文件即可

下面是我们写的配置文件`/data/nginx/conf.d/proxy.conf`:

```
server {
    listen 30258;
    listen [::]:30258;
    server_name _;

    charset utf-8;
    client_max_body_size 0;
    client_header_timeout 180;
    client_body_timeout 180;
    send_timeout 180;

    proxy_http_version 1.1;
    proxy_connect_timeout 900;
    proxy_send_timeout 900;
    proxy_read_timeout 900;
    proxy_buffering off;
    proxy_request_buffering off;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    location / {
        proxy_pass http://harbor.example.com;
    }
}
```

因为我们配置文件中用到了未在解析服务器上注册的域名`proxy_pass http://harbor.example.com`, 所以我们需要在启动容器的时候增加`--add-host`参数.

配置好之后记得reload下nginx:

```sh
docker exec -t harborproxy nginx -t # 先测试配置文件
docker exec -t harborproxy nginx -s reload # reload配置文件
```

好了下面就测试下结果吧!

## 测试

使用下面的命令就可以测试:

```sh
curl http://ipv4地址:30258/api/v2.0/ping
curl -6  http://[<ipv6地址>]:30258/api/v2.0/ping
```
如果返回`Pong`说明成功!