---
title: Hive速记
date: 2021-08-24
lastmod: 2021-08-29
slug: 8fa8aa4
draft: false
author:
  name: tryao
tags: ["bigdata"]
collections: []
toc: true
math: true
lightgallery: false
---

众所周知，hadoop可以大略分为hdfs文件系统+MR引擎两部分构成，然后再加上yarn这个调度引擎（有的公司改用k8s调度了）。

Hive是用来将SQL语句转成MR的，最初是Facebook贡献，后转为Apache开源项目。

现在流行的是Hive on tez，后者取代MR作为DAG计算引擎。此外还有Hive On Spark，使用spark代替MR，Hadoop3之后，默认引擎变成了tez。

Hive依赖MySQL（或其他数据库），用来存放元数据(hive meta)。命令行下一般使用*beeline*访问hive server。

## 建表

```
create [external] table [if not exist] xxx (
	name type comment '' # 列定义，语法类似MySQL
) comment ''
	partition by ()  # 分区
  clustered by () into n buckets # 分桶
  [row format delimited] # 序列化定义
  NULL defined as '' # null值处理
  fields terminated by x # 字段分隔符
  stored as xxx # 存储格式
  [location '/xxx'] # 存储位置
  tblproperties (); # 其他属性
```

- CREATE TABLE 创建一个指定名字的表。如果相同名字的表已经存在，则抛出异常；用户可以用 IF NOT EXIST 选项来忽略这个异常。

- EXTERNAL 关键字可以让用户创建一个外部表，在建表的同时指定一个指向实际数据的路径（LOCATION），Hive创建内部表时，会将数据移动到数据仓库指向的路径；若创建外部表，仅记录数据所在的路径，不对数据的位置做任何改变。在删除表的时候，内部表的元数据和数据会被一起删除，而外部表只删除元数据，不删除数据。

- LIKE 允许用户复制现有的表结构，但是不复制数据。

- 用户在建表的时候可以自定义 SerDe 或者使用自带的 SerDe。如果没有指定 ROW FORMAT 或者 ROW FORMAT DELIMITED，将会使用自带的 SerDe。在建表的时候，用户还需要为表指定列，用户在指定表的列的同时也会指定自定义的 SerDe，Hive 通过 SerDe 确定表的具体的列的数据。

- 如果文件数据是纯文本，可以使用 STORED AS TEXTFILE。如果数据需要压缩，使用 STORED AS SEQUENCE；新版本一般使用ORC文件或者PARQUET格式，如果不使用复杂数据列，或者spark引擎，则优先考虑orc格式；

- 有分区的表可以在创建的时候使用 PARTITIONED BY 语句。一个表可以拥有一个或者多个分区，每一个分区单独存在一个目录下。而且，表和分区都可以对某个列进行 CLUSTERED BY 操作，将若干个列放入一个桶（bucket）中。也可以利用SORT BY 对数据进行排序，这样可以为特定应用提高性能。用来partition的维度**并不是实际数据的某一列**，具体分区的标志是由插入内容时给定的；

- 表名和列名不区分大小写，SerDe 和属性名区分大小写；表和列的注释是字符串；

- SequenceFile支持三种压缩选择：NONE，RECORD，BLOCK。Record压缩率低，一般建议使用BLOCK压缩。

- 数据库常用间隔符的读取。我们的常用间隔符一般是Ascii码5，Ascii码7等。在hive中Ascii码5用’\005’表示， Ascii码7用’\007’表示，依此类推。使用不可见字符是为了防止和真实数据冲突；

- 分隔符设置：

  > FIELDS TERMINATED BY：设置字段与字段之间的分隔符
  > COLLECTION ITEMS TERMINATED BY：设置一个复杂类型（array,struct)字段的各个item之间的分隔符
  > MAP KEYS TERMINATED BY：设置一个复杂类型(Map)字段的key value之间的分隔符
  > LINES TERMINATED BY：设置行与行之间的分隔符

- hive中不存在主键、外键的概念，也不推荐使用索引；

