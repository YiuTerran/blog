---
title: Springcloud Alibaba学习笔记
date: 2021-07-01
lastmod: 2021-07-02
slug: d52d870
draft: false
author:
  name: tryao
tags: ["java"]
collections: []
toc: true
math: true
lightgallery: false
---

公司技术选型决定使用`spring-cloud-alibaba`作为基础框架，这里简单记录一下对没用过组件的学习笔记。

## Nacos

主要完成服务发现、配置分发、流量管理等功能。

### 配置管理

namespace：不同命名空间下，可以存在相同的group或者dataID。一般创建生产环境、测试环境等命名空间，方便隔离；

dataId: 配置集的ID，多个配置项组成一个配置集，对应普通模式下的配置文件名字；dataId一般按包名命名，但并非强制；

group: 一组配置集，即一个项目的多个配置文件。一般每个微服务独立一个group；

![nacos_data_model](https://tva1.sinaimg.cn/large/008i3skNgy1gs1g1cgqsaj30j40g6dho.jpg)

使用主要看[跟spring的集成](https://nacos.io/zh-cn/docs/nacos-spring.html)，和[跟spring cloud的集成](https://nacos.io/zh-cn/docs/quick-start-spring-cloud.html)，以及Java的[SDK](https://nacos.io/zh-cn/docs/sdk.html)。

### 服务发现

这个就比较简单，应用将服务名和自身的ip:port注册到到nacos，并提供健康检查的url。其他服务通过服务名调用服务时就可以自动路由到正确的服务实例上，方便动态添加服务而无需修改配置文件。

## Sentinel

主要完成熔断降级。即：任意资源调用出现异常比例上升时，让调用快速失败，避免服务雪崩。

一般使用较为简单，可以配合nacos持久化配置。支持[集群限流](https://github.com/alibaba/Sentinel/wiki/集群流控)和[网关限流](https://github.com/alibaba/Sentinel/wiki/网关限流)。

生产环境使用的注意事项也较多，B端产品一般不需要限流。

## Dubbo

这个就不用说了，RPC框架，我们暂时不会用。

新版本v3.0改了架构，支持跨平台通信了。

## scheduleX

这玩意儿没开源，估计还是用xxl-job的可能性更大。

前期可以先单点跑吧。

## Sleuth

这是spring cloud里面用于链路追踪的组件。但是这玩意儿他不跨语言，所以肯定不能用。

链路追踪有一个标准规范`open-tracing`，我们实际使用中zipkin/jaeger/skywalking用的更多。

Java技术栈的推荐使用skywalking，侵入性很小。

## Stream

也是Spring Cloud原生组件，用于操作消息队列。

如果有更换消息队列的需求或者考虑，可以使用Stream抽象的pub/sub来与消息队列通信，否则建议直接用kafka等组件。
