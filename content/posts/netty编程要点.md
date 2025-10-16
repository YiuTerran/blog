---
title: Netty编程要点
date: 2021-05-31
lastmod: 2021-06-07
slug: 711642d
draft: false
author:
  name: tryao
tags: ["java", "netty"]
collections: []
toc: true
math: true
lightgallery: false
---

现阶段的网络编程，更推荐使用golang而不是java，但是netty这个事件驱动的框架，在Java技术栈里面也算必须掌握的内容。对我个人而言，在熟悉go的`leaf`框架后，再回头来看netty，它的很多概念就不言自明了。

## 事件循环

首先回忆我们在leaf中是如何写一个`Module`的，我们定义接口如下：

```
type Module interface {
	Name() string
	OnInit()
	OnDestroy()
	Run(closeSig chan struct{})
	RPCServer() *chanrpc.Server //如果module可以接受外来的指令，则必须有一个chanrpc server，否则返回nil即可
}
```

显然一个模块拥有名称，生命周期管理的回调，`Run`就是启动事件循环，通过`RPCServer()`返回的结果进行模块间的事件传递通信。`chanrpc.Server`支持通过事件标示进行消息路由，最后发送到成员`chan *CallInfo`这个管道里，在`Run`中通过`for..select`从该管道中循环取出事件进行处理即可。

那么在netty中，我们定义一个事件循环为`EventLoopGroup`。需要有一个`Channel`来接受各种消息并注册回调函数，即`ChannelHandler`.使用`Bootstrap`容器类将eventloop和channel连接起来，就启动了一个模块。如果是我方作为客户端，只需要启动一个`EventLoopGroup`即可。

## 抽象连接

在`leaf`中一个连接被抽象为一个接口：

```
type Conn interface {
	ReadMsg() ([]byte, error)
	WriteMsg(args ...[]byte) error
	LocalAddr() net.Addr
	RemoteAddr() net.Addr
	Close()
	Destroy()
}
```

不同协议实现该接口，并提供一个函数将`Conn`转变为`Agent`，然后再单独的协程里运行Agent:

```
type Agent interface {
	Run()
	OnClose()
}
```

即每个连接agent都运行在**单独的协程**里。

netty这里没法让每个连接在单独的线程里跑（线程太重），因为采用的是传统的池化处理方式。`EventLoop`在创建时实际创建了一个线程池，因此多个Channel实际上可能会公用同一个线程。

连接建立后，Channel会自动创建一个线程安全的`ChannelPipeline`，然后调用`Bootstrap`上面绑定`ChannelInitializer`将需要的`ChannelHandler`依次加到这个`ChannelPipeline`里，每个回调的`channelRead0`里要调用`fireChannelRead(msg.retain())`向下传递消息。

如果可以保证`ChannelHandler`是线程安全的，就用`@Sharable`注解该类，此时所有的连接可都共享同一个实例（pipeline直接添加这个单例），否则每个连接应new一个Handler添加到pipeline里。前者一般用`AttributeKey`来共享statefull的数据，后者可以直接用类的私有变量。

`ChannelInitializer`是一个特殊的ChannelHandler，在向pipeline中添加相关组件后，该handler就会被移除(参考go中的Once). handler在初始化时就会执行，而childHandler会在客户端成功connect后才执行，这是两者的区别。

## 数据分包

直接扩展`ByteToMessageDecoder`，实现分包逻辑:

```
protected Object decode(ChannelHandlerContext cxt, Channel channel, ChannelBuffer channelBuffer) throws Exception
```

重载上述方法，返回null表示没有取到有意义的帧，否则表示解析正确的帧。

和leaf的设计不同，这里一般习惯在这里直接反序列化到具体的对象。

netty自带了一些拆包器，一般能满足大部分情况下的需求：

1. FixedLengthFrameDecoder: 定长解码器来解决定长消息;
2. LineBasedFrameDecoder和StringDecoder:解决以回车换行符作为结束符的消息;
3. DelimiterBasedFrameDecoder: 特殊分隔符解码器;
4. LengthFieldBasedFrameDecoder: 自定义长度解码器

其中最后一个可以灵活配置，他的四个参数分别表示：

1. lengthFieldOffset 长度字段的偏差
2. lengthFieldLength 长度字段占的字节数
3. lengthAdjustment 添加到长度字段的补偿值
4. initialBytesToStrip 从解码帧中第一次去除的字节数

当然如果协议比较复杂，还是需要手动解包。需要注意在数据到齐之前，不能移动游标，一个示例：

```
while (true){
   //判断当前缓存中的数据是否满足一条指令的最小基础数据
   if(byteBuf.readableBytes() >= BASE_LENTH){
       //寻找包头
       while (true){
           //记录数据包开始的指针位置
           byteBuf.markReaderIndex();
           //判断是否是属于包头
           if(byteBuf.readInt() == HEAD){
               break;
           }
           //不是包头
           //指针复位
           byteBuf.resetReaderIndex();
           // 缓存指针向后移动一个字节
           byteBuf.readByte();
           //判断当前缓存是否依然满足一条指令的最小长度
           if(byteBuf.readableBytes() < BASE_LENTH){
               return;
           }
       }
       //找到了当前的包头
       byte cmdOf1st = byteBuf.readByte();
       short cmdOf2nd = byteBuf.readShort();
       int dataLength = byteBuf.readInt();
       //检验当前指令的数据长度
       if(dataLength < 0){
           channelHandlerContext.channel().close();
       }
       //判断当前数据是否已经到齐
       if(byteBuf.readableBytes() < dataLength){
           //没到齐
           //复位到最开始的地方
           byteBuf.resetReaderIndex();
           return;
       }
       //数据到齐了
       byte[] data = new byte[dataLength];
       byteBuf.readBytes(data);
   }
}
```

