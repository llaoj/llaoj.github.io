---
title: "首页"
type: docs
bookComments: false
---

## 一直是一个学生

喜欢技术, 喜欢云原生. 我们的工作/人生需要不断总结和复盘, 归纳整理. 这里是我记录学习过程, 积累经验, 总结工作的地方. 如果恰好对你也有所帮助, 我真的会很高兴. 水平一般, 能力有限, 希望我们能共同进步, 多创造点价值, 多帮助到别人, 不枉此生!

```
package main

import (
    "fmt"
    "math/rand"
    "time"
)

func main() {
    fmt.Println("Hello, world!")
    rand.Seed(time.Now().UnixNano())
    for year := 1; year <= rand.Intn(100); year++ {
        fmt.Println("Learn, Work, Life...")
        fmt.Println("Review")
    }
    fmt.Println("Goodbye, world!")
}

```

## 我平时还做了点小工具和小项目

它们解决了工作中的一个痛点, 能给工作带来便捷, 弥补了行业内一点点的小空缺, 如果你正好需要, 那真太好了!

{{< columns >}}
## OAuth2&SSO

[llaoj/oauth2nsso](https://github.com/llaoj/oauth2nsso) 项目是基于 go-oauth2 打造的**独立**的 OAuth2.0 和 SSO 服务，提供了开箱即用的 OAuth2.0服务和单点登录SSO服务。开源一年多，获得了社区很多用户的关注，该项目多公司线上在用，其中包含上市公司。轻又好用，很稳。

<--->

## KubeFinder

[llaoj/kube-finder](https://github.com/llaoj/kube-finder)是一个独立的容器文件服务器, 可以通过该项目查看集群容器内的文件目录结构, 在指定的目录中上传或者下载文件. 使用golang开发, 直接操作主机 `/proc/<pid>/root` 目录, 速度很快. 这是一个后端项目, 仅提供API.
