---
title: Flink学习纪要
date: 2021-10-16T15:46:03+08:00
slug: 05cf1be
draft: false
author:
  name: tryao
tags: ["bigdata", "flink"]
collections: []
toc: true
math: true
lightgallery: false
---

flink有两套API，一套是datastream，类似spark的RDD；另外一套则是TableSQL，这是一种更新的流批一体技术，两者可以相互转换。至于传统的批处理DataSet技术，将会在未来被废弃，不必再学习。

## 基本概念

根据Google的dataflow论文，批处理可以视为有界流，这是流批一体的理论基础。

![A DataStream program, and its dataflow.](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/program_dataflow.svg)

上图是一段官方的示例代码，一个典型flink应用程序，数据从source中抽取，然后经过一系列*Operator*的*Transformation*，最后汇集到*sink*里。

注意，所有的operator之间是可以并发执行的，前提是对流进行按key hash，这也是为啥最后有一个sink等待结果汇总。

一般情况下，流数据都有一个时间戳*Event Time*，事件本身发生的时间顺序非常重要；与之对应的还有摄取时间（*ingestion time*）和算子的*processing time*。由于乱序到达问题，需要对事件进行按*Event Time*重排序，但是我们不能**无限制**的等待较早事件到来的可能，这会导致所有的事件都会被放弃处理。引入*watermark*的概念来解决这个问题，这是一个特殊事件发生器，将一个特殊时间戳插入流中，表示t之前的数据都已经全部到达。如果真的有事件早于t在watermark之后到来，称之为延迟事件。默认情况下，延迟事件将被删除。可以使用旁路输出单独获取这些延迟流；或者加一个允许延迟，在允许延迟范围内仍然会单独触发窗口；

Flink的算子可以**保留状态**，这种保留可以是持久化的，即便发生故障，也能达到**精确一次计算**( 每一个事件都会影响 Flink 管理的状态精确一次)的语义。当然端到端的精确一次需要程序本身的幂等性来实现。

可以看出，整体执行路径是一个有向图。

*window*: 将事件流拆分成窗口，常见的方式有固定时间、滑动窗口、固定数量、滑动数量以及会话窗口（最小间隔），一些注意事项：

1. 滑动窗口是通过复制实现的；
2. 时间窗口会和整数时间对齐；
3. 如果窗口之间的距离足够小，窗口就会merge；

## API

flink提供了四层抽象等级，最上面一层是纯SQL

然后是Table SQL

然后是DataStream/DataSet的抽象

目前推荐使用的是：TableSQL/DataStream，这两类API，并根据需求创建UDF

### datastream

流式处理模式，主要需要掌握的是如何写自定义Function，使用state和window；以及Watermark的配置和使用。

### CEP

复杂事件处理

配合规则引擎可以动态处理事件规则

## 练习

```
git clone git@github.com:apache/flink-training.git
git checkout release-1.13
cd flink-training
```

通过readme进行练习测试。
