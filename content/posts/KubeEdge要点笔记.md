---
title: KubeEdge要点笔记
description:
toc: true
authors: ["tryao"]
tags: ["k8s","edge"]
categories: []
series: []
date: 2023-02-21T15:07:54+08:00
lastmod: 2023-02-21T15:07:54+08:00
featuredVideo:
featuredImage:
draft: false
---

## 安装流程

首先要在云端安装k8s，理论上只需要master节点，可以没有worker，换句话说可以是一个单节点集群（但是要关闭NoSchedule的taint）。

k8s迭代的非常快，kubeEdge适配的版本会落后3~4个大版本，因此k8s的版本不能太新。这里使用的是k8s v1.23，对应的是kubeEdge的v1.13.

