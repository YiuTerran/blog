---
title: linux日常使用记录
description:
toc: true
authors: ["tryao"]
tags: ["linux"]
categories: []
collections: []
date: 2023-11-24T10:51:31+08:00
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

国产的还有星火商店，也可以安装一些常用软件，这些都是跨发行版的。

个人还是推荐星火商店+apt，其他几个也可以用，但是需要配置国内软件源，不然下载速度感人。

## 字体

全局字体推荐使用[**霞鹜新晰黑屏幕阅读版**](https://github.com/lxgw/LxgwNeoXiHei-Screen)，比较清晰。全局字体不推荐使用楷体，主要是太细了，如果想要用的话，可以用这个[屏幕阅读版](https://github.com/lxgw/LxgwWenKai-Screen)，我的chrome字体和Android字体用的都是这个，感觉还不错。另外字体推荐放在`~/.fonts`里面，这样重装系统不会丢失。刷新字体使用`fc-cache -vf`即可，查看字体名称可以用`fc-list`。

## WezTerm配置

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

  font = wezterm.font_with_fallback {
      "FiraCode Nerd Font Mono",
      "LXGW WenKai GB Screen",
  },

  color_scheme = 'MaterialDark',
}

return config
```



## SSH参考配置

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

## 输入法

输入法框架**只推荐**fcitx，ibus各种延迟卡顿，fcitx5和钉钉的兼容性很差。另外如果用的机械硬盘，换成ssd之后输入法卡顿会有很大改善。

我目前用的是rime输入法，推荐使用[这个](https://github.com/Mark24Code/rime-auto-deploy)脚本进行安装，还是很方便的。个性化配置可以修改`~/.config/fcitx/rime/default.yaml`文件，可以删除掉`default.custom.yaml`，不然会被那边的覆盖掉。

参考配置如下：

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

大部分配置都可以删掉，只保留必要的快捷键和映射。个人习惯使用逗号和句号翻页，所以仅保留了这个。另外，自动纠错功能建议少用，会导致输入法卡顿，我是直接删除掉自动纠错配置了的。

`rime_ice.schema.yml`保留如下配置：

```yaml
# 方案说明
schema:
  schema_id: rime_ice
  name: 雾凇拼音
  version: "2023-10-22"
  author:
    - Dvel
  description: |
    雾凇拼音
    https://github.com/iDvel/rime-ice
  dependencies:
    - melt_eng  # 英文输入，作为次翻译器挂载到拼音方案
    - liangfen  # 两分拼字，作为反查挂载到拼音方案


# 开关
# 鼠须管 0.16 后，用快捷键切换时的提示文字由 states 定义
# states: 方案选单显示的名称。可以注释掉，仍可以通过快捷键切换。
# reset: 默认状态。 注释掉后，切换窗口时不会重置到默认状态。
switches:
  - name: ascii_mode
    states: [ 中, Ａ ]
    reset: 0
  - name: ascii_punct # 中英标点
    states: [ ¥, $ ]
    reset: 0
  - name: traditionalization
    states: [ 简, 繁 ]
    reset: 0
  - name: emoji
    states: [ 💀, 😄 ]
    reset: 1
  - name: full_shape
    states: [ 半角, 全角 ]
    reset: 0


# 输入引擎
engine:
  processors:
    - lua_processor@select_character      # 以词定字
    - ascii_composer
    - recognizer
    - key_binder
    - speller
    - punctuator
    - selector
    - navigator
    - express_editor
  segmentors:
    - ascii_segmentor
    - matcher
    - abc_segmentor
    - punct_segmentor
    - fallback_segmentor
  translators:
    - punct_translator
    - script_translator
    - lua_translator@date_translator      # 时间、日期、星期
    - table_translator@custom_phrase      # 自定义短语 custom_phrase.txt
    - table_translator@melt_eng           # 英文输入
    - reverse_lookup_translator@liangfen  # 反查，两分拼字
    - lua_translator@unicode              # Unicode
    - lua_translator@number_translator    # 数字、金额大写
  filters:
    - lua_filter@corrector                # 错音错字提示
    - simplifier@emoji                    # Emoji
    - simplifier@traditionalize           # 简繁切换
    - lua_filter@v_filter                 # v 模式 symbols 优先（否则是英文优先）
    - lua_filter@autocap_filter           # 英文自动大写
    - lua_filter@reduce_english_filter    # 降低部分英语单词在候选项的位置
    - uniquifier                          # 去重


# Lua 配置: 日期、时间、星期、ISO 8601、时间戳的触发关键字
date_translator:
  date: rq       # 日期： 2022-11-29
  time: sj       # 时间： 18:13
  week: xq       # 星期： 星期二
  datetime: dt   # ISO 8601： 2022-11-29T18:13:11+08:00
  timestamp: ts  # 时间戳： 1669716794


