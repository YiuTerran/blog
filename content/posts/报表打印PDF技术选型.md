---
title: 报表打印PDF技术选型
date: 2017-07-07
lastmod: 2017-07-10
slug: 1b4669b
draft: false
author:
  name: tryao
tags: ["python","office"]
collections: []
toc: true
math: true
lightgallery: false
---

做的外包项目有这个需求：输出PDF格式的单据，稍微调研了一下实现方式，做个汇总。

首先吐槽一下…做外包还是尽量用成熟技术，下次再做管理平台的需求，还是flask-admin配上JQuery上吧。这次用vue+elementUI，写的倒是挺爽，关键时候找不到组件还要自己造轮子，效率堪忧_(:зゝ∠)_

## 服务端实现

Python这边用ReportLab比较多，稍微研究了一下发现过于复杂。利用xml定义了一套新的语法，叫RML，如果要写的话，先要学习一遍这个东西，成本太高。而且像这种学完基本不怎么用的东西，很快就忘了…不建议使用。

使用`pdfkit`，这玩意儿底层调用了`wkhtmltopdf`，看名字也知道使用html转pdf.

`Sphinx`本质上是调用$\TeX$来渲染成PDF，依赖项比较复杂，但是控制粒度非常好（毕竟是标准）。

## 客户端实现

1. 使用HTML做普通排版，然后调用`print.js`. 结果：效果很差，样式丢失严重。
2. 使用`jsPDF`，不支持中文。
3. 使用`pdfmake`，嵌入中文字体后，生成要求的内容，然后就可以直接调用接口，很爽…生成内容直接用JS内置的数据结构就可以完成。使用起来最简单，但是：嵌入字体后资源文件太大（至少2M+），除非使用TTF裁剪，不然浏览影响很大；其次：浏览器兼容性不好，用起来很受限。我本来尝试了一番，最后还是放弃了。不过不得不说的是，如果使用nodejs作为服务器的话，选这个方案很好。

## pdfkit

最终选型使用pdfkit方案。

### 安装依赖

主要依赖`wkhtmltopdf`这个二进制文件。注意，如果使用的是`ubuntu16.04`，请不要直接使用ubuntu源里面的该文件，源里面是without qt patched的，需要自己下载安装，[具体步骤](http://localhost:1313/2017/07/07/报表打印-pdf-技术选型/!https://stackoverflow.com/questions/37765698/unable-to-install-wkhtmltopdf-with-patched-qt-in-ubuntu-16-04)是：

```
sudo apt-get update
sudo apt-get install libxrender1 fontconfig xvfb
wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.4/wkhtmltox-0.12.4_linux-generic-amd64.tar.xz -P /tmp/
cd /opt/
sudo tar xf /tmp/wkhtmltox-0.12.4_linux-generic-amd64.tar.xz
sudo ln -s /opt/wkhtmltox/bin/wkhtmltopdf /usr/local/bin/wkhtmltopdf
```

然后使用`pip install pdfkit`安装Python这边的依赖即可。

如果是Linux服务器，记得安装中文字体，使用文泉驿正黑即可(wqy).

### 具体使用

几个要点：

1. 报表的HTML文件最好不要依赖外部css，全部直接内嵌在文件中比较方便；
2. HTML需要声明为utf8编码；
3. 不要对文件使用中文名称；
4. 渲染的时候有些参数需要设置，如下：

```
pdfkit.from_string(page, outfile, options={
    'page-size': 'A4',
    'margin-top': '0.75in',
    'margin-right': '0.75in',
    'margin-left': '0.75in',
    'margin-bottom': '0.75in',
    'encoding': "UTF-8",
    'no-outline': None,
    # 'zoom': 1.5,  # when run on mac
    # 'dpi': 250
})
```

其中`0.12.4`版本mac上运行的时候，需要设置最后两个参数才能保证字体大小看起来比较正常.

pdfkit渲染速度超快，非常👍
