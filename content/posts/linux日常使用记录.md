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

Deepin20.9的docker安装有问题，k3s也无法正常使用；Deepin 23就更离谱了，我的连安装界面都进不去。

优麒麟版本的linux，系统快捷键不能改，很麻烦。

Debian系还是推荐使用Linux mint Cinamon，或者直接用arch也行，常用软件也比较好装。

## 软件源

除了发行版自带的软件源之外，还有几个流行的安装方式，比如snap、linuxbrew和flathub.

国产的还有星火商店，也可以安装一些常用软件。上面这些都是跨发行版的。

## 常用软件

网易云官方的播放器不能用，建议改为**YesPlayMusic音乐播放器**这个开源的播放器。

微信实际上有原生的版本，可以从deepin论坛下载，不过非deepin的debian系需要额外装一些依赖才能使用。也可以使用星火商店，不过依赖的deb包还是要手动安装（如果不是国产发行版）。

**注意**，原生微信目前（v2.1.9）在LinuxMint下新消息没有提示，这个没办法，可以考虑改用wine版本微信。

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

  font = wezterm.font("FiraCode Nerd Font Mono", {weight="Regular", stretch="Normal", style="Normal"}),

  color_scheme = 'MaterialDark',
}

return config
```

命令行提示工具推荐使用[`starship`](https://github.com/starship/starship)，可以配合zsh使用，也可以直接在bash使用。个人感觉比oh-my-zsh+powerline10k体验更好，而且这个还能配合powershell使用。

全局字体推荐使用[**霞鹜新晰黑**](https://github.com/lxgw/LxgwNeoXiHei)，比较清晰。全局字体不推荐使用楷体，主要是太细了，如果想要用的话，可以用这个[屏幕阅读版](https://github.com/lxgw/LxgwWenKai-Screen)，我的chrome字体和Android字体用的都是这个，感觉还不错。另外字体推荐放在`~/.fonts`里面，这样重装系统不会丢失。刷新字体使用`fc-cache -vf`即可。

IDE的话，我买了正版的jetbrain全家桶，所以直接用`jetbrain toolbox`安装即可，而且默认是装在home目录下，重装系统不会丢失。

剪贴板软件可以用`CopyQ`，快捷键绑定到命令`copyq toggle`即可（不要使用自带的全局快捷键，没用）。

截图软件可以用**火焰截图**，快捷键绑定到命令`flameshot gui`即可，功能很丰富。

办公软件使用wps 2019，这个没啥说的，自带的那个office可以用apt卸载掉。另外xmind也支持Linux，当然你也可以使用wps里面自带的processOn工具。

番茄钟软件，可以用[**wnr**](https://github.com/RoderickQiu/wnr)，同样支持Windows。

梯子可以用`cfw`或者`clash verge`，星火商店里面可以直接下载…

### SSH

wezterm的问题是不支持zmodem，也就是lrzsz的上传下载，可以用`trzsz`来代替。

具体方法是在本地安装[tssh](https://github.com/trzsz/trzsz-ssh/tree/main)，并打开[zmodem支持](https://github.com/trzsz/trzsz-ssh/blob/main/README.cn.md#%E6%94%AF%E6%8C%81-zmodem)，这样就可以正常在服务器使用`rz`/`sz`命令了。

一个参考的`~/.ssh/config`配置如下：

```
Host *
ServerAliveInterval 60
#!! EnableZmodem Yes

Host github.com
User git
Port 22
Hostname github.com
TCPKeepAlive yes
ProxyCommand nc -v -x 127.0.0.1:7890 %h %p

Host ssh.github.com
Hostname ssh.github.com
Port 443
User git
TCPKeepAlive yes

Host prod
HostName zzzz.bastionhost.aliyuncs.com
Port 60022
User zzzz
#!! encPassword zzzzzzzz
PubkeyAcceptedKeyTypes +ssh-rsa
HostKeyAlgorithms +ssh-rsa
```

这里以`#!!`开头的配置都是供`tssh`使用的.

### Rime的配置

主要修改`~/.config/fcitx/rime/default.yaml`文件，注意删除掉`default.custom.yaml`，不然会被那边的覆盖掉：

