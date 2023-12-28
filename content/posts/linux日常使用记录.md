---
title: linux日常使用记录
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

由于公司开始强制使用Linux桌面系统，记录一下使用中遇到的问题。

## 发行版选择

本来先尝试了Ubuntu 22.04和KDE Neon做为开发环境，但是体验都不太好：

KDE Neon与日常使用的软件兼容性很差，主要是大部分软件都是GTK搞的；

原生Ubuntu的蓝牙耳机连接经常断连；

Deepin20.9的docker安装有问题，k3s也无法正常使用；Deepin 23就更离谱了，连安装界面都进不去。

优麒麟版本的linux，系统快捷键不能改，很麻烦。

Debian系还是推荐使用Linux mint Cinamon，或者直接用arch也行，常用软件也比较好装。

## 常用软件

网易云官方的播放器不能用，建议改为**YesPlayMusic音乐播放器**这个开源的播放器。

微信实际上有原生的版本，可以从deepin论坛下载，不过非deepin的debian系需要额外装一些依赖才能使用。也可以使用星火商店，不过依赖的deb包还是要手动安装（如果不是国产发行版）。**注意**，原生微信目前（v2.1.9）在LinuxMint下新消息没有提示，这个没办法，建议打开手机的消息提示配合使用：（

输入法**只推荐**fcitx，ibus各种延迟卡顿，fcitx5和钉钉的兼容性很差。用的话可以考虑搜狗输入法，或者rime，我目前用的是后者。rime推荐使用[这个](https://github.com/Mark24Code/rime-auto-deploy)脚本进行安装，还是很方便的。

终端推荐`wezterm`，可以跨平台使用，配置文件使用lua，比较方便(~/.config/wezterm/wezterm.lua)：

```lua
local wezterm = require 'wezterm'

local act = wezterm.action
local mykeys = {}

-- 重新定义Tab切换快捷键
-- 描述：通过alt+1/2/3/../8进行切换Tab标签
for i = 1, 8 do
  table.insert(mykeys, {
    key = tostring(i),
    mods = 'ALT',
    action = act.ActivateTab(i - 1),
  })
end

-- 重新定义左右分割
-- 描述：通过ctrl+shift+s
table.insert(mykeys, {
    key = 's',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
})

-- 重新定义上下分割
-- 描述：通过ctrl+shift+d
table.insert(mykeys, {
    key = 'd',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
})

table.insert(mykeys, {
    key = 'F11',
    mods = 'CTRL',
    action = wezterm.action.ToggleFullScreen,
})

-- 重新定义分屏窗口切换快捷键
-- 描述：通过ctrl+shift+hjkl
table.insert(mykeys,  {
    key = 'h', --左侧的分屏窗口
    mods = 'CTRL|SHIFT',
    action = act.ActivatePaneDirection 'Left',
})

table.insert(mykeys, {
    key = 'l', -- 右侧的分屏窗口
    mods = 'CTRL|SHIFT',
    action = act.ActivatePaneDirection 'Right',
})

table.insert(mykeys, {
    key = 'k', -- 上侧的分屏窗口
    mods = 'CTRL|SHIFT',
    action = act.ActivatePaneDirection 'Up',
})

table.insert(mykeys, {
    key = 'j', -- 下侧的分屏窗口
    mods = 'CTRL|SHIFT',
    action = act.ActivatePaneDirection 'Down',
})

local config = {
  check_for_updates = false,

  keys = mykeys,

  window_decorations = "INTEGRATED_BUTTONS|RESIZE",

  font = wezterm.font 'FiraCode Nerd Font',

  color_scheme = 'MaterialDark',
}

return config
```

命令行提示工具推荐使用[`starship`](https://github.com/starship/starship)，可以配合zsh使用，也可以直接在bash使用。个人感觉比zsh+powerline10k体验更好，而且这个还能配合powershell使用。

全局字体推荐使用[**霞鹜新晰黑**](https://github.com/lxgw/LxgwNeoXiHei)，比较清晰。全局字体不推荐使用楷体，主要是太细了，如果想要用的话，可以用这个[屏幕阅读版](https://github.com/lxgw/LxgwWenKai-Screen)，我的chrome字体和Android字体用的都是这个，感觉还不错。另外字体推荐放在`~/.fonts`里面，这样重装系统不会丢失。刷新字体使用`fc-cache -vf`即可。

IDE的话，我买了正版的jetbrain全家桶，所以直接用`jetbrain toolbox`安装即可，而且默认是装在home目录下，重装系统不会丢失。

剪贴板软件可以用`CopyQ`，快捷键绑定到命令`copyq toggle`即可（不要使用自带的全局快捷键，没用）。

截图软件可以用**火焰截图**，快捷键绑定到命令`flameshot gui`即可，功能很丰富。

办公软件使用wps 2019，这个没啥说的，自带的那个office可以用apt卸载掉。另外xmind也支持Linux，当然你也可以使用wps里面自带的processOn工具。

番茄钟软件，可以用[**wnr**](https://github.com/RoderickQiu/wnr)，同样支持Windows。

梯子可以用`cfw`或者`clash verge`，星火商店里面可以直接下载…

## 键盘映射

我是一个改键党：必须使用Emacs的一些快捷键， 改键的开源软件其实很多，我先后尝试了几个，其中keyd的设置最简单，但是不知道为啥我设置之后没有生效…

最后能用的是`xremap`这个rust写的小软件，使用cargo安装即可。配置文件如下：

```yaml
keymap:
  - name: Emacs
    application:
      not: [Emacs]
    remap:
      C-a: { with_mark: home }
      C-e: { with_mark: end }
      M-a: { with_mark: C-a }
      M-c: { with_mark: C-c }
      M-v: { with_mark: C-v }
```

我常用的只有这些，其他的都被我删掉了。

在root的cronjob里加入：

```bash
 @reboot /home/tryao/.cargo/bin/xremap /home/tryao/.xremap.yml
```

之后即可开机自启动了。

实际体验很好，rust写的小软件性能很强，使用中基本没有延迟。