- HIVE表中默认将NULL存为\N，可查看表的源文件（hadoop fs -cat或者hadoop fs -text），文件中存储大量\N，
  这样造成浪费大量空间。而且用java、python直接进入路径操作源数据时，解析也要注意。

  另外，hive表的源文件中，默认列分隔符为\001(SOH)，行分隔符为\n（目前只支持\n，别的不能用，所以定义时不需要显示声明）。
  元素间分隔符\002，map中key和value的分隔符为\003。

## 插入数据

### 批量插入

一般使用`LOAD DATA [LOCAL] INPATH 'filepath' [OVERWRITE] INTO TABLE tablename [PARTITION (partcol1=val1, partcol2=val2 ...)]`直接装载数据到分区。

或者使用`INSERT OVERWRITE TABLE tablename PARTITION (partcol1[=val1], partcol2[=val2] ...) select_statement FROM from_statement`从别的表里插入数据。

也可以倒装成`from ... insert`

其中`overwrite`用来先清空表格再插入。

### 单条插入

当建表时使用orc格式时，可以对单行数据CURD，甚至可以使用事务。语法类似MySQL。

## 导出数据

```
INSERT OVERWRITE [LOCAL] DIRECTORY directory1 SELECT ... FROM ...
```

## 删除数据

`delete from ... where...`，仅orc支持。

其他存储格式，只能删除整张表，不允许修改或者删除单行数据。

## 事务支持

如上文所述，事务支持必须使用ORC存储，且表必须分桶。orc不支持直接LOAD DATA，必须从其他表插入。

修改hive-site.xml配置，做以下修改：

```
<property>
	<name>hive.support.concurrency</name>
  <value>true</value>
</property>
<property>
  <name>hive.exec.dynamic.partition.mode</name>
  <value>nonstrict</value>
</property>
<property>
  <name>hive.txn.manager</name>
  <value>org.apache.hadoop.hive.ql.lockmgr.DbTxnManager</value>
</property>
<property>
  <name>hive.compactor.initiator.on</name>
  <value>true</value>
</property>
<property>
  <name>hive.compactor.worker.threads</name>
  <value>1</value>
</property>
```

在MySQL里面插入元数据（3.x不需要）：

```
insert into next_lock_id values(1);
insert into next_compaction_queue_id values(1);
insert into next_txn_id values(1);
```

修改结束后，需要重启服务。如果使用CDH或者HDP，可以直接在控制台上修改。

建表：

```
create table t1 (id int, name string) clustered by (id) into 8 buckets stored as orc tblproperties ('transactional'='true');
```

**NOTE**：需要先安装好Hadoop并启动(`brew install hadoop`，然后修改一些配置)

可以手动插入一条数据做测试：`insert into t1 values(1, "aaa")`，可以看到插入速度是非常慢的。

## 例子

```
create table t2 (id int, name string, cty string, st string) row format delimited fields terminated by ',' lines terminated by '\n';
```

创建一个txt文件，随便写点数据：

```
1,a,us,ca
2,b,us,cb
3,c,cn,cc
4,d,fr,cd
```

然后使用语句导入：

```
load data local inpath '/tmp/test.txt' into table t2;
```

筛选导入：

```
create table t3 like t2;
insert overwrite table t3 select id,name,cty,st from t2 where id > 2;
```

分区分桶：

```
create table t4 (id int, name string) partitioned by (country string, state string) clustered by (id) into 8 buckets stored as orc tblproperties ('transactional'='true');
```

筛选导入：

```
insert into table t4 partition(country,state) select id, name, cty as country,st as state from t2;
```

注意partition后面的分区列必须和建表语句中声明的一致，后面select 需要用as转换出分区列的名字。

## 优化与技巧

- 可以设置`set hive.mapred.mode=strict`强制使用分区过滤；
- 使用`hive -e`执行外部sql脚本；
- 外部表也可以建立分区，在外部添加分区目录后，使用`alter table xx add partition(col=$name) location ''`增加分区即可；
- 在hive命令行里可以执行`dfs`命令，和在bash里面跑`hdfs dfs`的命令一样；
- `load`命令不支持动态分区插入，所以必须建立一个中间表过渡；
- null相关处理函数有：
  - `nullif(a, b)`，如果a==b返回null，否则返回a
  - `coalesce(a1,a2,a3...)`，返回第一个非null值
  - `nvl(a, b)`，如果a==null返回b，否则返回a
