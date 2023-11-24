---
title: DeepinLinux键盘映射
description:
toc: true
authors: ["tryao"]
tags: ["linux"]
categories: []
series: []
date: 2023-11-24T10:51:31+08:00
lastmod: 2023-11-24T10:51:31+08:00
featuredVideo:
featuredImage:
draft: false
---

由于公司开始强制使用Linux桌面系统，所以最近安装了Deepin 20.9作为日常开发系统。

> 本来先尝试了Ubuntu 22.04和KDE Neon做为开发环境，但是体验都不太好：
>
> KDE Neon与日常使用的软件兼容性很差，主要是大部分软件都是GTK搞的；
>
> Ubuntu安装微信很麻烦，而且蓝牙耳机连接经常断连；

装好之后，大部分软件都可以直接在商店下载，比较简单。网易云官方的播放器不能用，建议改为**YesPlayMusic音乐播放器**这个开源的播放器。

Deepin的快捷键和Windows一模一样，所以很容易适应。

但是我是一个改键党：必须使用Emacs的一些快捷键，但是深度的DDE实际上没有gnome中的emacs全局设定，这就有点麻烦。

改键的开源软件其实很多，我先后尝试了几个，其中keyd的设置最简单，但是不知道为啥我设置之后没有生效…

最后能用的是`xremap`这个rust写的小软件，使用cargo安装即可。配置文件如下：

```yaml
keymap:
  - name: Emacs
    application:
      not: [Emacs]
    remap:
      # Cursor
      C-b: { with_mark: left }
      C-f: { with_mark: right }
      C-p: { with_mark: up }
      C-n: { with_mark: down }
      # Forward/Backward word
      M-b: { with_mark: C-left }
      M-f: { with_mark: C-right }
      # Beginning/End of line
      C-a: { with_mark: home }
      C-e: { with_mark: end }
      M-a: { with_mark: C-a }
      M-c: { with_mark: C-c }
      M-v: { with_mark: C-v }
```

我常用的只有这些，其他的都被我删掉了。

在root的cronjob里加入：

```bash
 @reboot /home/tryao/.cargo/bin/xremap /home/tryao/.xremap/config.yml
```

之后即可开机自启动了。

实际体验很好，rust写的小软件性能很强，使用中基本没有延迟。