# Lua 配置: 降低部分英语单词在候选项的位置。
# 详细介绍 https://dvel.me/posts/make-rime-en-better/#短单词置顶的问题
# 正常情况： 输入 rug 得到 「1.rug 2.如果 …… 」
# 降低之后： 输入 rug 得到 「1.如果 2.rug …… 」
# 几种模式：
# all     降低所有 3~4 位长度、前 2~3 位是完整拼音、最后一位是声母的单词
# none    不降低任何单词，相当于没有启用这个 Lua
# custom  自定义，只降低 words 里的
# （匹配的是编码，不是单词）
reduce_english_filter:
  mode: custom  # all | none | custom
  idx: 2        # 降低到第 idx 个位置
  # 自定义的单词列表，示例列表没有降低部分常用单词，如 and cat mail Mac but bad shit ……
  words: [aid, ann,
  bail, bait, bam, band, bans, bat, bay, bend, bent, benz, bib, bid, bien, biz, boc, bop, bos, bud, buf,
  cab, cad, cain, cam, cans, cap, cas, cef, chad, chan, chap, chef, cher, chew, chic, chin, chip, chit, coup, cum, cunt, cur,
  dab, dag, dal, dam, dent, dew, dial, diet, dim, din, dip, dis, dit, doug, dub, dug, dunn,
  fab, fax, fob, fog, foul, fur,
  gag, gail, gain, gal, gam, gaol, ged, gel, ger, guam, gus, gut,
  hail, ham, hank, hans, hat, hay, heil, heir, hem, hep, hud, hum, hung, hunk, hut,
  jim, jug,
  kat,
  lab, lad, lag, laid, lam, laos, lap, lat, lax, lay, led, leg, lex, liam, lib, lid, lied, lien, lies, linn, lip, lit, liz, lob, lug, lund, lung, lux,
  mag, maid, mann, mar, mat, med, mel, mend, mens, ment, mil, mins, mint, mob, moc, mod, mop, mos, mot, mud, mug, mum, nail,
  nap, nat, nay, neil, nib, nip, noun, nous, nun, nut,
  pac, paid, pail, pain, pair, pak, pal, pam, pans, pant, pap, par, pat, paw, pax, pens, pic, pier, pies, pins, pint, pit, pix, pod, pop, pos, pot, pour, pow, pub,
  rand, rant, rent, rep, res, ret, rex, rib, rid, rig, rim, rub, rug, rum, runs,
  sac, sail, sal, sam, sans, sap, saw, sax, sew, sham, shaw, shin, sig, sin, sip, sis, suit, sung, suns, sup, sur, sus,
  tad, tail, taj, tar, tax, tec, ted, tel, ter, tex, tic, tied, tier, ties, tim, tin, tit, tour, tout, tum,
  wag, wand, womens, wap, wax, weir, won,
  yan, yen]


# 主翻译器，拼音
translator:
  dictionary: rime_ice           # 挂载词库 rime_ice.dict.yaml
  spelling_hints: 8              # corrector.lua ：为了让错音错字提示的 Lua 同时适配全拼双拼，将拼音显示在 comment 中
  always_show_comments: true     # corrector.lua ：Rime 默认在 preedit 等于 comment 时取消显示 comment，这里强制一直显示，供 corrector.lua 做判断用。
  initial_quality: 1.2           # 拼音的权重应该比英文大
  preedit_format:                # preedit_format 影响到输入框的显示和“Shift+回车”上屏的字符
    - xform/([jqxy])v/$1u/       # 显示为 ju qu xu yu
    # - xform/([nl])v/$1ü/       # 显示为 nü lü
    # - xform/([nl])ue/$1üe/     # 显示为 nüe lüe
    - xform/([nl])v/$1v/         # 显示为 nv lv
    - xform/([nl])ue/$1ve/       # 显示为 nve lve


# 次翻译器，英文
melt_eng:
  dictionary: melt_eng     # 挂载词库 melt_eng.dict.yaml
  enable_sentence: false   # 禁止造句
  enable_user_dict: false  # 禁用用户词典
  initial_quality: 1.1     # 初始权重
  comment_format:          # 自定义提示码
    - xform/.*//           # 清空提示码


# 反查：两分（拼字）
liangfen:
  dictionary: liangfen     # 挂载两分词典 liangfen.dict.yaml
  prefix: "u"              # 以 u 开头来反查
  enable_completion: true  # 补全提示
  # tips: 〔两分〕          # 反查时显示的文字，建议注释掉，否则很多 u 开头的英文单词也会显示这个


# 自定义短语：custom_phrase.txt
custom_phrase:
  dictionary: ""
  user_dict: custom_phrase
  db_class: stabledb
  enable_completion: false # 补全提示
  enable_sentence: false   # 禁止造句
  initial_quality: 99      # custom_phrase 的权重应该比 pinyin 和 melt_eng 大


# Emoji
emoji:
  opencc_config: emoji.json
  option_name: emoji


