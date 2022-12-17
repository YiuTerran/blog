---
title: Tinode源码解析
description:
toc: true
authors: ["tryao"]
tags: ["golang", "im", "tinode"]
categories: []
series: []
date: 2022-11-14T19:21:38+08:00
lastmod: 2022-11-14T19:21:38+08:00
featuredVideo:
featuredImage:
draft: false
---

## 概述

有朋友需要做一个im，简单做了一下技术调研，[开源的实现](https://github.com/haiiiiiyun/awesome-selfhosted-cn#%E9%80%9A%E8%AE%AF%E7%B3%BB%E7%BB%9F)其实蛮多的，这里挑几个说一下：

* Synapse/dendrite，matrix系，客户端比较多，比较推荐的应该是element.io. 稳定版本是python写的，性能很一般，golang/rust的服务端还没有stable，不建议使用；
* Tinode/chat: 即本文主角，golang编写，架构比较简单，有MySQL就能跑，轻量级方案。支持web/ios/android，界面长得比较像telegram；支持chatbot. 国内用有点水土不服，主要是推送等组件依赖国外大厂的服务(S3, Firebase等），国内根本连不上，需要自己改成个推之类的方案。由于方案比较轻量，消息可靠性上有一些缺陷，内置了chatbot支持（可以用Python写）；
* Open-IM-Server：据说是某个腾讯核心人员离职后自己开源的。服务端golang，架构基于微服务，有商业产品，自己试了一下目前版本大概有16个微服务，依赖kafka&zk、mysql、etcd、redis、miniIO和MongoDB。架构比较合理，早期是写扩散模型，v2.3之后群聊改为读扩散模型。主要问题是架构比较重，文档写的烂，需要自己分析代码，小团队维护比较吃力；另外客户端开源的只是demo，bug满天飞，不能直接拿来用。
* turms-im/turms：java写的，读扩散模型。maintainer比较有自信，号称开源界最先进的方案，文档确实写的不错，很详细的技术分析。不过star数不多，实际使用者估计也寥寥。而且作者喜欢自研，Log/注册中心/配置中心这些都是自研的…有种自嗨过了头的感觉。整体来讲架构比较中庸，技术细节把控的比较好。java团队可以考虑，代码还比较易读，而且没有商业版，作者没有恰饭需求；客户端没有开源产品，只有sdk；
* wildfirechat/im-server：也是java做的，主要卖商业版，开源的功能做的很全了，和国内生态也结合的蛮好。开源版强行指定了使用七牛云做文件夹存储，然后服务端端口强行指定了80/1883，另外开源版不支持集群模式；国内的小规模内部使用推荐使用该项目（<10w人）；
* Rocket.chat/mattermost：面向B端，类似zulip/Slack这种IM，有复杂B端需求的团队建议优先考虑。界面不太符合普通人使用im(qq/微信/钉钉)的习惯，办公人士用比较合适；

这几个项目是客户端生态做的最好的了，基本能开箱即用。其他一些如goim之类的，没有客户端只有服务器，那还不如用mqtt自己写一个，毕竟有emqx这种高性能broker，写一个im真不算啥难事。聊天存储用influxdb或者MongoDB，元数据存MySQL。设计好推拉模型，读写扩散，消息时序，topic规则，一个基本的im软件还是能很快成型的。

由于这次的需求是小团队，少量用户(<1w)聊天场景，需要机器人支持，目前就先用tinode试水。

## 安装

在github上fork一下chat项目，clone下来。install.md里面的安装指南也是错的，不用看，要跑起来准备一个MySQL5.7+的版本即可。MongoDB不支持集群，因此这里用MongoDB没啥优势，MySQL可以换成tidb.

在server文件夹下建立static文件夹，将`https://github.com/tinode/webapp/archive/master.zip`解压到static文件夹下。

修改build-all.sh，仅保留windows和linux的两个二进制文件，mac可以自己加上darwin+amd64/arm64的配置，数据库仅保留mysql即可。将GOSRC改成`..`，使其不再依赖GOPATH.

在平台上安装grpc相关依赖(apt install protobuf-compiler)，以及：

```go
go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.28
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
```

另外安装Python3环境，并pip安装如下依赖：

```
tinode-grpc>=0.20.0b3
grpcio==1.50.0
grpcio-tools==1.50.0
protobuf==4.21.9
six==1.16.0
```

这是给chatbot以及py_grpc这个包用的。

然后，在linux下运行build-all.sh即可，会在release文件夹下生成打包文件。其中zip结尾的是windows下的，tar.gz结尾的是linux下的。

## 配置

主要有3个包：

- tinode开头的是主程序
- chatbot顾名思义是聊天机器人
- cli是命令行客户端主要用来调试

解开tinode开头的压缩包，里面有三个二进制文件：

* keygen 这是密钥生成器，用于配置文件
* tinode 这是主程序
* init-db 这是初始化数据库的二进制文件

配置文件就是`tinode.conf`，这是一个`json with comments`格式，或者说`json5`格式，也可以用`hcl`来解析（用viper的话）。可以把后缀改成`jsonc`或者`json5`，一般的编辑器就可以语法高亮了。

配置文件的注释非常详尽，按着配置来就行，如果为了测试，必须修改的就只有MySQL的用户名密码和地址（生产的话，有几个IMPORTANT的地方必须修改以提高安全性）。见store_config部分，修改：

```json
{
    "use_adapter": "mysql",
    "mysql":{
        "Addr": "",
        "User": "",
        "Passwd": ""
    }
}
```

这几个参数。MySQL密码可能默认是空的，可以用`ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '123456'`加一个密码。使用`init-db`初始化数据库

然后直接运行`tinode`，没意外的话程序可以正常启动。进入浏览器输入`localhost:6060`即可看到web版本登陆界面。

这个半自动化脚本其实挺蛋疼的，但是看文档这个项目前后端没分离，虽然前端是react写的，但是必须通过golang服务来提供。所以就算前端有一个nginx，也不能直接托管静态文件。

conf文件中，默认情况下推送是没打开的，需要自己配置Google FCM的参数和firebase-init.js（在前端）。文件默认存储在本地（可以用juiceFS扩展成分布式文件夹存储），也可以配置s3.

## 解析

我们主要关注的是消息路由以及集群组成方式两部分的逻辑，以及插件系统（机器人的依赖）的工作原理。

可以先读一下[api.md](https://github.com/tinode/chat/blob/master/docs/API.md#how-it-works)，也可以直接看代码。由于架构比较简单，所以代码并不复杂。

打开main.go文件，可以看到除了静态文件，`mux`一共托管了如下几个API：

```go
	// Handle websocket clients.
	mux.HandleFunc(config.ApiPath+"v0/channels", serveWebSocket)
	// Handle long polling clients. Enable compression.
	mux.Handle(config.ApiPath+"v0/channels/lp", gh.CompressHandler(http.HandlerFunc(serveLongPoll)))
	if config.Media != nil {
		// Handle uploads of large files.
		mux.Handle(config.ApiPath+"v0/file/u/", gh.CompressHandler(http.HandlerFunc(largeFileReceive)))
		// Serve large files.
		mux.Handle(config.ApiPath+"v0/file/s/", gh.CompressHandler(http.HandlerFunc(largeFileServe)))
		logs.Info.Println("Large media handling enabled", config.Media.UseHandler)
	}
```

longpolling是兼容旧式浏览器的，基本不用看，主要逻辑就在websocket里，其他两个是二进制文件的上传下载。

另外，grpc是可选的：

```go
	if globals.grpcServer, err = serveGrpc(*listenGrpc, config.GrpcKeepalive, tlsConfig); err != nil {
		logs.Err.Fatal(err)
	}
```

### websocket

这里仍然用的经典的`github.com/gorilla/websocket`这个ws库，不过由于maintainer想退休了，所以gorilla系列的库实际上已经停止维护了，新建项目不再推荐使用，参考[这里](https://github.com/gorilla/mux/issues/659)和[这里](https://github.com/gorilla/websocket/issues/370)。当然这个库还是比较稳定的，只要没有致命漏洞倒也没必要迁移。

在`serveWebSocket`里面可以看到，经过鉴权之后，session被存入`globals.sessionStore`这个全局变量。session本身存储了用户相关的大部分上下文，可以看到session中含有

```go
	// Outbound mesages, buffered.
	// The content must be serialized in format suitable for the session.
	send chan interface{}

	// Channel for shutting down the session, buffer 1.
	// Content in the same format as for 'send'
	stop chan interface{}

	// detach - channel for detaching session from topic, buffered.
	// Content is topic name to detach from.
	detach chan string

	// Map of topic subscriptions, indexed by topic name.
	// Don't access directly. Use getters/setters.
	subs map[string]*Subscription
	// Mutex for subs access: both topic go routines and network go routines access
	// subs concurrently.
```

以及

```go
// Subscription is a mapper of sessions to topics.
type Subscription struct {
	// Channel to communicate with the topic, copy of Topic.clientMsg
	broadcast chan<- *ClientComMessage

	// Session sends a signal to Topic when this session is unsubscribed
	// This is a copy of Topic.unreg
	done chan<- *ClientComMessage

	// Channel to send {meta} requests, copy of Topic.meta
	meta chan<- *ClientComMessage

	// Channel to ping topic with session's updates, copy of Topic.supd
	supd chan<- *sessionUpdate
}
```

可以看出用户通信是直接通过golang的channel来进行缓冲的（所以消息有可能丢失）。此外一个用户可以有多个session（多端登录）。

最后，对每个session打开

```go
	// Do work in goroutines to return from serveWebSocket() to release file pointers.
	// Otherwise "too many open files" will happen.
	go sess.writeLoop()
	go sess.readLoop()
```

两个协程进行读写循环。这里很明显一个问题是这两个协程没有做生命周期控制。

#### readLoop

websocket的ping/pong相当于应用层心跳，这里给了55s的超时。

一个死循环获取消息直到EOF，然后将消息分发到`s.dispatch`，分发逻辑是同步处理的。

注意这里的`pluginFirehose`是触发插件处理的逻辑，一会儿再看。

客户端过来的消息被映射成json的kv对，通过判断field是不是nil来判断消息类型（protobuf里这里使用`oneof`定义的）。

这里可以看到：

```go
	if globals.cluster.isPartitioned() {
		// The cluster is partitioned due to network or other failure and this node is a part of the smaller partition.
		// In order to avoid data inconsistency across the cluster we must reject all requests.
		s.queueOut(ErrClusterUnreachableReply(msg, msg.Timestamp))
		return
	}
```

分区容忍度判断方式是`(len(c.nodes)+1)/2 >= len(c.fo.activeNodes)`，避免节点死亡过多。

真正的消息处理逻辑是通过`checkVers`返回的handler函数来进行的，核心逻辑则是通过`s.publish`, `s.subscribe`等处理器来完成的。特别需要注意的是，所有的处理逻辑都是同步的，直到最后`s.queueOut`将回复消息塞进session的`send`管道。

#### writeLoop

写循环显然就是从`send`管道里面读出数据，写给目标。这里也定义了一个定时器用来定时向客户端发送ping。

### 集群原理

显然im的主要逻辑就是接收一个人的消息，然后找到接收者对应的socket，将消息写过去。

难的地方是如何保证消息不多不少不乱，同时延迟尽可能低。

所以核心的逻辑在如何处理pub和sub的关系。如果用mqtt的话，实际上最难的这一步emqx这种broker已经帮你做了，因为后者本来就是pub/sub模型，且支持QoS.

回到`publish`函数，这里就是找到topic的订阅者集合，将消息写到broadcast队列里。跟踪这个变量的使用，最终可以看到`Topic`的`clientMsg`管道。

跟踪Topic，可以看到创建的地方在`Hub.run`这个成员函数。这里有一大段注释：

```go
		case join := <-h.join:
			// Handle a subscription request:
			// 1. Init topic
			// 1.1 If a new topic is requested, create it
			// 1.2 If a new subscription to an existing topic is requested:
			// 1.2.1 check if topic is already loaded
			// 1.2.2 if not, load it
			// 1.2.3 if it cannot be loaded (not found), fail
			// 2. Check access rights and reject, if appropriate
			// 3. Attach session to the topic
			// Is the topic already loaded?
			t := h.topicGet(join.RcptTo)
```

注意后面的`isProxy`成员，这里也有一大段注释：

```go
	// If isProxy == true, the actual topic is hosted by another cluster member.
	// The topic should:
	// 1. forward all messages to master
	// 2. route replies from the master to sessions.
	// 3. disconnect sessions at master's request.
	// 4. shut down the topic at master's request.
	// 5. aggregate access permissions on behalf of attached sessions.
```

到这里已经可以猜出集群的大致原理：

1. 消息系统的核心是topic；
2. topic在集群上某个节点上（初次被订阅的时候）创建为master节点，集群的其他结点则是该topic的proxy节点；
3. proxy节点会将所有发往该topic的消息路由到master节点，所有的消息处理逻辑在master节点进行；
4. 如果是事务类消息，master会将处理结果发回proxy节点；
5. 如果是pub消息，master节点会广播到其他结点；

其实核心逻辑就在`runLocal`和`runLocal`这两个函数里。

其中master节点pub类消息的处理逻辑在`Topic.handlePubBroadcast`里，追踪可达`Topic.saveAndBroadcastMessage`这里。

这里可以看到`PluginMessage`调用了插件来回调。真正的写入就是简单的`sess.queueOut`，后者判断`s.multi`，如果是proxy的session，则会通过`clusterWriteLoop`将数据通过rpc写入session所在的真正节点。

那么proxy的session是怎么连接到master的topic上的呢，查看s.proto的赋值，可以看到和PROXY或者MULTIPLEX的赋值都在`TopicMaster`里。这个函数没有被直接调用，而是通过反射的方式，在`ClusterNode.proxyToMaster`里调用。

一路追寻可以看到`Cluster.start`函数，这里定义了节点之间相互连接的处理流程。实际上大部分逻辑还是在`TopicMaster`里，proxy节点订阅会在这里创建一个copy的session，其proto定义为PROXY.所以proxy节点对topic的每个订阅session，在master节点上都有一个副本。这个设计显然称不上很妙，理论上master节点只需要知道哪个proxy节点对topic有订阅即可（类似路由表的设计），session的副本实在是没有必要，非常浪费内存。

另外查看`ClusterNode.reconnect`，可以看到大大的**FIXME**，这里消息可能丢失。

### chatbot

上面有两个plugin的调用，显然是供插件系统的生命周期回调。在`chatbot/python`文件夹下面有一个Python机器人的示例。虽然我有点奇怪他这明明是golang的项目，机器人要用Python来写。可能是为了突出机器人的语言无关性？

实际上就是使用grpc通信，从`readme.md`中可以看到具体使用方法，对应的protobuf文件在`pbx`文件夹下，主要接口包括：

```protobuf
// This is the single method that needs to be implemented by a gRPC client.
service Node {
	// Client sends a stream of ClientMsg, server responds with a stream of ServerMsg
  	rpc MessageLoop(stream ClientMsg) returns (stream ServerMsg) {}
}

// Plugin interface.
service Plugin {
	// This plugin method is called by Tinode server for every message received from the clients. The
	// method returns a ServerCtrl message. Non-zero ServerCtrl.code indicates that no further
	// processing is needed. The Tinode server will generate a {ctrl} message from the returned ServerCtrl
	// and forward it to the client session.
	// ServerCtrl.code equals to 0 instructs the server to continue with default processing of the client message.
	rpc FireHose(ClientReq) returns (ServerResp) {}

	// An alteranative user and topic discovery mechanism.
	// A search request issued on a 'fnd' topic. This method is called to generate an alternative result set.
	rpc Find(SearchQuery) returns (SearchFound) {}

	// The following methods are for the Tinode server to report individual events.

	// Account created, updated or deleted
	rpc Account(AccountEvent) returns (Unused) {}

	// Topic created, updated [or deleted -- not supported yet]
	rpc Topic(TopicEvent) returns (Unused) {}

	// Subscription created, updated or deleted
	rpc Subscription(SubscriptionEvent) returns (Unused) {}

	// Message published or deleted
	rpc Message(MessageEvent) returns (Unused) {}
}
```

一般客户端实际上只需要实现`MessageLoop`这个消息循环，处理服务端转发给它的消息（用户发给他的），然后进行处理即可。

插件显然需要实现Plugin的server，chat的主程序作为plugin的客户端，调用插件提供的服务，而插件需要通过配置文件进行激活，详见`plugins`部分（在最后）。整体逻辑不难理解，就是客户端行为的回调。

包里面示例的就是一个聊天机器人，主要实现了`MessageLoop`部分的随机应答。

如果要写一个插件的话，主要需要实现`FireHose`部分。

#### FireHose

这里的文档比较缺，需要看源码（源码的注释还有点问题），主要在`plugins.go`这个文件里。

在`tinode.conf`的最下面，有个`plugins`的配置，这里激活插件系统：

```js
	"plugins": [
		{
			// Enable or disable this plugin.
			"enabled": true,

			// Name of the plugin, must be unique.
			"name": "python_chat_bot",

			// Timeout in microseconds.
			"timeout": 20000,

			// Events to send to the plugin.
			"filters": {
				// Account creation events.
				"fire_hose": "pub,sub,del;grp,new;"
			},

			// Error code to use in case plugin has failed; 0 means to ignore the failures.
			"failure_code": 0,

			// Text of an error message to report in case of plugin failure.
			"failure_text": null,

			// Address of the plugin.
			"service_addr": "tcp://localhost:40051"
		}
	]
```

filters这里配置需要回调的消息类型，我这里拦截了新建群组、订阅群组、在群中发送消息/删除消息等.

特别需要注意的是，用户的id在数据库里是长整型，但是显示在界面上是字符串，所以需要转换一次。

## 设计缺陷

通过上面的解析可以看到一些很明显的缺陷：

1. 没有QoS设计，消息是可能丢失的；
2. 没看到消息时序的设计，消息的顺序完全依赖达到服务端的顺序；
3. 集群通信的效率不太高；



