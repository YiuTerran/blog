---
title: 基于阿里云iot平台的简化版设计方案
date: 2021-08-03
lastmod: 2021-08-05
slug: aacf314
draft: false
author:
  name: tryao
tags: ["architecture"]
collections: []
toc: true
math: true
lightgallery: false
---

## 抽象概念

- 产品(Product)：使用相同连接方式+相同物模型的一类设备。基本字段：

  - 唯一标识：平台生成的产品唯一标识，一般是uuid；

  - 名称；

  - 描述；

  - 节点类型：直连设备、网关设备和网关子设备；

  - 联网方式：WiFi、蜂窝、以太网，以及lora，lora需要填入一些参数（前期先不支持）；

  - 连接协议：指的是数据到上一级节点的通信协议。我们暂时**不使用阿里云那种自定义topic+脚本转换**的方式，而是选择已经对接好的协议：

    - 对于直连设备和网关设备：
    - 标准MQTT协议：使用规定好的topic进行pub/sub，格式可以参考阿里云；
      - 标准HTTP(S)协议：使用规定好的url进行上报；如果想要下控，需要对端host地址；或者参考阿里云，**不支持通过HTTP协议下控**；
      - 其他协议：手动对接的各类协议。所有协议都有唯一编码；
    - 对于网关子设备，可以实现一些常见的硬件协议，如：
      - modbus协议；
      - opc ua协议；
      - ZigBee协议；
      - 蓝牙协议；
      - **未知协议**：这里的网关还包括云云对接的情况，此时网关产品下挂载的设备实际是一种虚拟设备；此时设备如何上第三方云平台我们是不必知晓的，此时标记为未知协议即可，该协议不需要任何参数；
    - 无论哪种设备，这里选择的协议都是设备与拓扑模型中的**上一层**通信的协议，协议需要的参数一般是配置在设备层的。

  - 物模型：**暂不允许自定义物模型**，只能从预置的物模型里面筛选；

    - 属性：属性其实是一种综合了事件+命令的抽象，自动生成对应的get/set命令，以及post属性的event；

  - 事件：设备上报的信息，使用json schema定义；

    - 命令：即服务，为了重构简单，仍然叫命令。也是json schema定义。

    注：

    1. 物模型和连接协议都是通过**使用场景+设备类型**进行筛选的，移除以前设计的设备品牌+设备型号的抽象，更便于维护；

  1. 与以前的设计不同，属性、事件和命令的标识符，只需要保证在同一设备类型下唯一即可。
  2. 参考阿里云的设计，属性上报的事件都固定叫`EVENT_POST_ATTR`，设置属性的命令叫`CMD_SET_ATTR`，获取属性的命令叫`EVENT_GET_ATTR`。实际上大部分设备都是定时上报属性，并不支持主动询问。所以属性应该分为：1：可读，2：可设置，4：可询问，这三种的位运算组合；
  3. **非标准协议一般选择了协议就自动绑定了物模型**，不再需要手动绑定；
  4. 选择了标准协议，但是没有绑定物模型，那就默认支持所有物模型。

  - 校验类型：不可选，目前都是强校验，数据不符合要求的，塞入异常数据的kafka topic里；
  - **协议参数**：某些协议参数可能需要在产品级别确定；
  - **注意**：除了名称和描述，其他字段都是**禁止编辑**的，想改的话，就删除产品后重新添加；如果产品下面挂载的有设备，禁止删除产品；

- 设备(Device)。设备是挂在产品下面的，继承产品的所有信息。由于大部分信息都定义在产品里了，设备这边的字段就很少：

  - ID：平台对设备的唯一标识；
  - 名称；
  - 设备本身的标识：一般是硬件本身的序列号，但是也可以是别的，阿里这里用了deviceName；productKey+deviceName构成唯一索引；
  - 状态：启用、禁用设备；
  - 在线状态：只读数据；
  - 对于网关子设备，还需要选择实际对接的网关设备（不考虑集群场景）；
  - secretKey：可以沿用以前的accessToken；
  - **协议参数**：如设备的内外网host地址，设备自身访问密钥等；阿里云无此类参数的原因是其要求子设备与网关的通信自行协商。
  - **注意**：设备的大部分信息也禁止编辑，要改的话也是删除后重新添加；

- 设备分类：参考阿里云的设计，分为领域-场景-设备类型三层。不同场景可以包含统一设备类型；

- TAG: 产品和设备都可以增加自定义的kv字段作为tag，主要用于搜索。之前设计的设备品牌、型号，都可以迁移到tag中，不影响接口返回值。可以沿用以前ext的json设计，也可以单独开表，为了节省时间可暂时沿用ext设计；