# 简繁切换
traditionalize:
  option_name: traditionalization
  opencc_config: s2t.json             # s2t.json | s2hk.json | s2tw.json | s2twp.json
  tips: none                          # 转换提示: all 都显示 | char 仅单字显示 | none 不显示。
  excluded_types: [ reverse_lookup ]  # 不转换反查（两分拼字）的内容


# 标点符号
# punctuator 下面有三个子项：
#   full_shape 全角标点映射
#   half_shape 半角标点映射
#   symbols    Rime 的预设配置是以 '/' 前缀开头输出一系列字符，自定义的 symbols_v.yaml 修改成了 'v' 开头。
punctuator:
  full_shape:
    __include: default:/punctuator/full_shape  # 从 default.yaml 导入配置
  half_shape:
    __include: default:/punctuator/half_shape  # 从 default.yaml 导入配置
  symbols:
    __include: symbols_v:/symbols              # 从 symbols_v.yaml 导入配置


# 处理符合特定规则的输入码，如网址、反查
recognizer:
  import_preset: default  # 从 default.yaml 继承通用的
  patterns:  # 再增加方案专有的：
    punct: "^v([0-9]|10|[A-Za-z]+)$"  # 响应 symbols_v.yaml 的 symbols，用 'v' 替换 '/'
    reverse_lookup: "^u[a-z]+$"       # 响应两分拼字的反查
    unicode: "^U[a-f0-9]+"            # 响应 Unicode
    number: "^R[0-9]+[.]?[0-9]*"      # 响应 number_translator


# 从 default 继承快捷键
key_binder:
  import_preset: default # 从 default.yaml 继承通用的


# 拼写设定
speller:
  # 如果不想让什么标点直接上屏，可以加在 alphabet，或者编辑标点符号为两个及以上的映射
  alphabet: zyxwvutsrqponmlkjihgfedcbaZYXWVUTSRQPONMLKJIHGFEDCBA
  delimiter: " '"  # 第一位<空格>是拼音之间的分隔符；第二位<'>表示可以手动输入单引号来分割拼音。
  algebra:
    ### 超级简拼
    - erase/^hm$/ # 响应超级简拼，取消「噷 hm」的独占
    - erase/^m$/  # 响应超级简拼，取消「呣 m」的独占
    - erase/^n$/  # 响应超级简拼，取消「嗯 n」的独占
    - erase/^ng$/ # 响应超级简拼，取消「嗯 ng」的独占
    - abbrev/^([a-z]).+$/$1/   # 超级简拼
    - abbrev/^([zcs]h).+$/$1/  # 超级简拼中，zh ch sh 视为整体（ch'sh → 城市），而不是像这样分开（c'h's'h → 吃好睡好）。

    ### v u 转换，增加对词库中「nue/nve」「qu/qv」等不同注音的支持
    - derive/^([nl])ue$/$1ve/
    - derive/^([nl])ve$/$1ue/
    - derive/^([jqxy])u/$1v/
    - derive/^([jqxy])v/$1u/
```

对应的custom文件也建议直接删除，其他配置文件不需要修改。

右键点击托盘的输入法图标，**重新启动**，让配置文件生效。

如果想要修改字体，使用classic皮肤时，直接在界面上修改即可；其他皮肤需要修改配置文件才行。我个人反正是用的classic皮肤，比较简单。

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

## 其他

网易云官方的播放器不能用，建议改为**YesPlayMusic音乐播放器**这个开源的播放器。

~~微信实际上有原生的版本，可以从deepin论坛下载，不过非deepin的debian系需要额外装一些依赖才能使用。也可以使用星火商店，不过依赖的deb包还是要手动安装（如果不是国产发行版）。~~

~~**注意**，原生微信目前（v2.1.9）在LinuxMint下新消息没有提示，这个没办法，可以考虑改用wine版本微信。~~

2024.03更新：微信重构了原生的版本，现在已经可以正常使用了，星火商店可以下载。

命令行提示工具推荐使用[`starship`](https://github.com/starship/starship)，可以配合zsh使用，也可以直接在bash使用。个人感觉比oh-my-zsh+powerline10k体验更好，而且这个还能配合powershell使用。

IDE的话，我买了正版的jetbrain全家桶，所以直接用`jetbrain toolbox`安装即可，而且默认是装在home目录下，重装系统不会丢失。vscode也是能正常使用的。

剪贴板软件可以用`CopyQ`，快捷键绑定到命令`copyq toggle`即可（不要使用自带的全局快捷键，没用）。

截图软件可以用**火焰截图**，快捷键绑定到命令`flameshot gui`即可，功能很丰富。

办公软件使用wps 2019，这个没啥说的，自带的那个office可以用apt卸载掉。另外xmind也支持Linux，当然你也可以使用wps里面自带的processOn工具。不过wps2019很久没更新了，自带的PDF浏览器不支持高亮标注，也是很蛋疼的。

番茄钟软件，可以用[**wnr**](https://github.com/RoderickQiu/wnr)，同样支持Windows。

梯子可以用`cfw`或者`clash verge`，星火商店里面可以直接下载…
