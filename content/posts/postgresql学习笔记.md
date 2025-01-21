---
title: Postgresql学习笔记
description:
toc: true
authors: []
tags: []
categories: []
series: []
date: 2024-12-23T11:04:29+08:00
lastmod: 2024-12-23T11:04:29+08:00
featuredVideo:
featuredImage:
draft: false
---

MySQL日薄西山，被oracle收购后迭代速度明显下降，代码质量也越发堪忧，最近还爆出几个重大的功能bug。国内目前又开始扯起信创的大旗，实际大部分都是基于开源数据库改，或者兼容开源库的驱动的，所以后端架构时，已经不再是以MySQL为第一选择，而是以同时兼容MySQL、Oracle和PostgreSQL为目标。

附上目前主流信创数据库兼容性列表：

- 人大金仓：oracle模式
- 虚谷：oracle模式
- GaussDB（for openGauss）：Postgresql模式
- 海量：Postgresql模式
- 瀚高：Postgresql模式
- OceanBase：mysql模式
- 亚信AntDB：mysql模式
- 中兴GoldenDB：mysql模式
- 腾讯TDSQL：mysql模式
- 京东StarDB：兼容mysql8

很久之前用过pg，但是pg每年都发大版本，到现在已经改了很多了。所以写个笔记记录一下pg的功能，方便以后查阅。

## 安装

mac:

```bash
brew install postgresql@17
brew services start postgresql@17
```

linux:

```bash
sudo apt install postgres-17
systemctl start postgres
```

linux可能需要自己添加源，debian 12里面最新的是15.

如果使用docker运行，则：

```bash
docker run --name postgres -e POSTGRES_PASSWORD=mysecretpassword -d postgres:17
```

支持的环境变量：

* 管理员：`POSTGRES_USER`
* 管理员密码：`POSTGRES_PASSWORD`
* 默认数据库：`POSTGRES_DB`
* 默认InitDB参数：`POSTGRES_INITDB_ARGS`，例如："--locale-provider=icu --icu-locale=C"
* 数据目录：`PGDATA`

默认的数据目录是`/var/lib/postgresql/data`，持久化的时候需要挂载出来。

也可以通过挂载`/etc/postgresql/postgresql.conf`进行配置。

如果需要运行初始化SQL脚本，可以使用-d挂载到`/docker-entrypoint-initdb.d`目录下，但是这个初始化脚本**只有data目录为空时才会运行**。

如果使用docker运行，默认字符集是en_US，中文order by的时候不会按拼音排序，需要自己修改一下镜像：

```dockerfile
FROM postgres:17
RUN localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8
ENV LANG zh_CN.utf8
```

当然，也可以改为使用icu排序，代价是有一些性能损失。

另外这里提一嘴，MySQL如果想要使用拼音排序的话，需要设置排序规则为`utf8mb4_zh_0900_as_cs`，注意这个排序规则没有ci版本。

## 配置

如果使用docker运行，可以直接用环境变量配置。几个需要注意的参数：

* shared_buffers: 共享内存的大小，默认32M，可以设为内存大小的1/4；
* work_mem: 单个sql执行时，允许使用的内存，默认4M，可以设为16或32M，主要看宿主机或container提供的内存大小；

## 管理

使用psql进行管理。

如果使用brew安装，默认当前用户就有管理员权限（不需要密码），直接用`psql -d postgres`即可登录。

如果用apt的话，需要切换到postgres账号再连接（`sudo su postgres`）。参考命令行：

```bash
psql -U postgres -h 127.0.0.1 -p 5432 -d postgres
```

postgres的管理方式和MySQL差别很大，使用的命令有点类似Windows cmd命令行，常用的包括：

