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

由于下面会大量从GitHub下载软件，所以请自备梯子。建议使用Clash For windows，下文会说明原因…WSL2最大的坑点就是网络。

### win10特有部分

win10之前，系统的命令行工具分裂为cmd和pwsh两种，界面都难看的很。所以首先安装[Windows Terminal](https://github.com/microsoft/terminal/releases)（以下简称wt），整一个好看一点的终端用。对于天天用命令行的人来说，这个比啥都重要。

然后安装最新的powershell。下载地址在[这里](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2)，目前最新版是powershell7.  pwsh7其实是开源的shell，在linux/macos上都能用，不过这玩意最大的问题是启动速度实在太慢，而且语法设计和bash差别太大。bash是把一切都看作文本，pwsh是把一切都看作对象……都是辣鸡设计，还是python好使。

安装的时候请注意选中添加环境变量，`Open here`那个那个建议不要选中，wt自带有这个功能。装完之后pwsh7会自动注册到wt里。

### 安装包管理器

先安装包管理器scoop（类似yum/apt），打开wt，输入`Set-ExecutionPolicy RemoteSigned -scope CurrentUser`打开安装权限。然后输入

```powershell
iwr -useb get.scoop.sh | iex
```

安装即可。如果网络没准备好，也可以使用

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

国内有人把其他bucket综合成一个[bucket](https://gitee.com/kkzzhizhou/scoop-apps)，也可以根据自己需求使用。

### 安装字体

类似美化zsh的思路，先安装能显示复杂Unicode符号的字体：

[MesloLGS NF Regular.ttf](https://github.com/romkatv/dotfiles-public/raw/master/.local/share/fonts/NerdFonts/MesloLGS NF Regular.ttf)

[MesloLGS NF Bold.ttf](https://github.com/romkatv/dotfiles-public/raw/master/.local/share/fonts/NerdFonts/MesloLGS NF Bold.ttf)

[MesloLGS NF Italic.ttf](https://github.com/romkatv/dotfiles-public/raw/master/.local/share/fonts/NerdFonts/MesloLGS NF Italic.ttf)

[MesloLGS NF Bold Italic.ttf](https://github.com/romkatv/dotfiles-public/raw/master/.local/share/fonts/NerdFonts/MesloLGS NF Bold Italic.ttf)

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

注意最后一行是一个插件`z.lua`，用来做跳转的，如果有需要可以参考[这里](https://github.com/skywind3000/z.lua)来安装。需要`scoop install lua5.4 fzf`先安装依赖。

配置完成后保存关闭，重启pwsh即可生效。

## 安装wsl2

前面都是windows里面的准备工作，下面开始安装wsl2. 注意这里是官方推荐方案，如果你想从源头解决某些问题，请参考[这里](https://github.com/nullpo-head/wsl-distrod)，使用社区的方案来安装，不过风险自负。

使用管理员权限打开pwsh（或者使用[gsudo](https://github.com/gerardog/gsudo)），输入以下指令：

```powershell
# 开启linux子系统
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
#开启虚拟机平台
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

之后windows会下载linux内核相关软件进行安装，然后需要重启。

再次使用管理员权限打开pwsh，输入：

```powershell
wsl --set-default-version 2
```

将wsl版本设置为第二代。

下面安装需要的发行版就行，打开windows商店，直接搜linux。出来的发行版随便找一个喜欢的下载。

**注意**：没有centos哦，如果你是yum或者rpm的狂热爱好者，可以考虑安装openSuse.  或者到社区里面找非官方CentOS镜像（风险自负）。不过个人还是建议安装debian或者ubuntu20.04，毕竟容器化时代再玩centos其实已经不合时宜了，centos8本身就是个废品，再往后就只有stream了，滚动升级还不如玩[ArchLinux](https://github.com/yuk7/ArchWSL)呢……总之，忘了红帽系吧。

注意wsl2是可以安装gui的，如果有需要可以装窗口管理器甚至桌面来玩。对于没使用过linux桌面的人，可以玩一下Tiling WM，如i3，高手装b必备。老实人还是建议直接用windows的GUI，或者装个xfce体验一下。

### 配置linux

打开Windows Terminal，安装的linux发行版入口应该会自动加到下拉选单里，选中后进入。

至于怎么配置Linux我就不写了，根据个人习惯来吧。几个点：

* 先用`sudo visudo`取消sudo必须输入密码，不然能烦死你；
* 用`zsh`替换掉bash，可以使用[`oh-my-zsh`](https://ohmyz.sh/)或者[`zi`](https://z-shell.pages.dev/)之类的进行配置管理；
* 安装`lsd`, `ripgrep`, `fzf`, `trash-cli`,  `z.lua`等工具，做好`alias`；
* 使用`screen`或者`tmux`进行进程管理；
* zsh有个插件`extract`，使用`x`解压一切压缩包；
* 配置好vim

### 【可选】使用docker desktop for windows

在win平台下安装docker desktop，并打开wsl2 backend. 

让所有服务跑在windows容器里，这个方案不会有下面systemd和Java访问wsl中服务问题的苦恼。但是要注意像MySQL这种有状态的服务需要绑定windows本地卷来持久化，不然关机之后数据就都丢了。

使用这个方案，建议Java/Golang等编译环境直接装在Windows下面，Linux仅作为docker的backend使用。

### 解决Linux网络问题

上面配置网络过程中会遇到一个头大无比的问题：linux系统里面的流量不走Windows的代理。

有几个解决方案仅供参考：

1. 在Linux里面重新安装代理软件，反正ss/clash都有linux版，重新配置一下就行；
2. 打开clash for windows的tun模式，让windows的clash接管所有流量，在mixin里面作以下配置：

```yaml
mixin:
   hosts:
     'mtalk.google.com': 108.177.125.188
     'services.googleapis.cn': 74.125.203.94
     'raw.githubusercontent.com': 151.101.76.133
   dns:
     enable: true
     default-nameserver:
       - 223.5.5.5
       - 1.0.0.1
     ipv6: false
     enhanced-mode: redir-host #fake-ip
     nameserver:
       - https://dns.rubyfish.cn/dns-query
       - https://223.5.5.5/dns-query
       - https://dns.pub/dns-query
     fallback:
       - https://1.0.0.1/dns-query
       - https://public.dns.iij.jp/dns-query
       - https://dns.twnic.tw/dns-query
     fallback-filter:
       geoip: true
       ipcidr:
         - 240.0.0.0/4
         - 0.0.0.0/32
         - 127.0.0.1/32
       domain:
         - +.google.com
         - +.facebook.com
         - +.twitter.com
         - +.youtube.com
         - +.xn--ngstr-lra8j.com
         - +.google.cn
         - +.googleapis.cn
         - +.gvt1.com
   tun:
     enable: true
     stack: gvisor
     dns-hijack:
       - 198.18.0.2:53
     macOS-auto-route: true
     macOS-auto-detect-interface: true # 自动检测出口网卡
```

### 解决systemd不能用的问题

目前wsl2的systemd是无法正常运行的，有两个解决方案：

1. 使用社区的工具强行修复，如上文提到的[这个](https://github.com/nullpo-head/wsl-distrod);

2. 自己写脚本在Windows启动时启动想要启动的服务，这个也很简单。

   1. 在linux里面找个目录，新建一个755的的bash脚本，如`/etc/init.wsl`。在里面填入要启动的命令，如：`service redis-server start`之类的；
   2. 在运行里面输入`shell:startup`打开自启动文件夹，然后在里面新建一个vbs文件，输入：

   ```vbscript
   Set ws = WScript.CreateObject("WScript.Shell")        
   ws.run "wsl -d debian -u root /etc/init.wsl",0
   ```

   这样在Windows启动之后，wsl就会以root权限运行以上脚本启动服务。

### 解决Java代码里面的本地回环问题

在wsl里面安装软件，监听`127.0.0.1`，在Windows里面可以直接用localhost访问，这是因为系统做了重定向。但是在java程序里配置localhost，会被强制解析为`127.0.0.1`，这样就导致无法访问。

这个[问题](https://github.com/microsoft/WSL/issues/4150)解决方案有三个：

1. 改成docker运行服务，这样服务和代码都跑在Windows环境下；
2. 全部使用wsl里面的程序，java也好，MySQL也好，都在Linux下就能正常访问了；idea和vscode都支持wsl了，推荐使用该方案；
3. 如果jdk用的Windows版本，MySQL跑在Linux下面。只能通过Windows防火墙进行处理。在Windows平台下建一个pwsh脚本，填入一下内容：

```powershell
$remoteport = bash.exe -c "ifconfig eth0 | grep 'inet '"
$found = $remoteport -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';

if( $found ){
  $remoteport = $matches[0];
} else{
  echo "The Script Exited, the ip address of WSL 2 cannot be found";
  exit;
}

#[Ports]

#All the ports you want to forward separated by coma
$ports=@(80,443,6379,3306,8000,8001,8554,8848,8888,9092,9848,11883,8081,8083);


#[Static ip]
#You can change the addr to your ip config to listen to a specific address
$addr='127.0.0.1';
$ports_a = $ports -join ",";


#Remove Firewall Exception Rules
iex "Remove-NetFireWallRule -DisplayName 'WSL 2 Firewall Unlock' ";

#adding Exception Rules for inbound and outbound Rules
iex "New-NetFireWallRule -DisplayName 'WSL 2 Firewall Unlock' -Direction Outbound -LocalPort $ports_a -Action Allow -Protocol TCP";
iex "New-NetFireWallRule -DisplayName 'WSL 2 Firewall Unlock' -Direction Inbound -LocalPort $ports_a -Action Allow -Protocol TCP";

for( $i = 0; $i -lt $ports.length; $i++ ){
  $port = $ports[$i];
  iex "netsh interface portproxy delete v4tov4 listenport=$port listenaddress=$addr";
  iex "netsh interface portproxy add v4tov4 listenport=$port listenaddress=$addr connectport=$port connectaddress=$remoteport";
}
```

在ports里面填入你想export到windows的服务端口，然后以管理员权限跑一下这个脚本。

这个脚本同样需要设置为自启动，在刚才的vbs启动脚本里面加入：`ws.run "pwsh E:/codes/powershell/run.ps1",0`即可。

## 注意事项

1. wsl2和windows之间传输文件io性能很差，建议代码仓库还是放在windows这边，用windows的ide来开发；
2. 如果依赖第三方库需要区分平台，那还是老老实实的用linux环境；
3. linux的PATH会自动继承windows的path，不过Linux系统里同名的文件优先级更高；所以像git这种软件到底装Windows还是装Linux要自己想清楚；全部在Linux下也可以，都装不是不行…就是要配置两遍；
4. WSL的命令行可以直接调用windows PATH下的exe文件，如vscode，explore（资源管理器）；
5. 在powershell里面可以用`start`命令打开文件，会自动调用关联的打开方式。类似macos的`open`命令，在wsl里面通过`alias`也可以调用（参考最后附录）；
5. macos用户可以使用quicklook实现空格预览，utools实现spotlight，并使用powertoys做快捷键映射：个人比较怀恋ctrl+a/ctrl+e映射到home和end的功能，然后把alt+a/c/v/s/w/r都映射成ctrl，alt+q映射成alt+f4，其他的其实都还好；

![image-20220305130750860](https://s2.loli.net/2022/03/05/pAxJ2rEqY1S5jNm.png)

## 附：Windows Terminal配置参考

```json
{
    "$help": "https://aka.ms/terminal-documentation",
    "$schema": "https://aka.ms/terminal-profiles-schema",
    "actions":
    [
        {
            "command":
            {
                "action": "copy",
                "singleLine": false
            },
            "keys": "ctrl+c"
        },
        {
            "command":
            {
                "action": "splitPane",
                "split": "right",
                "splitMode": "duplicate"
            },
            "keys": "alt+d"
        },
        {
            "command": "unbound",
            "keys": "alt+enter"
        },
        {
            "command": "paste",
            "keys": "ctrl+v"
        },
        {
            "command": "find",
            "keys": "ctrl+f"
        },
        {
            "command":
            {
                "action": "splitPane",
                "split": "down",
                "splitMode": "duplicate"
            },
            "keys": "alt+s"
        },
        {
            "command":
            {
                "action": "splitPane",
                "split": "auto",
                "splitMode": "duplicate"
            },
            "keys": "alt+shift+d"
        }
    ],
    "copyFormatting": "none",
    "copyOnSelect": true,
    "defaultProfile": "{58ad8b0c-3ef8-5f4d-bc6f-13e4c00f2530}",
    "profiles":
    {
        "defaults":
        {
            "antialiasingMode": "cleartype",
            "closeOnExit": "always",
            "colorScheme": "Tango Dark",
            "font":
            {
                "face": "MesloLGS NF",
                "size": 11
            }
        },
        "list":
        [
            {
                "guid": "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
                "hidden": false,
                "name": "PowerShell",
                "source": "Windows.Terminal.PowershellCore",
                "startingDirectory": "%USERPROFILE%"
            },
            {
                "guid": "{58ad8b0c-3ef8-5f4d-bc6f-13e4c00f2530}",
                "hidden": false,
                "name": "Debian",
                "source": "Windows.Terminal.Wsl"
            },
            {
                "guid": "{2ece5bfe-50ed-5f3a-ab87-5cd4baafed2b}",
                "hidden": false,
                "name": "Git Bash",
                "source": "Git",
                "startingDirectory": "E:\\codes"
            }
        ]
    },
    "schemes":
    [
        {
            "background": "#0C0C0C",
            "black": "#0C0C0C",
            "blue": "#0037DA",
            "brightBlack": "#767676",
            "brightBlue": "#3B78FF",
            "brightCyan": "#61D6D6",
            "brightGreen": "#16C60C",
            "brightPurple": "#B4009E",
            "brightRed": "#E74856",
            "brightWhite": "#F2F2F2",
            "brightYellow": "#F9F1A5",
            "cursorColor": "#FFFFFF",
            "cyan": "#3A96DD",
            "foreground": "#CCCCCC",
            "green": "#13A10E",
            "name": "Campbell",
            "purple": "#881798",
            "red": "#C50F1F",
            "selectionBackground": "#FFFFFF",
            "white": "#CCCCCC",
            "yellow": "#C19C00"
        },
        {
            "background": "#012456",
            "black": "#0C0C0C",
            "blue": "#0037DA",
            "brightBlack": "#767676",
            "brightBlue": "#3B78FF",
            "brightCyan": "#61D6D6",
            "brightGreen": "#16C60C",
            "brightPurple": "#B4009E",
            "brightRed": "#E74856",
            "brightWhite": "#F2F2F2",
            "brightYellow": "#F9F1A5",
            "cursorColor": "#FFFFFF",
            "cyan": "#3A96DD",
            "foreground": "#CCCCCC",
            "green": "#13A10E",
            "name": "Campbell Powershell",
            "purple": "#881798",
            "red": "#C50F1F",
            "selectionBackground": "#FFFFFF",
            "white": "#CCCCCC",
            "yellow": "#C19C00"
        },
        {
            "background": "#282C34",
            "black": "#282C34",
            "blue": "#61AFEF",
            "brightBlack": "#5A6374",
            "brightBlue": "#61AFEF",
            "brightCyan": "#56B6C2",
            "brightGreen": "#98C379",
            "brightPurple": "#C678DD",
            "brightRed": "#E06C75",
            "brightWhite": "#DCDFE4",
            "brightYellow": "#E5C07B",
            "cursorColor": "#FFFFFF",
            "cyan": "#56B6C2",
            "foreground": "#DCDFE4",
            "green": "#98C379",
            "name": "One Half Dark",
            "purple": "#C678DD",
            "red": "#E06C75",
            "selectionBackground": "#FFFFFF",
            "white": "#DCDFE4",
            "yellow": "#E5C07B"
        },
        {
            "background": "#FAFAFA",
            "black": "#383A42",
            "blue": "#0184BC",
            "brightBlack": "#4F525D",
            "brightBlue": "#61AFEF",
            "brightCyan": "#56B5C1",
            "brightGreen": "#98C379",
            "brightPurple": "#C577DD",
            "brightRed": "#DF6C75",
            "brightWhite": "#FFFFFF",
            "brightYellow": "#E4C07A",
            "cursorColor": "#4F525D",
            "cyan": "#0997B3",
            "foreground": "#383A42",
            "green": "#50A14F",
            "name": "One Half Light",
            "purple": "#A626A4",
            "red": "#E45649",
            "selectionBackground": "#FFFFFF",
            "white": "#FAFAFA",
            "yellow": "#C18301"
        },
        {
            "background": "#002B36",
            "black": "#002B36",
            "blue": "#268BD2",
            "brightBlack": "#073642",
            "brightBlue": "#839496",
            "brightCyan": "#93A1A1",
            "brightGreen": "#586E75",
            "brightPurple": "#6C71C4",
            "brightRed": "#CB4B16",
            "brightWhite": "#FDF6E3",
            "brightYellow": "#657B83",
            "cursorColor": "#FFFFFF",
            "cyan": "#2AA198",
            "foreground": "#839496",
            "green": "#859900",
            "name": "Solarized Dark",
            "purple": "#D33682",
            "red": "#DC322F",
            "selectionBackground": "#FFFFFF",
            "white": "#EEE8D5",
            "yellow": "#B58900"
        },
        {
            "background": "#FDF6E3",
            "black": "#002B36",
            "blue": "#268BD2",
            "brightBlack": "#073642",
            "brightBlue": "#839496",
            "brightCyan": "#93A1A1",
            "brightGreen": "#586E75",
            "brightPurple": "#6C71C4",
            "brightRed": "#CB4B16",
            "brightWhite": "#FDF6E3",
            "brightYellow": "#657B83",
            "cursorColor": "#002B36",
            "cyan": "#2AA198",
            "foreground": "#657B83",
            "green": "#859900",
            "name": "Solarized Light",
            "purple": "#D33682",
            "red": "#DC322F",
            "selectionBackground": "#FFFFFF",
            "white": "#EEE8D5",
            "yellow": "#B58900"
        },
        {
            "background": "#000000",
            "black": "#000000",
            "blue": "#3465A4",
            "brightBlack": "#555753",
            "brightBlue": "#729FCF",
            "brightCyan": "#34E2E2",
            "brightGreen": "#8AE234",
            "brightPurple": "#AD7FA8",
            "brightRed": "#EF2929",
            "brightWhite": "#EEEEEC",
            "brightYellow": "#FCE94F",
            "cursorColor": "#FFFFFF",
            "cyan": "#06989A",
            "foreground": "#D3D7CF",
            "green": "#4E9A06",
            "name": "Tango Dark",
            "purple": "#75507B",
            "red": "#CC0000",
            "selectionBackground": "#FFFFFF",
            "white": "#D3D7CF",
            "yellow": "#C4A000"
        },
        {
            "background": "#FFFFFF",
            "black": "#000000",
            "blue": "#3465A4",
            "brightBlack": "#555753",
            "brightBlue": "#729FCF",
            "brightCyan": "#34E2E2",
            "brightGreen": "#8AE234",
            "brightPurple": "#AD7FA8",
            "brightRed": "#EF2929",
            "brightWhite": "#EEEEEC",
            "brightYellow": "#FCE94F",
            "cursorColor": "#000000",
            "cyan": "#06989A",
            "foreground": "#555753",
            "green": "#4E9A06",
            "name": "Tango Light",
            "purple": "#75507B",
            "red": "#CC0000",
            "selectionBackground": "#FFFFFF",
            "white": "#D3D7CF",
            "yellow": "#C4A000"
        },
        {
            "background": "#000000",
            "black": "#000000",
            "blue": "#000080",
            "brightBlack": "#808080",
            "brightBlue": "#0000FF",
            "brightCyan": "#00FFFF",
            "brightGreen": "#00FF00",
            "brightPurple": "#FF00FF",
            "brightRed": "#FF0000",
            "brightWhite": "#FFFFFF",
            "brightYellow": "#FFFF00",
            "cursorColor": "#FFFFFF",
            "cyan": "#008080",
            "foreground": "#C0C0C0",
            "green": "#008000",
            "name": "Vintage",
            "purple": "#800080",
            "red": "#800000",
            "selectionBackground": "#FFFFFF",
            "white": "#C0C0C0",
            "yellow": "#808000"
        }
    ],
    "trimBlockSelection": true
}
```

## 附：Mysql的启动脚本

从源里面安装MySQL8的话，只会安装systemd，而没有service。所以要自己在`/etc/init.d`下面建一个可执行脚本，内容如下：

```bash
#!/bin/sh
# Copyright Abandoned 1996 TCX DataKonsult AB & Monty Program KB & Detron HB
# This file is public domain and comes with NO WARRANTY of any kind

# MySQL daemon start/stop script.

# Usually this is put in /etc/init.d (at least on machines SYSV R4 based
# systems) and linked to /etc/rc3.d/S99mysql and /etc/rc0.d/K01mysql.
# When this is done the mysql server will be started when the machine is
# started and shut down when the systems goes down.

# Comments to support chkconfig on RedHat Linux
# chkconfig: 2345 64 36
# description: A very fast and reliable SQL database engine.

# Comments to support LSB init script conventions
### BEGIN INIT INFO
# Provides: mysql
# Required-Start: $local_fs $network $remote_fs
# Should-Start: ypbind nscd ldap ntpd xntpd
# Required-Stop: $local_fs $network $remote_fs
# Default-Start:  2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: start and stop MySQL
# Description: MySQL is a very fast and reliable SQL database engine.
### END INIT INFO
 
# If you install MySQL on some other places than @prefix@, then you
# have to do one of the following things for this script to work:
#
# - Run this script from within the MySQL installation directory
# - Create a /etc/my.cnf file with the following information:
#   [mysqld]
#   basedir=<path-to-mysql-installation-directory>
# - Add the above to any other configuration file (for example ~/.my.ini)
#   and copy my_print_defaults to /usr/bin
# - Add the path to the mysql-installation-directory to the basedir variable
#   below.
#
# If you want to affect other MySQL variables, you should make your changes
# in the /etc/my.cnf, ~/.my.cnf or other MySQL configuration files.

# If you change base dir, you must also change datadir. These may get
# overwritten by settings in the MySQL configuration files.

basedir=/usr
datadir=/var/lib/mysql

# Default value, in seconds, afterwhich the script should timeout waiting
# for server start. 
# Value here is overriden by value in my.cnf. 
# 0 means don't wait at all
# Negative numbers mean to wait indefinitely
service_startup_timeout=900

# Lock directory for RedHat / SuSE.
lockdir='/var/lock/subsys'
lock_file_path="$lockdir/mysql"

# The following variables are only set for letting mysql.server find things.

# Set some defaults
mysqld_pid_file_path=
if test -z "$basedir"
then
  basedir=@prefix@
  bindir=@bindir@
  if test -z "$datadir"
  then
    datadir=@localstatedir@
  fi
  sbindir=@sbindir@
  libexecdir=@sbindir@
else
  bindir="$basedir/bin"
  if test -z "$datadir"
  then
    datadir="$basedir/data"
  fi
  sbindir="$basedir/sbin"
  libexecdir="$basedir/libexec"
fi

# datadir_set is used to determine if datadir was set (and so should be
# *not* set inside of the --basedir= handler.)
datadir_set=

#
# Use LSB init script functions for printing messages, if possible
#
lsb_functions="/lib/lsb/init-functions"
if test -f $lsb_functions ; then
  . $lsb_functions
else
  log_success_msg()
  {
    echo " SUCCESS! $@"
  }
  log_failure_msg()
  {
    echo " ERROR! $@"
  }
fi

PATH="/sbin:/usr/sbin:/bin:/usr/bin:$basedir/bin"
export PATH

mode=$1    # start or stop

[ $# -ge 1 ] && shift


other_args="$*"   # uncommon, but needed when called from an RPM upgrade action
           # Expected: "--skip-networking --skip-grant-tables"
           # They are not checked here, intentionally, as it is the resposibility
           # of the "spec" file author to give correct arguments only.

case `echo "testing\c"`,`echo -n testing` in
    *c*,-n*) echo_n=   echo_c=     ;;
    *c*,*)   echo_n=-n echo_c=     ;;
    *)       echo_n=   echo_c='\c' ;;
esac

parse_server_arguments() {
  for arg do
    case "$arg" in
      --basedir=*)  basedir=`echo "$arg" | sed -e 's/^[^=]*=//'`
                    bindir="$basedir/bin"
		    if test -z "$datadir_set"; then
		      datadir="$basedir/data"
		    fi
		    sbindir="$basedir/sbin"
		    libexecdir="$basedir/libexec"
        ;;
      --datadir=*)  datadir=`echo "$arg" | sed -e 's/^[^=]*=//'`
		    datadir_set=1
	;;
      --pid-file=*) mysqld_pid_file_path=`echo "$arg" | sed -e 's/^[^=]*=//'` ;;
      --service-startup-timeout=*) service_startup_timeout=`echo "$arg" | sed -e 's/^[^=]*=//'` ;;
    esac
  done
}

wait_for_pid () {
  verb="$1"           # created | removed
  pid="$2"            # process ID of the program operating on the pid-file
  pid_file_path="$3" # path to the PID file.

  i=0
  avoid_race_condition="by checking again"

  while test $i -ne $service_startup_timeout ; do

    case "$verb" in
      'created')
        # wait for a PID-file to pop into existence.
        test -s "$pid_file_path" && i='' && break
        ;;
      'removed')
        # wait for this PID-file to disappear
        test ! -s "$pid_file_path" && i='' && break
        ;;
      *)
        echo "wait_for_pid () usage: wait_for_pid created|removed pid pid_file_path"
        exit 1
        ;;
    esac

    # if server isn't running, then pid-file will never be updated
    if test -n "$pid"; then
      if kill -0 "$pid" 2>/dev/null; then
        :  # the server still runs
      else
        # The server may have exited between the last pid-file check and now.  
        if test -n "$avoid_race_condition"; then
          avoid_race_condition=""
          continue  # Check again.
        fi

        # there's nothing that will affect the file.
        log_failure_msg "The server quit without updating PID file ($pid_file_path)."
        return 1  # not waiting any more.
      fi
    fi

    echo $echo_n ".$echo_c"
    i=`expr $i + 1`
    sleep 1

  done

  if test -z "$i" ; then
    log_success_msg
    return 0
  else
    log_failure_msg
    return 1
  fi
}

