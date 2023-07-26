---
title: PromQL笔记
description:
toc: true
authors: [“tryao"]
tags: ["prometheus","k8s"]
categories: []
series: []
date: 2023-07-24T11:21:33+08:00
lastmod: 2023-07-24T11:21:33+08:00
featuredVideo:
featuredImage:
draft: false
---

## 格式

类似influxdb，prometheus也有自己的line protocol：

```
<--------------- metric ---------------------><-timestamp -><-value->
<---metric name--->{labelname=labelvalue,....}
http_request_total{status="200", method="GET"}@1434417560938 => 94355
http_request_total{status="200", method="GET"}@1434417561287 => 94334
```

上面就表示在某个时间戳系统http GET请求中200的数量。

指标(metric)名称即`http_request_total`，必须符合正则：`[a-zA-Z_:][a-zA-Z0-9_:]*`;

标签(label)用来过滤，名称符合正则：`[a-zA-Z_][a-zA-Z0-9_]*`;系统保留以双下划线`__`开头的标签；value则可以是任意字符串；

## 指标类型

prometheus预定义了四种指标类型(Metric Type)：

1. Counter：计数器。只增不减，如上面那个`http_request_total`；推荐用`_total`作为metric的后缀；
2. Gauge: 仪表盘。可增可减，如系统可用内存等；
3. Histogram（直方图）和Summary（概览）：为了解决99分位等长尾指标设计的类型。两者的区别是Summary是客户端算好的分位；History则是需要服务端在查询时实时计算；

## PromQL格式

### 基础

其实prometheus的查询语法很简单，和line protocol很像：

```
http_requests_total{instance="localhost:9090",...}[5m]offset 1m
```

前面是查询指标，`{}`内是查询条件，通过`label`过滤。支持的操作符包括：

> =: 等于
>
> !=: 不等于
>
> =~: 正则匹配
>
> !~: 反向正则匹配

`[]`内是时间范围，支持`s/m/h/d/w/y`. 这个结束时间就是当前，如果想要结束时间不是当前，就要加上`offset`，后面跟上的值相当于将结束时间向前推移多少。

不加时间范围，默认查询的就是最新一条数据，这种返回结果称为**瞬时向量**；反之被称为**区间向量**。

聚合函数就是在前面一般查询语法的基础上增加函数调用：

```
sum(http_requests_total)
avg(node_cpu) by (mode)
```

by后面的是分组的标签。

合法的PromQL要求至少一个指标名称或不会匹配到空字符串的标签过滤器。

如果想要同时查询多个指标名称，可以写成：

```
{__name__=~"a|b"}
```

这是因为指标名称本身也是一个标签。

在PromQL中还可以直接使用数值和字符串，如：

```
node_memory_free_bytes_total / (1024 * 1024)
```

后面的数值被称为**标量**。

> 当瞬时向量与标量之间进行数学运算时，数学运算符会依次作用域瞬时向量中的每一个样本值，从而得到一组新的时间序列。

这个其实比较容易理解。但是瞬时向量之间也可以进行数学运算，如：

```
node_disk_bytes_written + node_disk_bytes_read
```

这个计算流程就比较复杂了：

> 依次找到与左边向量元素匹配（标签完全一致）的右边向量元素进行运算，如果没找到匹配元素，则直接丢弃。同时新的时间序列将不会包含指标名称。 

有点类似SQL中的`join on`所有字段的意思。

### bool过滤

如果需要的是bool类型的过滤，直接在表达式后面添加操作符即可，如`==`/`!=`/`>`/`>=`/`<`/`<=`某个值。如：

```
http_request_total > 1000
```

获取的是>1000的值。

如果只想要bool的结果，如：

```
http_request_total > bool 1000
```

则返回的时间序列里value是`1`或者`0`，表示`true`和`false`。

### 集合运算

瞬时向量之间可以使用集合运算：

* `and`: a and b会生成一个a的子集，由a中完全匹配b中的元素组成；
* `or`: a or b会产生一个a的超集，包括a中所有元素和b中未能匹配a中的元素；
* `unless`: a unless b会产生a的一个子集，与and相反，由a中无法与b匹配的元素组成；

所谓**匹配**，默认情况下指的是标签完全一致，不过可以使用 `on`或者`ignoring`来修改匹配的逻辑。

举个例子，时序数据如下：

```
method_code:http_errors:rate5m{method="get", code="500"}  24
method_code:http_errors:rate5m{method="get", code="404"}  30
method_code:http_errors:rate5m{method="put", code="501"}  3
method_code:http_errors:rate5m{method="post", code="500"} 6
method_code:http_errors:rate5m{method="post", code="404"} 21

method:http_requests:rate5m{method="get"}  600
method:http_requests:rate5m{method="del"}  34
method:http_requests:rate5m{method="post"} 120
```

则表达式

```
method_code:http_errors:rate5m{code="500"} / ignoring(code) method:http_requests:rate5m
```

分子是所有code=500的瞬时向量，分母是忽略了code匹配的总请求数。如果不使用`ignoring`表达式，这里无法匹配到任何指标。

上面是一对一的情况，而表达式：

```
method_code:http_errors:rate5m / ignoring(code) group_left method:http_requests:rate5m
```

则表示多对一的情况。

在`ignoring code`的前提下，右侧1行数据可以匹配到左侧多余1行的数据。这种情况下，必须通过`group`修饰符指明保留左侧的所有行还是右侧的，这里是为了计算各类method报错的比例，所以以左侧为主。

### 聚合函数

内置的聚合操作符包括：

* sum (求和)
* min (最小值)
* max (最大值)
* avg (平均值)
* stddev (标准差)
* stdvar (标准方差)
* count (计数)
* count_values (对value进行计数)
* bottomk (后n条时序)
* topk (前n条时序)
* quantile (分位数)

语法是：

```
<aggr-op>([parameter,] <vector expression>) [without|by (<label list>)]
```

只有`count_values`, `quantile`, `topk`, `bottomk`支持参数(parameter)。

without用于从计算结果中移除列举的标签，而保留其它标签。by则正好相反，结果向量中只保留列出的标签，其余标签则移除。类似SQL中`group by`的参数。

### 其他内置函数

除了聚合函数外，prometheus内置了大量各种统计的函数方便作图运算。例如：

* irate: 瞬时增长率
* rate: 平均增长率
* increase: 增长量
* predict_linear: 基于线性回归的变化预测
* histogram_quantile: 对histogram类型的数据计算分位数
* label_repace/label_join：对标签做一些基于字符串的动态增减

### 通过命令行使用PromQL

就是通过http API直接访问接口获得数据，参考[这里](https://prometheus.io/docs/prometheus/latest/querying/api/)。

这里返回的结果当然就是json数据，如果需要类似MySQL的表格输出，可以使用[这个](https://github.com/nalbury/promql-cli)工具，该工具还支持简单的ASCII图形输出。

