---
title: Lua5.1要点笔记
date: 2017-06-12
lastmod: 2017-06-13
slug: a39b598
draft: false
author:
  name: tryao
tags: ["lua"]
collections: []
toc: true
math: true
lightgallery: false
---

## 安装

```
sudo apt-get install lua5.1
```

lua的各个版本之间不兼容问题很严重，5.1-5.2-5.3之间都有一些不兼容的问题，5.1是最经典的版本，适用范围广泛。luajit与lua的关系相当于pypy与cpython的关系，luajit采用lua5.1语法，作者已经另起炉灶了，永远不和lua5.2兼容。Heka的lua扩展也是使用5.1版本的lua。

lua是一门嵌入式语言，也就是程序的入口点必定在别处，这是和python等脚本语言的最大区别。lua的性能很好，虽然比不上v8的js。

## 语法

1. 作为一门动态语言，可以从lua身上看出许多动态语言的影子。lua与js，python都有一定的相似性，可以说是综合了二者之所长。但是有个坑，就是unicode问题，lua5.3解决了这个问题。不过对于heka，一般情况下我们不太需要处理utf8，毕竟日志数据track一般都是编号和数据。

2. 与python不同而与js类似，lua是动态类型语言。字符串会在适当时候自动转成数字， 当然也可以使用string.format自己进行转换；

3. 所有的变量默认是全局的（与js一致），需要使用local修饰符来创建局部变量；全局变量被存放在一个table中，被称为环境，可以通过`getfenv`和`setfenv`来对环境进行操作；

4. 只有一种数据结构：table. 赋值语句比较奇怪:

   ```
   a = {x=3, [2]=2}
   a[1] == 2
   a["x"] == 3
   ```

   注意table里面值不能是nil，否则会有各种奇怪的问题。连接操作符：`..`，取长度操作符`#`，但是`#`返回的是字节数，所以更像是`sizeof`。

5. 函数与js中的很像，支持闭包。`：`可以用来定义方法，本质上是一种语法糖；

6. `metatable`类似与python的内置方法，各种重载操作符。

7. lua支持`coroutine`.

### 库

1. 由于lua中table不支持`nil`，这与json中的`null`产生了矛盾，需要使用`cjson.null`来表示
