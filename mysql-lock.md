- 1 mysql 是多线程模型, 可以并发执行处理请求
- 2 innodb支持行锁

```
set autocommit=0; # 关闭自动提交
update t set c1="test" where id=2;
commit;
```

这是一次事物执行, `commit` 之前其他进程是无法修改`id=2` 的这个数据的

- 3 范围锁

```
set autocommit=0;
update t set num=500 where id>1;
commit;
```

`commit`之前, `where`后指定的范围就是锁生效的范围, 之内的所有数据都会被锁定, 其他线程都不能修改, `insert`一条新记录也不行, 因为在范围之内

**原则** 

锁的范围越小越好. 这样对其他线程的影响才会越小


- 4 锁表

myisam 引擎不支持事务, 可以用锁表.

读锁, 当前线程只读, 限制其他线程写,可以读

```
lock table t read;
select * from t; # 成功, 其他线程也成功
insert into t(name, num) values ("t-shirt",100); # 这里会执行失败, 其他线程写操作也失败
unlock tables;
```


写锁, 当前线程可读写, 限制其他线程读写

```
lock table t write;
select * from t;  # 成功, 其他线程不可读写该表
unlock tables;
```


- 5 乐观锁

解释: 乐观一点, 我操作的时候不见得别人操作, 等出现问题再说.

```
set autocommit=0;
select num, version from t where id=1; # 别人可以查

# 比如上面查出version=0
update t set num=num-1, version=version+1 where id=1 and version=0; # 这里要维护一个版本号,从而保证没有别人修改过

commit;
```

如果其他线程在修改的时候, 查到的是上面`update`语句提交执行之前的值, 那么`version`就能很好的避免**超卖**的情况.

**注意**

乐观锁不是数据库自带的，需要我们自己去实现, 就比如上面


- 7 悲观锁

一个有意思的解释: 我们总是担心, 我在操作数据的时候别人也在操作, 很紧张. 那么这样, 当我在查的时候别人就别查了


**注意**

悲观锁, mysql自带, 再细分为: 共享锁 & 排他锁


- 7.1 共享锁  read lock

对于多个不同的事务，对同一个资源共享同一个锁, 使用`lock in share mode`
读取操作创建的锁, 其他用户可以并发读取数据, 但任何事务都不能对数据进行修改（获取数据上的排他锁），直到已释放所有共享锁。

简单来说, 加上共享锁之后, `commit` 提交之前, 其他线程只能读不能修改

```
set autocommit=0;
begin;
SELECT * from TABLE where id = 1  lock in share mode;
insert into TABLE (id,value) values (2,2);
update TABLE set value=2 where id=1;
commit;
```

**应用场景**

```
set autocommit=0;
begin;
select * from parent where id=1 lock in share mode; # 防止我插入子表数据之前, 被人删除或者篡改
insert children(..data from parent..) values (...);
commit;
```

- 7.2 排他锁 exclusive lock / write lock

多个不同的事务，对同一个资源只能有一把锁,  使用`for update`语法. 

```
set autocommit=0;
begin;
select * from t where id=1 for update; # 别人都不能查了
update t set num=num-1 where id=1;
commit;
```

执行完`fro update`, `commit`释放锁之前, 其他事务不能再给这条数据做任何操作, 连查都不能, 阻塞着. 很严格. 

**应用场景**

防止商品超卖