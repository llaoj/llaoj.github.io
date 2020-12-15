layout: page
title: "常见mq产品对比"
permalink: /mq/

## mq

### 常见mq产品对比

- kafka: 100wtps, 多用于日志收集分析
- rocketmq: 50w tps, 消息0丢失
- rabbitmq: <=10w tps, 但是社区活跃, 会有消息丢失的.

### 

- 定时任务扫描

传统的cron模式, 存在延迟. 

可以订阅`redis`的`key`失效的`event: notify-keyspace-envents`, 然后去执行业务代码. 但是,
  
- 这个办法存在消息丢失的问题, 因为redis不保证一定投递到, 只发送一次, 
- 而且, 因为redis是单线程, key失效到通知也会存在延迟.
- 还有, 所有客户端都会收到envent

rocketmq特性

- ack机制, 保证消息至少投递一次, 不丢失
- 延时投递, 但是延时消息太多, 因为是单线程搬运(中转状态->投递状态), 会存在消息积压, 会有延时