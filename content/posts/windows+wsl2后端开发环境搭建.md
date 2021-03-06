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

就我个人而言，目前感觉最理想的后端开发环境还是Intel CPU的MacOS，基本所有常用的后端依赖都可以用homebrew安装，GUI和命令行的结合也是最方便的。不过Windows从10代之后添加了WSL/WSL2，将Linux命令行和Windows开发环境（不那么）完美的结合起来，目前来说可用性还算不错了。
## 准备工作
### 网络准备

由于下面会大量从GitHub下载软件，所以请自备工具保证能够顺利下载。

### windows命令行工具

win10之前，系统的命令行工具分裂为cmd和pwsh两种，界面都难看的很。所以首先安装[Windows Terminal](https://github.com/microsoft/terminal/releases)（以下简称wt），整一个好看一点的终端用。对于天天用命令行的人来说，这个比啥都重要。如果是win11，系统自带了wt，但是版本较老，建议更新到最新版。

然后安装最新的powershell，下载地址在[这里](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2)，目前最新版是powershell7.  pwsh7其实是开源的shell，在linux/macos上都能用，不过这玩意最大的问题是启动速度实在太慢，而且语法设计和bash差别太大。bash是把一切都看作文本，pwsh是把一切都看作对象……都是辣鸡设计，还是python好使。

安装的时候请注意选中添加环境变量，`Open here`那个那个建议不要选中，wt自带有这个功能。装完之后pwsh7会自动注册到wt里。

### 安装包管理器

linux下有apt/yum/pacman之类的包管理工具，mac也有homebrew/macport，windows下实际上也有对应的包管理工具，如scoop/Chocolatey或者官方的winget. 这里以scoop为例：

打开wt，输入`Set-ExecutionPolicy RemoteSigned -scope CurrentUser`打开安装权限。然后输入

```powershell
iwr -useb get.scoop.sh | iex
```

安装即可。如果网络不通，也可以使用

```powershell
iwr -useb https://gitee.com/glsnames/scoop-installer/raw/master/bin/install.ps1 | iex
```

来安装。

然后替换掉scoop的源，官方源太慢了：

```powershell
scoop bucket rm main
scoop bucket add main https://codechina.csdn.net/mirrors/ScoopInstaller/Main.git
scoop bucket add extras https://codechina.csdn.net/mirrors/lukesampson/scoop-extras.git
scoop update
```

常用的软件可以使用scoop直接安装，如：

```powershell
scoop install git 7zip aria2 python3 vscode typora vlc sumatrapdf
```

国内有人把其他bucket综合成一个[bucket](https://gitee.com/kkzzhizhou/scoop-apps)，也可以根据自己需求使用。scoop比上面说的另外两个包管理器可玩性更高一些，软件数量也相对更加丰富。

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

Invoke-Expression (& { (lua E:/codes/z.lua/z.lua --init powershell once fzf enhanced) -join "`n" })
```

注意最后一行是一个插件`z.lua`，用来做跳转的，如果有需要可以参考[这里](https://github.com/skywind3000/z.lua)来安装。需要`scoop install lua fzf`先安装依赖。

配置完成后保存关闭，重启pwsh即可生效。

## 安装wsl2

前面都是windows里面的准备工作，下面开始安装wsl2. 注意这里写的是官方推荐方案，如果你想从源头解决某些问题，请参考[这里](https://github.com/nullpo-head/wsl-distrod)，使用社区的方案来安装，不过风险自负。

使用管理员权限打开pwsh（或者使用[gsudo](https://github.com/gerardog/gsudo)），输入以下指令：

```powershell
# 开启linux子系统
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
#开启虚拟机平台
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

然后需要[下载](https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi)linux内核更新并安装，安装完成后建议重启。

然后再次使用管理员权限打开pwsh，输入：

```powershell
wsl --set-default-version 2
```

将wsl版本设置为默认第二代。

下面安装需要的发行版就行，打开windows商店，直接搜linux。出来的发行版随便找一个喜欢的下载。

**注意**：没有centos哦，如果你是yum或者rpm的狂热爱好者，可以考虑安装OpenSuse.  或者到社区里面找非官方CentOS镜像（风险自负）。不过个人还是建议安装debian或者ubuntu20.04（推荐），毕竟容器化时代再玩centos其实已经不合时宜了，centos8已经停止支持，再往后就只有滚动升级的stream了，不适合当服务器用。

注意wsl2是可以安装gui的，如果有需要可以装窗口管理器甚至桌面来玩。对于没使用过linux桌面的人，可以玩一下Tiling WM，如i3，高手装b必备。老实人还是建议直接用windows的GUI，或者装个xfce体验一下。

### 配置linux

打开Windows Terminal，安装的linux发行版入口应该会自动加到下拉选单里，选中后进入。

至于怎么配置Linux我就不写了，根据个人习惯来吧。几个点：

* 先用`sudo visudo`取消sudo必须输入密码，不然能烦死你；
* 用`zsh`替换掉bash，可以使用[`oh-my-zsh`](https://ohmyz.sh/)或者[`zi`](https://z-shell.pages.dev/)之类的进行配置管理；
* 安装`lsd`, `fd`, `ripgrep`, `fzf`, `trash-cli`,  `z.lua`等工具，做好`alias`；
* 使用`screen`或者`tmux`进行进程管理；
* 配置好vim

### 【可选】使用docker desktop for windows

在win平台下安装docker desktop，并打开wsl2 backend. 

让所有服务跑在windows容器里，这个方案不会有下面systemd和Java访问wsl中服务问题的苦恼。但是要注意像MySQL这种有状态的服务需要绑定windows本地卷来持久化，不然关机之后数据就都丢了。

使用这个方案，建议Java/Golang等编译环境直接装在Windows下面，Linux仅作为docker的backend使用。

### 解决Linux网络问题

上面配置网络过程中会遇到一个头大无比的问题：linux系统里面的流量不走Windows的代理。

有几个解决方案仅供参考：

1. 在Linux里面重新安装代理软件，反正ss/clash都有linux版，重新配置一下就行；
2. 打开clash for windows的tun模式，让windows的clash接管所有流量，具体方案自行搜索；

### 解决systemd不能用的问题

目前wsl2的systemd是无法正常运行的，有两个解决方案：

1. 使用社区的工具强行修复，如上文提到的[这个](https://github.com/nullpo-head/wsl-distrod);

2. 自己写脚本在Windows启动时启动想要启动的服务，这个也很简单。

   1. 在linux里面找个目录，新建一个755的的bash脚本，如`/etc/init.wsl`。在里面填入要启动的命令，如：`service redis-server start`之类的；
   2. 在运行里面输入`shell:startup`打开自启动文件夹，然后在里面新建一个vbs文件，输入：

   ```vbscript
   Set ws = WScript.CreateObject("WScript.Shell")        
   ws.run "wsl -d ubuntu-20.04 -u root /etc/init.wsl",0
   ```

   这样在Windows启动之后，wsl就会以root权限运行以上脚本启动服务。

### 解决windows和wsl内服务通信问题

在wsl里面安装软件，监听`127.0.0.1`，在Windows里面可以直接用localhost访问，这是因为系统做了重定向。但是我们的代码或者用的某些软件会强制使用127.0.0.1来解析localhost，这就导致无法连接。

这个[问题](https://github.com/microsoft/WSL/issues/4150)解决方案有以下几个：

1. 改成docker运行服务，这样服务和代码都跑在Windows环境下；
2. 全部使用wsl里面的程序，java也好，MySQL也好，idea也好，都在Linux下就能正常访问了；使用该方案需要安装[wslg](https://github.com/microsoft/wslg)(仅win11支持);
2. idea新版（2021.2之后）支持调用wsl里面的jdk，远程跑程序。其他工具使用用Linux下的命令行：

![image-20220307102252002](https://s2.loli.net/2022/03/07/GJwdsXjLmZ72vBV.png)

4. 【推荐】使用[这个工具](https://github.com/shayne/go-wsl2-host)每次启动系统时将wsl的ip地址写入hosts，然后使用本地域名访问（如`ubuntu2004.local`)；
4. 类似4，可以通过事件查看器来触发，参考[这里](https://bytem.io/posts/wsl2-network-tricks/#%E4%B8%BB%E6%9C%BA%E8%AE%BF%E9%97%AE-WSL2)，文中给出的脚本备份如下：

```powershell
# [Config]
$wsl_hosts = "wsl.local"
$win_hosts = "win.local"
$HOSTS_PATH = "$env:windir\System32\drivers\etc\hosts"

# [Start]
$winip = (bash.exe -c "ip route | grep default | awk '{print `$3}'")
$wslip = (bash.exe -c "hostname -I | awk '{print `$1}'")
$found1 = $winip -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';
$found2 = $wslip -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';

if( !($found1 -and $found2) ){
  echo "The Script Exited, the ip address of WSL 2 cannot be found";
  exit;
}

# [Hosts]
# Get hosts file Content
$HOSTS_CONTENT = (Get-Content -Path $HOSTS_PATH) | ? {$_.trim() -ne "" } | Select-String -Pattern '# w(sl)|(in)_hosts' -NotMatch
# add custom hosts into hosts content
$HOSTS_CONTENT = $HOSTS_CONTENT + "`n$wslip $wsl_hosts # wsl_hosts`n$winip $win_hosts # win_hosts"
# write file
Out-File -FilePath $HOSTS_PATH -InputObject $HOSTS_CONTENT -Encoding ASCII

ipconfig /flushdns | Out-Null
```

我在win11家庭版使用方案4/5时都遇到了计划任务权限不足的问题，最后用一个古老的应用`startup delayer`实现了自启动。

## 注意事项

1. wsl2和windows之间传输文件io性能很差；
1. idea支持ssh远程开发，但目前还是beta，不好用；vscode还是比较流畅的；
3. linux的PATH会自动继承windows的path，不过Linux系统里同名的文件优先级更高；所以像git这种软件到底装Windows还是装Linux要自己想清楚；全部在Linux下也可以，都装不是不行…就是要配置两遍；
4. WSL的命令行可以直接调用windows PATH下的exe文件，如vscode，explore（资源管理器）；
5. 在powershell里面可以用`start`命令打开文件，会自动调用关联的打开方式。类似macos的`open`命令，在wsl里面通过`alias`也可以调用（参考最后附录）；
5. 在idea里面讲终端设置为：`"cmd.exe" /k "wsl.exe"`，就可以使用bash做终端了；
5. macos用户可以使用quicklook实现空格预览，utools实现spotlight，并使用powertoys做快捷键映射：个人比较怀恋ctrl+a/ctrl+e映射到home和end的功能，然后把alt+a/c/v/s/w/r都映射成ctrl，alt+q映射成alt+f4，其他的其实都还好；不过离鼠标太远了还是不太方便，最后还是用ideavim插件来减少鼠标使用。

![image-20220305130750860](https://s2.loli.net/2022/03/05/pAxJ2rEqY1S5jNm.png)

## 附：常用alias

```bash
alias ls="lsd"
alias rm="trash"
alias py="python3"
alias find="fd"
alias tailf="tail -F"
alias start="cmd.exe /C start"
```