```yaml
# 要比共享目录的同名文件的 config_version 大才可以生效
config_version: '2024-02-07'


# 方案列表
schema_list:
  # 可以直接删除或注释不需要的方案，对应的 *.schema.yaml 方案文件也可以直接删除
  # 除了 t9，它依赖于 rime_ice，用九宫格别删 rime_ice.schema.yaml
  - schema: rime_ice               # 雾凇拼音（全拼）


# 菜单
menu:
  page_size: 9  # 候选词个数


# 方案选单相关
switcher:
  caption: 「方案选单」
  hotkeys:
    - F4
  save_options:  # 开关记忆（方案中的 switches），从方案选单（而非快捷键）切换时会记住的选项，需要记忆的开关不能设定 reset
    - traditionalization
    - emoji
    - full_shape
  fold_options: false            # 呼出时是否折叠，多方案时建议折叠 true ，一个方案建议展开 false
  abbreviate_options: true      # 折叠时是否缩写选项
  option_list_separator: ' / '  # 折叠时的选项分隔符


# 中西文切换
#
# good_old_caps_lock:
# true   切换大写
# false  切换中英
# macOS 偏好设置的优先级更高，如果勾选【使用大写锁定键切换“ABC”输入法】则始终会切换输入法。
#
# 切换中英：
# 不同的选项表示：打字打到一半时按下了 CapsLock、Shift、Control 后：
# commit_code  上屏原始的编码，然后切换到英文
# commit_text  上屏拼出的词句，然后切换到英文
# clear        清除未上屏内容，然后切换到英文
# inline_ascii 切换到临时英文模式，按回车上屏后回到中文状态
# noop         屏蔽快捷键，不切换中英，但不要屏蔽 CapsLock
ascii_composer:
  good_old_caps_lock: true  # true | false
  switch_key:
    Caps_Lock: clear      # commit_code | commit_text | clear
    Shift_L: commit_code  # commit_code | commit_text | inline_ascii | clear | noop
    Shift_R: noop         # commit_code | commit_text | inline_ascii | clear | noop
    Control_L: noop       # commit_code | commit_text | inline_ascii | clear | noop
    Control_R: noop       # commit_code | commit_text | inline_ascii | clear | noop


###################################################################################


# 下面的 punctuator recognizer key_binder 写了一些所有方案通用的配置项。
# 写在 default.yaml 里，方便多个方案引用，就是不用每个方案都写一遍了。


# 标点符号
# 设置为一个映射，就自动上屏；设置为多个映射，如 '/' : [ '/', ÷ ] 则进行复选。
#   full_shape: 全角没改，使用预设值
#   half_shape: 标点符号全部直接上屏，和 macOS 自带输入法的区别是
#              '|' 是半角的，
#              '~' 是半角的，
#              '`'（反引号）没有改成 '·'（间隔号）。
punctuator:
  full_shape:
    ' ' : { commit: '　' }
    ',' : { commit: ， }
    '.' : { commit: 。 }
    '<' : [ 《, 〈, «, ‹ ]
    '>' : [ 》, 〉, », › ]
    '/' : [ ／, ÷ ]
    '?' : { commit: ？ }
    ';' : { commit: ； }
    ':' : { commit: ： }
    '''' : { pair: [ '‘', '’' ] }
    '"' : { pair: [ '“', '”' ] }
    '\' : [ 、, ＼ ]
    '|' : [ ·, ｜, '§', '¦' ]
    '`' : ｀
    '~' : ～
    '!' : { commit: ！ }
    '@' : [ ＠, ☯ ]
    '#' : [ ＃, ⌘ ]
    '%' : [ ％, '°', '℃' ]
    '$' : [ ￥, '$', '€', '£', '¥', '¢', '¤' ]
    '^' : { commit: …… }
    '&' : ＆
    '*' : [ ＊, ·, ・, ×, ※, ❂ ]
    '(' : （
    ')' : ）
    '-' : －
    '_' : ——
    '+' : ＋
    '=' : ＝
    '[' : [ 「, 【, 〔, ［ ]
    ']' : [ 」, 】, 〕, ］ ]
    '{' : [ 『, 〖, ｛ ]
    '}' : [ 』, 〗, ｝ ]
  half_shape:
    ',' : '，'
    '.' : '。'
    '<' : '《'
    '>' : '》'
    '/' : '/'
    '?' : '？'
    ';' : '；'
    ':' : '：'
    '''' : { pair: [ '‘', '’' ] }
    '"' : { pair: [ '“', '”' ] }
    '\' : '、'
    '|' : '|'
    '`' : '`'
    '~' : '~'
    '!' : '！'
    '@' : '@'
    '#' : '#'
    '%' : '%'
    '$' : '¥'
    '^' : '……'
    '&' : '&'
    '*' : '*'
    '(' : '（'
    ')' : '）'
    '-' : '-'
    '_' : ——
    '+' : '+'
    '=' : '='
    '[' : '【'
    ']' : '】'
    '{' : '「'
    '}' : '」'


