---
title: 使用python生成word文档
date: 2021-06-08
lastmod: 2021-06-21
slug: f60311f
draft: false
author:
  name: tryao
tags: ["python","office"]
collections: []
toc: true
math: true
lightgallery: false
---

有个任务是根据已有的word模板动态生成一部分内容，需要插入的数据包括：普通文本（部分含编号）；表格以及表格下方的标注（通过excel导入）；图片以及图片下方的标注；

使用的库主要是[python-docx-template](https://github.com/elapouya/python-docx-template)以及pandas. 后者主要用来读取excel，所以还依赖openpyxl.

python-docx-template其实是[python-docx](https://python-docx.readthedocs.io/en/latest/)这个库的扩展，两边的文档都要看一下。

需要先做好word的模板，可以参考python-docx-template项目下的`tests/templates`文件夹，里面是一些做好的word模板。注意几个点：

1. 除了内置样式(style)外，其他都通过样式窗格创建，这些样式需要使用**英文命名**；
2. 内置样式的英文名称可以查看这里的[文档](https://python-docx.readthedocs.io/en/latest/api/enum/WdBuiltinStyle.html)，总之出现在代码里`style=''`，引号只能是英文；
3. 一些简单的样式调整（如字体颜色、粗体、斜体、下划线），临时的对齐等，可以通过硬编码；
4. 编号的生成是通过样式完成的，而不是手动在代码里生成；
5. 无法生成目录，需要创建完成后手动更新域；
6. 动态表头的生成非常复杂，目前可能完成不了某些需求；可以使用python-docx-template的replace dummy file思路进行替换，但是插入的表格可能会有点丑；

其实大部分精力都是在**调整样式**上。

创建模板时，使用python-docx-template的类jinja2语法插入标签当做占位符：

- 简单的变量替换都是`{{ var1 }}`；
- 占位符特别需要注意空格的使用，普通占位符两边有空格，有前缀的占位符就不一定了；
- 大段复杂数据生成，使用`Sub-documents`技术，在文档里面放一个`{{p subdoc1}}`，注意p前面没有空格；
- 非完全动态的表格，可以先画个模板上去，参考templates里面`horizontal_merge_tpl.docx`和`vertical_merge_tpl.docx`这两个文档。可以满足一定的动态化需求；

模板完成后就写代码，逻辑比较简单，就打开模板->渲染数据->另存为文件，三板斧结束。主要业务是生成占位符对应的渲染内容（一个dict），反正写的时候多看文档。

这个方案目前只能满足比较简单的文档需求，复杂的还是要手动调整的。只能说可以减轻部分工作量。