* \h 查看帮助
* \? 查看可用命令
* \l 查看库，类似show databases;
* \d 显示当前库的所有表，类似show tables;
* \d 后跟表名，显示表结构，类似desc xxx;
* \d+ 后跟表名，显示表结构，但是有更多内容。另外pg不支持show create table xxx的效果，需要使用pg_dump拿到建表语句；
* \d 后跟索引，显示索引信息；
* \d 后面可以使用通配符?和*，可以使用\dt, \di, \ds, \dv, \df等命令，减少通配符匹配的范围；
* \timing on，打开sql计时；
* \dn 显示所有的schema；
* \db 显示所有的表空间；表空间是为了方便将数据拆分到不同位置，Linux扩展挂载磁盘，无需重启服务。
* \du \dg显示所有的用户；
* \dp或\z 显示表的权限分配；
* \encoding 配置客户端字符编码；
* \pset 设置返回的边框格式。如果使用\pset format unaligned，可以返回成以`|`分割的格式，方便导入Excel等工具；
* \o 设置输出文件；
* \t 移除输出的表头；
* \x 按列展示，类似MySQL \G的效果；
* \i 导入外部sql文件，类似MySQL的source命令；也可以通过psql使用-f的命令；
* \e 编辑文件并执行，可以后跟文件名指定一个已存在的文件；
* \ef 编辑函数， \ev 编辑视图，如果只是查看不想执行，运行完毕之后使用\reset清除命令缓冲区；
* \echo 可以在sql脚本里面输出某些信息；

## 数据类型

pg支持的数据类型比MySQL少，也比较简单。比如仅支持smallint不支持tinyint，也没有smalltext, middletext之类的玩意儿。但是在json支持上，远比MySQL要完善。

### 布尔值

字面值TRUE和FALSE，也支持字符串或数字转换。

支持 AND OR NOT计算，支持 IS 判断。

### 数值类型

* smallint: 2字节，别名int2
* int: 4字节，别名int4
* bigint: 8字节，别名int8
* numeric或decimal：高精度变长，即numeric(m, n)
* real: 4字节，即float
* double: 8字节
* serial: 4字节自增整数
* bigserial: 8字节自增整数

不支持无符号数。浮点数支持几个特殊值：

* Infinity
* -Infinity
* NaN

serial和bigserial用于实现自增id，相当于MySQL的auto increment。不过现在一般推荐使用ULID或者uuid v7来生成id了。

* money类型，可以视为一个特殊的decimal，小数点固定为2位；

### 数值操作符和函数

除了常规的加减乘除、取余、指数、位运算，还支持一些特殊的运算符：

* |/ 平方根
* ||/ 立方根
* ! 阶乘，后缀操作符
* !! 阶乘，前缀操作符
* @ 绝对值
* `#` 按位异或

函数：支持常见的数学函数，不一一列出。

### 字符串类型

* varchar：最大1GB，一般用这个
* char，最大1GB
* text，无长度限制

只有这三种，由于pg中char和varchar性能相同，一般不建议使用char。

### 字符串操作符和函数

* `||`，字符串连接
* `big_length`，二进制位长度
* `char_length`，字符个数，等价于`length`
* `convert`，修改编码
* `octet_length` 字节数
* `overlay`，替换子字符串
* `position`，查找子串位置
* `substring`，抽取子串
* `trim`，按子串修剪字符串
* `btrim`，按字符集修剪字符串
* `quote_ident`，反向转义，必要时添加引号
* `quote_literal`，将文本转为sql语句中可使用的形式

### 二进制数据

只有一种：bytea，类似blob。

### 位串类型

即bit(n)和bit varing(n)，前者是定长，后者是变长。

### 时间日期

* date
* time
* timestamp
* timestamptz
* interval

可以通过datestyle配置年月日的顺序，对应的是YMD，如果按标准的ISO 8601格式，则无需配置。

timestamp默认不含时区信息，适合UTC时间存储方案，对应Java中的LocalDateTime。

**使用timestamptz来存储时间，对应Java中的Instant，或者OffsetDateTime，推荐使用该方案。**

使用Java访问时，建议明确设置PostgreSQL和jvm的时区，而不要使用默认值，可以都设置为UTC。**注意postgresql的驱动参数中serverTimeZone参数是无效的。**

### JSON与JSONB

简单来说，用JSONB，使用方式和MySQL8.0有点像。

## 模式

MySQL中没有模式的概念，为了兼容性，不建议使用模式。或者说，把模式(schema)对应到MySQL中的database。

