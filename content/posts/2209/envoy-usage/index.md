---
title: "Envoy的静态配置使用方法"
description: ""
summary: ""
date: "2022-09-15"
bookToC: true
draft: false
tags:
- envoy
categories:
- "technology"
---

## Envoy静态配置

### L4转发

下面的例子是配置4层转发, 将443端口的流量都代理到`www.example.com`对应的后端的443端口上, 如下:

```yaml
static_resources:

  listeners:
  - name: listener_0
    address:
      socket_address:
        protocol: TCP
        address: 0.0.0.0
        port_value: 443
    filter_chains:
    - filters:
      - name: envoy.filters.network.tcp_proxy
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
          stat_prefix: tcp_443
          cluster: cluster_0

  clusters:
  - name: cluster_0
    type: LOGICAL_DNS
    dns_lookup_family: V4_ONLY
    load_assignment:
      cluster_name: cluster_0
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: www.example.com
                port_value: 443
```

## 启动Envoy

将创建的静态配置文件`envoy-custom.yaml`映射到容器内部, 启动:

```sh
docker run -d --name=envoy --restart=always \
    -p 443:443
    -v /root/envoy-custom.yaml:/etc/envoy/envoy.yaml \
    envoyproxy/envoy:v1.22.2
```