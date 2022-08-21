---
weight: 1
title: "配置"
---

# 配置

该项目的配置修改都是在配置文件中完成的，配置文件在启动应用的时候通过`--config=`标签进行配置.

配置文件介绍如下：

```yaml
# session 相关配置
session:
  name: session_id
  secret_key: "kkoiybh1ah6rbh0"
  # 过期时间
  # 单位秒
  # 默认20分钟
  max_age: 1200

# 用户登录验证方式
# 支持: db ldap
auth_mode: ldap

# 数据库相关配置
# 这里可以添加多个连接支持
# 默认是 default 连接
db:
  default:
    type: mysql
    host: string
    port: 3306
    user: 123
    password: abc
    dbname: oauth2nsso

ldap:
  # 服务地址
  # 支持 ldap ldaps
  url: ldap://ldap.forumsys.com
  # url: ldaps://ldap.rutron.net

  # 查询使用的DN
  search_dn: cn=read-only-admin,dc=example,dc=com
  # 查询使用DN的密码
  search_password: password
  
  # 基础DN
  # 以此为基础开始查找用户
  base_dn: dc=example,dc=com
  # 查询用户的Filter
  # 比如: 
  #   (&(uid=%s)) 
  #   或 (&(objectClass=organizationalPerson)(uid=%s))
  #   其中, (uid=%s) 表示使用 uid 属性检索用户, 
  #   %s 为用户名, 这一段必须要有, 可以替换 uid 以使用其他属性检索用户名
  filter: (&(uid=%s))

# 可选
# redis 相关配置
# 可以提供:
# - 统一回话存储
# - oauth2 client 存储
redis:
  default:
    addr: 127.0.0.1:6379
    password: 
    db: 0

# oauth2 相关配置
oauth2:
  # access_token 过期时间
  # 单位小时
  # 默认2小时
  access_token_exp: 2
  # 签名 jwt access_token 时所用 key
  jwt_signed_key: "k2bjI75JJHolp0i"
  
  # oauth2 客户端配置
  # 数组类型
  # 可配置多客户端
  client:

      # 客户端id 必须全局唯一
    - id: test_client_1
      # 客户端 secret
      secret: test_secret_1
      # 应用名 在页面上必要时进行显示
      name: 测试应用1
      # 客户端 domain
      # !!注意 http/https 不要写错!!
      domain: http://localhost:9093
      # 权限范围
      # 数组类型
      # 可以配置多个权限 
      # 颁发的 access_token 中会包含该值 资源方可以对该值进行验证
      scope:
          # 权限范围 id 唯一
        - id: all
          # 权限范围名称
          # 会在页面（登录页面）进行展示
          title: "用户账号、手机、权限、角色等信息"

    - id: test_client_2
      secret: test_secret_2
      name: 测试应用2 
      domain: http://localhost:9094
      scope:
        - id: all
          title: 用户账号, 手机, 权限, 角色等信息
```
