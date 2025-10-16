---
title: Docker常见命令
date: 2019-02-17
slug: c0a4f25
draft: false
author:
  name: tryao
tags: ["devops"]
collections: []
toc: true
math: true
lightgallery: false
---

## 日志类

```
docker logs -f <container> # 查看日志
journalctl
```

## 容器类

```
docker ps # 查看正在运行的容器
docker ps -a -q # 查看全部容器和信息
docker ps top
docker pull/commit/tag/push/diff/attach
docker create/build/run/rm
docker start/stop/pause
docker  exec -it {{containerName or containerID}} bash  # 进入容器交互
docker cp
```

## 镜像

```
# 列出本地所有镜像
docker images
# 本地镜像名为 ubuntu 的所有镜像
docker images ubuntu
# 查看指定镜像的创建历史
docker history [id]
# 本地移除一个或多个指定的镜像
docker rmi
# 移除本地全部镜像
docker rmi `docker images -a -q`
# 指定镜像保存成 tar 归档文件， docker load 的逆操作
docker save
# 将镜像 ubuntu:14.04 保存为 ubuntu14.04.tar 文件
docker save -o ubuntu14.04.tar ubuntu:14.04
# 从 tar 镜像归档中载入镜像， docker save 的逆操作
docker load
# 上面命令的意思是将 ubuntu14.04.tar 文件载入镜像中
docker load -i ubuntu14.04.tar
docker load < /home/save.tar
# 构建自己的镜像
docker build -t <镜像名> <Dockerfile路径>
docker build -t xx/gitlab .
```
