---
title: Opc协议概要
date: 2021-09-01
lastmod: 2021-09-15
slug: 95d683f
draft: false
author:
  name: tryao
tags: ["iot"]
collections: []
toc: true
math: true
lightgallery: false
---

opc协议是一种中间层物联协议抽象模型，目前在用的主要是opc ua. 相关基础只是请自行百度，这里仅记录编码通信所需要的知识。

OPC UA的抽象模型就是OOP，将物理设备的物模型映射成地址空间里的 **节点(Node)** 。

例子：

1. 空调有风扇，有温度传感器，在地址空间中可以将其定义为空调对象包含的对象；
2. 空调还有温度、风速，可以定义为空调对象下的变量；
3. 空调还可以开、可以关，开和关的动作可以定义为空调对象的方法；
4. 空调也许还具有报警功能，向外发送通知，则可以定义为事件；
5. 由此，对象、变量和方法构成了OPC UA最重要的节点类别。对象拥有变量和方法，而且可以触发事件。

## 节点

标准的节点类有如下几种：

- 基本节点类：能够派生所有其他节点类，对应Java中的Node基类
- 对象类型节点类：对应实例的类型，比如AirControllerNode extends Node
- 对象节点类：对应一个实例，new AirControllerNode()
- 变量节点类：定义数据变量，AirController里面的成员变量，比如temprature表示温度
- 变量类型节点类：定义特性，成员变量的类型（temprature类型是Double）
- 方法节点类：定义方法，AirController里面的method，如setTemprature
- 引用类型节点类：定义引用。AirController里面，比如引用了一个空调遥控器实例，对应有一个引用类型。
- 视图节点类：定义地址空间中节点子集，默认是全部开放的，可以筛选自己感兴趣的节点组成一个视图。视图还可以用来跟踪配置的版本变更。

![img](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1gu13liqbmpj6087062glr02.jpg)

对象模型见上图，对象有对应的类型节点，对象代表**一组**变量和方法节点，变量也有对应的类型节点；方法可以被调用，其他节点可以引用节点，同时节点可以触发事件。

![img](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1gu13tdv3v2j60cr04b0sz02.jpg)

变量与变量类型之间的引用如上。

![image-20210901141720112](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1gu13qdvas6j607g067t8r02.jpg)

节点模型见上图，节点由属性和引用构成，NodeClass分为Type和Object。所有的节点（除了方法）都有对应的类型节点。

包含引用的节点为源节点，被引用的节点称目标节点。引用的目标节点可以与源节点在同一个地址空间，也可以在另一个OPC服务器的地址空间，甚至是目标节点可以不存在。引用是通过BrowseName来实现的，同一个地址空间里引用类型必须唯一（即类名不能重复）。

节点类常用的基础属性(attribute)：

| 名称          | 使用 | 数据类型      |
| ------------- | ---- | ------------- |
| NodeId        | M    | NodeId        |
| NodeClass     | M    | NodeClass     |
| BrowseName    | M    | QualifiedName |
| DisplayName   | M    | LocalizedText |
| Description   | O    | LocalizedText |
| WriteMask     | O    | UInt32        |
| UserWriteMask | O    | UInt32        |

> 注：M代表必备项，O代表可选项

- **NodeId**：节点ID，在服务器中唯一标识一个节点。是定位和在服务器间交换信息的最重要概念。浏览地址空间时，服务器返回NodeId，客户端在服务调用时使用NodeId来定位节点。
- **BrowseName**：浏览名称，仅用于浏览目的，不宜用来显示节点的名称，用作浏览地址空间浏览路径的一个非本地化人员可读的名称。
- **DisplayName**：显示名称，包含了节点的本地化名称。如果客户端响应显示节点名称给用户，宜使用该属性。
- **Description**：描述，本地化的文本中解释节点的含义。
- **WriteMask**：写入掩码，公开了客户端写入节点属性的可能性。该属性不考虑任何用户访问权。
- **UserWriteMask**：考虑用户访问权时，公开的客户端写入节点属性的可能性。指定哪个节点属性可被当前连接到服务器上的用户修改。

