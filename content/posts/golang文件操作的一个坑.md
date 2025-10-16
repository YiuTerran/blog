---
title: Golang文件操作的一个坑
date: 2020-06-05
lastmod: 2020-06-05
slug: 325310a
draft: false
author:
  name: tryao
tags: ["golang"]
collections: []
toc: true
math: true
lightgallery: false
---

今天遇到一个蛋疼的问题，定位了很久，发现在windows上`path.Dir`获取的结果总是`.`，后来发现：

**在windows上永远只用`filepath`这个库里面的函数**，不要直接用path

哎，浪费了一上午=_=
