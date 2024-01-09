---
title: Python技术栈更新
description:
toc: true
authors: ["tryao"]
tags: ["python", "web", "crawler"]
categories: []
series: []
date: 2024-01-09T09:35:01+08:00
lastmod: 2024-01-09T09:35:01+08:00
featuredVideo:
featuredImage:
draft: false
---

有段时间没用Python写工程了，基本都是写脚本，最近接了个活帮忙搞个爬虫相关项目，需要更新一下技术栈，做个笔记。

* web开发：`fastapi`, 其实还可以接着用flask，不过前者对asyncio支持更完善一些，顺便学一下新东西；至于django还是太重了，写单体估计有点用；
* 数据库ORM：仍然可以继续使用`sqlalchemy`，最新的是2.0版本，已经支持asyncio；
* 爬虫：爬虫相关的技术栈变化不大…scrapy其实不太好用，封装的太厚，而且`twisted`早就过时了。自己写的话就：
  * 用`aiohttp`做网络请求；
  * `dom`解析：仍然是基于`lxml`的技术栈，主要还是`xpath`和`css-selector`来获取元素；
  * 浏览器模拟（动态网页）：`Playwright`代替了`Selenium`等古早的框架；
  * 打包：用docker就行；
  * 验证码破解：这个相关的网站蛮多的，但是好不好使需要测试一下才知道。包括：`yesCapture`, `2Capture`和穿云等；
  * 其他反爬技术：这个只能随机应变了，现在很多网站都做了反爬，具体手段不一，需要尝试解决；

## [FastAPI](https://fastapi.tiangolo.com/zh/)

