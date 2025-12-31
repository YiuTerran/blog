---
title: Apifox使用技巧
date: 2025-12-31T15:08:00+08:00
slug: bfe5531
draft: false
author:
  name: tryao
tags: ['test']
collections: []
toc: true
math: true
lightgallery: false
---

现阶段还是Apifox当api管理的体验最好。

<!--more-->

# Apifox Helper配置参考

1. 首先要在idea配置-Apifox Helper-上传里配置令牌；
2. 内置规则可以关闭部分，仅保留使用到的：

![img](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/20251231151051.png)

3. 默认情况下上传接口是智能合并的，如果改动较大，可以改为覆盖：

![img](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/20251231151105.png)

## 同一模块的代码上传到不同的目录

默认情况下，同一个maven子工程是上传到同一个目录的，如果想要上传到不同的文件夹，使用@module参数进行分组。

在Controller的类上增加@module xxx的注解，第一次上传时会提示配置映射的目录，后续再次上传相同module的API时，会自动归档到对应的文件夹，也可以在如下位置手动修改：

![img](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/20251231151126.png)

建议**手动创建**API的归类目录（二级目录），因为一般是按业务来对API进行分组的，而不是按代码位置，强行关联意义不大。三级目录可以在Controller层顶端加注释来自动创建。

此外，不同服务的数据模型要新建一个文件夹，不要都导入到根目录，因为**apifox中同名的数据模型会相互覆盖**。

## 忽略某些接口或参数

使用@ignore注解即可

使用@JsonIgnore注解的参数也会被自动忽略。

## 正确处理枚举值

目前需要返回给用户的枚举分为两类：继承IPairEnum的固定枚举，和继承BaseDictValue的动态枚举（实际上是一个class，对应数据库是一个数字），这两种都需要特殊处理：

在根目录下增加一个名为`.apifox-helper.properties`的文件，内容参考：

```properties
enum.use.by.type=true
json.rule.enum.convert[groovy:it.isExtend("com.odin.common.db.convertor.IPairEnum")]=~#getValue()
json.rule.convert[groovy:it.isExtend("com.odin.common.db.dictvalue.BaseDictValue")]=java.lang.Integer
json.rule.convert[com.fasterxml.jackson.databind.JsonNode]=java.util.Map
json.rule.convert[com.fasterxml.jackson.databind.node.ObjectNode]=java.util.Map
```

如果你直接用了普通枚举，则建议转换成IPairEnum；如果在upload的时候弹出枚举的配置选择，对应的是普通枚举的处理方式。

如果你在请求参数或者返回值中直接用了枚举对应的值，可以通过@see YorEnum#value 的格式指向枚举，这样生成的文件里面自动就有枚举值的描述了，例如：

```java
/**
 * 节点类型
 *
 * @see NodeTypeEnum#getValue()
 */
private Integer nodeType;
```

在上传完成后，如果看文档发现有问题，其他类型转换也可以参考这个配置自行添加。

# 自动化测试撰写流程

1. 为模块、controller层接口添加注释；
2. 同步接口到Apifox；
3. 检查同步后的接口是否需要修改，通过添加注释、配置自定义规则等方式修正不正确的接口；
4. 为对应的接口添加接口用例；
5. 在自动化测试中引用前面的接口用例组成流程；
6. 考虑业务场景来撰写测试流程，一般需要完成正常情况下场景（正向）和**常见**的异常情况下的场景（反向）的测试；

# 离线测试

手动将自动化测试导出成json文件，使用apifox的cli文件来运行