## 数据传递顺序

- Inbound event propagation methods:
  - [`ChannelHandlerContext.fireChannelRegistered()`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#fireChannelRegistered--)
  - [`ChannelHandlerContext.fireChannelActive()`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#fireChannelActive--)
  - [`ChannelHandlerContext.fireChannelRead(Object)`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#fireChannelRead-java.lang.Object-)
  - [`ChannelHandlerContext.fireChannelReadComplete()`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#fireChannelReadComplete--)
  - [`ChannelHandlerContext.fireExceptionCaught(Throwable)`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#fireExceptionCaught-java.lang.Throwable-)
  - [`ChannelHandlerContext.fireUserEventTriggered(Object)`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#fireUserEventTriggered-java.lang.Object-)
  - [`ChannelHandlerContext.fireChannelWritabilityChanged()`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#fireChannelWritabilityChanged--)
  - [`ChannelHandlerContext.fireChannelInactive()`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#fireChannelInactive--)
  - [`ChannelHandlerContext.fireChannelUnregistered()`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#fireChannelUnregistered--)
- Outbound event propagation methods:
  - [`ChannelHandlerContext.bind(SocketAddress, ChannelPromise)`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#bind-java.net.SocketAddress-io.netty.channel.ChannelPromise-)
  - [`ChannelHandlerContext.connect(SocketAddress, SocketAddress, ChannelPromise)`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#connect-java.net.SocketAddress-java.net.SocketAddress-io.netty.channel.ChannelPromise-)
  - [`ChannelHandlerContext.write(Object, ChannelPromise)`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#write-java.lang.Object-io.netty.channel.ChannelPromise-)
  - [`ChannelHandlerContext.flush()`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#flush--)
  - [`ChannelHandlerContext.read()`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#read--)
  - [`ChannelHandlerContext.disconnect(ChannelPromise)`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#disconnect-io.netty.channel.ChannelPromise-)
  - [`ChannelHandlerContext.close(ChannelPromise)`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#close-io.netty.channel.ChannelPromise-)
  - [`ChannelHandlerContext.deregister(ChannelPromise)`](https://netty.io/4.0/api/io/netty/channel/ChannelHandlerContext.html#deregister-io.netty.channel.ChannelPromise-)

习惯上在pipeline中添加handler时，先加decoder，后面跟着对应的encoder. 如：

1. 将字节流转换成帧(Bytebuf)的decoder；
2. 将帧数据转换成字节流的encoder;
3. 将帧反序列化到POJO的decoder;
4. 将POJO序列化的encoder;
5. 业务逻辑handler1（如写日志）；
6. 业务逻辑handler2（正常逻辑）；

一般这些handler都是`ChannelInboundHandlerAdapter`或者`ChannelOutboundHandlerAdapter`的子类。

## 一些坑

1. 需要注意，一个handler可以反复被添加到同一个pipeline，多个pipeline也可以公用同一个handler，这就造成一个handler可能会有多个context；
2. 不同handler的context之间没有关系，也就是说这个context是局部上下文而非全局上下文；不同handler之间传递消息后者保存状态就要用`attr`了，这个是附属于channel的而不是cxt的（netty4.1版本前，ctx本身也有个attr，那个和channel的attr不互通，容易引起歧义，后来就改成channel的alias了）；

## 耗时任务

在go语言里，耗时任务单独开一个协程就可以了（但是要防止io资源耗尽问题）。由于线程的昂贵性，在netty里一般使用线程池或者TaskQueue来解决。

通过`channel.eventLoop.execute`在任务队列中插入任务，注意任务在队列中是单线程顺序执行的；通过`schedule`方法则可以调度定时任务。

如果需要循环定时执行任务，则调用`scheduleAtFixedDelay`方法即可，注意这个任务需要手动`cancel`掉。

## 结合springboot使用的思路

现在我们要写一个网关程序，它会与设备使用各种各样的协议进行通信，并接受应用层（其他服务）下达的命令转发给设备。

首先每个通信协议对应一个Bean，类似上文中Leaf的`Module`，Bean的名称采用设备`品牌-类型-驱动`，并实现一个`call(reqId, args…)`的方法。对于长连接通信，显然bean里面需要保存设备id与channel的映射（并在断开连接时清理）。

注意这个设计里，call的执行线程是与应用层通信的bean所在的线程，和实际通信的线程可能并不一样。不过channel.write本身是线程安全的。当应用层发送命令时，通过目标设备的`品牌-类型-驱动`找到对应的bean，然后调用call发送命令即可。

更优雅的设计则是，将命令发送到消息循环里。服务端可以通过`fireUserEventTriggered`向channel中传递一个自定义对象，channel在`userEventTriggered`回调里面处理对应的消息，可以保证回调和channel的读写在同一个线程里面进行。
