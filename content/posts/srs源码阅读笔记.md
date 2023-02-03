---
title: Srs源码阅读笔记
description:
toc: true
authors: ["tryao"]
tags: ["srs","media","cpp"]
categories: []
series: []
date: 2023-01-25T16:15:52+08:00
lastmod: 2023-01-25T16:15:52+08:00
featuredVideo:
featuredImage:
draft: true
---

春节休息了几天，正式开始看srs的源码了，流媒体领域估计我也没时间深入研究，只求能理解一个大概逻辑。之前有大略看过ffmpeg的代码，感觉不追求细节的话，还是能看懂大概的。

## 准备工作

首先当然是获取源码，去github clone整个仓库（比较大，可以用depth=1浅克隆），然后切换到比较稳定的tag上（我这里是5.0-a3）。

我这里是在macos上使用clion看代码，linux环境下也可以。如果是windows，则只能使用docker或者wsl，srs不支持windows环境。

在clion中打开trunk目录，然后进入`ide/srs_clion/CMakeLists.txt`，ide会提示加载项目，点击确定即可。

这里可以简单看一下这个cmake配置文件（需要先学习cmake）。

```cmake
include(ProcessorCount)
ProcessorCount(JOBS)
```

这里是计算cpu数目，然后通过

```cmake
    EXECUTE_PROCESS(
        COMMAND ./configure --osx --srt=on --gb28181=on --apm=on --utest=on --jobs=${JOBS}
        WORKING_DIRECTORY ${SRS_DIR} RESULT_VARIABLE ret)
```

执行外部`configure`命令，显然这里主要的编译逻辑托管给这个bash脚本了，而不是使用cmake本身来进行编译。

这个脚本比较长，并且大量引用`auto/`文件夹下其他脚本，这些脚本总的来说就是逐模块生成`Makefile`，拼凑成一个大的Makefile，最后生成的文件在`objs`下。可以打开该文件看一下大概的make顺序。

之后的cmake脚本就是指定依赖头文件和source的路径，将target关联到路径上（一部分路径在`objs`里），比较简单。

总的来说只是用了cmake的壳子，方便ide解析而已。而且里面使用了`AUX_SOURCE_DIRECTORY`，所以有时候修改了源文件还需要重新手动生成CMakeCache.

## 从main文件开始

从makefile里面可以看出srs主服务的入口文件在`src/main/srs_main_server.cpp`，虽然这个项目说是用了C++11，但是实际上写法还是非常98的…比如大量使用NULL而不是nullptr，智能指针也没怎么见到之类的，还大量使用各种宏，总之代码质量不高，可以看做C with class的写法。

由于这是一个单线程服务，所以存在全局变量（实际上在C++中一般不允许使用全局类变量，而是应该使用单例）。

初始化主要是`srs_global_initialize`，包括：

### 日志

这里没有使用spdlog之类的日志库，而是自己写了一个（陋习）。

定义了一个`ISrsLog`的接口：

```cpp
class ISrsLog {
public:
    ISrsLog();
    virtual ~ISrsLog();

public:
    // Initialize log utilities.
    virtual srs_error_t initialize() = 0;

    // Reopen the log file for log rotate.
    virtual void reopen() = 0;

    // Write an application level log. All parameters are required except the tag.
    virtual void
    log(SrsLogLevel level, const char *tag, const SrsContextId &context_id, const char *fmt, va_list args) = 0;
};
```

三个纯虚函数待实现，这个接口有三个实现，分别对应文件/控制台和测试用的mock.

查看`SrsFileLog`对应的cpp文件可以看到具体实现。

### 计时器

C++11实际上已经有`<chrono>`了，不过srs还是自己写了一套计时的代码。包括：

`SrsWallClock`用于获取墙上时钟（即时间戳）；

`SrsPps`应该是用于采样管理（感觉pps是视频编码中的概念）；
