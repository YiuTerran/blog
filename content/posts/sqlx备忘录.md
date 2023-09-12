---
title: Sqlx备忘录
description:
toc: true
authors: [“tryao"]
tags: ["golang","sqlx"]
categories: []
series: []
date: 2023-09-12T15:22:00+08:00
lastmod: 2023-09-12T15:22:00+08:00
featuredVideo:
featuredImage:
draft: false
---

很少用golang写增删改查，sqlx的用法和java差别很大，用的时候总是要从头看文档。这里写个备忘录方便以后查询，使用sqlx和go-sqlbuilder来完成增删改查。

## 连接

```go
var (
    db *sqlx.DB
    err error
)
//右边是dsn格式表达式，即<用户名>:<密码>@tcp(<主机>:<端口>)/<数据库名>?<连接参数>
db, err = sqlx.Connect("mysql", "root:123456@localhost:6379/example?charset=utf8mb4&parseTime=True&loc=Local")
db.Ping()
```

如果只是想打开但不连接，可以用`sqlx.Open`. 如果从已经存在的`sqlx.DB`中创建一个新db对象，使用`NewDb`.

连接池参数：

```go
//最大闲置连接
db.SetMaxIdleConns(1)
//最大允许打开连接，默认无限制
db.SetMaxOpenConns(5)
```

## 增删改

非查询请求都是同样的接口，即：`db.Exec(sql, args...)`，当然也可以用`MustExec`，失败就panic. 实际上这个接口也是标准sql库支持的接口。

返回值是`sql.Result`和`error`. `sql.Result`有LastInsertId()和RowsAffected()两个方法，但是这个返回值能不能正确获取其实取决于数据库自己的实现。MySQL可以正确获得自增id和影响的列，但是PG就要自己在sql里面加上`returning`才行。

sql和args可以通过`go-sqlbuilder`库来生成，如（以下例子来自该库的godoc）：

```go
ib := SQLite.NewInsertBuilder()
ib.InsertIgnoreInto("demo.user")
ib.Cols("id", "name", "status", "created_at")
ib.Values(1, "Huan Du", 1, Raw("UNIX_TIMESTAMP(NOW())"))
ib.Values(2, "Charmy Liu", 1, 1234567890)

sql, args := ib.Build()
```

当然select同理.

如果不使用sqlbuilder，自己写的话，大致格式是：

```sql
insert or ignore into demo.user (id, name, status, created_at) values (?, ?, ?, ?, ?)
```

为了防止SQL注入，变量都要使用`?`占位，而不是直接拼写到sql中。

内置类型会正确映射成数据库支持的参数类型。如果是自定义类型，则可以通过实现`driver.Valuer`接口来实现。

## 查询

### 基础

首先应当知道标准sql库里如何查询：

```go
Query(sql, args...) (*sql.Rows, error)
QueryRow(sql, args...)*sql.Row
```

显然前者返回多行，后者返回单行。

`sql.Rows`是一个游标，可以通过`Next()`迭代处理：

```go
rows, err := db.Query("select age from person")
if err != nil{
    //查询错误
    return
}
for rows.Next(){
    var x int
    if err = rows.Scan(&x); err != nil{
        //scan错误
        log.Error(err)
    }
}
if err = rows.Err(); err != nil{
    //处理错误
    return
}
```

`sql.Row`可以直接`Scan`进行保存，Scan的参数个数显然应当与`SELECT`中查询的列数相当。

将数据库中获取的结果`Scan`到自定义类型，则需要实现`sql.Scanner`这个接口。

如果`Query`结果是空的，Scan会返回`sql.ErrNoRows`.

**特别注意**：如果使用`rows.Next`完成迭代，需要手动`rows.Close`关闭游标。

### sqlx的orm

sqlx扩展了标准sql的功能，可以将数据直接映射到struct中。

```go
Queryx(sql, args...) (*sqlx.Rows, error)
QueryRowx(sql, args...) (*sqlx.Row)
```

`sqlx.Rows`和`sqlx.Row`可以直接scan到struct里，sql中的字段用`db`的注解来映射：

```go
var x struct{
    Age int `db:"age"`
}
row.StructScan(&p)
```

如果不想每个字段都手动映射，可以用`db.MapperFunc(f)`, f是映射函数.

除了`StructScan`之外，还有`SliceScan`和`MapScan`，前者目标应当是`[]any`，后者则是`map[string]any`，一般很少使用这两个方法，除非不知道列的明确类型。

除了上面的方法以外，还有两个更简便的方法：

```go
Get(dest, sql, args...) error
Select([]dest, sql, args...) error
```

`Get`直接将单行结果Scan到dest里，`Select`直接将多行结果scan到dest slice里。注意后者会一次性Load所有数据，对内存造成一定的压力。

### sqlbuilder的orm

sqlbuilder也自带了一个类似的功能，无须使用`db.queryx`，而是直接使用`db.query`:

```go
var ageStruct = NewStruct(new(Age))
var age Age
row.Scan(ageStruct(&age)...)
```

不过这个用起来太麻烦，不如直接用sqlx的功能方便。可以仅使用sqlbuilder生成SELECT语句的能力。

## 事务

sqlx的事务很简单：

```
tx, err := db.Beginx()
tx.Exec()
tx.Query()
tx.Commit()
```

如果事务失败，就手动`tx.Rollback()`.

如果想要修改事务的隔离级别，使用`tx.Exec`直接运行sql语句进行更改即可。