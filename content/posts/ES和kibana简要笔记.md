---
title: ES和kibana简要笔记
description:
toc: true
authors: ["tryao"]
tags: ["elasticsearch"]
categories: []
series: []
date: 2023-11-13T10:11:35+08:00
lastmod: 2023-11-13T10:11:35+08:00
featuredVideo:
featuredImage:
draft: false
---

由于比赛需要用到es和kibana，重新复习一下这块的内容。

## 基础概念

ES的概念和其他数据库截然不同，虽然和mongodb同为文档型数据库，但是后者的很多概念更接近于普通的关系型数据库。

### 集群

ES是分布式数据库，并且自己实现了一致性算法。

ES7之前，leader选举算法是bully；之后则换成了类似raft的算法，细节可以参考[这个博客](https://yemilice.com/2021/06/16/elasticsearch-%E6%96%B0%E8%80%81%E9%80%89%E4%B8%BB%E7%AE%97%E6%B3%95%E5%AF%B9%E6%AF%94/).

### 节点

实际上就是一个进程，依靠集群的名称来自动发现集群。

### 索引

es的索引可以简单理解为MySQL中的表。

### 文档

可以简单理解为MySQL中的行。

### 分片与副本

分片是为了水平拆分数据，类似MySQL中的手动分表，但是es是自动分片的。每个分片都是一个完整的Lucene索引。

副本：为分片创建的备份，可以理解为MySQL中的从库。当主分片失效后，某个副本分片可以被选做主分片。

在创建索引时，可以指定分片与副本的数量（也可以统一配置）。创建索引之后，副本的数量是可以调整的，但是分片的数量理论上不行（不过也有相关的API，如`_shrink`或`_split`.

默认情况下，会有1个主分片和1个副本。

## API

默认情况下，内部使用的API都会以`_`开头，比如

```bash
curl "localhost:9200/_cat/health?v"
```

统一格式如下：

```bash
<HTTP Verb> /<index>/<endpoint>/<id>
```

endpoint如`_doc`是操作文档本身，put和post可以通过`_doc`创建/替换文档。

更新部分字段可以用POST `_update`来进行。但是请**注意**：es底层并不能更新文档，而是删除旧的创建一个新的，所以即使更新的内容不变也会做此操作。可以用`"detect_noop": true`来做一次无变更检测。

POST `_bulk`可以批量更新/创建/删除文档，如

```curl
POST /idx/_bulk?pretty

{"update":{"_id": "1"}}
{"doc":{"foo":"bar"}}
{"delete":{"_id": "2"}}
```

这里的批量其实更类似redis的multi，只是为了减少网络io耗时。

批量导入json数据集，可以用 `--data-binary "@name.json"`  配合curl.

真正的批量删除（按查询条件删除），使用`_delete_by_query`，该接口支持异步化；同理也有`_update_by_query`的批量操作。

## schema

作为文档型数据库，类似MongoDB，可以无schema建表。如果需要的话，也可以使用mapping来建立schema.

PUT /idx

```json
{
    "mappings":{
        "properties":{
            "age":{"type": "long"},
            "birthDate":{"type": "date"},
            "name":{"type":"text", "fields":{"keyword":{"type":"keyword", "ignore_above": 100}}}
        }
    }
}
```

支持的类型：

* 字符串：text, keyword；text不能被用于排序，会被全文检索；keyword则相反；
* 整数：integer, long, short, byte
* 浮点：double, float, half_float, scaled_float
* 逻辑: boolean
* 日期：date，一般配合`format`参数来使用：`"format": "yyyy-MM-dd HH:mm:ss||yyyy/MM/dd||epoch_millis"`；
* 范围类型：range(integer_range, long_range, date_range等)
* 二进制：binary
* 数组：array
* 对象类型：object
* 嵌套类型：nested
* 地理类型：geo_point
* 地理地图：geo_shape
* 特殊类型：ip

如果text字段需要用来进行排序，就要增加`fields`参数；

默认所有字段的`doc_values`都是打开的，设置`doc_values: false`，这个字段将不再支持据聚合、排序和脚本执行（Script）；如果设置`index: no`，则关闭了倒排索引，此时不支持查询，但是可以聚合；



## 搜索

作为一个搜索引擎，es最重要的API就是关于搜索的。es支持querystring搜索和body搜索，一般使用后者，即query DSL.

API路径为`<index>/_search`，index支持通配符，即跨多个索引检索。

query DSL的大致格式如下：

```js
{
    "query":{"match":{"foo": "bar"}}, //搜索条件
	"_source":["key1", "key2"], //需要的字段
	"sort":{"key1":{"order": "desc"}} //排序
}
```

query里面显然能塞各种查询条件，类似SQL. 如：

### bool查询

```js
{
    "query":{"bool":{
        "must":[{"match":{"foo":"bar"}}] //must也可以改为should，表示任意一个条件满足即可；也可以是must_not或者should_not
    }}
}
```

返回值有一个`_score`，这个是根据bool查询的匹配程度来的，越匹配分数越高。

如果我们不关心分数，只想过滤字段，可以使用`filter`查询：

```js
{
    "query":{
        "bool":{
            "must":{"match_all":{}}, //查询部分，匹配所有文档
        	"filter":{ //过滤部分，具体的条件
                "range":{
                    "balance":{
                        "gte": 1000,
                        "lte": 2000
                    }
                }
            }
    }
}
```

### 日期匹配

索引中的日期，可以用一些特殊的特殊来搜索，即

```
<static_name|date_math_expr{date_format|timezone}>
```

如：

```
<logstash-{now/d}>
```

对应的实际上是`logstash-2023.11.13`.

### 查询折叠

```js
{
    "collapse":{
        "field": "user"
    },
    "sort":["likes"],
    "from": 10,
    "size": 10
}
```

相当于按user分组，每组只取排序中的第一个结果。折叠字段必须是keyword或者numeric，而且打开doc_values属性。

SQL中可以用窗口查询完成类似操作。

如果想要每组多返回几个结果，可以在里面加上`inner_hits`选项：

```js
{
    "collapse":{
        "field": "user",
        "inner_hits":{ //这里也可以是一个数组，多种排序规则
            "name": "last_tweet",
            "size": 5,
            "sort":[{"date":"asc"}]
        }
    }
}
```

inner_hits里面还允许传入`collapse`进行二级折叠，但是更多的就不允许了。

### 索引加权

跨多个索引搜索时，可以为每个索引设置权重：

```js
{
    "indices_boost":{
        {"idx1": 1.4},
        {"idx2*": 1.5}
    }
}
```

这里也支持通配符或者别名。

### 对象数组搜索

即es中的`nested`类型，这种类型无法通过`a.b.c`这种格式直接搜索，需要在外层增加`nested`，或者has_child/has_parent来进行搜索。

```js
"query":{
    "nested":{
        "path": "user",
        "query":{
            "match":{"user.first": "John"} //注意这里key仍然是全路径
        },
        "inner_hits":{}
    }
}
```

`inner_hits`会把搜索条件的命中也显示出来。

### 分页

默认分页(from + size)，最多只能看10000页，这是因为深分页开销太大。

解决方案之一，是用scroll api来完成深分页，即

POST /idx/_search?scroll=1m

```js
{
    "size": 100,
    "query":{
        "match_all":{}
    }
}
```

返回结果里面有一个`_scroll_id`，后面翻页可以用:

POST /_search/scroll来继续，每次都需要传入一个`scroll`参数，表示快照继续保留的时间长度。超过这个时间，scroll上下文会从内存里面清除。

scroll搜索不适用于实时搜索，即后续的滚动翻页返回的仍然是第一次搜索时间点产生的快照。

如果想要实时搜索，可以使用`search_after`参数进行翻页，它每次返回的都是实时的结果，这就有一些额外的要求：

* 必须基于排序字段来进行翻页，这个排序字段最好是不重复的；
* 如果不关心排序，可以使用`_doc`加快速度；

### total值预估

默认情况下，命中在10000以内的搜索，total结果是准确的；反之，是一个预估值。

可以通过将`track_total_hits`设为true或者具体的数值，来配置这一默认行为。

### 并发控制

es默认使用乐观锁，也就是版本来进行并发控制。

如果我们想要修改某个版本的文档（如果此时文档被他人并发修改，则放弃修改），可以在`_search`中传入`version: true`参数，获取文档的版本参数。

然后在PUT的时候指定版本：在url后面加上类似`?version=1`的参数即可。

### 其他

通过GET /idx/_count完成计数；

通过GET /idx/_validate/query 来校验自己的查询语句是否合法；

### 聚合

一般分为4类：

* 桶聚合：将文档关联到满足条件的桶中，最终获得一组桶；
* 度量值聚合：在一组文档上跟踪和计算metrics的聚合；
* 矩阵聚合：对多个字段进行操作，并根据从请求的文档字段中提取的值生成矩阵结果的聚合；
* 管道聚合：聚合上面各种聚合，通过管道操作符进行连接；

格式一般是：

```js
{
    "aggs":{
        "key":{ //聚合后的字段
            "buckets":[ //聚合的方法，如avg/min/max/terms等
             {"key": "x", ""} //聚合方法的参数，如桶的分段、百分位等等  
            ],
            "aggs":{ //嵌套聚合
                
            }
        }
    }
}
```

这块的函数特别多，需要的时候再查询。