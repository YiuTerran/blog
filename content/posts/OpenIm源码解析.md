---
title: "OpenIm源码解析"
date: 2022-11-22T21:17:01+08:00
draft: true
---

Tinode的源码比较简单，架构也不太依赖外部组件，代价就是可靠性不强，集群设计也比较弱鸡。大型项目上，还是需要考虑其他项目，这里主要考察另外一个golang语言的主项目[Open-IM-Server](https://github.com/OpenIMSDK/Open-IM-Server).这个项目是国人作品，所以集成的第三方组件主要都是国内的商业软件，比较开箱即用。

之前也说过这个项目是有对应的商业项目的，所以不要太指望开源社区这边积极度很高。实际上这项目文档写的极其拉胯，github issue也给人一种没人维护的感觉，研究起来比较痛苦。

## 安装运行

按着`Source code deployment`的指引，将代码clone到本地，在Linux环境下直接运行`build_all_service.sh`就能跑起来了。项目中使用了CGO，如果想在macos上运行需要折腾一下，在项目根目录下运行：

```bash
brew install FiloSottile/musl-cross/musl-cross
grep -rl GOARCH=amd64 . | xargs sed -i 's/GOARCH=amd64 CC=x86_64-linux-musl-gcc  CXX=x86_64-linux-musl-g++/g'
```

这里主要是将makefile中的编译语句修改，使用musl代替默认的glibc进行编译。

当然这个编译出来的二进制只能在linux下面跑，而且linux上还要安装musl才行。想要在本地跑，还要修改`GOARCH`为darwin，不过这个软件貌似不承诺兼容macos，所以总体还是建议在linux下进行开发。

由于依赖很多，建议先在远端服务器上使用docker-compose启动依赖组件。其中Prometheus和grafana用于监控系统，只是为了开发的话可以不启动。编译完了会在`bin/`文件夹下生成一堆二进制文件，这就是本服务包含的一堆微服务了。

