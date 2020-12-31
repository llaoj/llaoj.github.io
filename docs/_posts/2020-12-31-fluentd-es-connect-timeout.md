---
layout: post
title: "解决fluentd报错: could not push logs to Elasticsearch connect_write timeout reached"
categories: diary
---

#### 报错内容

查看fluentd pod的日志, 主要报错内容如下,

```
kubectl logs -f fluentd-es-v3.1.0-gwckk -n kube-system

suppressed same stacktrace
{
    "chunk":"5b7b819258966e4fe373f2165fe84514",
    "message":"[elasticsearch] taking back chunk for errors. chunk=\"5b7b819258966e4fe373f2165fe84514\""
}
...
failed to flush the buffer. retry_time=13 next_retry_seconds=2020-12-31 03:13:57 868144098402631593/2147483648000000000 +0000 
chunk="5b7b819258966e4fe373f2165fe84514" 
error_class=Fluent::Plugin::ElasticsearchOutput::RecoverableRequestFailure 
error="could not push logs to Elasticsearch cluster (
    {
        :host=>\"172.18.0.139\", 
        :port=>9200, 
        :scheme=>\"http\", 
        :user=>\"elastic\", 
        :password=>\"obfuscated\"
    }): connect_write timeout reached"
```

#### 问题原因

fluent-plugin-elasticsearch 默认每1w次请求会重启连接.(因为这个插件用了很多api, 所以不是指 events 计数 1w). 这种重启机制导致了报错.

#### 解决办法

配置文件`output.conf`中增加如下配置

```
reload_connections false
reconnect_on_error true
reload_on_failure true
```

#### 参考链接

1. [github-issues #525](https://github.com/uken/fluent-plugin-elasticsearch/issues/525)
2. [uken/fluent-plugin-elasticsearch/stopped-to-send-events-on-k8s-why](https://github.com/uken/fluent-plugin-elasticsearch#stopped-to-send-events-on-k8s-why)