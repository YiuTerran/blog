---
title: Java的MQTT客户端使用注意事项
date: 2021-09-12
lastmod: 2021-09-12
slug: 73cd87f
draft: false
author:
  name: tryao
tags: ["java"]
collections: []
toc: true
math: true
lightgallery: false
---

Java的MQTT主要客户端库是[Eclipse Paho Java Client](https://github.com/eclipse/paho.mqtt.java)，该库存在以下问题：

1. 性能不行，使用[传统BIO](https://github.com/eclipse/paho.mqtt.java/issues/473)通信，只能用线程池的方法强行并发；
2. MQTT V5的支持比较差，到目前为止还不支持[共享订阅](https://github.com/eclipse/paho.mqtt.java/issues/827)，需要自行实现；
3. 以前在使用的过程中，遇到一些莫名其妙的bug，比如[这个](https://github.com/eclipse/paho.mqtt.java/issues/576)；

所以这次重写iot平台，选用了[hive-mqtt-client](https://github.com/hivemq/hivemq-mqtt-client)，这个库目前还比较年轻，但属于hivemq的官方作品，所以质量还可以，缺点是文档不太健全，性能调优方法不是很明确。经过摸索，得到以下结论（截止1.2.2版本）：

1. 依赖问题：
   - 如果不需要在项目里单独使用netty，可以直接使用`hivemq-mqtt-client-shaded`这个库；此时netty版本就是该包里的版本；
   - 正常情况下，可以使用`hivemq-mqtt-client`配合`io.netty:netty-bom:4.x.x.Final`，来获得最新的netty版本；
   - 在linux环境下，可以添加依赖`netty-transport-native-epoll`启用原生的epoll支持，提高性能；
2. 参数调优：
   - 创建客户端时，在`executorConfig`里，可以传入netty的`NioEventLoop`，配置netty客户端的线程数；这个参数默认是2*cpu核数，实际上一般不需要自定义；
   - 在`subscribeWith`，传入callback之后可以配置executor，这个线程池用于提高**不同回调函数之间**的并发度；
   - **同一个回调函数的执行是串行的**，这是为了保证mqtt消息处理的顺序，这点调整上面的参数都没有任何作用，这是一个最大的坑点，因为文档上没有明确说明。解决方法也很简单，对于消息顺序不敏感的topic，在外面wrap一层线程池就行，或者直接使用`CompleteFuture.suplyAsync`使用核心线程池；