# Get arguments from the my.cnf file,
# the only group, which is read from now on is [mysqld]
if test -x "$bindir/my_print_defaults";  then
  print_defaults="$bindir/my_print_defaults"
else
  # Try to find basedir in /etc/my.cnf
  conf=/etc/my.cnf
  print_defaults=
  if test -r $conf
  then
    subpat='^[^=]*basedir[^=]*=\(.*\)$'
    dirs=`sed -e "/$subpat/!d" -e 's//\1/' $conf`
    for d in $dirs
    do
      d=`echo $d | sed -e 's/[ 	]//g'`
      if test -x "$d/bin/my_print_defaults"
      then
        print_defaults="$d/bin/my_print_defaults"
        break
      fi
    done
  fi

  # Hope it's in the PATH ... but I doubt it
  test -z "$print_defaults" && print_defaults="my_print_defaults"
fi

#
# Read defaults file from 'basedir'.   If there is no defaults file there
# check if it's in the old (depricated) place (datadir) and read it from there
#

extra_args=""
if test -r "$basedir/my.cnf"
then
  extra_args="-e $basedir/my.cnf"
fi

parse_server_arguments `$print_defaults $extra_args mysqld server mysql_server mysql.server`

#
# Set pid file if not given
#
if test -z "$mysqld_pid_file_path"
then
  mysqld_pid_file_path=$datadir/`hostname`.pid
