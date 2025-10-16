---
title: Spring Kafka注意事项
date: 2025-09-14
lastmod: 2024-09-14
slug: 5d8324b
draft: false
author:
  name: tryao
tags: ["kafka", "java"]
collections: []
toc: true
math: true
lightgallery: false
---

spring-kafka是spring-boot内置的依赖之一，如果操作kafka的话，还是比较推荐的。更上层的抽象，比如stream或者integration，写的质量都不太好，不推荐使用。

<!--more-->

## 简单应用

直接在配置文件里面配好所有必须项，kv都是string。

在代码里使用@KafkaListener注解method，参数是`Consumer<?,?> records`，然后自己拿到string再反序列化。

批量消费的话，设置`batchListener`为true，然后使用`List<String>)`接受批量参数即可。

生产者需要注意的参数：

```
//0，1或者all，为了消息可靠性，一般选all；如果消息丢失影响不大，可以选1提高吞吐量
props.put(ProducerConfig.ACKS_CONFIG, producerAckMode);
//打开批量写入，128k一批，默认16k，提高8倍，所以buffer那边也要提高8倍
props.put(ProducerConfig.BATCH_SIZE_CONFIG, 131072);
//最多延迟xms，注意这里可能导致消息丢失
props.put(ProducerConfig.LINGER_MS_CONFIG, 100);
//缓存大，默认32M，提高8倍到256M
props.put(ProducerConfig.BUFFER_MEMORY_CONFIG, 256 * 1024 * 1024);
//写入超时，120s
props.put(ProducerConfig.DELIVERY_TIMEOUT_MS_CONFIG, 120000);
//重试次数：无上限，为了保证消息不丢
props.put(ProducerConfig.RETRIES_CONFIG, Integer.MAX_VALUE);
```

消费者需要注意的参数：

```
//自动提交最好关了，不过对重复消费要做一些处理
props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false);
//每次批量拉取时避免拉太多，内存
props.put(ConsumerConfig.MAX_POLL_RECORDS_CONFIG, 50);
//避免频繁重平衡
props.put(ConsumerConfig.SESSION_TIMEOUT_MS_CONFIG, 120000);
```

为了提高并发消费速度，一般Listener线程数量应该>=topic分区数，可以使用`factory.setConcurrency`设置每个Listener的默认并发线程数，这个数值可以用`@KafkaListener`的`concurrency`参数覆盖。

当然，批量消费时，可以使用线程池并发消费，等全部完成后再统一ack即可。

由于kafka的分区只能增加不能减少，所以不要一下子把分区数开的太多，不然缩容很麻烦。kafka的topic数量太多也对其性能有很大影响。

## TypeHeader

上面的简单方案中，kv都是string，通过topic来进行业务路由。但是topic本身又不能建的太多，所以更好的办法是在topic中传递多种类型的数据结构。

如果使用json作为序列化方式，很容易想到的是在json最外层加一个`type`字段，然后使用该字段进行手动路由。实际上Kafka已经内置了header机制，可以将类型放在header里面，在push/poll时自动根据添加/根据type进行路由。

生产者配置：

```
props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, JsonSerializer.class);
props.put(JsonSerializer.ADD_TYPE_INFO_HEADERS, true);
props.put(JsonSerializer.TYPE_MAPPINGS, KafkaUtils.genTypeMappingString(produceTypes));
```

消费者配置：

```
props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, JsonDeserializer.class);
props.put(JsonDeserializer.TRUSTED_PACKAGES, "*");
props.put(JsonDeserializer.TYPE_MAPPINGS, KafkaUtils.genTypeMappingString(consumeTypes));
```

其中`genTypeMappingString`用来将header中的类型字符串与实际类的名字关联起来：

```
private String genTypeMappingString(Map<String, Class<?>> map) {
  List<String> parts = new ArrayList<>();
  for (Map.Entry<String, Class<?>> entry : map.entrySet()) {
    parts.add(String.format("%s:%s", entry.getKey(), 
                            entry.getValue().getCanonicalName()));
  }
  return Joiner.on(",").join(parts);
}
```

将`@KafkaListener`放在类上面，然后在method上面使用`@KafkaHandler`，method的参数使用具体的类就行，会自动路由的。

如果害怕路由写错，可以加一个`@KafkaHandler(isDefault=true)`，配置一个默认路由，参数写`Object`类型就可以。

## Json序列化/反序列化的自定义配置

有个问题是，JsonSerializer和JsonDeserializer默认使用的ObjectMapper不太行(不能正确序列化LocalDateTime到字符串），一般需要注入自定义的objectMapper。

这里没有什么特别方便的办法，要么改为使用代码配置：

```
DefaultKafkaProducerFactory<Object, Object> factory = new DefaultKafkaProducerFactory<>(producerConfigs());
factory.setValueSerializer(new JsonSerializer(objectMapper));
```

此时所有直接通过props配置的json相关属性都要改为通过代码配置，而不能只修改这个。

要么自己继承`JsonSerializer`/`JsonDeserializer`，在ctor中注入ObjectMapper，此时这需要修改`VALUE_DESERIALIZER_CLASS_CONFIG`后面对应的类就可以。推荐使用后者，放在一个公共库里一劳永逸。

## 批量消费注意事项

上文说过，如果打开`batchListener`，监听参数必须变成List。

但是批量消费和自动路由是冲突的，这还是Java泛型类型擦除的锅，如果在批量场景多个KafkaHandler时，参数都是`List<xxx>`，由于类型擦除，所以实际上都变成了List参数，Runtime就无法判断如何进行分发。

此时只能退回将@KafkaListener加在method上的使用方式，并进行手动分发：

```
@KafkaListener(topics = Constant.TOPIC_KAFKA_XXX)
public void onEvent(List<Object> records, Acknowledgment ack) {
  for(Object record: records){
    if(record instanceof TypeA){
      //...
    }
  }
  ack.acknowledge();
}
```

如果部分topic需要打开batchListener，部分又不需要。可以建立多个返回`ConcurrentKafkaListenerContainerFactory<String, Object>`的bean，然后再`@KafkaListener`里面手动指定`containerFactory`对应的bean名字。

一般情况下，只有吞吐量特别大、且不在意处理顺序的topic才需要打开batchListener，普通的topic只要消费结点数匹配分区数就行。如果消息顺序很重要的话，即使打开批量，也是要逐个处理消息，跟逐条poll没啥区别。

## 其他

1. debug模式下，kafka每次拉取都会生成日志，所以kafka模块的日志级别最好调到INFO以上，不然日志量太大；
2. kafka的topic删除非常麻烦，即使打开了`delete.topic.enable`，有时候也删除不了（原因不明）。此时需要到节点对应的zk中，`rmr /brokers/topics/{topicName}`，并`rmr /admin/deleted_topics/{topicName}`，后者不删的话，以后重建的同名topic还是会被自动标记为待删除。
3. 如果配置`auto.create.topics.enable=true`，切记配置好自动生成topic的分区和副本数，默认配置不适合集群环境。规模较小的情况下，一般N个节点配置2N个分区+N个副本。
