# Postgresql学习笔记


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

# 安装

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
docker volume create pgdata
docker run -d \
  --name postgres \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB=mydatabase \
  -p 5432:5432 \
  -v pgdata:/var/lib/postgresql/data \
  postgres:17
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

>  MySQL如果想要使用拼音排序的话，需要设置排序规则为`utf8mb4_zh_0900_as_cs`，注意这个排序规则没有ci版本。

## 配置

如果使用docker运行，可以直接用环境变量配置。几个需要注意的参数：

* shared_buffers: 共享内存的大小，默认32M，可以设为内存大小的1/4；
* work_mem: 单个sql执行时，允许使用的内存，默认4M，可以设为16或32M，主要看宿主机或container提供的内存大小；

# 管理

使用psql进行管理。

如果使用brew安装，默认当前用户就有管理员权限（不需要密码），直接用`psql -d postgres`即可登录。

如果用apt的话，需要切换到postgres账号再连接（`sudo su postgres`）。参考命令行：

```bash
psql -U postgres -h 127.0.0.1 -p 5432 -d postgres
```

如果使用docker，推荐使用pgcli进行管理，类似mycli（可以用pip或者brew直接装），并创建一个`~/.pg_service.conf`，格式如下：

```ini
[local]
host=127.0.0.1
port=5432
dbname=learn_pg
user=admin
password=zaq1@WSX
```

然后`export PGSERVICE="local"`后直接使用pgcli连接，或者使用`pgcli "PGSERVICE=local"`。

postgres的管理方式和MySQL差别很大，使用的命令有点类似Windows cmd命令行，常用的包括：

* \h 查看帮助
* \? 查看可用命令
* \l 查看库，类似show databases;
* \c 连接到具体的库，类似use xxx;
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

# 基础知识

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

* serial和bigserial用于实现自增id，相当于MySQL的auto increment。不过现在一般推荐使用ULID或者uuid v7来生成id了。

* money类型，可以视为一个特殊的decimal，小数点固定为2位；

### 数值操作符和函数

除了常规的加减乘除、取余、指数、位运算，还支持一些特殊的运算符：

* |/ 平方根
* ||/ 立方根
* ! 阶乘，**后缀操作符**
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

简单来说，**用JSONB**，使用方式和MySQL8.0有点像。

* `->`取原始值（JSOBB）类型，方便继续进行嵌套式操作。
* `->>`返回文本。如果是浮点数，可以用`::INT`或`::REAL`做类型转换。
* 可以加索引，一般使用GIN类型索引，例如：

```
create index ix_ext on "user" using gin (ext jsonb_path_ops);
```

* 当然也可以使用btree索引，此时需要指名json内需要加索引的字段；

## Range

范围，一个例子是ip地址：

```
create type iprange range (subtype = inet);
create table user_track (
	ip_range iprange,
	user_id bigint
);
```

range一般使用GiST索引，使用操作符`@>`查询是否在范围内。

range使用字符串输入，类似数学中的集合（前开后闭等）。

range也支持一般集合操作（交集、并集等）。

## 数组

除了直接用JSONB之外，也可以用数组类型。

数组类型语法就是在基本类型后面加`[]`，如`varchar(10)[]`。赋值时，字面值使用大括号，如`{1,2,3}`。

**数组下标默认从1开始**，使用GIN索引。

数组可以有多维，元素也可以是复杂类型（如box）。

查询数组中包含元素，需要使用`@>`操作符。

可以使用`unnest`函数将数组拆分多行，也可以使用`array_agg`函数将多行聚合成数组。

数组是不可变的，array_append函数会生成一个新数组，如果在存储过程中需要处理大量数据，建议使用临时表。

## 伪类型

非字段类型，而是用来声明函数的参数和返回类型。

如：any, anyarray, void等

## 模式

MySQL中没有模式的概念，为了兼容性，不建议使用模式。或者说，把模式(schema)对应到MySQL中的database。

由于pg的命令行并不支持切换database，习惯上我们为每个微服务创建一个schema而非database。

默认情况下，创建database后会创建一个名为`public`的schema。

## 表继承

create table 尾部使用`inherits table`，在子表中插入的数据可以在父表中查出来，所以可以用来做日期分片。特性：

1. **结构继承**：子表会自动拥有父表的全部列和约束条件。
2. **数据独立**：父表和子表的数据是分开存储的。
3. **查询自动扩展**：对父表进行查询时，会自动把所有子表的数据也包含进来。
4. **约束限制**：子表可以增添新的列，但无法修改或移除从父表继承来的列。

如果只想查父表，可以在表明前加ONLY。

## 分区表

分区表是通过表继承实现的，可以使用专门的语法来创建：

```
create table xxx () partition by range(date);
```