# 处理符合特定规则的输入码，如网址、反查
# 此处配置所有方案通用的；各方案中另设专有的，比如全拼的拼字用 u，双拼的拼字用 L
recognizer:
  patterns:
    email: "^[A-Za-z][-_.0-9A-Za-z]*@.*$"   # 自带的，email 正则
    # uppercase: "[A-Z][-_+.'0-9A-Za-z]*$"  # 自带的，大写字母开头后，可以输入[-_+.'0-9A-Za-z]这些字符（和雾凇有些冲突，关闭了）
    url: "^(www[.]|https?:|ftp[.:]|mailto:|file:).*$|^[a-z]+[.].+$"  # 自带的，URL 正则
    # 一些不直接上屏的配置示例：
    # url_2: "^[A-Za-z]+[.].*"     # 句号不上屏，支持 google.com abc.txt 等网址或文件名，使用句号翻页时需要注释掉
    # colon: "^[A-Za-z]+:.*"       # 冒号不上屏
    # underscore: "^[A-Za-z]+_.*"  # 下划线不上屏


# 快捷键
key_binder:
  # Lua 配置: 以词定字（上屏当前词句的第一个或最后一个字），和中括号翻页有冲突
  select_first_character: "bracketleft"  # 左中括号 [
  select_last_character: "bracketright"  # 右中括号 ]

  bindings:
    # 翻页 , .
    - { when: paging, accept: comma, send: Page_Up }
    - { when: has_menu, accept: period, send: Page_Down }

    # optimized_mode_switch:
    # - { when: always, accept: Control+Shift+space, select: .next }
    # - { when: always, accept: Shift+space, toggle: ascii_mode }
    # - { when: always, accept: Control+comma, toggle: full_shape }
    # - { when: always, accept: Control+period, toggle: ascii_punct }
    # - { when: always, accept: Control+slash, toggle: traditionalization }

    # 将小键盘 0~9 . 映射到主键盘，数字金额大写的 Lua 如 R1234.5678 可使用小键盘输入
    - {accept: KP_0, send: 0, when: composing}
    - {accept: KP_1, send: 1, when: composing}
    - {accept: KP_2, send: 2, when: composing}
    - {accept: KP_3, send: 3, when: composing}
    - {accept: KP_4, send: 4, when: composing}
    - {accept: KP_5, send: 5, when: composing}
    - {accept: KP_6, send: 6, when: composing}
    - {accept: KP_7, send: 7, when: composing}
    - {accept: KP_8, send: 8, when: composing}
    - {accept: KP_9, send: 9, when: composing}
    - {accept: KP_Decimal, send: period, when: composing}
```

大部分配置都可以删掉，只保留必要的快捷键和映射。个人习惯使用逗号和句号翻页，所以仅保留了这个。

右键点击托盘的输入法图标，**重新启动**，让配置文件生效。如果想要修改字体，使用classic皮肤时，直接在界面上修改即可；其他皮肤需要修改配置文件才行。

> 我在使用输入法的时候，经常会遇到卡死的问题，具体表现就是输入框卡住了，键盘输入没有反应，此时只能等待，或者杀掉窗口。
>
> 具体原因还未知晓，fcitx已经很久没有更新，推测可能有bug.

## 键盘映射

我是一个改键党：必须使用Emacs的一些快捷键， 改键的开源软件其实很多，我先后尝试了几个，其中keyd的设置最简单，但是不知道为啥我设置之后没有生效…

最后能用的是`xremap`这个rust写的小软件，使用cargo安装即可。配置文件如下：

```yaml
keymap:
  - name: Emacs
    application:
      not: [Emacs, wezterm-gui]
    remap:
      C-a: { with_mark: home }
      C-e: { with_mark: end }
      M-a: { with_mark: C-a }
      M-c: { with_mark: C-c }
      M-v: { with_mark: C-v }
```

我常用的只有这些，其他的都被我删掉了。不知道为什么，在wezterm中有时候还是无法使用ctrl+a，似乎有什么冲突。

在root的cronjob里加入：

```bash
 @reboot /home/tryao/.cargo/bin/xremap /home/tryao/.xremap.yml
```

之后即可开机自启动了。

实际体验很好，rust写的小软件性能很强，使用中基本没有延迟。

上面的映射有个问题：在xterm中无法正常使用`home`, `end`，需要加一个配置(~/.Xresources):

```
XTerm*termName: xterm-256color
URxvt*termName: rxvt-unicode
```

这样才行。
