---
title: Windows+wsl2后端开发环境搭建
description:
toc: true
authors: ["tryao"]
tags: ["wsl"]
categories: ["瞎折腾"]
series: []
date: 2022-03-04T20:54:01+08:00
lastmod: 2022-03-04T20:54:01+08:00
featuredVideo:
featuredImage:
draft: false
---

2023/11/16 Update: wsl2 2.0通过镜像网络解决了所有网络问题，已经不用折腾了。

2023/2/2 Update: wsl已经解决了systemd和网络问题，现在已经基本无障碍使用，移除了大部分无用的配置步骤。

就我个人而言，目前感觉最理想的后端开发环境还是Intel CPU的MacOS，基本所有常用的后端依赖都可以用homebrew安装，GUI和命令行的结合也是最方便的。不过Windows从10代之后添加了WSL/WSL2，将Linux命令行和Windows开发环境完美的结合起来，目前来说可用性还算不错了。

## 准备工作
### 网络准备

由于下面会大量从GitHub下载软件，所以请自备工具保证能够顺利下载。

### windows命令行工具

win10之前，系统的命令行工具分裂为cmd和pwsh两种，界面都难看的很。所以首先安装[Windows Terminal](https://github.com/microsoft/terminal/releases)（以下简称wt），整一个好看一点的终端用。对于天天用命令行的人来说，这个比啥都重要。如果是win11，系统自带了wt，但是版本较老，建议更新到最新版。

然后安装最新的powershell，下载地址在[这里](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2)，目前最新版是powershell7.  pwsh7其实是开源的shell，在linux/macos上都能用，不过这玩意最大的问题是启动速度实在太慢，而且语法设计和bash差别太大。bash是把一切都看作文本，pwsh是把一切都看作对象……都是辣鸡设计，还是python好使。

安装的时候请注意选中添加环境变量，`Open here`那个那个建议不要选中，wt自带有这个功能。装完之后pwsh7会自动注册到wt里。

### 安装包管理器

linux下有apt/yum/pacman之类的包管理工具，mac也有homebrew/macport，windows下实际上也有对应的包管理工具，如scoop/Chocolatey或者官方的winget. 这里以scoop为例（choco不需要翻墙，但是源里面包要少一些）：

打开wt，输入`Set-ExecutionPolicy RemoteSigned -scope CurrentUser`打开安装权限。然后输入

```powershell
iwr -useb get.scoop.sh | iex
```

安装即可。

然后替换掉scoop的源，官方源太慢了：

```powershell
scoop bucket rm main
scoop bucket add main https://mirror.nju.edu.cn/git/scoop-extras.git/ 
scoop bucket add extras https://mirror.nju.edu.cn/git/scoop-extras.git/ 
scoop update
```

使用aria2开启16线程加速下载：

```
scoop install aria2
scoop config aria2-max-connection-per-server 16
scoop config aria2-split 16
scoop config aria2-min-split-size 1M
```

常用的软件可以使用scoop直接安装，如：

```powershell
scoop install git 7zip aria2 python3 typora vlc sumatrapdf
```

注意：类似vscode这种自带更新功能的软件，不建议使用scoop安装。

国内有人把其他bucket综合成一个[bucket](https://gitee.com/kkzzhizhou/scoop-apps)，也可以根据自己需求使用。默认会安装到C盘，空间紧张的在安装之前可以修改一下：

```powershell
[environment]::setEnvironmentVariable('SCOOP','D:\scoop','User')
```

### 安装字体

类似美化zsh的思路，先安装能显示复杂Unicode符号的字体，到[这里](https://github.com/romkatv/dotfiles-public/tree/master/.local/share/fonts/NerdFonts)下载所有的字体并安装到Windows.

然后在window terminal里面设置字体，位置见下图 ：

![image-20220304215714707](https://s2.loli.net/2022/03/04/fdsXjivpm18NEoJ.png)

设为刚安装的字体就行。

### 配置pwsh

类似zsh安装`oh-my-zsh`，pwsh也有`oh-my-posh`用来辅助配置：

```powershell
Install-Module oh-my-posh -Scope CurrentUser
```

有选择的话选全部同意(A)。

然后`Update-Module oh-my-posh`更新一下。

然后安装git插件和readLine插件：

```powershell
Install-Module posh-git -Scope CurrentUser
Update-Module posh-git
Install-Module PSReadLine -Scope CurrentUser
```

然后选命令行风格主题，输入`Get-PoshThemes`，界面上会输出所有风格的主题，找一个自己喜欢的，把名字复制下来。如果你是zsh的`powershell10k`主题爱好者，pwsh也有个[类似的](https://github.com/Kudostoy0u/pwsh10k)供你选择。

输入

```powershell
notepad $profile
```

会打开powershell的配置文件，输入：

```powershell
# ========================= Import Modules =======================
Import-Module posh-git
Import-Module oh-my-posh
Import-Module PSReadLine

Set-PoshPrompt -Theme avit
# ========================= PSReadLine =======================
# 使用历史命令记录来应用自动补全
Set-PSReadLineOption -PredictionSource History
# bash风格快捷键
Set-PSReadLineOption -EditMode Emacs

# 每次回溯输入历史，光标定位于输入内容末尾
Set-PSReadLineOption -HistorySearchCursorMovesToEnd

# 设置 Tab 为补全的快捷键
Set-PSReadLineKeyHandler -Key "Tab" -Function MenuComplete

# 设置向上键为后向搜索历史记录
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward

# 设置向下键为前向搜索历史纪录
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
```

配置完成后保存关闭，重启pwsh即可生效。

在oh-my-zsh中的z，可以在powershell中安装[ZLocation](https://github.com/vors/ZLocation)来完成类似功能。

## 安装wsl2

参考[WSL 安装](https://learn.microsoft.com/zh-cn/windows/wsl/install)，新版wsl安装步骤非常简单，比之前手动安装容易的多。

安装完成后可以运行`wsl --version`，结果中WSL版本应该>2.0了。

### 配置linux

打开Windows Terminal，安装的linux发行版入口应该会自动加到下拉选单里，选中后进入。

至于怎么配置Linux我就不写了，根据个人习惯来吧。几个点：

* 先用`sudo visudo`取消sudo必须输入密码，不然能烦死你；
* 用`zsh`替换掉bash，可以使用[`oh-my-zsh`](https://ohmyz.sh/)或者[`zi`](https://z-shell.pages.dev/)之类的进行配置管理；
* 安装`lsd`, `fd`, `ripgrep`, `fzf`, `trash-cli`,  `z.lua`等工具，做好`alias`；
* 使用`screen`或者`tmux`进行进程管理；
* 配置好vim等；

### 配置wsl

激活systemd，先确定发行版里面已经安装了`systemd`，然后编辑`/etc/wsl.conf`添加：

```
[boot]
systemd=true
```

然后重启wsl即可，建议等下面操作结束之后再一起重启。

配置网络，在windows的home目录下添加`.wslconfig`，里面内容是：

```
[experimental]
networkingMode=mirrored
dnsTunneling=true
firewall=true
autoProxy=true
```

如果你是在windows中安装docker desktop，那么直接用就可以。如果是在wsl里面安装了docker，需要配置`/etc/docker/daemon.json`，在里面加入：`"iptables":false`，否则docker可能无法正常使用。

## 注意事项

1. wsl2和windows之间传输文件io性能很差；
2. idea支持ssh远程开发，但目前还是beta，不好用；vscode还是比较流畅的，习惯ssh开发的推荐使用该方式；
3. 如果是本地开发，优先建议在windows下直接使用IDE开发，不要使用wslg，因为很难用；
4. 类似java/python/golang这种高级语言，直接在windows下写代码调试就行；
5. 如果是C++开发，推荐使用CLion+WSL工具链。现在CLion已经支持Makefile工程，所以linux下所有开发都已经无碍；2023版本的CLion甚至支持vcpkg集成，有一说一比rust也差不多了；
7. 建议wsl直接用root账户，不然会经常遇到各种权限问题，比较迷惑；
8. linux的PATH会自动继承windows的path，不过Linux系统里同名的文件优先级更高；所以像git这种软件到底装Windows还是装Linux要自己想清楚；全部在Linux下也可以，都装不是不行…就是要配置两遍；
9. WSL的命令行可以直接调用windows PATH下的exe文件，如`code`，不过非`/mnt`路径下可能无法正常使用；
10. 在powershell里面可以用`start`命令打开文件，会自动调用关联的打开方式。类似macos的`open`命令，在wsl里面通过`alias`也可以调用（参考最后附录）；
11. 在idea里面讲终端设置为：`"cmd.exe" /k "wsl.exe"`，就可以使用bash做终端了；当然也可以直接用bash的路径；
12. 如果原来是macos用户，可以在win下使用quicklook实现空格预览，utools实现spotlight（或者直接用powertools里面那个简化的run工具也行），并使用powertoys做快捷键映射：个人比较怀恋ctrl+a/ctrl+e映射到home和end的功能，然后把alt+a/c/v/s/w/r都映射成ctrl，alt+q映射成alt+f4；

## 附：常用alias

```bash
alias ls="lsd"
alias rm="trash"
alias py="python3"
alias find="fd"
alias tailf="tail -F"
alias start="cmd.exe /C start"
```

