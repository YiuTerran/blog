---
title: Oracle学习笔记
date: 2017-07-03
lastmod: 2018-01-04
slug: 19bc86b
draft: false
author:
  name: tryao
tags: ["db"]
collections: []
toc: true
math: true
lightgallery: false
---

工作以后只用过MySQL，互联网公司也基本都是MySQL了。现在来到了金融公司，不得不进行Oracle的逆入门（毕竟一般人都是Oracle到MySQL）。

## 安装

Mac下可以使用docker安装，可以参考[这篇博客](http://blog.csdn.net/xp541130126/article/details/70138904).

## 概念

`OLTP`：在线事务处理系统，强调数据库的内存效率，强调内存各种指标的命中率，强调绑定变量，强调并发操作。用户并发数都很多，但他们只对数据库做很小的操作，数据库侧重于对用户操作的快速响应。
`OLAP`：在线分析系统，强调数据分析，强调SQL 执行时长，强调磁盘I/O，强调分区等。主要用户数据分析，对于性能要求没那么高。

### 索引

oracle的索引分为B-tree, Bitmap，Hash等，其中位图索引不能被声明为唯一索引，适合候选值很少，且不频繁改动的列。对于高并发系统，不要使用位图索引。

函数索引：如果查询的时候总是使用某个函数，使用函数索引较多。例如，对于搜索大小写不敏感的字段，查询的时候总会使用`Upper`函数将其转为大写，但是存放的时候还是用户的原始数据，就可以建立一个函数索引。

### 分区表

类似MySQL中的shard，不同的是Oracle自带了这个功能。现在基于MySQL的TiDB，以及各类开源的Proxy功能也可以实现透明分区。注意：含有LONG、LONGRAW数据类型的表不能进行分区。

分区方法：

1. 范围分区：以某个字段的range为标准进行分区，适合以日期分割的历史数据，如交易记录
2. 哈希分区：以某个字段的hash为标准进行分区，分区
3. 列表分区：以某个字段的值为标准进行分区，适合列为有限枚举值的情况
4. 组合分区：以Range分区作为根分区方法，其他分区作为子分区

Oracle可以自动根据时间建立分区表。

### 锁

整体和MySQL类似。使用`LOCK TABLE tablename`的格式加表锁。

使用`SELECT..FOR UPDATE`方式加行级锁。

当`COMMIT`或者`ROLLBACK`后，释放锁。但是`ROLLBACK`不能释放行级锁。其他的锁主要是供系统使用，是DBA需要掌握的内容，包括如何解决死锁等。

## 体系结构

MySQL的体系结构非常简单：`database` ——> `table`，可以随意创建用户，然后我们通过`grant`命令赋予用户对库、表的访问权利。

Oracle的体系稍微麻烦一些，`database`（数据库实例，又称为SID）还存在，但是下一级不是`table`，而是`tablespace`（表空间，一个实例可以有N个表空间。表空间创建时可以指定大小），再下一层是具体的数据文件。如果想要建表，必须创建用户(`user`)，并为用户指定表空间。这个是物理存储角度下oracle的结构。

在逻辑概念上，SID下面一层是用户，存储过程、函数、表、序列等等，则是隶属于这个用户的对象(`object`)。用户创建任意object后，会默认生成一个方案(`schema`，与用户对应)，在逻辑上，这个用户创建的所有object属于这个schema，即使这些object属于不同的`tablespace`.

在权限管理上，user默认有自己schema的所有权限，如果用户想要访问其他schema的object，必须赋权。

一般流程：创建`database` -> 创建`tablespace` -> 创建`user`（指定默认的`tablespace`） -> 用户建表。

有关表的元数据被存放在数据字典中。

## 权限

默认情况下，oracle会自动创建若干个用户，如`sys`, `system`和`scott(Tiger)`，并提示输入默认密码. 使用`sqlplus`登入后，使用命令`select username,account_status from dba_users;`获取所有账户状态，有需要的话可以使用`password`命令修改密码。

创建用户：类似MySQL，使用`create user root identified by '123456';`，然后使用`alter user root account unlock`解锁用户。

权限：分为系统权限（如建表、建库等）和具体的数据权限（增删改查等）。用户可以将自己`schema`下的object授权给其他用户，或者使用管理员账户进行授权。语句格式大致为`grant select on emp to root with grant option`.

收回权限：`revoke select on emp from root`.

删除用户： `drop user root cascade`，删除用户会导致用户名下所有的数据都被删除，谨慎使用。

可以使用`profile`进行安全策略的限制（输错密码次数、密码过期时间、密码强度限制等等）。

## 使用

我们先通过`sys`等系统dba账户登入，创建项目需要的管理员账户，然后赋予`connect`, `resource`和`dba`的权利。然后使用这个账户登入，创建项目需要的表。

注意：oracle命令默认是**区分**大小写的，但是如果不加双引号的话，所有的字段、命令都会被转化为大写。一般情况下，使用单引号来引用字符串，如果字符串里面有单引号，需要使用两个单引号转义。如果用了系统关键字（或者空格等符号），则使用双引号包围字符串。

使用上和MySQL有很多细节的不同，主要包括：

1. 自增。需要先`create sequence myseq increment by 1 start with 1000`创建一个自增序列，然后在插入的时候使用`myseq.nextval`来取得自增的值（有点类似mongo）；
2. 外部脚本。使用`@ xxx.sql`导入；
3. 表达式。使用`select 3 * 2 from dual`;
4. 系统时间。使用`select sysdate from dual`，具体格式可以使用`select to_char(sysdate,'yyyy-mm-dd') from dual;`;
5. 修改表名。 `rename xx to yy`;
6. 分页。Oracle的分页做的很挫…最好使用id分页，如果要用数据库自身的分页，需要使用嵌套子查询。oracle对每一列有`rownum`和`rowid`两个虚列，前者是结果集的序列（从1开始），后者是物理上每一行的id。

```
SELECT * FROM
(
SELECT A.*, ROWNUM RN
FROM (SELECT * FROM TABLE_NAME ORDER BY x) A
WHERE ROWNUM <= 40
) T
WHERE RN >= 21
```

这里最里面那一层是真正的SQL语句，进行全表搜索。然后`ROWNUM<=40`表示只要前四十行，最外层表示在这前40行里面只要第二页（假设每页20个）的.
需要注意：

1. `rownum`是自动生成的，所以内层的`rownum`只能用`<=`，而绝对不能用`>=10`这种，因为生成的列永远从1开始；
2. 如果有`order by`字段，必须有三层查询，最内层做排序，次外层选择前N条，最外层做偏移量

### 建表

oracle建表有很多可选参数，其中：

```
pctfree：用于指定BLOCK中必需保留的最小空间的比例。
pctused：为一个百分比数值，当BLOCK中已经使用的空间降低到该数值以下时，该BLOCK才是可用的，达到或是超过这个数值的BLOCK是不可用的。
一般在控制具有独立segment结构的对象时，使用这两个参数来控制BLOCK的存储管理。
initrans：指定可以并发操作该表的事务的数目。
```

如果你预计只有很少的更新操作会增加行的大小，则可将PCTFREE设置为较低的值（如5或者10），使得ORACLE填满每个块的更多的空间。但是，如果你预计更新操作将会经常增加行的大小，则将PCTFREE设置为较高的值（如20或30），使得ORACLE为已有行的更新操作保留更多的块空间；否则，将出现行链。

如果你预计很少有删除操作，则可设置PCTUSED为较高的值（如60），当偶然的删除操作发生时，使数据块弹出可用清单。但是，如果你预计将PCTUSED 设置为较低的值（如40），使ORACLE不常产生块在表的可用空间中移进或移出的开销。

## PL/SQL

PL/SQL是针对Oracle特有的SQL语句，不可移植。

基本单位：块(block).

语句：声明(declare)，执行(begin…end)，异常处理(exception..end)

运算符：注意`||`是字符串连接，其他和MySQL差不多

### 变量

命名：`DECLARE test VARCHAR(20)`，命名规范：

```
至多有30个字符
不能是保留字
必须以字母开头
不允许和数据库中表的列名相同
不可包括$,_和数字以外的字符
```

变量定义（类似go语言）： `v_number NUMBER(2) NOT NULL := 20`，常量使用`CONSTANT`. 可以在声明时指定其他变量的类型作为其类型（类似泛型），格式是`var%TYPE`

基本数据类型就是JDBC中的那些，常用的是Number和varchar2, boolean, date这几个。数组类型使用`VARRAY(size) OF element_type [NOT NULL]`的形式，使用`(n)`进行下标访问

复合数据类型:

```
TYPE type_name IS RECORD(
    fieldname fieldtype,
    fieldname fieldtype
);
```

显然这玩意儿类似C语言中的`struct`. 也可以直接用`table%RAWTYPE`声明一个同表结构的记录。甚至可以直接声明表类型，类似一个数据，格式为：

```
 declare
            type ename_table_type is table of emp.ename%type
            index by binary_integer;
ename_table ename_table_type;
```

可以使用`ename_table(-1)`进行下标访问，使用`.FIRST`和`.LAST`访问第一行和最后一行。

除了普通变量外，还有替换变量。主要用于人机交互，`&`前缀表示提示用户输入，且仅此次有效，`&&`前缀则表示永久有效，仅需要输入一次。

变量的可见范围，在`DECLARE`中声明的变量，在后面的`BEGIN`块中可见。

### 游标

游标是查询结果集的指针。
显式使用语法：

```
CURSOR cursor_name[(parameter[, parameter]…)]
       [RETURN datatype]
IS
    select_statement;
```

游标里面显然不能用`SELECT..INTO..`，而是要手动遍历。使用`OPEN cursor_name`打开游标，执行语句。
使用`FETCH cursor_name INTO xxx`取出游标对应的行，`FETCH`以后，游标会自动指向下一行。游标不能回退，使用完毕后要记得`CLOSE`掉。

可以通过参数类型`sys_refcursor`传递游标。接受的函数/存储过程必须使用`OPEN xxx FOR SELECT`打开游标进行赋值。

游标属性包括：

```
Cursor_name%FOUND     布尔型属性，当最近一次提取游标操作FETCH成功则为 TRUE,否则为FALSE；
Cursor_name%NOTFOUND   布尔型属性，与%FOUND相反；
Cursor_name%ISOPEN     布尔型属性，当游标已打开时返回 TRUE；
Cursor_name%ROWCOUNT   数字型属性，返回已从游标中读取的记录数。
```

可以直接使用`FOR var IN CURSOR LOOP`进行循环取值。

除了显式使用以外，普通的update、insert和delete语句也会自动生成隐式游标，可以用`SQL`查询上面的属性。

使用`SELECT FOR UPDATE [NOWAIT]`加悲观锁，如果使用 FOR UPDATE 声明游标，则可在DELETE和UPDATE 语句中使用`WHERE CURRENT OF cursor_name`子句，修改或删除游标结果集合当前行对应的数据库表中的数据行。

除了静态游标外，还可以使用游标变量，形式是：

```
TYPE ref_type_name IS REF CURSOR
 [ RETURN return_type];
```

### 语句

条件语句：`IF..THEN..ELSIF..ELSE..ENDIF`，或者`CASE..WHEN..THEN..ELSE..END`

循环语句：`LOOP..EXIT WHEN..END LOOP`, 或者`FOR..IN..LOOP..END LOOP`, 或者`WHILE..LOOP..END LOOP`

范围循环使用`..`连接上下限.

使用`GOTO`跳转到label, label使用`<<>>`标示起来

### 包（package）

有点类似C/C++，先声明包头，然后创建包体。包名自动被注册到`schema`下，可以直接调用。

包是pl/sql实现抽象的主要途径。创建包的语法为：

```
CREATE [OR REPLACE] PACKAGE package_name
  {IS | AS}
  [公有游标定义[公有游标定义]…]
  [公有函数定义[公有函数定义]…]
  [公有过程定义[公有过程定义]…]
BEGIN
  执行部分(初始化部分)
END package_name;
```

上面类似C/C++中的头文件，导出了可供外部调用的函数和过程、游标。

包体则对应具体的实现，其语法为：

```
CREATE OR REPLACE PACKAGE BODY pkg_name
IS
[私有内容定义]
[公有内容定义]
END
```

这样，就可以在其他函数/存储过程里面通过`package_name.function_name`来调用包内的函数/过程了。

### 函数(function) & 存储过程(Proceduce)

调用函数可以用命名传递方式，即`func_name(1, param2 => 1)`，同时声明的函数参数可以用`DEFAULT`关键字指定默认值。

类似函数，除了无返回值，定义语法：

```
 CREATE ［OR REPLACE］PROCEDURE procedure_name
 [(argument_name [IN | OUT | IN OUT] argument_type [DEFAULT value])]
 AS | IS
 BEGIN
     procedure_body;
 END [procedure_name];
```

其中:

```
IN：表示是一个输入参数，可以指定缺省值。如省略参数类型，则缺省为in类型
OUT：表示是一个输出参数
IN OUT：既可以作为一个输入参数，也可以作为一个输出参数来输出结果
```

调用语法：

```
EXECUTE ｜CALL procedure_name [(argument_list)]
```

### 异步IO

使用`dbms_job.submit`可以异步调用存储过程

### 异常

预定义了以下异常：

```
NO_DATA_FOUND          SELECT ... INTO ... 时，没有找到数据
DUL_VAL_ON_INDEX       试图在一个有惟一性约束的列上存储重复值
CURSOR_ALREADY_OPEN    试图打开一个已经打开的游标
TOO_MANY_ROWS          SELECT ... INTO ... 时，查询的结果是多值
ZERO_DIVIDE            零被整除
```

当然也可以自己声明`EXCEPTION`, 在程序中`RAISE`出来。处理语法是`BEGIN..EXCEPTION..WHEN..THEN..WHEN OTHERS THEN...END`

使用`SQLCODE`和`SQLERRM`分别取得错误码和错误信息，还可以使用`RAISE_APPLICATION_ERROR(error_number,error_message,[keep_errors] );`将异常传递到客户端
