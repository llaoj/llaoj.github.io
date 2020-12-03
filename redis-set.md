### Redis Set 主要操作

**命令**

- 1 `SADD key value`

- 2 `SMEMBERS key`

- 3 `SRANDMEMBER key count`

- 4 `SPOP key count`

- 5 `SREM key value` 删除value

- 6 `SCARD key`集合中元素数量


**实现抽奖**

- 1 参加

    `SADD key {userID}`

- 2 所有参与人

    `SMEMBERS key`

- 3 开始抽

    `SRANDMEMBER key 1` -> 1等奖1个 
    这个方法不能排除抽中的人
    `SPOP key 1` -> 1等奖1个, 他后续不会再抽到

还可以实现微信朋友圈点赞功能

![redis-set](/pic/redis-set.png)

**命令**

- 1 `SDIFF set1 set2 set3`

    计算set1 减去 set2 set3 的并集

- 2 `SINTER set1 set2` 交集

- 3 `SUNION set1 set2` 并集

- 4 `SISMEMBER set value` value是否在set中

**实现社交**

- 1 微博/微信共同关注的人
    
    SINTER mySet otherSet -> {}

- 2 我关注的人也关注他

    SISMEMBER othersSet he/her
    ...

- 3 可能认识的人

    SDIFF othersSet mySet -> {}
    别人的关注列表减去我的关注列表得到的集合