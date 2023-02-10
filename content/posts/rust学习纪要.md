---
title: Rust学习纪要
description:
toc: true
authors: ["tryao"]
tags: ["rust"]
categories: []
series: []
date: 2023-02-10T09:50:48+08:00
lastmod: 2023-02-10T09:50:48+08:00
featuredVideo:
featuredImage:
draft: true
---

我大概学了3次rust, 之前基本都是半途而废。第一次是卡在生命周期那里，第二次是卡在智能指针那里。

最近写了一段时间C++，再拿起rust的书，突然感觉没啥阻塞了。

说到底我还是不太习惯用无GC语言，而且之间IDE的支持一直很差，用起来比较崩溃(￣▽￣") 。这跟Haskell那种**真**学不会的情况还是有点差别的，估计啥时候我能看懂范畴论了，Haskell才能学会。

还有关键的一点，之前讨厌C++主要是因为太古老了，工具链落后，写起来有点浪费生命的感觉。Visual C++和Linux C++完全是两个物种，割裂的非常严重。最近发现CLion已经支持Makefile工程，加上有了vcpkg这种包管理器，对C++的抵触心理下降了很多，所以rust也能看进去了。当然Visual Studio还是只能支持CMake工程，Makefile工程还是不行的。感觉Jetbrain全家桶应该是这几年买的最值的东西了，尤其是我这种啥都想写的。

这里记录一下rust的关键难点，方便将来需要的时候拿来复习。

## 语法