![《OPC UA 学习教程 — 总览和核心概念》](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1gu1du66am5j61hd0u043802.jpg)

各类节点之间的关系如上图。

对象节点除了上述属性外，还有下图中的属性和可能的引用：

![img](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1gu13vmxod5j60ey0e0jt202.jpg)

> 注：0…* 表示没有限制，不使用或者可以无限次用；0…1 表示最多用一次；1 表示必须提供一次

- 必备的EventNotifier属性表示对象是否可以被用于订阅事件或者读和写事件的历史；
- HasTypeDefinition引用指向被用作对象的类型定义的对象类型；
- 使用HasComponent引用来定义数据变量、对象和对象的方法；
- 使用HasProperty引用来定义对象的特性，特性都是PropertyType类型；
- HasModellingRule规定了建模规则，对象最多只能指定一个该引用；
- HasModelParent引用规定了对象的父模型；

对象类型节点可能的属性和引用：

![img](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1gu13zbjt8nj60eu09pt9p02.jpg)

注意property翻译为**特性**。

变量节点：

![img](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1gu1409r1l0j60fp0dmwg902.jpg)

变量类型节点（即变量节点中的HasTypeDefinition):

![img](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1gu14160wopj60fp0bsjsz02.jpg)

方法节点：

![img](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1gu141vc4fij60fn0b0dh802.jpg)

引用类型节点：

![img](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1gu14h8g7q1j60ew080wf702.jpg)

IsAbstract属性指示引用类型是否抽象，抽象的引用类型不能被实例化，只能用于组织。

视图节点：

![img](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1gu14lufi6mj60f908adgq02.jpg)

这些概念实际上有点绕，下面是一个例子：

![《OPC UA 学习教程 — 总览和核心概念》](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1gu1fgdpbf8j61480o178w02.jpg)

温度、压力传感器这里被定义为对象（而不是变量），连续两个黑色箭头表示ObjectType实例化为Object，连续两个白色箭头表示继承的子类型。`+`表示`hasComponent`, `-H-`表示`hasProperty`。

![《OPC UA 学习教程 — 总览和核心概念》](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1gu1fgodn7xj613h0oeq7w02.jpg)

## 建模

把信息建模分为四个详细步骤：

(1) 需求获取主要是从系统框架图和应用场景图中获取建模需要的设备类型、设备的参数即属性、设备具有的方法即事件，以及设备之间或设备与属性、设备与方法之间的关系,然后，根据特定领域相关规范来验证建模需要的信息，同时进行必要的补充，最后对这些节点信息归入八个标准的节点类别。

(2) 定义类型模型主要根据节点类别中的 4 个类型，分别定义对象类型模型、变量类型模型、引用类型模型、数据类型模型，然后合并为统一的类型模型，在定义这些模型时，UA 规范中已经存在的内置类型，可以不定义，在定义类型模型中仅仅显示根据特定领域扩展的类型，

(3) 类型模型定义之后，根据特定领域的具体实例对 4 个类型模型进行实例化，同时按照 OPC UA 服务器的标准地址空间方式，建立实例化信息模型。

(4) 利用 UA Address Space Model Designer 工具导出 XML 和 CSV 文档，作为实现实例化信息的数据来源。
OPCUA建模工具有：UAmodeler,opcua-modeler等。

## 示例

实际上OPC的建模和写Java代码差不多，就是在opc server上添加各种节点，并和PLC输入/输出端子做物理连接映射。

一般约定的建模方式：每个PLC建立一个dir，`/Objects/PLC1/device1`

device1可以用设备sn命名，是一个Object，其Type是抽象的设备类型。里面含有多个变量，对应传感器的采集值。

那么遍历device1节点下的`Variable`就可以拿到所有需要采集的属性值，只要保证`Variable`的displayName一致（通过实例化Type创建的Object，变量的displayName肯定是一致的），在产品参数里面定义好物模型字段和displayName的映射就可以。

录入设备时，录入设备对应的节点路径就可以了。