- 初期暂时不需要实现的功能：

  - 设备影子。该设计主要是为了解决设备网络情况不佳收不到下发命令的情况，以及主动索取设备属性导致请求过于频繁到设备压力较大的情况。后者可以使用事件/属性缓存完成，前者暂时让用户手动重发；
  - 设备分组。该功能放在应用层做即可，只是为了方便管理；
  - 任务(Job)功能：后期根据情况添加，可以和规则引擎融合；
  - 证书相关功能：暂不需要；
  - 通过脚本解析协议：优先级靠后，目前在代码层实现（脚本的性能较低，只是灵活度更高）；

## 与阿里云平台的区别

阿里云添加设备的流程是：

1. 添加产品；
2. 添加设备；
3. 设备/网关使用sdk**主动连接**阿里云平台，激活设备；
4. 仅支持固定的云云对接场景；

注意第3步是要求设备/或者设备网关适配阿里云平台，所以如果设备采用我们自研的MQTT软网关，可以使用同样的对接流程。但是我们要考虑更广泛的云云对接的场景，所以我们需要更多的参数。

## 例子

这里拿个人曾经对接过的一些设备类型作为例子，说明添加流程。

### 标准协议设备直连

任意设备使用标准协议，步骤都类似。

先新建一个产品，对应该类设备。然后选择标准协议，绑定物模型。

### 标准协议网关连接

创建一个网关产品，然后选择标准协议。

理论上，网关会根据实际连接的网关子设备来决定物模型，所以网关无须绑定物模型。

创建一个网关设备。

创建网关子设备产品，然后选择子设备连接网关的协议（一般是非标协议，物模型自动绑定）。

创建网关子设备，然后将其挂到网关设备管理之下。

### 非标协议直连

新普惠环境监测仪，采用自定义的modbus over tcp协议，蜂窝通信。在设备上设定服务器地址后，设备会主动连接服务器。但是上报数据需要服务器主动发送请求索取。

建立产品：节点选择直连设备，协议选择“智慧工地-环境监测-新普惠环境监测仪“

产品协议参数：采样间隔

添加设备：正常添加序列号即可

### 非标协议边缘网关连接

宇泛人脸检测设备离线版，采用以太网通信，http+ftp协议（限局域网）。必须经过边缘网关转换才能正常与云端通信。

首先建立网关产品：假设这里是自研网关，采用标准MQTT协议（无须产品参数）；

然后在网关产品下面添加实际的网关设备，需要参数：

- ip地址；
- 其他协议通信地址；

然后建立网关子设备产品：通信方式选择”智慧园区-人脸识别-宇泛设备离线版“；

网关子设备产品协议参数：

- 上报地址：当有人通过考勤机时，上报到哪里。该参数也可以在实施的时候一次性设置好；
- 心跳间隔：该参数需要设置给设备，然后设备主动发起心跳与网关通信；

然后添加网关子设备，关联到上文中网关产品下的设备，设备协议参数：

- 局域网ip地址；
- 通信端口；
- 通信密钥；

**注意**：如果仅仅需要设备上报考勤信息，而无需人员、照片下发功能，也可以作为云端直连设备接入。此时所有参数都已经预先设置好，云端其实不需要任何参数。这种情况可以单独设置一个简化版协议。

同样，大部分直连设备都可以通过自研的边缘网关中转。

### 非标协议云云对接

宇泛人脸检测设备wo平台版，采用以太网通信，直连宇泛自家的wo平台，属于云云对接。

首先建立网关产品：通信协议选择”智慧园区-人脸识别-宇泛设备wo平台版”，产品本身不需要协议参数；

在网关产品下面增加网关设备，填入参数：

- wo平台appId；
- wo平台appKey；
- wo平台appSecret；

增加网关子设备产品，通信协议选未知协议，不需要任何参数。

在网关子设备产品下，录入真正的人脸识别设备，也不需要额外参数。

## MySQL schema设计

