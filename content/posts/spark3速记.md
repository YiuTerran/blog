---
title: Spark3速记
date: 2021-08-30
lastmod: 2021-08-31
slug: a32eece
draft: false
author:
  name: tryao
tags: ["bigdata"]
collections: []
toc: true
math: true
lightgallery: false
---

spark的核心抽象概念是RDD，但是到了spark2就不再推荐直接使用rdd来编程，而是使用sparkSQL和StructStreaming（代替旧的spark streaming）。

由于架构问题，spark无法做到真正的realtime，所以在流处理这里，国内团队基本都是以flink为主。这就造成了lambda架构中，离线数仓以hive+spark sql为主；实时数仓以flink+kudu/doris为主的两条链路。

根据业界目前公认的“批是有界流”抽象思路，Flink流批一体的架构是正确的方向。未来，大数据处理逻辑会简化成以Flink为计算中心，配合实时存储（HTAP数据库）的简化路径。甚至于，对于流量不太大的场景，直接使用TiDB+Flink/Spark的架构就可以同时满足流批处理需求。

## RDD概念

RDD is an **immutable**, **fault-tolerant**, **partitioned** collection of elements that can be operated on **in parallel**。

将数据集进行拆分，变为一个不可变、多分区的元素组合，这样就可以在多结点进行并行计算。

RDD支持比MapReduce多的多的算子，一般分为两类：

### Transformation

此类算子是延迟执行的，直到Action算子出现。用于将RDD变换成新的RDD。

对应参数可以简单分为KV类型和纯value类型。

value类型包括：

- map
- flatMap
- mapPartitions: 遍历算子，可以改变RDD格式，会提高RDD并行度，遍历单位是partition，也就是在遍历之前它会将一个partition的数据加载到内存中。一般比map效率更高，但是可能会OOM，此时用repartition增加rdd数目即可解决；
- mapPartitionsWithIndex
- cartesian: 笛卡尔积
- groupBy
- groupByKey
- filter
- distinct
- union: rdd数据并集
- subtract: 差集
- intersection: 交集
- sample
- cache/persist: 缓存/持久化，加快重复计算

kv型包括：

- mapValues
- combineByKey
- reduceByKey
- repartition
- cogroup：将(k, v), (k, w)组合成(k, [v], [w])，即k和v的数组
- join：连接，将(k, v)和(k, w)连接成(k, [v,w])，其中[v, w]是对k相同的集合value做笛卡尔积，即(1, 2) (1, 3)合并成(1,(2,2)), (1, (3,3))和(1,(2,3))，该操作用处较少
- leftOuterJoin/rightOuterJoin/fullOuterJoin，类似数据库的左|右|全连接

### action算子

spark会立刻执行action算子。

- foreach
- saveAsTextFile
- saveAsObjectFile
- collect：收集结果，注意防止OOM
- collectAsMap
- count/countByKey/CountByValue
- take/takeSample
- reduce
- aggregate：聚合，常用
- zip/zipWithIndex

## SparkSQL

spark目前推荐直接使用sparksql进行操作，而不是使用低级的rdd。

这也符合整个大数据届从DBMS -> NoSQL -> NewSQL的发展趋势，Flink/Hive/Spark都重新回归SQL了。甚至ES、Clickhouse这些新型数据库也都是主推SQL了。

但是注意：使用sparkSQL和直接用hive on tez use llap的sql来计算，速度已经差不多了。

所以如果直接从hadoop3.x搭建基础设施的话，可以考虑回归到离线直接用hive来算，不再引入spark的旧路上。

一般使用步骤：

1. 先创建sparkSession

```
import org.apache.spark.sql.SparkSession;

SparkSession spark = SparkSession
  .builder()
  .appName("Java Spark SQL basic example")
  .config("spark.some.config.option", "some-value")
  .getOrCreate();
```

然后从数据源里面创建dataframe:

```
Dataset<Row> df = spark.read().json("examples/src/main/resources/people.json");
```

df本身支持一些常见的数据库操作，如：

```
//select * from table where age > 21
df.filter(df.col("age").gt(21)).show();
//select age, count(*) from table group by age
df.groupBy("age").count().show();
```

`DataSet<POJO>`就是讲Row反序列化到具体的Java Bean，其实就是ORM的思路。

所以这玩意儿到最后就和一般的Java程序没啥区别了……

比如定义一个Person的POJO:

```
@Data
@Accessors(chain=true)
public class Person {
  private String name;
  private int age;
}
```

定义一个encoder：

```
Encoder<Person> encoder = Encoders.bean(Person.class);
```

然后用`df.as(encoder)`就可以完成类型转换。

或者用

```
Person person = new Person().setName("xx").setAge(18);
spark.createDataset(
  Collections.singletonList(person),
  encoder
);
```

也可以创建一个`DataSet<Person>`.

也可以从RDD逐步创建出DataFrame，步骤比较繁琐，必须要手动创造出schema：

```
// Create an RDD
JavaRDD<String> peopleRDD = spark.sparkContext()
  .textFile("examples/src/main/resources/people.txt", 1)
  .toJavaRDD();

// The schema is encoded in a string
String schemaString = "name age";

// Generate the schema based on the string of schema
List<StructField> fields = new ArrayList<>();
for (String fieldName : schemaString.split(" ")) {
  StructField field = DataTypes.createStructField(fieldName, DataTypes.StringType, true);
  fields.add(field);
}
StructType schema = DataTypes.createStructType(fields);

// Convert records of the RDD (people) to Rows
JavaRDD<Row> rowRDD = peopleRDD.map((Function<String, Row>) record -> {
  String[] attributes = record.split(",");
  return RowFactory.create(attributes[0], attributes[1].trim());
});

// Apply the schema to the RDD
Dataset<Row> peopleDataFrame = spark.createDataFrame(rowRDD, schema);
```

可以通过集成`UserDefinedAggregateFunction`实现UDF，类似DBMS里面的函数/存储过程。

sparkSQL可以直接在文件、Hive和JDBC上连接上运行.

如果需要用spark分析hive数据，推荐将hive存为parquet格式。
