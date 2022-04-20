---
title: Golang定时器要点
description:
toc: true
authors: ["tryao"]
tags: ["golang", "timer"]
categories: []
series: []
date: 2022-04-07T09:35:13+08:00
lastmod: 2022-04-07T09:35:13+08:00
featuredVideo:
featuredImage:
draft: false
---

golang内置的定时器是基于多个四叉堆封装调度的，增删定时器的效率是O(lgn)，所以大量定时器本身可能成为性能瓶颈。可以考虑使用开源的时间轮算法实现方案进行替换。不过一般情况下不需要考虑该问题，如果时间轮真的万能的话，官方肯定就重构了。

复用定时器技巧：

```go
for {
    t = timer.NewTimer(5 * time.Second)
    defer t.Stop()
    select {
    case b := <- a:
        fmt.Print(b)
        break
    case <-t.C:
        fmt.Print("timeout")
        continue
    }
}
```

这种循环场景下回创建大量定时器，对性能有较大影响，所以应该通过Reset进行复用。即：

```go
t = timer.NewTimer()
for{
    t.Reset(5 * time.Second)
    //...
}
```

`timer.Reset`的使用很容易出现各种问题，这主要是`timer.Stop`实际上并不会关闭`t.C`这个channel，因此需要：

```go
if !t.Stop(){
    <-t.C
}
```

来判断t是expired还是stop成功，如果expired，需要将`t.C`里面的信号取出来抛弃掉。

令人蛋疼的是，在Reset之前是否需要做这一步完全取决于`t.C`里面是否有数据。如果确认`t.C`里面的数据已经取出，就**必须不能**做这一步，否则会卡在`<-t.C`这里。

而看似万无一失的:

```go
if !t.Stop(){
    select{
    case <-t.C:
    default:
    }
}
```

一样有问题。由于go的timer源码里存在竞态条件，导致`t.Stop`和`<-t.C`这两部之间存在时序问题，这么干了可能会导致后面用到`<-t.C`的地方立刻触发。

所以官方给出的解答是：

- 程序始终在同一个 goroutine 中进行 Timer 的 Stop、Reset 和 receive/drain channel 操作
- 程序需要维护一个状态变量，用于记录它是否已经从 channel 中接收过事件，进而作为 Stop 中 draining 操作的判断依据

一定要小心谨慎地使用。