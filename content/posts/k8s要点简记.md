---
title: K8s要点简记
description:
toc: true
authors: ["tryao"]
tags: ["k8s"]
categories: []
series: []
date: 2023-02-10T09:30:19+08:00
lastmod: 2023-02-10T09:30:19+08:00
featuredVideo:
featuredImage:
draft: false
---

22年的时候需要使用CICD的时候，看了一遍k8s相关的知识点。买了一本《深入剖析Kubernetes》，大致熟悉了常用的概念。

最近因为工作调动需要做云原生相关的开发，有必要重新复习一遍相关概念，并深入部分章节的细节。

## 容器原理

容器是云原生时代的进程。

之前大家都是在ECS这种虚拟机里面部署应用，操作系统一般是CentOS/Debian之类的Linux系统，服务通过Supervisor/Systemd等进程管理工具进行管理，CPU/内存等容量规划是以虚拟机为单位的，环境一般使用bash/python脚本进行初始化，监控、服务集群扩容和缩容都是运维手动配置。

容器最开始是为了解决环境问题（为应用创建隔离的运行环境），有点类似Python的virtualEnv，它的底层原理是基于Linux的资源隔离机制，也就是：

1. Namespace. 通过`clone`创建进程时，可以传入`CLONE_NEWPID`参数，此时这个进程会“看到”一个新的进程空间，在这里他的进程pid是1。在这个进程空间里，它是被隔离的，只能看到操作系统配置的东西；当然在宿主机看来这就是一个普通的进程；
2. CGroups. 用来为进程设置资源限制，如内存、CPU、磁盘、带宽等，同时还具有优先级设置、审计以及进程挂起、恢复等功能；cgroups通过文件系统实现，可以在`/sys/fs/cgroup`下看到各种资源目录，在里面建立文件夹，系统会自动创建对应的资源限制文件
3. 