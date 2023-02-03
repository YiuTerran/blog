---
title: Makefile要点简记
description:
toc: true
authors: ["tryao"]
tags: ["make","gnu","cpp"]
categories: []
series: []
date: 2023-01-25T16:49:11+08:00
lastmod: 2023-01-25T16:49:11+08:00
featuredVideo:
featuredImage:
draft: false
---

虽然现代C/CPP一般使用cmake作为工具链，但是如果要看陈年老项目，makefile相关的知识还是要掌握一些的，不然估计很难理清编译逻辑。这也是c/cpp的技术负债之一。

## 梗概

```makefile
target ... : prerequisites ...
<tab>command
<tab>other commands
```

其实和cmake有点像，也是先定义target，以及其依赖，然后运行命令生成target。

> prerequisites中如果有一个以上的文件比target文件要新的话，command所定义的命令就会被执行。

也就是增量编译。

第一个target是默认生成的文件，直接跑`make`命令即可。其他target需要用`make xxx`来手动执行。

## 语法

1. 类似bash，直接`obj = a b c`就是数组，使用`$(obj)`来引用变量；
2. 使用`include`来导入其他makefile，也可以用`MAKEFILES`的环境变量来隐式include；
3. 通配符默认并不会展开，需要手动指定，如`obj := $(wildcard *.c)`;
4. 使用`vpath`关键字定义搜索目录，语法是`vpath pattern directorys`，pattern并不是正则，而是类似glob语法，但是使用`%`而不是`*`。如`vpath %.h ../headers`;
5. `.PHONY`表示伪目标，并不会真的生成对应的目标，如`clean`动作；
6. 多个目标可以使用相同的生成语法，使用`$@`来引用具体的目标名称；
7. `$<`表示第一个依赖文件；
8. 命令前加`@`，那么命令将不会显示出来；
9. 如果命令之间有依赖关系，那么不能放在两行，而是同一行用`;`隔开，例如`cd ..;pwd`；
10. 命令前加`-`，表示可以忽略该指令的错误；
11. 可以类似cmake，将makefile拆成多个文件；不过makefile向下级传递变量的方式和cmake不一样，需要显式export；
12. 下级makefile需要手动执行`$(MAKE)`；
13. 可以用`define..endef`定义一系列命令组成的命令包；
14. makefile中的变量使用起来是宏展开，使用`:=`定义时，只允许引用已定义的变量；使用`?=`定义，则表示如果变量不存在则定义；
15. 我们可以替换变量中的共有的部分，其格式是 `$(var:a=b)` 或是 `${var:a=b}`；
16. 如果有变量是通常make的命令行参数设置的，那么Makefile中对这个变量的赋值会被忽略。如果你想在Makefile中设置这类参数的值，那么，你可以使用“override”指示符。如`override obj; := xxx`;
17. 目标变量：可以在目标之后定义变量，如`target: obj:=yyy`，这样，在target相关命令中，`$(obj)`都是`yyy`;
18. 模式变量：对目标变量的扩展，如`%.o: CFLAGS = -0`；
19. 条件语句：`ifeq`,`ifneq`,`ifdef`,`ifndef`；

## 内置函数

请参考[这里](https://seisman.github.io/how-to-write-makefile/functions.html)

## 隐式规则

同样参考文档即可，这玩意儿只是使用惯例。