---
title: Influxdb Cluster集成
description:
toc: true
authors: ["tryao"]
tags: ["influxdb", "tsdb", "golang"]
categories: []
series: []
date: 2022-09-01T15:47:56+08:00
lastmod: 2022-09-01T15:47:56+08:00
featuredVideo:
featuredImage:
draft: true
---

本文记录在golang项目中集成`influxdb-cluster`需要的知识储备。

## 术语

### database

和MySQL中一致

### batch

`\n`分割的多行数据，用来批量写入。

influxDB推荐5000~10000个点批量写入以提高性能。

### bucket

database+RP

### CQ

连续查询，可以理解为一个物化视图，当数据更新时自动执行的select语句。不过这里要求必须带上`GROUP BY time()`

### duration

数据保存时间，自动滚动删除

### field

没加索引的额外字段，kv pair

### data point

即点位，可以理解为表中的一行数据。

### line protocol

写入数据时，数据的格式：

>```
>weather,location=us-midwest temperature=82 1465839830100400200
>  |    -------------------- --------------  |
>  |             |             |             |
>  |             |             |             |
>+-----------+--------+-+---------+-+---------+
>|measurement|,tag_set| |field_set| |timestamp|
>+-----------+--------+-+---------+-+---------+
>```

注意分隔符，时间戳在最后，默认时间精确到纳秒

tag和field的key是字符串，value默认为float，其他的的格式约定如下：

* 整数，在数字后面加`i`;
* 字符串，加双引号`""`；
* `t`, `T`, `true`,`True`和`TRUE`，都是真；相对应的false也存在；
* 以下需要使用`\`转义：
  * 逗号`,`
  * 等于号`=`
  * 空格` `
  * 双引号`""`

如果measurement、tag_set和timestamp都相同，则视为同一个点位。此时field_set会尝试合并，如果新的key与旧的重复，则使用新的覆盖旧的。

## 数据结构

`shard`是`influxdb`存储引擎`TSM`的具体实现。`TSM TREE`是专门为`influxdb`构建的数据存储格式。与现有的`B+ tree`或`LSM tree`实现相比，`TSM tree`具有更好的压缩和更高的读写吞吐量。

`shard group`是存储`shard`的逻辑容器，每一个`shard group`都有一个不重叠的时间跨度，可根据保留策略`retention policy`的`duration`换算而得。数据根据不同的时间跨度存储在不同的`shard group`中。

