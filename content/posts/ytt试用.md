---
title: Ytt试用
description:
toc: true
authors: ["tryao"]
tags: ["json", "yaml", "ytt"]
categories: []
series: []
date: 2023-12-29T16:13:12+08:00
lastmod: 2023-12-29T16:13:12+08:00
featuredVideo:
featuredImage:
draft: false
---

jsonnet最大的问题其实是：它支持的是json，而不是yaml. 其实这也不是什么问题，因为yaml是json的超集，json本身就是一个合法的yaml. 但是写起来需要将原来的yaml转成jsonnet，输出成yaml就更麻烦，需要在外围加上`std.YamlManifest()`，这种侵入式的设计感觉很蛋疼。

yaml本身也有对应的DSL，ytt就是其中一种。蚂蚁开源的`kcl`也默认输出的是yaml，不过它和ytt的区别是后者本身是合法的yaml，这里先看一下ytt，再看kcl.

## 安装

很意外，虽然是go写的，但是并不支持`go install`，需要使用脚本安装：

```bash
curl https://carvel.dev/install.sh | sudo bash -
```

安装需要翻墙…所以如果是给别人用，最好还是download下来传到oss之类的地方。

## 设计

ytt的设计思路和jsonnet还是有一些差别的。他是通过在yaml里面注入注释的方式进行扩展：

```yaml
#@data/values
---
a: 8
```

并将yaml分为以下几类：

* 值文档。类似helm的`values.yaml`，其实就是外层的配置；以`#@data/values`开头；
* 值模板文档。用来声明值文档中可用的变量和默认值之类的；以`#@data/values-schema`开头；
* 纯粹的yaml：不含`#@`之类的ytt注释；
* 模板：含有ytt注释的yml；
* 覆盖文档：含有`#@overlay/match`注释的文档；

![pipeline](https://carvel.dev/images/ytt/ytt-pipeline-overview.jpg)

生成yaml的流水线参考上面的图。

## 语法

大体使用Python语法

函数包括两种：

```yaml
#@ def fmt(x, y):
#@   return x+y
#@ end
```

这种有return，还有一种或者类似jsonnet:

```yaml
#@ def labels(x, y):
app.kubernetes.io/version: #@ x
app.kubernetes.io/name: #@ y
#@ end
```

可以将这两种函数分别放到后缀为`.star`和`.lib.yml`的文件里。这种情况下，前者不需要再添加`#@`前缀。

在模板文件里面通过`#@ load("format.star", "fmt")`这种方式进行加载。

## 使用方法

最简单的使用方法，用值yaml渲染模板yaml：

`ytt -f schema.yml -f config.yml --data-values-file values.yml`

其中`schema.yml`是用来定义`values.yml`的默认值和格式、约束的；

`values.yml`是不同环境的真正需要配置的东西；

`config.yml`则是生成最终配置需要的模板；

## schema语法

说实话这块设计的不好，全是各种magic code，看的头疼。

