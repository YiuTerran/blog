---
title: Jinja2小结
description:
toc: true
authors: ["tryao"]
tags: ["devops"]
categories: []
series: []
date: 2024-01-05T08:55:48+08:00
lastmod: 2024-01-05T08:55:48+08:00
featuredVideo:
featuredImage:
draft: false
---



之前写Python的时候其实有接触过一些jinja2，不过没有怎么用过实际上。毕竟前后端分离之后，这些模板语言在web开发上用处并不大。不过`ansible`选用了它做渲染模板，所以还是需要深入学习一下。比较蛋疼的是，k8s这边因为都是golang生态，所以用的是`go template`，那就是另外一套东西了。

## 基础

首先是使用`{{ x }}`来引用变量，这个是最基础的语法。如果想要声明变量，可以用`set`.

可以通过过滤器`|`修改变量，内置了大量常用的过滤器用来修改字符串或者数字。

如果是逻辑语句，例如`for`, `if`等，则使用`{% for %}`这种格式；这种语句一般有对应的`endfor`, `endif`做收口。

注释使用`{#  #}`, 可以跨行。

模板默认不会移除空白，可以使用类似`yaml`的减号，如`{%- if xxx -%}`。

raw字符串，即类似`r`前缀的：`{% raw %}...{% endraw %}`

如果启用了行语句，则可以使用更简单的语法，比如规定行语句前缀为`#`， 就可以直接写 `# for t in ts`了。

## 模板继承

在父模板里面定义`{% block xxx %}`和`{% endblock xxx %}`，在子模板里面使用`{% extends "xxx.yml" %}`，然后再通过覆盖block的方式进行继承。

支持通过`self`和`super`关键字调用自身或者父级模块。

## 循环

比较特殊的只有一点：不支持`break`和`continue`，不过可以用`{% for item in items if item %}`这种语法，并且支持`for .. else ..`语法。

## 宏

即函数，语法类似：

```jinja2
{% macro input(name, value='', type='text') -%}
	
{%- endmacro %}
```



## 模板引用

可以使用`{% include 'some.yml' ingore missing %}`，直接引用其他模板，相当于直接将模板嵌套进来。

还有一种方法是通过`{% import 'xx' as xx %}`的方式导入，这种是用来导入模板中的macro，以用来调用的。

默认下，每个包含的模板会被传递到当前上下文，而导入的模板不会。这样做的原因是导入量不会像包含量被缓存，因为导入量经常只作容纳宏的模块。但是这个行为可以通过在`include`/`import`后面增加`with/without context`来显示的改变。

## 扩展

可以通过扩展来修改jinja2的默认行为，比如打开循环扩展，就可以支持`continue`和`break`了。