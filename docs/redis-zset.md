zset和set差不多, 每一个元素多了一个score

**实现排行榜**

- 1 点击新闻

    相关命令: `ZINCRBY key increment member`

    比如: `ZINCRBY hotnews:20201111 1 {newsID}`

- 2 获取榜单

    相关命令 `ZREVRANGE key start stop [WITHSCORES]` 

    比如: `ZREVRANGE hotnews:20201111 0 9` 获取top10

- 3 七日排行榜计算

    相关命令: `ZUNIONSTORE destination numkeys key [key ...] [WEIGHTS weight [weight ...]] [AGGREGATE SUM|MIN|MAX]`

    比如: `ZUNIONSTORE hotnews:day1-7 7 day1 day2 ... day7`

**其他**

- 摇一摇 附近的人

- 布隆过滤器

- 搜索自动补全

...