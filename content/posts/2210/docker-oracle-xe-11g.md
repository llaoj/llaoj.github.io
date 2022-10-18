---
title: "使用docker运行orcale xe 11g"
description: ""
summary: ""
date: "2022-10-18"
bookToC: true
draft: false
tags:
- docker
- oracle
categories:
- "technology"
---

**注意**: 根据自己实际情况, 替换下面名利中的`<var>`变量.

## 启动orcale xe 11g容器

Oracle Database XE是人人都可免费使用的 Oracle 数据库. Oracle Database XE 支持最高:

- 最多 12 GB 的用户磁盘数据
- 最大 2 GB 的数据库 RAM
- 最多 2 个 CPU 线程 

产品介绍地址: https://www.oracle.com/cn/database/technologies/appdev/xe.html

Oracle Database XE支持容器化部署, 镜像项目地址(这里面也有详细使用文档): https://hub.docker.com/r/oracleinanutshell/oracle-xe-11g

```shell
docker run -d \
  --name=oracle-xe-11g \
  --restart=always \
  -p 31521:1521 \
  -p 38080:8080 \
  -v /data/oracle_data:/opt/oracle/oracle_data:rw \
  oracleinanutshell/oracle-xe-11g
```

该镜像的默认登录信息是:

```
hostname: localhost
port: 31521
sid: xe
username: system 或者 sys
password: oracle
```

使用了主机的`/data/oracle_data`目录作为数据持久化目录.

## 创建表空间和用户

1. 进入容器

```shell
docker exec -it oracle-xe-11g bash
```

2. 创建表空间

切换到oracle用户

```
su oracle
```

以管理员身份登录数据库, 两个系统账号 `system/sys` 密码默认都是 `oracle`

```
sqlplus system/oracle as sysdba
```

创建表空间

```
create tablespace <tablespace-name> logging datafile '/opt/oracle/oracle_data/<tablespace-name>.dbf' size 200m autoextend on next 100m maxsize unlimited;
```

3. 创建用户并分配权限

创建和业务相关的用户, 并赋予相关权限.

```
create user <user-name> identified by <user-password> default tablespace <tablespace-name>;
```

角色授权

```
grant connect,resource,dba to <user-name>;
```

## 修改字符集

一般来说,初装之后数据库字符集都是`AMERICAN_AMERICA.AL32UTF8`, 有些数据库要求使用特定字符集, 比如需要修改成`ZHS16GBK`, 先查询现在的字符集:

```
select userenv('language') from dual;
```

参考上述步骤, 先以管理员身份登录oracle数据库, 执行变更:

```
shutdown immediate;
startup mount;
alter system enable restricted session;
alter system set job_queue_processes=0;
alter system set aq_tm_processes=0;
alter database open;
alter database character set internal_use ZHS16GBK;
shutdown immediate;
startup;
```

最后执行命令检查字符集是否修改完成.

参考文档: https://www.cnblogs.com/geekdc/p/5817306.html

## 导入dmp文件

很多使用, 我们需要从dmp文件导入oracle数据库, 参考上面步骤, 进入oracle-xe-11g容器, 切换到 `oracle` 用户执行下面命令, 把数据和结构一起导入. 先将dmp文件放到主机目录`/data/oracle_data/imp/example.dmp`中, 这样映射到容器中需要导入的数据目录为: `/opt/oracle/oracle_data/imp/example.dmp`, 执行导入:

```
imp <user-name>/<user-password> file=/opt/oracle/oracle_data/dmp/example.dmp full=y;
```

## 修改管理员账号密码

为了安全, 我们可能需要修改管理员账号的密码, 可以使用管理员免密登录:

```
sqlplus /nolog;
conn /as sysdba;
```

查看用户列表:

```
select username from dba_users;
```

修改密码:

```
alter user sys identified by <new-password>;
alter user system identified by <new-password>;
```

`system`是数据库内置的一个普通管理员, 手工创建的任何用户在被授予dba角色后都跟这个用户差不多. `sys`是数据库的超级用户, 数据库内很多重要的东西(数据字典表、内置包、静态数据字典视图等)都属于这个用户, `sys`用户必须以sysdba身份登录.

## 登录信息

好了! 现在可以登录了, 登录信息:

```
host: <host-ip>
port: 31521
user: <user-name>
password: <user-password>
sid: xe
```