---
title: Java并发编程实战读书笔记
date: 2017-06-12
lastmod: 2017-06-13
slug: d9abd3c
draft: false
author:
  name: tryao
tags: ["java"]
collections: []
toc: true
math: true
lightgallery: false
---

并发编程实际上极其复杂，有很多绝对值得去看的建议。
<!--more-->

1. 不要在构造器里面调用可变函数（虚函数），这是所谓的安全构造需求；
2. 最简单的线程安全类是不可变类，不可变类有如下硬性要求：
   - 对象创建以后就不能修改
   - 对象所有域都是`final`的
   - 对象是安全构造的
3. 所谓可见性指的是a线程修改了变量，b线程可以知道这种修改；所谓原子性指的是a线程在修改变量时，b线程不会干扰这种修改；
4. 所谓安全发布，必须满足以下条件之一：
   - 在静态初始化函数中初始化一个对象引用
   - 将对象的引用保存到`volatile`类型或者`AtomicReferance`对象之中
   - 将对象的应用保存到某个正确构造对象的`final`域中
   - 将对象引用保存到一个由锁保护的域中
5. `volatile`变量只能保证可见性，无法保证原子性；加锁则都可以保证（但是会繁琐一些）。
6. 不要在构造器中调用新的线程，这会导致不安全发布；正确的做法是使用静态工厂函数，构造完毕后再启动线程（或者做其他发布）；
7. 最简单维持线程安全的方法是使用局部变量（栈封闭），其次是使用原子类，包括现场本地存储类`ThreadLocal<>`
8. 大多数情况下，我们无须直接使用`Thread`这种基础类，java提供了很多适用范围广泛的组件，包括：
9. 并发容器类，使用`java.util.concurrent`中定义的包括`ConcurrentHashMap`, `CopyOnWriteArrayList`，`ConcurrentLinkedQueue`和`BlockingQueue`（`BlockingDeque`),以及`ConcurrentSkipListMap`和`ConcurrentSkipListSet`（作为`SortedMap`和`SortedSet`的替代品）.`BlockingQueue`在`take`和`put`时，如果没有元素/空间就会阻塞；
10. 如果线程被中断，会抛出`InterruptedException`如果是`Runnable`的对象，是不可以直接抛出这个异常的，必须捕获并使用`Thread.currentThread().interrupt()`恢复中断；其他类型的对象倒是无所谓，可以直接抛出或者捕获清理后重新抛出；
11. 闭锁。`CountDownLatch`可以用来等待计数，`FutureTask`是一种`Callable`，可以通过`get`来获得结果（或者阻塞），`Semaphore`用来对资源进行限制计数，可以用来实现资源池，使用`acquire`获得一个资源，使用`release`释放一个资源，`Barrier`用来实现分段任务，当所有任务都到达Barrier时，任务继续，否则抛出`BrokenBarrierException`异常。本章给出了一个缓存的例子。
12. Executor框架。`Executor`是一个接口，只规定了`execute`一个接口（其参数是一个`Runnable` class）；`Executors`包含生产线程池的几个静态方法，如`newFixedThreadPool`（固定大小），`newCachedThreadPool`（无限增长）和`newSingleThreadExecutor`（单线程串行）,和`newScheduledThreadPool`（定时执行）。如果这些都不能满足需求，可以直接使用`ThreadPoolExecutor`自己灵活构造线程池
13. `ExecutorService`接口在`Executor`接口的基础上增加了生命周期，可以使用`shutdown`，`shutdownNow`，`awaitTermination`等方法进行生命周期（运行、关闭和已终止）控制和感知。
14. `ExecutorService`的`submit`方法用于提交一个任务并返回一个`Future`，使用这个结果可以控制任务的生命周期；
15. 线程的超时：一般可以用重载的`get`，`await`等方法指定超时时间；
16. 线程的取消：习惯上使用一个`volatile`变量作为取消标志，但是如果线程阻塞了，这个方法就不好用了。最佳方式是使用中断(`Future.cancel`)，注意需要处理好相关的异常；
17. 可以通过继承`Thread`重载`interrupt`方法来将中断处理封闭在异常类中；可以通过使用`ThreadPoolExecutor`中的`newTaskFor`静态方法由`Callable`生产`RunnableFuture`
