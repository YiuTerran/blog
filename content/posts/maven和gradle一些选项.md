---
title: Maven和gradle一些选项
date: 2017-06-26
lastmod: 2017-06-26
slug: da08b62
draft: false
author:
  name: tryao
tags: ["java"]
collections: []
toc: true
math: true
lightgallery: false
---

Java的包依赖系统简单粗暴，就是直接下载jar包，经历了`Ant` -> `Maven` -> `Gradle`这几个阶段，目前的项目里面还是Maven比较多，后续我会试着迁到Gradle上。

如果用一句话来表明区别的话：Gradle的配置文件是一种DSL，而Maven则使用XML，表达能力不可同日而语。

## 冲突

Maven在多个模块依赖同一个模块时，需要手动处理版本冲突问题（将公共依赖手动排除），而Gradle会尝试自动解决该问题（使用公共依赖的最新版本）。

## scope

类似`npm`中的概念：这个包是啥时候被需要。显然有些包只是编译的时候需求，运行的时候不再被需要，因为Maven中的`scope`分为以下几种：

- compile. 默认范围，会被打包。
- provided. 这个概念比较模糊，意思是这东西由外部容器提供，不需要自己打包进去。
- runtime. 只有运行和测试系统的时候需要，编译的时候不需要。一个典型的例子就是`jdbc`的接口API在编译时必须要可用，但是具体实现可以只在运行时插入。
- test. 只被测试依赖。Maven有标准的测试流程。
- system. 系统范围，jar包被放在本地，无须从仓库中寻找。当然一般不推荐使用。

## Idea的使用

Idea中可以在`Project Structure`里面直接修改配置，会自动生成/修改对应的Pom文件，主要在`modules/dependencies`里面改。
