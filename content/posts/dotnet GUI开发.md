---
title: Dotnet GUI开发
description:
toc: true
authors: ["tryao"]
tags: []
categories: []
series: []
date: 2024-02-01T11:35:06+08:00
lastmod: 2024-02-01T11:35:06+08:00
featuredVideo:
featuredImage:
draft: true
---

微软官方的跨平台GUI框架MAUI不支持linux，一般还是使用`Avalonia`，此外还有一个`UNO Platform`框架，对比可见[此文](https://zhuanlan.zhihu.com/p/638115608).

目前C#最新版是12，.NET最新的LTS版本是.NET 8.

## 安装

ubuntu22.04的源里目前只有dotnet7，想要装8的话需要使用微软官方的源，安装方式如下：

```bash
# Download Microsoft signing key and repository
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb

# Install Microsoft signing key and repository
sudo dpkg -i packages-microsoft-prod.deb

# Clean up
rm packages-microsoft-prod.deb

# Update packages
sudo apt update && sudo apt install dotnet-sdk-8.0

# 使用国内源
dotnet nuget remove source nuget.org
dotnet nuget add source https://mirrors.cloud.tencent.com/nuget/ -n tencent_nuget
```

然后，如果要写`Avalonia`应用的话，建议使用`Rider`编辑器，并安装相关插件和模板：

```bash
dotnet new install Avalonia.Templates
```

## 基础

C#的基础知识可以看[这本](https://dl.ebooksworld.ir/books/CSharp.12.and.NET.8.9781837635870.EBooksWorld.ir.pdf)比较新的书，或者直接看MSDN也行，微软的文档水平还是没得挑的。

C#语言整体和Java比较像，内置的包管理NuGet比maven好用一点，大部分概念和Java也比较一致。

支持tuple因此可以返回多个值。默认值传递，但是也可以使用`ref`, `in`, `out`修饰符。

比Java更好的是，支持AOT编译成原生程序，类似Golang，可以无运行时启动。

## Avalonia

这个框架可以理解为C#版本的flutter，主要还是用skia进行绘制，不依赖平台的界面库。所以好处是在各个平台保持一致性，坏处是性能不如原生的程序。

Avalonia和WPF的很多基础概念是一致的，所以可以通过阅读wpf的书籍快速熟悉相关概念

