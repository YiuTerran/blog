---
title: Thingsboard压测报告
date: 2021-06-21
lastmod: 2021-08-31
slug: 125f108
draft: false
author:
  name: tryao
tags: ["iot", "test"]
collections: []
toc: true
math: true
lightgallery: false
---

## 概述

目前thingsboard(以下简称tb)支持http/coap和mqtt三种协议，本次压测内容包括：

1. 基于http的qps测试；
2. 基于mqtt的连接数测试；
3. 基于mqtt的qps测试；
4. 极限qps下，系统其他相关数据；

tb使用rpm包单点安装在centos7上，mq采用kafka，db采用pg+timescaledb.

postgresql和tb安装在同一个节点机器上，采用默认配置，未做优化。

消息队列采用kafka，在单独的机器上，压测客户端也在此机器。

客户端和服务器所在机器配置均为4核16G.

## 测试准备

创建一个csv文件，生成3w台设备，导入系统（主要字段：设备名称、设备类型、accessToken）。

使用租户管理员登陆设备管理页面，导入创建的设备。

遇到的问题：导入创建设备时，前端提示超时，设备数量过多导致。

![截屏2021-06-17 10.42.21](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1grl2fk5mzlj30hk04a0sw.jpg)

最终成功导入29993个，失败7个，导入时长约25分钟。

在tb所在服务端安装服务器性能监测工具，这里用的是nmon.

