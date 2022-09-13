---
title: Ginkgo使用笔记
description:
toc: true
authors: ["tryao"]
tags: ["golang", "test"]
categories: []
series: []
date: 2022-09-05T18:10:06+08:00
lastmod: 2022-09-05T18:10:06+08:00
featuredVideo:
featuredImage:
draft: false
---

go自带的单元测试比较适合测一个小函数，如果要做一系列的流程测试，则显得较为繁琐。

推荐使用`ginkgo`来做流程测试，BDD风格写出来的测试代码非常容易读懂和维护。

## 安装

这里使用v2版本进行测试，首先安装二进制文件

```bash
go install github.com/onsi/ginkgo/v2/ginkgo@latest
```

在待测试的项目中运行：

```go
go get github.com/onsi/gomega
```

## 生成

在待测试的package下面跑

```bash
ginkgo bootstrap
```

生成suit_test文件。

然后对单个文件跑

```bash
ginkgo generate xxx
```

xxx是待测试文件的名字。

## 语法

这个生成的`xxx_test.go`被称为一个spec. spec分为三类结点：

* 容器节点，如`Describe`、`Context`和`It`，可以理解为前端的`div`，就是用来组织代码的；一般用来说明测试的场景；
* setup结点，如`BeforeEach`，用来初始化数据；
* 主题结点，一般用`gomega`里面的各种断言，形如`Except(xxx).To()`，后面会详细解释；

### JustBeforeEach

该节点运行在`BeforeEach`之后，主题节点之前，可以用来做统一初始化；

### BeforeEach

运行所有主题节点之前都要跑的函数

### AfterEach

在主题节点结束之后运行

### JustAfterEach

在主题节点结束之后，AfterEach节点运行之前

### DeferCleanUp

可以在BeforeEach里面写的闭包，代替AfterEach清理，代码更为简单

### BeforeSuite和AfterSuite

在整个测试集开始之前和结束之后运行的代码，通过全局变量写在`suite_test`文件里；

### DescribeTable与Entry

可以配合用来测试多个case，避免重复代码

## 生命周期

Ginkgo默认支持并行测试，所以必须知道整个测试树的生命周期。

1. 测试树构建阶段：
   1. 遍历顶层容器（Describe），并调用其匿名函数；
   2. 定义在顶层容器中的闭包变量被初始化；
   3. 注册BeforeEach，并传递内嵌的匿名函数（不会执行）；
   4. 注册It，并传递内嵌的匿名函数（不会执行）；
   5. 注册Context，并传递内嵌的匿名函数（立即执行）；
   6. 递归构建Context中的内容；
2. 测试树调用阶段：
   1. 将BeforeEach和It关联起来，依次运行这些函数；

所以需要注意：

* 2阶段中不能包含1阶段定义的函数，即It中不能再包含Context等；
* 2阶段不会重新初始化1阶段匿名函数中的变量，所以小心测试污染；
* 不要在1阶段容器中使用断言；
* BeforeSuite在**测试树调用阶段**只运行一次；