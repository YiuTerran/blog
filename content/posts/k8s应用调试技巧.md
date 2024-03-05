---
title: K8s应用调试技巧
description:
toc: true
authors: []
tags: []
categories: []
series: []
date: 2024-03-05T14:09:31+08:00
lastmod: 2024-03-05T14:09:31+08:00
featuredVideo:
featuredImage:
draft: false
---


>**注意：**
谨慎使用本文所述的工具，尤其是不要直接修改生产环境数据，风险自负！！！

rancher只读账号也可以登录服务pod的终端，而能登录到pod里就可以访问生产环境的所有组件。

## TIPS
下面需要下载github上的文件，在服务器上可以使用`https://mirror.ghproxy.com/`辅助下载，方法是将github release里面linux amd64对应的文件的链接前面加上这个地址。

例如，usql的下载地址为：`https://github.com/xo/usql/releases/download/v0.17.5/usql-0.17.5-linux-amd64.tar.bz2`，可以在服务器上使用

```bash
curl -O https://mirror.ghproxy.com/https://github.com/xo/usql/releases/download/v0.17.5/usql-0.17.5-linux-amd64.tar.bz2
```
进行下载.

## pod无法启动
如果遇到`CrashLoopBackOff`，可以看一下`kubectl logs <pod-name> -n <namespace> --previous`的输出，指定前一个pod。

如果还是无法确认问题，需要进pod里面进行调试，可以修改pod的启动命令：

```yaml
spec:
  containers:
  - image: <your-image>
    command: [ "/bin/bash", "-ec"]
    args: [ while true; do sleep 20; done;]
```

这样pod就不会退出，可以进入pod中手动执行正常的启动命令，查看无法启动的原因


## Nacos
你可以使用nacos的openAPI获取配置，例如：

```bash
curl -XPOST 'http://127.0.0.1:8848/nacos/v1/auth/login' -d 'username=nacos&password=nacos'
# 结果里有accessToken，然后用
curl 'http://127.0.0.1:8848/nacos/v1/cs/configs?tenant=sim-test&dataId=hermes-api-test.yaml&group=DEFAULT_GROUP&accessToken=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJuYWNvcyIsImV4cCI6MTYwNTYyMzkyM30.O-s2yWfDSUZ7Svd3Vs7jy9tsfDNHs1SuebJB4KlNY8Q'
# 获取到yaml配置
```

甚至于，你可以通过[API](https://nacos.io/zh-cn/docs/open-api.html)直接修改nacos配置，**但是一定不要这么做**。

## Redis
redis可以直接用netcat连接，无须redis-cli，例如`nc redis-test-master.tools.svc.cluster.local 6379`，然后输入`auth <passwd>`进行认证即可。
centos可以用`yum install -y nc`安装。

## MySQL
mysql可以使用`usql`进行连接，下载地址[点这里](https://github.com/xo/usql/releases)

连接方法：

```sql
usql 'mysql://root:123456$@172.16.11.200:3306/hermes'
```

## Kafka
使用`kaf`连接，下载地址[点这里](https://github.com/birdayz/kaf/releases).

使用方法，先配置集群地址：

```bash
kaf config add-cluster local -b localhost:9092
kaf config use-cluster local
```

常用命令：
```bash
# 查看group消费lag
kaf group describe <group_name>
# 模拟消费端，查看数据
kaf consume <topic_name> -f --offset newest --output json
```

## emqx
使用emqx官方出的[mqttx cli](https://mqttx.app/cli), 使用方法：

```bash
# Connect
mqttx conn -h 'broker.emqx.io' -p 1883 -u 'admin' -P 'public'
# Subscribe
mqttx sub -t 'hello' -h 'broker.emqx.io' -p 1883
# Publish a single message
mqttx pub -t 'hello' -h 'broker.emqx.io' -p 1883 -m 'from MQTTX CLI'
# Publish multiple messages (multiline)
mqttx pub -t 'hello' -h 'broker.emqx.io' -p 1883 -s -M
```

## influxdb
influxdb不需要客户端，直接调用curl即可调试。

## rabbitmq
想使用rabbitmqctl命令，必须登录到rabbitmq所在pod或者机器节点.

**注意**：与kafka不一样，你不应该试图消费rabbitmq中的消息，即使是`peak`消息（即消费后重新放入），也可能会因为消息顺序错乱导致不可预测的后果（比如设备短时间在离线切换）。

如果需要手动生产消息（**最好不要这么干**），可以使用[这个工具](https://github.com/streamdal/plumber)。