tb服务端采用默认配置，未限制jvm内存，增大数据库连接池线程数到10。适当优化了服务器内核参数和文件描述符限制以更加接近生产环境配置。特别注意这里用的是真机安装，所以systemd本身的文件描述符限制也要改，参考[这里](https://developer.aliyun.com/article/762289)。

压测客户端所在机器需要修改内核设置如下：

```
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_mem = 786432 2097152 3145728
net.ipv4.tcp_rmem = 4096 4096 16777216
net.ipv4.tcp_wmem = 4096 4096 16777216
```

由于只有一台压测机器，所以连接数最大只能测6万多，现在建立3w个设备，模拟3万连接。

先用curl测一下可用性：

```
curl -v -X POST --data "{"temperature":19,"humidity":75}" http://172.25.213.216:8080/api/v1/TOKEN-ENV-12230/telemetry --header "Content-Type:application/json"
```

thingsboard使用的各个表意义可以参看[该文档](http://www.atjiang.com/thingsboard-entity-database/)，我们主要需要关注`ts_kv`这个表，这里是上传遥感数据存放的表。`ts_kv_latest`则是各设备最新数据的缓存。

在`ts_kv`表里增加一列标明最终落库时间：

```
alter table ts_kv add column create_ts bigint not null default (extract(epoch from now()) * 1000);
```

这样就可以通过：

```
select * from ts_kv where long_v > ?;
```

`?`处填入本次压测开始的时间戳，筛选出本次压测写入的数据了。

### HTTP压测

参考文档：https://thingsboard.io/docs/reference/http-api/

使用工具：https://github.com/JoeDog/siege

由于上传数据的API里含有设备token，所以这里先生成一个urls.txt，放在`/etc/siege`下，每行内容类似：

```
http://172.25.213.216:8080/api/v1/TOKEN-ENV-2/telemetry POST {"temperature": 20, "humidity":68}
```

POST后面的数据是随机生成的。

使用 `siege -c 1 -r 1 -b -v --content-type "application/json"`做单次调用测试，服务器正常的话会返回200表示OK。在thingsboard设备页查看最新数据，一切正常的话这里会看到刚才POST的数据。

siege默认最大并发是255，运行`siege.config`命令，生成`~/.siege/siege.conf`，然后修改该文件的`limit = 30000`打开限制。

下面模拟正常情况下的设备连接，500个设备，随机休眠0-10s，5分钟测试:

```
siege -q -c 500 -d 10 -i -t 5m -v --content-type="application/json" | tee /tmp/benchmark.log
```

结果如下：

> Transactions: 59433 hits
> Availability: 100.00 %
> Elapsed time: 299.94 secs
> Data transferred: 0.49 MB
> Response time: 0.03 secs
> Transaction rate: 198.15 trans/sec
> Throughput: 0.00 MB/sec
> Concurrency: 5.81
> Successful transactions: 58256
> Failed transactions: 0
> Longest transaction: 2.16
> Shortest transaction: 0.00

此时qps为59433/300，不到200，但是查看log发现有1177个请求返回400。显然http server的负载能力极差。经过检查源码，发现http transport直接使用的springboot，默认tomcat性能较差，故不再进行相关测试。

### MQTT压测

mqtt层使用的是netty作为服务端，[默认](https://thingsboard.io/docs/user-guide/install/config/)boss线程数1，worker线程数12，且没有打开keepalive。

参考文档：https://thingsboard.io/docs/reference/mqtt-api/

使用工具：https://github.com/krylovsk/mqtt-benchmark

由于thingsboard限制每个设备只能建立一个连接，且AccessToken必须不同，所以需要修改测试工具的代码。这里fork了一个分支，存放修改后的go源码：https://github.com/YiuTerran/mqtt-benchmark

这个fork增加了从文件中读取配置的功能，并允许配置payload，且payload中有两个占位符可以被动态替换成发送时间和指定长度的随机ASCII码。这就可以满足我们测试的需要了。

使用以下命令简单测试：

```
./mqtt-benchmark -broker tcp://172.25.213.216:1883 -clients 1 -count 1 -topic v1/devices/me/telemetry -username TOKEN-ENV-1
```

一切正常，开始压测。

#### 并发连接数压测

先尝试10000台设备连接，每个1条消息，连接超时时间5s：

> Connect Ratio: 1.000
> Average Connect Time (ms): 0.302
> Connect Speed(conn/sec) 3310.000
> Total Ratio: 1.000 (10000/10000)
> Total Runtime (sec): 0.700
> Average Runtime (sec): 0.289
> Msg time min (ms): 88.167
> Msg time max (ms): 438.791
> Msg time mean mean (ms): 283.851
> Average Bandwidth (msg/sec): 3.622
> Total Bandwidth (msg/sec): 14294.922

平均每秒建立连接数3310，全部连接成功，消息全部发送成功。

改为2w台设备：

> Connect Ratio: 0.663
> Average Connect Time (ms): 0.310
> Connect Speed(conn/sec) 3224.992
> Total Ratio: 1.000 (13269/13269)
> Total Runtime (sec): 0.903
> Average Runtime (sec): 0.384
> Msg time min (ms): 63.051
> Msg time max (ms): 610.933
> Msg time mean mean (ms): 377.913
> Average Bandwidth (msg/sec): 2.741
> Total Bandwidth (msg/sec): 14696.849

此时出现连接失败，成功率为66.3%，连接速率仍然是3200左右。所以**当前环境单节点netty服务器连接速率上限就是每秒3000~3500个连接**，再快的话就会连接失败。

修改代码，每个连接之间中加入随机sleep 1~3ms，保证绝大部分客户端连接可以成功，继续下面的测试。

#### QPS压测

先模拟正常场景的极限情况：3w台设备，每个1s采集一次数据，qos为1，每个数据1kb左右。**实际场景中，采集频率一般在5s以上，大部分消息体也不足1k。**

每个客户端发送10条数据：

> ========= TOTAL (29993) =========
> Connect Ratio: 1.000
> Average Connect Time (ms): 1.902
> Connect Speed(conn/sec) 525.700
> Total Ratio: 1.000 (299930/299930)
> Total Runtime (sec): 13.031
> Average Runtime (sec): 11.441
> Msg time min (ms): 1.922
> Msg time max (ms): 2443.148
> Msg time mean mean (ms): 690.198
> Average Bandwidth (msg/sec): 0.876
> Total Bandwidth (msg/sec): 23016.027

实际成功连接数29993，消息发送全部成功。查看数据库ts_kv表，核对落库数据，最终为299669条，比发送端299930少了261条。查看日志发现有：

> 2021-06-19 09:46:18,129 [nioEventLoopGroup-4-5] ERROR o.t.s.t.mqtt.MqttTransportHandler - [be4a23a5-ec20-4c82-8adf-a9dc317591b7] Unexpected Exception

看来有未知bug导致数据丢失。多次重复该测试发现仍然有数据丢失，看来**已经超出qps上限**（此时写入约为23M/s)。

不断尝试调整消息发送间隔，最终发现在数据不丢失的情况下，最小消息间隔为1375~1400ms，此时发送端统计数据如下：

> Total Ratio: 1.000 (299930/299930)
> Total Runtime (sec): 14.542
> Average Runtime (sec): 13.323
> Msg time min (ms): 1.796
> Msg time max (ms): 1218.753
> Msg time mean mean (ms): 394.088
> Average Bandwidth (msg/sec): 0.751
> Total Bandwidth (msg/sec): 20625.662

即最大写入带宽约为20M/s，qps为2w左右，**超出最大qps会导致消息丢失**。

下面测试负载大小与qps的关系，将负载从1kb降低到256字节，即降低到1/4，将发送间隔降低到1400/4=350ms，理论上此时发送带宽不变。

发送端统计数据：

> Connect Ratio: 1.000
> Average Connect Time (ms): 1.906
> Connect Speed(conn/sec) 524.585
> Total Ratio: 1.000 (299930/299930)
> Total Runtime (sec): 6.803
> Average Runtime (sec): 5.560
> Msg time min (ms): 30.817
> Msg time max (ms): 3690.415
> Msg time mean mean (ms): 1401.135
> Average Bandwidth (msg/sec): 1.808
> Total Bandwidth (msg/sec): 44086.667

查询数据库发现最终落库数据为233474条，出现较大数量丢失，可见**qps与写入带宽不成线性关系**。

反复调整发送消息间隔，最终测得在保证消息不丢失情况下，此时最小发送间隔为750~800ms，此时发送端统计数据如下：

> ========= TOTAL (29993) =========
> Connect Ratio: 1.000
> Average Connect Time (ms): 1.898
> Connect Speed(conn/sec) 526.812
> Total Ratio: 1.000 (299930/299930)
> Total Runtime (sec): 9.098
> Average Runtime (sec): 7.817
> Msg time min (ms): 1.871
> Msg time max (ms): 1516.970
> Msg time mean mean (ms): 467.936
> Average Bandwidth (msg/sec): 1.280
> Total Bandwidth (msg/sec): 32967.141

写入带宽仅为8M左右，**qps为3w3左右**。

正常情况下，设备采集间隔为5s左右。所以下面应该测试发送间隔5s，payload为256字节时的最大允许设备数。**由于条件限制，这里暂时不再测试。**

#### 极限情况下落库延迟测试

采用上面测试的极限参数进行落库延迟测试，3w台设备，发送256字节左右数据，发送延迟800毫秒，每台设备发送100条数据，等待数据全部落库，并使用nmon采集10分钟的服务器性能数据。

```
select max(create_ts-long_v) from ts_kv where long_v >?;
```

使用该sql获取最大延迟，此时的最大延迟约为342709ms，即5.7分钟左右，平均延迟为180141ms，约为3分钟，数据库平均写入速度为每秒8700行左右。**这次测试中数据出现少许丢失，故已经达到qps极限**。

#### 应用服务器性能数据采集

使用`NMONVisualizer`打开落库延迟测试中的采集文件。

CPU使用信息：

![截屏2021-06-18 17.15.15](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1grnetwr880j31k00u0gxd.jpg)

可以看到图线分为4段，第一段主要是建立mqtt连接(10:56-10:57)，第二段是客户端开始并发发送消息(10:57-10:58)，之后客户端断开连接；10:58到11:04，这6分钟是异步落库的时间，之后处理完毕回到无负载状态。

这里连接速率较低(每秒500个连接左右)，所以连接阶段的cpu占用只有40%左右。推测如果将连接速率达到极限(3300以上)，CPU将会超载。

在netty处理数据写入kafka的过程中（kakfa在另外一台机器上），CPU占用率达到95%左右。

异步落库阶段，CPU占用率在40~45%，由于数据库和应用在同一个机器上，从这张图里不太容易确定每个进程占用了多少CPU，需要使用其他工具辅助。

![截屏2021-06-18 17.25.32](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1grnf0l02y6j31jd0u015u.jpg)

数据库使用的数据盘，io图线见上，峰值写入达到90Mb/s左右，加权均值45Mb/s.

内存使用如下图：

![截屏2021-06-18 17.28.42](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1grnf2c7o3wj31l20u079y.jpg)

总量约为16G，使用过程中占用内存从10.5G缓慢增长到12.5G左右，可用内存降到只有几百兆。

网络使用量如下图：

![截屏2021-06-18 17.32.07](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1grnf4hxz7ej31j90u0ak1.jpg)

客户端峰值写入流量为50M/s左右，加权均值为20M/s左右，落库阶段从kafka读取数据批量写入，故该图线和vdb磁盘写入图线均呈现锯齿状。

线程使用情况：

![截屏2021-06-18 17.34.25](https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/008i3skNgy1grnf7v751aj31e10u0qfa.jpg)

推测Netty的worker在数据通信阶段使用线程达到峰值，后续恢复正常。后续呈现锯齿状与数据库连接池或kafka消费线程池的使用有关。

## 结论

- 因为是直接用的springboot+tomcat充当web服务，tb的http transport性能较差，在单节点qps为200左右时就出现了上传失败；

- 本次压测服务器，单节点tb最大连接速率约为3300/s，超出该速度后，客户端建立连接失败；

- Tb的mqtt netty服务端，qps极限值与mqtt payload大小有非线性关系，总体来说payload越大，qps极限值越小。**qps超出极限时，数据会丢失**。

  - 3w个节点，payload在270个字节左右，在保证数据不丢失的情况下，最小消息发送间隔为750~800ms，qps极限为3w3左右；
  - 同样条件，payload 1k字节，qps极限值为2w左右；

- 在mqtt测试中，服务端出现了`Unexpected Exception`错误日志，具体原因待查证；

- 后端异步落库，在qps较大时延迟会较大；此处涉及的原因可能包括：

  - kafka参数配置；
  - 连接kafka的消费端参数配置；
  - timescaledb的参数配置；
  - 批量写入timescaledb的Java端参数配置；

  如果使用tb，此处是需要调优的重点对象。
