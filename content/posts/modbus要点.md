---
title: Modbus要点
description:
toc: true
authors: []
tags: []
categories: []
series: []
date: 2025-02-08T09:13:17+08:00
lastmod: 2025-02-08T09:13:17+08:00
featuredVideo:
featuredImage:
draft: false
---

modbus很多术语是从旧时代继承过来的，所以看起来有点莫名其妙。

## 通信模式

![Modbus的主从通信模式](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/08e78792b649f72d5c10ebd7e7b14b72.png)

一主多从。**Modbus请求只能由主机发起**，主机发送请求数据给从机，从机只有在接收到主机的请求数据后，才能发送应答数据到总线上；整个过程中**从机只能被动应答，不能主动发送数据到总线上**。通过主从通信模式，Modbus避免了多个设备数据的冲突。

为了避免数据冲突，不允许主机并行发送多个消息到总线上，主机发送请求数据后，必须等到从机应答数据或者超时后，才能发送下一个请求；主机发送信息给从机后，主机会启动一个等待超时计时器，如果主机没有收到从机的应答信息，**只有在等待超时计时器超时后，才可以发送下一个请求信息**。

**每个从机都一个唯一的从机地址，主机发起请求时，请求数据中携带了目标从机地址**；主机把请求数据发送到总线上，**总线上所有从机都会收到该请求，从机会检查该请求中携带的从机地址是否是自己，如果是自己就回复应答数据，如果不是自己就忽略请求**。

## 地址空间

modbus和PLC是直接对应的，PLC上有4个寄存器地址空间（对应内存空间），分别是：

![img](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/modbus_addr_zh.jpg)

0x和1x空间里面都是bool变量，只能有0和1，即离散量。0x空间是可读可写的，1x空间是离散只读的。

3x和4x空间里面是16bit数据，适合输入输出整数或者浮点数。3x是只读的，4x是只读只写的。

注意：没有2x空间。奇数空间只读，偶数空间可读可写。

modbus寄存器地址有多种标记方法：

![Modbus数据地址表示法](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/ce4009c692513bf88cdbf5e9a4e56aea.png)

虽然标法各有异同，不过也比较好区别，记住如下特征即可：

- 地址范围（最大）都是0x0000-0xFFFF，但是分为16进制表示法或者10进制表示法
- 地址最前面，有的有**寄存器序号的前缀**，有的没有，见上图中红色框，寄存器序号对应4种寄存器
- 16进制表示法的地址从0开始，而十进制表示法的地址从1开始

## 报文格式

常用的就是ModBus RTU和ModBus TCP，前者是485线缆通信，后者是网线通信。

### ModBus RTU

![Modbus RTU](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/3af5dee1c3588827e2823d6e20164fbc.png)

* 第1个字节：从机地址用来标识设备的唯一性，说白了就是设备的编号，范围1-247。0为广播地址，248-255为预留地址。

* 第2个字节：功能码，分为3类：
  * 公共功能码：即预定义的操作码，参考[这里](https://www.modbus.org/docs/Modbus_Application_Protocol_V1_1b3.pdf)，常用的包括：
    * 0x01 Multiple Coils 批量读寄存器0
    * 0x02 Multiple Discrete Inputs 批量读寄存器1
    * 0x03 Multiple Holding Registers 批量读寄存器4
    * 0x04 Multiple Input Registers 批量读寄存器3
    * 0x05 Single Coil 写单个寄存器0
    * 0x06 Single Holding Register 写单个寄存器4
    * 0x07 Read Exception Status 读异常状态
    * 0x0F Multiple Coils 批量写寄存器0
    * 0x10 Multiple Holding Registers 批量写寄存器4
  * 自定义功能码：65-72，以及100-110；
  * 保留功能码：除了上面之外的
* 数据区：0到252个字节，具体内容的格式由功能码决定。
* 校验位：最后2个字节，CRC校验结果。

特别注意：当设备数据长度>2个字节时，需要使用批量读写的功能码才能一次性读写完整的数据，这又涉及到大小端的问题。

RTU类似UDP通信，一次发送完整的数据包，所以不需要长度标识。

### ModBus TCP

![img](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/175144ee5d406b98c2902807322680c1.jpeg)

* 前2个字节：自增id，由于modbus不允许并发，一般直接填0
* 3-4字节：填0
* 5-6字节：长度标识
* 第7个字节：从站标识
* 第9个字节：功能码，和RTU中一致
* 后面n个字节：payload

ModBus主机对应客户端，从机对应服务端，仅支持轮询查找。

所以一般情况下ModBus不适合用来上云。