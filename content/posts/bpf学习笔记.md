---
title: eBPF学习笔记
description:
toc: true
authors: []
tags: []
categories: []
collections: []
date: 2024-04-14T09:25:27+08:00
featuredVideo:
featuredImage:
draft: false
---

eBPF的理论看起来有点抽象，实际上就是注册到内核的回调函数，可以拦截系统调用，然后用来完成自己的事情。

只是这个回调函数在内核空间只能用C来写，门槛还是有点高的，除了C之外其他的语言可以写用户空间部分。

tcpdump和strace等常用程序就是基于eBPF来实现的。

## bcc程序集

eBPF常用的利用方式是直接使用其他人贡献的bcc程序集，就和你直接用tcpdump一样。

安装程序集的方法参考[这里](https://github.com/iovisor/bcc/blob/master/INSTALL.md)，Ubuntu最新版需要使用非官方PPA：

```bash
sudo add-apt-repository ppa:hadret/libbpf
sudo add-apt-repository ppa:hadret/bpftrace
sudo add-apt-repository ppa:hadret/bpfcc
sudo apt-get install bpfcc-tools linux-headers-$(uname -r)
```

Ubuntu里这些二进制文件的名字会添加`-bpfbcc`的后缀，比如`exesnoop-bpfbcc`.

bcc用户态的代码是用Python写的。

### execsnoop

监控系统新进程的产生，那些会消耗系统资源，但很短暂的进程，它们甚至不会出现在 `top` 命令或其它工具中的显示之中，此时使用该命令可以有效监控。

这个名字的来源是它实际监控`exec`的系统调用。

### opensnoop

类似地，用来监控文件打开。

### biosnoop

根据块设备io，并打印延迟。

一般使用biolatency -D找到延迟大的磁盘，然后使用biosnoop找到延迟大的进程。

### biotop

可以迅速定位占用大量io的进程。

### ext4slower

检测ext4系统上，文件io较慢的进程和文件名。

其他文件系统也有对应的工具，修改前缀匹配即可。

### biolatency

块设备io延迟跟踪，以直方图显示。

比iostat的输出更加直观。

### cachestat

查看文件系统的缓存命中率。