然后为该分区表创建分区即可。

## 触发器

和教科书上的触发器区别不大。

pg不支持datetime字段在更新时更新为当前时间，必须通过触发器来实现。

## 表空间

创建数据库时可以指定表空间，创建表空间时可以指定不同的存储目录。

## 视图

略。支持物化视图。

## 索引

除了最常见的BTree索引（只支持<, = , >谓词）之外，还支持

* Hash：只支持相等查询
* GiST： 通用索引框架，支持包含`@>`，重叠`&&`等复杂运算
* SP-GiST：通用索引框架，空间分区GiST索引（9.2+）
* GIN：广义倒排索引，一般用来做全文检索。生成效率较低，大量数据注入时建议先删掉索引。可以通过增加`maintenance_work_mem`参数来更快完成索引更新；建议设置`gin_fuzzy_search_limit`的值为5000~20000之间，避免产生大量匹配。
* BRIN索引：块范围索引。内置数组使用该索引。

支持并发创建索引（并行操作，需要配置数据库参数，max_worker_processes >=max_parallel_works>=max_parallel_works_per_gather）。

支持创建函数索引和部分索引（加上where条件，排除不感兴趣的数值），也包括部分唯一索引。

## 权限

pg中用户就是一个角色，可以将一个用户的权限赋予另一个用户。

## 规则系统

规则类似触发器，但是效率比触发器更高。规则的作用机理是查询重写，而触发器会对命中的每一行都生效。例如

```sql
create rule "_RETURN" as on select to mytab2 do instead select * from mytab1;
create rule rule_mytab_insert as on insert to
	mytab
do also insert into mytab_log(oprtype, oprtime, new_id, new_note)
values ('i', now(), new.id, new.note);
create rule rule_mytab_update as on update to
  mytab
do also insert into mytab_log(oprtype, oprtime, old_id, new_id, old_note, new_note)
values ('u', now(), old.id, new.id, old.note, new.note);
create rule rule_mytab_delete as on delete
do also insert into mytab_log(oprtype, oprtime, old_id, old_note)
values ('d', now(), old.id, old.note);
```

规则的权限从属于表或者视图。

## 消息队列

客户端可以使用`listen xxx`的方法监听一个通道，另一个客户端可以用`notify xxx, 'msg'`的方法往通道里发送消息。

因此可以用来实现简易的消息队列。

如果在事务中发送消息，需要等事务提交时消息才会被发送，这样消息队列和数据库可以完成事务一致性。

队列长度默认是8GB，如果满了notify就会失败。二阶段提交中不能使用notify命令（即prepare transaction 'xxx'）。

## 序列

类似oracle，自增长（减少）的生成器，一般用于生成id。

可以指定步长、最小最大值（默认是bigint范围）、是否循环，缓存数量等。

使用`nextval('serial_name')`函数获取下一个值，使用`currval`获取当前值，使用`setval`改变当前值。

注意：在事务中使用序列，事务回滚，序列值不会回滚。显然，如果回滚会有并发问题。

可以使用`generate_series`函数生成序列，类似Python中的range函数。

## 咨询锁

咨询锁与具体的数据没啥关系，单纯作为一种分布式锁的功能。

pg提供两种咨询锁：session级别和事务级别，后者函数名里面有`xact`字样。

参数分为两种：1个64bit的整数，或者2个32bit的整数。

session级别的咨询锁在连接断开时会自动释放，所以不需要设置过期。调用了几次lock就要调用几次unlock。

事务级别的咨询锁在事务结束之后会自动释放，不需要手动释放。

## SQL/MED

可以理解为一个框架，pg可以通过该框架将其他类型的数据库（如mongo，MySQL）映射到pg里面，这样就可以通过pg统一访问异构数据库了。

可以替换dblink，在某些特殊情况下有点用。

## 全文检索

可以使用zhparser或pg_jieba支持中文分词。

一般需要额外增加tsvector字段来对支持全文检索的字段进行token缓存，可以使用生成列自动分解为token。

## 性能视图

pg内部会自动track性能，包含了几个常用的表：

* pg_stat_database：活跃进程数、已提交/已回滚的事务总数，死锁次数、读写数据块总时间（默认没打开）等
* pg_stat_all_tables：顺序扫描总数、索引扫描总数等
* pg_stat_sys_tables
* pg_stat_user_tables
* pg_stat_user_funcitons: 函数调用次数和执行时间
* pg_stat_all_indexes
* pg_stat_sys_indexes
* pg_stat_user_indexes

# 配置优化

## 操作系统

首先要关闭透明大页功能。

```bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
```

更新sysctl.conf，参考如下：

