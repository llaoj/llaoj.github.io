---
weight: 6
title: "KubeFinder"
---

![KubeFinder](https://github.com/llaoj/kube-finder/raw/main/docs/logo.png)

项目地址: https://github.com/llaoj/kube-finder

一个独立的容器文件服务器, 可以通过该项目查看容器内(namespace/pod/container)的文件目录结构/列表, 下载文件或者上传文件到指定目录中. 使用golang开发, 直接操作主机 `/proc/<pid>/root` 目录, 速度很快.

这是一个后端项目, **仅提供API**, 前端对接之后可以是这样的

![fileserver1](https://github.com/llaoj/kube-finder/raw/main/docs/fileserver1.png)

也可以是这样的：

![fileserver2](https://github.com/llaoj/kube-finder/raw/main/docs/fileserver2.png)

项目名取自MacOS Finder, 希望它像Finder一样好用.