else
  case "$mysqld_pid_file_path" in
    /* ) ;;
    * )  mysqld_pid_file_path="$datadir/$mysqld_pid_file_path" ;;
  esac
fi

case "$mode" in
  'start')
    # Start daemon

    # Safeguard (relative paths, core dumps..)
    cd $basedir

    echo $echo_n "Starting MySQL"
    if test -x $bindir/mysqld_safe
    then
      # Give extra arguments to mysqld with the my.cnf file. This script
      # may be overwritten at next upgrade.
      $bindir/mysqld_safe --datadir="$datadir" --pid-file="$mysqld_pid_file_path" $other_args >/dev/null &
      wait_for_pid created "$!" "$mysqld_pid_file_path"; return_value=$?

      # Make lock for RedHat / SuSE
      if test -w "$lockdir"
      then
        touch "$lock_file_path"
      fi

      exit $return_value
    else
      log_failure_msg "Couldn't find MySQL server ($bindir/mysqld_safe)"
    fi
    ;;

  'stop')
    # Stop daemon. We use a signal here to avoid having to know the
    # root password.

    if test -s "$mysqld_pid_file_path"
    then
      # signal mysqld_safe that it needs to stop
      touch "$mysqld_pid_file_path.shutdown"

      mysqld_pid=`cat "$mysqld_pid_file_path"`

      if (kill -0 $mysqld_pid 2>/dev/null)
      then
        echo $echo_n "Shutting down MySQL"
        kill $mysqld_pid
        # mysqld should remove the pid file when it exits, so wait for it.
        wait_for_pid removed "$mysqld_pid" "$mysqld_pid_file_path"; return_value=$?
      else
        log_failure_msg "MySQL server process #$mysqld_pid is not running!"
        rm "$mysqld_pid_file_path"
      fi

      # Delete lock for RedHat / SuSE
      if test -f "$lock_file_path"
      then
        rm -f "$lock_file_path"
      fi
      exit $return_value
    else
      log_failure_msg "MySQL server PID file could not be found!"
    fi
    ;;

  'restart')
    # Stop the service and regardless of whether it was
    # running or not, start it again.
    if $0 stop  $other_args; then
      $0 start $other_args
    else
      log_failure_msg "Failed to stop running server, so refusing to try to start."
      exit 1
    fi
    ;;

  'reload'|'force-reload')
    if test -s "$mysqld_pid_file_path" ; then
      read mysqld_pid <  "$mysqld_pid_file_path"
      kill -HUP $mysqld_pid && log_success_msg "Reloading service MySQL"
      touch "$mysqld_pid_file_path"
    else
      log_failure_msg "MySQL PID file could not be found!"
      exit 1
    fi
    ;;
  'status')
    # First, check to see if pid file exists
    if test -s "$mysqld_pid_file_path" ; then 
      read mysqld_pid < "$mysqld_pid_file_path"
      if kill -0 $mysqld_pid 2>/dev/null ; then 
        log_success_msg "MySQL running ($mysqld_pid)"
        exit 0
      else
        log_failure_msg "MySQL is not running, but PID file exists"
        exit 1
      fi
    else
      # Try to find appropriate mysqld process
      mysqld_pid=`@PIDOF@ $libexecdir/mysqld`

      # test if multiple pids exist
      pid_count=`echo $mysqld_pid | wc -w`
      if test $pid_count -gt 1 ; then
        log_failure_msg "Multiple MySQL running but PID file could not be found ($mysqld_pid)"
        exit 5
      elif test -z $mysqld_pid ; then 
        if test -f "$lock_file_path" ; then 
          log_failure_msg "MySQL is not running, but lock file ($lock_file_path) exists"
          exit 2
        fi 
        log_failure_msg "MySQL is not running"
        exit 3
      else
        log_failure_msg "MySQL is running but PID file could not be found"
        exit 4
      fi
    fi
    ;;
    *)
      # usage
      basename=`basename "$0"`
      echo "Usage: $basename  {start|stop|restart|reload|force-reload|status}  [ MySQL server options ]"
      exit 1
    ;;
esac

exit 0
```

主要注意`basedir`和`datadir`的位置。

在wsl启动脚本里面需要加入：

```bash
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld
service mysql start
```

来启动服务。

## 附：常用alias

```bash
alias ls="lsd"
alias rm="trash"
alias py="python3"
alias tailf="tail -F"
alias start="cmd.exe /C start"
```