```
create table if not exists device
(
    id              bigint auto_increment comment '设备id'
        primary key,
    name            varchar(100) default ''                not null comment '设备名称',
    sn              varchar(128)                           not null comment '设备标识',
    product_code    varchar(100)                           not null comment '归属产品',
    access_token    varchar(100)                           not null comment '直连访问密钥',
    protocol_params json                                   null comment '协议参数',
    ext             json                                   null comment 'tags',
    create_time     datetime     default CURRENT_TIMESTAMP not null,
    update_time     datetime     default CURRENT_TIMESTAMP not null on update CURRENT_TIMESTAMP,
    constraint unq_product_device
        unique (product_code, sn)
)
    comment '设备表';

create table if not exists device_category
(
    id          bigint not null,
    domain_type int    not null comment '领域code，中文在sys_dict里',
    scene_type  int    not null comment '场景',
    device_type int    null comment '设备类型',
    constraint unq_relation
        unique (domain_type, scene_type, device_type)
)
    comment '设备分类';

create table if not exists product
(
    code            varchar(100)                           not null comment '随机生成的唯一标识'
        primary key,
    name            varchar(100)                           not null comment '产品名称',
    conn_type       smallint                               not null comment '联网方式',
    node_type       smallint                               not null comment '结点类型',
    memo            varchar(200) default ''                not null comment '描述',
    protocol_code   varchar(100)                           not null comment '与上级的通信协议',
    protocol_params json                                   null comment '协议参数',
    ext             json                                   null comment 'tags',
    owner_app       bigint                                 not null,
    schema_attrs    json                                   null comment '物模型-属性',
    schema_events   json                                   null comment '物模型-事件',
    schema_cmds     json                                   null comment '物模型-命令',
    create_time     datetime     default CURRENT_TIMESTAMP not null,
    update_time     datetime     default CURRENT_TIMESTAMP not null on update CURRENT_TIMESTAMP
)
    comment '产品表';

create table if not exists protocol
(
    code           varchar(100)            not null comment '协议唯一标识'
        primary key,
    name           varchar(100) default '' not null comment '协议中文名称',
    device_type    smallint     default 0  not null comment '协议适配设备类型',
    product_params json                    null comment '使用该协议通信的产品参数',
    device_params  json                    null comment '使用该协议通信需要的设备参数',
    node_type      tinyint      default 7  not null comment '适配结点类型。位运算：1-直连，2-网关，4-网关子设备',
    conn_type      tinyint      default 0  not null comment '0-我方服务端，1-我方客户端',
    schema_attr    bigint                  null comment '协议绑定的物模型中的属性id',
    schema_events  json                    null comment '物模型中的事件数组',
    schema_cmds    json                    null comment '物模型中的命令数组'
)
    comment '设备协议';

CREATE TABLE `schema_meta` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `device_type` int NOT NULL COMMENT '设备类型',
  `name` varchar(100) DEFAULT NULL,
  `code` varchar(100) DEFAULT NULL COMMENT '属性/命令/事件的编码，属性固定为ATTR',
  `type` tinyint NOT NULL COMMENT '1-属性，2-事件，3-命令',
  `data` json DEFAULT NULL COMMENT '属性的json schema描述',
  `reply` json DEFAULT NULL COMMENT '对端回复的schema，一般只有命令需要',
  `mode` tinyint NOT NULL DEFAULT '0' COMMENT '事件的优先级：0,1,2；命令的执行方式0-异步，1-同步',
  `required` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否必选',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unq_schema_elem` (`code`,`device_type`,`type`)
) COMMENT='物模型';
```

1. 具有相同物模型的设备应被归类为同一设备类型；
2. 设备分类引用的都是系统字典里面的value_str；
3. 物模型最终是由product中的字段确定的；
4. 如果按着阿里云的设计，选择标准品类之后，物模型仍然是可以编辑的；也就是说，product里面保存的是数据的copy而非引用；
5. protocol表里关联的物模型，是私有协议对应的物模型，是schema_meta表里id的数组；举个例子：
   - 人类识别上传考勤信息时，体温信息是一个标准物模型里“考勤上传”这个事件的可选字段；定义在schema_meta里；
   - 私有协议里的schema_events里面含有该事件；
   - 产品在选择该私有协议后，自动绑定了该事件的副本。用户可以编辑物模型，将体温参数删除。

## 物模型数据结构设计

阿里云是自定义了一套json来描述schema，我们这里直接用[json schema标准](https://www.apifox.cn/help/reference/json-schema)，并进行扩展。

### 属性

```
{
  "type": "object",
  "properties": {
    "temprature": {
      "type": "integer",
      "title": "温度", //名称
      "symbol": "°C", //符号
      "unit": "摄氏度", //中文单位
      "mode": 3, //1-可读取，2-可设置
      "minimum": 15, //最小值
      "maximum": 40, //最大值
      "default": 26, //默认值
      "step": 1 //步长
    },
    "windSpeed": {
      "type": "integer",
      "title": "风速",
      "enum": [ //枚举值
        0,
        1,
        2,
        3
      ],
      "enumDesc": "自动\n一级\n二级\n三级", //枚举描述
      "default": "0", //默认值
      "mode": 3 //可读可写
    }
  },
  "required": [ //必选
    "temprature",
    "windSpeed"
  ]
}
```

其他的细节可以参考阿里云进行扩展

### 事件和命令

其实与属性类似，但是标识符需要分别手动设置。

此外：

1. 事件有个优先级设置（0-低，1-一般，2-高）；
2. 命令有个同步、异步的设置，不过目前所有命令都是异步设计；
3. 命令的回复也有一个schema；