```nginx
vm.swappiness=0
# 防止OOM
vm.overcommit_memory=2
vm.overcommit_ratio=85
# 脏数据刷新比例阈值
vm.dirty_background_ratio=1
vm.dirty_ratio=2
# 设置的与总内存一样
kernel.shmmax = 274877906944
# 设置的与总内存的页面数一样
kernel.shmall = 67108864
# 信号量相关配置
kernel.sem=20 13000 20 650
kernel.sysrq = 1
kernel.core_uses_pid = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.msgmni = 2048
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_forward = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.conf.all.arp_filter = 1
net.ipv4.ip_local_port_range = 1025 65535
net.core.netdev_max_backlog = 10000
net.core.rmem_max = 2097152
net.core.wmem_max = 2097152
net.core.somaxconn = 2048
```

## 数据库

配置供参考

```nginx
listen_addresses = '*'
port = 5432 # (change requires restart)
max_connections = 3000 # (change requires restart)
superuser_reserved_connections = 10 # (change requires restart)
tcp_keepalives_idle = 5 # TCP_KEEPIDLE, in seconds;
tcp_keepalives_interval = 5 # TCP_KEEPINTVL, in seconds;
tcp_keepalives_count = 3 # TCP_KEEPCNT;
shared_buffers = 32GB
huge_pages = on # 默认是try，强制打开大页，需要操作系统配置正确
# you actively intend to use prepared transactions.
work_mem = 4MB
maintenance_work_mem = 128MB
autovacuum_work_mem = 256MB
wal_writer_delay = 10ms
max_wal_size = 50GB
min_wal_size = 40GB
checkpoint_timeout = 15min
max_locks_per_transaction =256
checkpoint_completion_target = 0.9 # checkpoint target duration, 0.0 - 1.0
effective_cache_size = 256GB
log_destination = 'csvlog' # Valid values are combinations of
logging_collector = on # Enable capturing of stderr and csvlog
log_directory = 'pg_log' # directory where log files are written
log_truncate_on_rotation = on # If on, an existing log file with the
log_rotation_age=3d
log_rotation_size=100MB
autovacuum = on # Enable autovacuum subprocess'on'
log_autovacuum_min_duration = 0
autovacuum_max_workers = 10 # max number of autovacuum subprocesses
autovacuum_naptime = 1min # time between autovacuum runs
autovacuum_vacuum_threshold = 500 # min number of row updates before vacuum
autovacuum_analyze_threshold = 500 # min number of row updates before analyze
autovacuum_vacuum_scale_factor = 0.2 # fraction of table size before vacuum
autovacuum_analyze_scale_factor = 0.1 # fraction of table size before analyze
autovacuum_vacuum_cost_delay = 2ms #
autovacuum_vacuum_cost_delay
autovacuum_vacuum_cost_limit = 5000 # default vacuum cost limit
wal_compression = on
lock_timeout=600000
statement_timeout=3600000
log_min_error_statement=error
log_min_duration_statement=5s
temp_file_limit=20G # 控制临时表空间size
vacuum_cost_limit = 5000 # sas 盘2000, SSD为10000
vacuum_cost_delay = 2ms
checkpoint_completion_target=0.9
random_page_cost = 1.1
log_checkpoints =on
log_statement = 'ddl'
idle_in_transaction_session_timeout = 600000 # 自动清理 idle session
track_io_timing = on
track_functions = all
shared_preload_libraries = 'pg_stat_statements'
track_activity_query_size = 2048
pg_stat_statements.max = 10000
pg_stat_statements.track = all
pg_stat_statements.track_utility = off
pg_stat_statements.save = on
archive_mode = 'on'
archive_command = '/usr/bin/true'
```

# 从库备份

pg基于PITR进行备份，类似redis的全量+WAL日志方式。

在postgresql.conf里面设置hot_standy=on，然后在数据库的数据目录下面touch standby.signal文件，重启数据库即可进入从库模式。

冷备库需要主库停机，copy数据目录，然后配置从库的配置文件指向主库。

热备库：使用pg_baseback工具完成。

在主库中增加pg_hba.conf：

```nginx
host replication all 0/0 md5
```

允许任意用户从任意网络泛起到本数据库的流复制连接，使用md5密码认证。可以创建一个流复制用户：

```sql
CREATE ROLE repl_user REPLICATION LOGIN PASSWORD 'yourpass';
```

在主库配置文件中配置：

```nginx
max_wal_senders = 10
wal_level = replica
min_wal_size = 800MB
```

修改完之后需要重启。

在从库机器上执行：

```bash
pg_basebackup -h 主库IP -p 5432 -U repl_user -D /var/lib/postgresql/16/main -Fp -X stream -R -C -S standby01
```



---

> 作者: [tryao](https://gravatar.com/afxmessagebox)  
> URL: https://yiuterran.github.io/blogs/posts/postgresql%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0/  

