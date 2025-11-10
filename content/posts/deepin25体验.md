---
title: Deepin25体验
date: 2025-11-09T10:11:15+08:00
slug: e44a058
draft: false
author:
  name: tryao
tags: ["linux", "deepin"]
collections: []
toc: true
math: true
lightgallery: false
---

最近把Chromebook又重装了，这台i7-1265U的笔记本运行win11还是有点勉强，风扇噪声有点烦人。家里本来就有windows的台式机，工作用Windows的时候一般用虚拟机就够了，这台笔记本还是拿来装linux比较合适。

<!--more-->

之前在公司电脑上装过deepin23，体验很不太行，主要是动画不够流畅，感觉卡卡的。公司电脑还是12代的标压cpu，配置的有独显（虽然是个2G显存的垃圾显卡），所以确实是系统做的不太行，[后面切换成LinuxMint之后很流畅](https://yiuterran.github.io/blog/posts/linux%E6%97%A5%E5%B8%B8%E4%BD%BF%E7%94%A8%E8%AE%B0%E5%BD%95/)，不过配置起来还是很繁琐。

这次体验了一下deepin25，感觉很不错，而且配置简单多了，简单记录一下。

## 安装

直接ventoy + 官方设备版镜像，全盘格式化全新安装即可。

deepin25基于Debian 12bookworm，切记这一点，安装开源软件的时候都按debian的步骤来。

## 驱动

大部分设备会直接识别，但是我这个毕竟是chromebook，还是要折腾一下。

声卡：用[chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio)项目，直接clone下来，安装zstd依赖之后按官方提示执行。注意deepin25安装之后默认系统分区是不可变的，需要先执行`sudo deepin-immutable-writable enable -d /usr`把usr目录的保护给关掉，不然驱动是装不进去的。

摄像头：需要英特尔的ipu6驱动，我试了一下暂时还无法在debian上安装（fedora是支持的）。

指纹：等Intel更新驱动吧，暂时搞不定。

## 常用软件

国产的OS安装办公软件非常简单，感谢信创，基本所有软件都能直接从商店安装，除了企业微信还是没有之外。列个清单：

* 微信
* qq
* 钉钉/飞书
* 腾讯会议
* atrust/openvpn
* wps
* typora/pandoc/vscode/jetbrain
* 打印机驱动（自带了打印管理器）
* 自带的浏览器，当然一般换成chrome
* 自带了AI，可以直接部署本地模型（当然有网还是用在线的，不然风扇转的老快了）

系统安装完成之后搜狗输入法直接可以用，安装星火商店之后连翻墙软件都能直接下载。

默认就是国内的源，因此不需要换源，可以安装一个chsrc来修改其他应用软件的源。

网易云音乐可以用musicfox这个命令行版本，扫码登录，空格播放，p切换播放模式，上一首[，下一首]。

## 配置

### 终端

年纪大了不太想折腾了，终端直接用自带，shell直接用bash + starship，不装zsh了。

bashrc还是需要额外配置一下，参考：

```
bind 'set show-all-if-ambiguous on'
bind 'TAB:menu-complete'
bind '"\e[Z":menu-complete-backward'

alias ..='cd ..'
alias ...='cd ...'
alias ls='exa'
alias ll='exa -l'

. "$HOME/.cargo/env"

export PATH="$HOME/.jenv/bin:$HOME/.go/bin:$HOME/.local/bin:$PATH"
eval "$(jenv init -)"

eval "$(starship init bash)"
eval "$(zoxide init bash)"
# Set up fzf key bindings and fuzzy completion
eval "$(fzf --bash)"
eval "$(register-python-argcomplete pipx)"

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

```

这里面主要安装了几个必备的软件：

* exa：ls增强版
* fzf：ctrl + r模糊查找
* zoxide：autojump增强版
* cargo：rust
* jenv：管理java版本
* pipx：安装Python bin
* nvm：管理node版本

终端可以配置一下快捷键，类似macos的效果。

ssh还是用tssh比较方便。

### 改键

这次直接用keyd改键，因为源里面有这个软件。

配置文件(/etc/keyd/default.conf)：

```
[ids]

*

[main]

102nd = leftshift

[control]
backspace = delete
a = home
e = end

[alt]
a = C-a
c = C-c
v = C-v
w = C-w
q = C-q
s = C-s

```

这个ChromeBook是欧版的，左边的shift键盘右边还有个键，很容易误触，这里直接将其修改为shift。

然后就是没有delete键，直接将Ctrl+backspace映射成delete。

其他的就是类似macos的按键配置了，我个人习惯在所有电脑上用这套配置。

### 触摸板

Linux下现在也可以配置三指拖动了，主要使用[这个](https://github.com/lmr97/linux-3-finger-drag)项目，注意先要去触摸板把默认的三指功能全关掉。

目前体验下来Linux下可以不再需要鼠标，当然前提是笔记本有压感全域触摸的硬件。

这个Chromebook反而比Windows笔记本有的更多，此外这台笔记本支持S3睡眠，不会有Windows笔记本睡死的问题。

## 体验

目前感觉很好，这台花了2800买的Chromebook的配置其实还可以，cpu差不多是m1的水平，优点是x86, 32G内存+512存储的配置用来开发正合适，还送了压感触摸版和触摸屏（虽然没啥用），唯一不足的是电池续航水平不太行了。

同样是买二手，这个价格（可能要再加一点）可以买m1的16+256，相比之下我还是更推荐m1 air。但是如果想要体验原汁原味的Linux，或者手里已经有其他电脑了，买这个玩玩也挺好，或者买更便宜的廉价chromebook也不错。

---

使用2天后：

有一个问题，待机/休眠之后触摸板概率失灵，需要通过xinput手动重启硬件，可以写一个脚本绑定快捷键之后快速运行。

这个掉驱动/硬件的问题，很久之前就有了，到现在也一直没修复😓
