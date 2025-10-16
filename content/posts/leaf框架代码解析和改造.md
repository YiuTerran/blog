---
title: Leaf框架代码解析和改造
date: 2019-10-31
lastmod: 2019-10-31
slug: cd6d6fe
draft: false
author:
  name: tryao
tags: ["golang","game"]
collections: []
toc: true
math: true
lightgallery: false
---

在接游戏外包的一段时间里，选型了golang的leaf框架作为游戏开发的基础框架，但是进行了一系列改造以更好的完成业务需求。简单记录如下：

## 基本思路

leaf本质上其实不是一个游戏框架，而是一个网络工程的脚手架，换句话来说你可以用它来写任何服务端而不仅仅是游戏。

它的基本思路是将每个socket封装成一个agent，使用独立的协程进行读写。主要分为几个模块：

1. 提供`Skeleton`这个脚手架，可以把它当成一个功能更加完善的协程。它提供了保证函数执行时序的一些工具，允许callback形式的代码；通过`chanRPCServer`抽象了一种类似RPC的协程间通信（通过channel），方便快速进行开发；
2. 按业务抽象了Module，进行生命周期管理；
3. 抽象了网络接口，并提供了裸TCP和websocket的实现，可以通过简单的配置同时支持多种协议；
4. 提供了protobuf和json的序列化支持；
5. 路由机制；
6. 通过telnet提供pprof接口，同时也可以自定义命令，方便进行debug；
7. 其他一些工具库；

## 细节分析

下面按着模块进行一些代码难点解析。

### Module

这个比较简单，规定了一个接口，里面是一些生命周期的回调函数，供leaf启动时注册运行，同时提供了一个`chan bool`作为关闭的信号。

注意每个模块运行在单独的协程里。

### Processor

序列化接口，支持序列化、反序列化和路由消息到对应的handler。框架给出了json和protobuf两种序列化方案。

json是明文传输，直接用类的名字作为消息的标示即可。protobuf是二进制传输，需要两个字节来描述消息的id，直到id才能正确的反序列化。

### network

对TCP和WebSocket通信的抽象，`Conn`是抽象出的接口。

TCP和WebSocket最大的不同是前者是传输层协议，后者是应用层协议。所以前者需要自定义消息格式，这里采用的是头X个字节描述消息大小，后面是序列化消息的方式，另外注意这里还有大小端的问题。读的过程很简单，每次都是先读前X个字节，然后读出整个消息体；写的过程也类似。

### Gate

路由主要作用是将socket封装成Agent，这里为了可以同时当作TCP和WebSocket服务器，将相关设置项直接当作Gate的成员变量了。

消息的路由通过注册processor来实现，通过`Run`来启动server，显然gate应该被封装作为一个Module在leaf中运行。这里还注册了打开关闭socket的固定回调(“NewAgent”和”CloseAgent”)。

下面看一下Server启动后做了啥，以TCPServer为例：

1. 在一个单独的协程中启动server，server本身是一个死循环；
2. Accept请求以后，通过server的`NewAgent`回调创造agent，并在一个单独的协程中运行agent；
3. agent的`Run`也是一个死循环，它简单的读取消息并进行路由处理；
4. agent的写消息是在调用协程里异步完成的，它将消息写入conn的`writeChan`缓冲区后返回；每个conn有个单独的协程遍历channel并完成真正的写操作；
5. 因此3，4为一个socket的读写各创建了一个单独的协程；

3中路由处理，在这里分为几种情况，如果对Processor调用了`SetHandler`或者`SetRawHandler`，那么就在读消息的协程里直接同步处理了消息。如果调用了`SetRouter`选择把消息路由到某个chanrpc中，则会把消息塞到队列中进行异步处理（回调的格式写死为f(args []interface{})。

### command

一个方便调试的工具。

用户可以通过telnet访问内存情况，通过自定义command指令获取内存中的数据并进行调试。

### chanrpc

该模块通过精巧的设计，为协程间通信增加了异步回调执行、同步调用、异步通知等常见模式。我们一般不直接使用它，而是通过Skeleton来使用。

### Skeleton

可以理解为一个胖协程，我们不再单独使用`go func(){}`运行协程，而是新建一个Skeleton，通过`go skeleton.Run()`来运行协程。

这样创建的协程，就可以通过内置的chanrpc来进行通信。此外，这里还对timer进行了封装，go默认的timer是在单独的协程里运行的，这里在时间到达后，将回调函数重新塞回调用chanTimer里，最终仍然在同一个协程里执行函数。同样，内置的`Go`也是通过类似的方法保证协程的同步。

所以Skeleton的`Run`函数就是一个select的死循环，使用io多路复用，依次中上述组件对应的channel中获取结果并执行对应的动作。

## 简单改进

由于leaf常年不再更新，fork了一个版本并修正了一些问题，地址在：https://github.com/YiuTerran/leaf

主要修正包括：

1. 移除了一些不需要的模块，如mongo的支持等，这些直接用第三方库即可；
2. 将自己实现的log模块改为zap的，性能更好并支持json格式的日志；
3. 将websocket的RemoteAddr返回值改为透过代理的（如果存在）；
4. 加上go mod支持，修改版本号为规范格式；
5. 移除了conf文件夹，这个设计不太符合类库的使用规范；
