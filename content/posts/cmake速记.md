---
title: CMake速记
description:
toc: true
authors: ["tryao"]
tags: ["cmake", "c++"]
categories: []
series: []
date: 2023-01-09T16:42:44+08:00
lastmod: 2023-01-09T16:42:44+08:00
featuredVideo:
featuredImage:
draft: false
---

主要参考书籍《Modern CMake for C++》，以及《CMake Best Practices》，使用CMake版本3.25.

## 使用

一般而言，cmake的使用方式非常简单。在命令行下使用

```bash
cmake -B <build tree> -S <source tree>
cmake --build <build tree>
```

其中`build tree`即build结果文件夹，可以直接用`build`，`source tree`则是源代码目录，一般就是`.`.

上面第一步是构建准备（配置阶段+生成阶段），第二步是真正的构建（包括compile/link/test/package）。

### 准备阶段

可以通过`-G`指定生成器，通过`cmake --help`可以看到可用的生成器列表，unix下习惯使用`Makefile`或者`Ninja`这两种生成器；windows下则习惯使用Visual Studio的各种版本IDE工程文件。

可以通过`-C`指定脚本文件，来预填充缓存信息；或者使用`-D k=v` 直接在命令行里面指定参数；

`-U`与`-D`的含义相反，是用来删除变量的，这两个参数都可以多次使用。

`--log-level=<level>`用来指定日志等级，可以通过`CMAKE_MESSAGE_LOG_LEVEL`来永久保留设置；

`--trace`跟踪模式，类似断点调试；

开发人员可以提供`CMakePresets.json`文件，用来预置相关选项，使用的时候通过`--preset=<preset>`来指定预设文件。

构建之后，可以通过`-L`列出已填充的变量，`-LA`会额外显示出高级变量，`-LH`会额外显示变量的帮助信息；注意通过`-D`指定的**自定义**变量，这里是看不到的；

### 构建阶段

需要传入的参数可以放在命令末尾。例如`-j`或者`--parallel`来指定并发构建数目。

先清理再构建：`--clean-first`.

多配置生成器，可以通过`--config <cfg>`来指定配置，包括`Debug, Release, MinSizeRel 或 RelWithDebInfo`，默认是Debug.

可以通过`-v`参数，打印更多信息。

### 安装

类似`make install`的效果，在cmake中是`cmake --install <dir> [options]`.

如果是多配置生成器，使用`--config <cfg>`来指定配置，一般是`Release`。

单个组件安装，则通过`--component <comp>`来指定组件的名字。

unix系统可以指定安装目录的默认权限，格式为`--default-directory-permissions <permissions>`，默认权限是755.

### 其他

cmake还提供了一些跨平台命令，使用`cmake -E`来执行，或者使用`cmake -P`来运行脚本。后者也可以用Python之类的完成，但是简单的任务可以考虑直接用cmake脚本来完成（后缀就是cmake），不过说实话cmake作为一门脚本语言真的很烂。

## 语法