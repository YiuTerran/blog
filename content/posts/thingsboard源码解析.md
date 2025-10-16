---
title: Thingsboard源码解析
date: 2021-06-23
lastmod: 2021-06-28
slug: 63d6701
draft: false
author:
  name: tryao
tags: ["java", "iot"]
collections: []
toc: true
math: true
lightgallery: false
---

看的源码是最新的3.2 release版本，目前支持的最低JDK版本是11. 如果本地默认jdk是8的话，可以用`jenv`标记成11.

项目使用了lombok插件，构建系统为Gradle混合maven，通信使用了Protobuf，相关知识可以先自行补完。

另外，请一定要首先阅读[thingsboard官方文档](https://thingsboard.io/docs/user-guide/entities-and-relations/)中**key concepts**这一节，明白它的抽象模型。

## 准备工作

首先IDE需要安装lombok和Protobuf相关插件，有个proto文件生成的java代码过大(`TransportProtos`)，默认是不会解析的。需要编辑ide的属性(Help-Edit Custom Properties)，加入`idea.max.intellisense.filesize=3000`，将上限提高到3M.

先在本地编译一下代码：`mvn clean install -Dmaven.test.skip=true`.

如果在编译过程中提示找不到Gradle，检查全局maven的`settings.xml`，参考配置如下：

```
<mirrors>
    <mirror>
      <id>aliyun-central</id>
      <mirrorOf>central</mirrorOf>
      <name>aliyun-central</name>
      <url>https://maven.aliyun.com/nexus/content/repositories/central</url>
    </mirror>
    <mirror>
      <id>aliyun-jcenter</id>
      <mirrorOf>jcenter</mirrorOf>
      <name>aliyun-jcenter</name>
      <url>https://maven.aliyun.com/nexus/content/repositories/jcenter</url>
    </mirror>
    <mirror>
      <id>aliyun-google</id>
      <mirrorOf>google</mirrorOf>
      <name>aliyun-google</name>
      <url>https://maven.aliyun.com/nexus/content/repositories/google</url>
    </mirror>
    <mirror>
      <id>aliyun-gradle</id>
      <mirrorOf>gradle-plugin</mirrorOf>
      <name>aliyun-gradle</name>
      <url>https://maven.aliyun.com/nexus/content/repositories/gradle-plugin</url>
    </mirror>
    <mirror>
      <id>aliyun-spring</id>
      <mirrorOf>spring</mirrorOf>
      <name>aliyun-spring</name>
      <url>https://maven.aliyun.com/nexus/content/repositories/spring</url>
    </mirror>
    <mirror>
      <id>aliyun-spring-plugin</id>
      <mirrorOf>spring-plugin</mirrorOf>
      <name>aliyun-spring-plugin</name>
      <url>https://maven.aliyun.com/nexus/content/repositories/spring-plugin</url>
    </mirror>
    <mirror>
      <id>aliyun-grails-core</id>
      <mirrorOf>grails-core</mirrorOf>
      <name>aliyun-grails-core</name>
      <url>https://maven.aliyun.com/nexus/content/repositories/grails-core</url>
    </mirror>
    <mirror>
      <id>aliyun-apache-snapshots</id>
      <mirrorOf>apache snapshots</mirrorOf>
      <name>aliyun-apache-snapshots</name>
      <url>https://maven.aliyun.com/nexus/content/repositories/apache-snapshots</url>
    </mirror>
</mirrors>
```

这里将大部分常用的仓库替换成阿里的代理，正常的话，就可以编译成功了。

## 主体结构

根目录下分为以下几个文件夹：

```
├── application # 主服务，单体部署时该服务就是最后跑的jar包
├── common # 通用组件
├── dao # 数据库dao层
├── docker # 容器化部署所需要的docker配置文件和各种脚本
├── img # logo文件夹
├── k8s # k8s部署需要的配置文件和脚本
├── msa # 微服务部署需要的maven子项目
├── netty-mqtt # 使用netty实现的mqttv3服务器
├── packaging # Gradle打包脚本，用于将前后端打包成rpm/deb包
├── rest-client # 测试用的rest客户端（可以忽略）
├── rule-engine # 规则引擎
├── tools # 一个迁移pg数据到timescaledb的工具
├── transport # msa部署时独立的接入层服务
└── ui-ngx # 前端项目，基于angular
```

其中netty-mqtt这个库应该是fork了[这个库](https://github.com/jeffreykog/netty-mqtt)，简单改了一些代码。

顶级transport文件夹下其实没有业务代码，只是一个独立的springboot application。真正的业务代码在`common/transport`下，通过`pom.xml`和 `ComponentScan`将对应的包加到依赖里，并随着springboot启动而自启动。

### actor模型

首先要看一下这里tb自己实现的actor模型（替换掉原来的akka），在`common/actor`这里。actor模型是规则引擎的基础，规则链上每一个结点都是一个actor，显然这里如果用go的话，每个做一个goroutine就行；actor这里是创建了各类消息的一堆线程池。

自己写结点只需要用`@RuleNode`注解，然后实现`TbNode`接口就行。

actor服务的入口在application下的`DefaultActorService`，这里初始化了整个actor系统。

`DefaultTbRuleEngineConsumerService`和`DefaultTbCoreConsumerService`是调用actor的入口，`AbstractConsumerService.onApplicationEvent`这里会在服务启动完毕之后拉起所有的消息队列consumer.

### 设备数据处理逻辑

接入层的代码处理逻辑其实差不多，只是支持的协议不一样。

查看mqtt的`MqttTransportHandler`中的`processMqttMsg`->`processPublish`->`processDevicePublish`，处理代码定位到`DefaultTransportService.process`中：

- 处理消息时调用了`DefaultTransportService.process(deviceSessionCtx.getSessionInfo(), postTelemetryMsg, getPubAckCallback(ctx, msgId, postTelemetryMsg))`，这里创建了包装消息TbMsg；
- `getPubAckCallback`显然传入了个处理ack的回调函数，正常才会ack，异常就直接disconnect了。另外process代码中有流量控制（基于bucket4j的令牌桶）；
- 然后调用`sendToRuleEngine(tenantId, deviceId, sessionInfo, json, metaData, SessionMsgType.POST_TELEMETRY_REQUEST, packCallback)`将消息发往规则引擎；注意这里除了遥测数据外，有些数据调用的是`sendToDeviceActor`，将数据发往core；
- `packCallback`在原来callback的基础上wrapper了一些信息，最后调用实际MQ的send实现；
- 假设用的是kafka，这里就是调用`TbKafkaProducerTemplate.send`将数据放入消息队列，消息的类型是`TbProtoQueueMsg<ToRuleEngineMsg>`；
- 查看thingsboard.yml，可以看到默认的ack设置是all，所以发送端没有exception才会ack，有异常就直接断开连接了；

所以从发送端来看，接受mqtt消息->pub到kafka->wait ack-> ack mqtt的逻辑没有问题，在这里**消息不会丢失**。

下面看消费端的逻辑：

消费端的入口比较难找，倒着来看，先找存储到db的代码，最后发现相关逻辑就在于`DefaultTelemetrySubscriptionService.saveAndNotify`这个方法里。调用方是`TbMsgTimeseriesNode.onMsg`，因此这里应用了上文所说的actor模型，即存储也是通过规则引擎完成的。

根据actor模型的入口`DefaultTbRuleEngineConsumerService`，查看`launchConsumer`的代码，可以看到这里取出了发送端入列的`TbProtoQueueMsg<ToRuleEngineMsg>`，然后调用`forwardToRuleEngineActor`将消息转发给规则引擎。callback在这里被创建，实际调用`TbMsgPackProcessingContext`的callback，查看实现发现核心逻辑在`submitStrategy`的callback，而这提交策略来自于`ruleEngineSettings.queues`，需要查看配置文件`thingsboard.yaml`里面的`queue.rule-engine.queues`，这里面根据队列的名称有不同的提交策略。

查看提交策略相关代码，会发现队列名字取决于设备本身的`deviceProfile`。查看[官方文档](https://thingsboard.io/docs/user-guide/device-profiles/)，会发现默认队列都是Main，此时提交策略是`BURST`，查看其实现代码，会发现`doOnSuccess`啥也没做。那么消费端的确认在哪里呢，回到`DefaultTbRuleEngineConsumerService`，会发现在这里直接就调用`consumer.commit()`了，并没有等待规则链调用完毕再进行消费确认。

所以**消息的丢失是因为消费端并未等待真正落地才commit offset**，而是转发给规则引擎后就立刻提交了。

**FIXME**：存储到db层不应该走规则引擎，而是直接存储完成后再触发规则引擎。不过这种设计要考虑如何让应用层自定义数据验证、清洗的逻辑。

其他设备相关的逻辑，比如设备连接/断开，设备命令等，也是类似的抽象成各种事件，最后使用规则引擎来处理。

### 微服务(msa)部署

从上面可以看出，tb的核心就是**规则引擎**，主要逻辑就是由规则引擎和接入层构成，存储只是规则引擎的一个节点。

msa这块，tb最开始作为单体服务设计，后面就是把这个单体服务拆分成msa.可以看[官方架构文档](https://thingsboard.io/docs/reference/msa/)明白大概设计。

查看docker-compose文件，可以看到大致分为以下几个服务：

- zookeeper. kafka依赖，thingsboard节点服务发现；

- Kafka. 通信依赖；

- redis. 缓存；

- tb-js-executor. 独立的js解释器，基于node.js；单体部署的时候，用的是嵌入式js执行器；

- 主服务. 包括：

  - [REST API](https://thingsboard.io/docs/reference/rest-api/) calls;
  - WebSocket [subscriptions](https://thingsboard.io/docs/user-guide/telemetry/#websocket-api) on entity telemetry and attribute changes;
  - Processing messages via [rule engine](https://thingsboard.io/docs/user-guide/rule-engine-2-0/re-getting-started/);
  - Monitoring device [connectivity state](https://thingsboard.io/docs/user-guide/device-connectivity-status/) (active/inactive).

  后续版本会把规则引擎移出去作为一个独立的服务。

- 前端web-ui服务；

- 接入层独立服务(mqtt/http/coap)；

可以看到各独立服务和单体的时候的区别就是加了个独立的入口，使得bean在不同的进程中运行而已。
