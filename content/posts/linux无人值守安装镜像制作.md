---
title: Linux无人值守安装镜像制作
tags: ["devops"]
date: 2020-04-29
lastmod: 2020-05-30
slug: a81d029
draft: false
---

这里需要批量安装的是centos 7服务器版，首先下载centos 7最新版，带上GUI的镜像，装在虚拟机里面。然后下载centos 7 minimal镜像用作批量安装的母盘。

注意：不要装centos 8，这货特别大，而且没有图形化配置工具。

## 概述

不同发行版支持的自动安装镜像技术不太一样，红帽这一系的主要使用kickstart，debian则使用`preseed`。这里安装的是centos7，所以用的主要是kickstart技术。

## kickstart配置

首先使用yum安装图形化工具`system-config-kickstart`，对语法熟悉的也可以不用这玩意儿直接撸。

把镜像挂在到centos里，然后`cp -r`(需要包含隐藏文件）光盘里面的所有的内容到某个路径，比如`/root/iso/`。在`/root/iso`下建立文件夹存放kickstart配置文件，比如`/root/iso/kickstart/ks.cfg`。

打开图形化配置工具kickstart，根据个人需求进行配置。具体可以参考[这里的介绍](https://pdf.us/2018/08/13/1710.html)。最后保存为刚才路径下的文件即可。

网络和个人帐户无需配置，因为可以离线安装。如果自己想装的额外的rpm包，使用`repotrack`工具下载到`Packages`文件夹里，在ks的`packages`部分中加入即可。

最后生成的ks文件如下：

```
#platform=x86, AMD64, 或 Intel EM64T
#version=DEVEL
# Install OS instead of upgrade
install
# Keyboard layouts
keyboard 'us'
# Root password
rootpw --iscrypted $1$0Rnj3JYy$.O6bjrhyiBucwxVpIg8eF1
# System language
lang en_US
# System authorization information
auth  --useshadow  --passalgo=sha512
# Use CDROM installation media
cdrom
# Use text mode install
text
# SELinux configuration
selinux --disabled
# Do not configure the X Window System
skipx

# System bootloader configuration
bootloader --location=mbr

# Firewall configuration
firewall --disabled
services --disabled="chronyd"
services --enabled="sshd"
# System timezone
timezone Asia/Shanghai
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part /boot --fstype="xfs" --size=500
part /boot/efi --fstype="xfs" --size=500
part swap --fstype="swap" --size=1024
part / --fstype="ext4" --grow --size=1
poweroff

%packages --multilib --ignoremissing
lrzsz
net-tools
openssl
python3
screen
tcpdump
zip
unzip
vim-enhanced
wget
yum-utils
nano
NetworkManager-tui
%end

%addon com_redhat_kdump --enable --reserve-mb='auto'
%end

%post --nochroot
cp -fr /mnt/install/repo/plus/* /mnt/sysimage/root/
echo "/bin/bash /root/init.sh" >> /mnt/sysimage/etc/rc.local
chmod a+x /mnt/sysimage/etc/rc.local
%end
```

## 其他配置

**每次**修改packages里面的安装条目，需要重新生成repo数据库，语法是在镜像根目录执行`createrepo -g repodata/xxxx-c7-minimal-x86_64-comps.xml .`，文件的名字可能是一串随机字符，根据个人情况生成。

下面是修改isolinux.cfg保证使用kickstart文件：

```
default vesamenu.c32
timeout 50

#省略一部分

label linux
  menu label ^Auto Install CentOS 7
  menu default
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=CENTOS7 inst.ks=hd:LABEL=CENTOS7:/kickstart/ks.cfg quiet

# 省略一部分

menu end
```

注意这里通过label指定ks文件的路径，防止U盘安装的时候找不到路径。卷标名在生成iso文件的时候可以修改，尽量不要用空格。

同样在`EFI/BOOT/grub.cfg`里面增加一个入口：

```
menuentry 'Auto Install CentOS 7' --class fedora --class gnu-linux --class gnu --class os {
       linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=CENTOS7 inst.ks=hd:LABEL=CENTOS7:/kickstart/ks.cfg quiet
       initrdefi /images/pxeboot/initrd.img
}
```

### 生成iso文件

```
cd /root/iso && mkisofs -v -cache-inodes -joliet-long -R -J -T -V CENTOS7 -o /root/centos7.iso -c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e images/efiboot.img -no-emul-boot .
isohybrid /root/centos7.iso
implantisomd5 /root/centos7.iso
```

上面是一个简单的脚本用来生成iso文件，注意这里使用-V改了卷标，和上面的hd:label保持一致。最后的alt-boot是efi启动支持。

最后使用dd刻盘到u盘，就可以安装了。

### 自动配置脚本

注意到ks文件的post段里面，创建了一个一次性自运行的服务。在镜像根目录下创建`plus`文件夹，把想要复制到系统的文件都拷贝进去。`cp -fr /mnt/install/repo/plus/* /mnt/sysimage/root/`这句会将所有的文件拷贝到`/root/`目录下。

其中`init.sh`的内容如下：

```
#!/bin/bash
# wait other service start
sleep 5
# iot-device
mv /root/cron /etc/cron.d/iot-device
# params
echo "" >> /etc/ssh/sshd_config
echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config
echo "ClientAliveCountMax 86400" >> /etc/ssh/sshd_config

echo "* - noproc 11000" >> /etc/security/limits.conf
echo "root soft nofile 1048576" >>  /etc/security/limits.conf
echo "root hard nofile 1048576" >> /etc/security/limits.conf
echo "* hard nofile 1048576" >> /etc/security/limits.conf
echo "* soft nofile 1048576" >> /etc/security/limits.conf
echo "fs.file-max = 1048576" >>  /etc/sysctl.conf
echo "net.core.somaxconn=32768" >> /etc/sysctl.conf
echo "DefaultLimitNOFILE=1048576" >> /etc/systemd/system.conf
sysctl -p
sysctl -w net.core.somaxconn=32768
sysctl -w net.ipv4.tcp_max_syn_backlog=16384
sysctl -w net.core.netdev_max_backlog=16384
sysctl -w net.ipv4.ip_local_port_range='1000 65535'
sysctl -w net.core.rmem_default=262144
sysctl -w net.core.wmem_default=262144
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.core.optmem_max=16777216

sysctl -w net.ipv4.tcp_rmem='1024 4096 16777216'
sysctl -w net.ipv4.tcp_wmem='1024 4096 16777216'
sysctl -w net.ipv4.tcp_max_tw_buckets=1048576
sysctl -w net.ipv4.tcp_fin_timeout=15
sed -i '/.*init.*/d' /etc/rc.local

# 清空在安装阶段从光盘安装的所有文件
rm -fr /mnt/*
rm /root/*.cfg
rm /root/TRAN*
rm $0

#主动启动网卡
interface=$(ls /sys/class/net| grep -v "lo" | head -1)
ifup $interface
if [$? -ne 0];then
    echo "can't start network, please run nmtui to connect Wi-Fi"
    exit 1
fi
#获取当前网络信息
default_route=$(ip route show)
default_interface=$(echo $default_route | sed -e 's/^.*dev \([^ ]*\).*$/\1/' | head -n 1)
address=$(ip addr show label $default_interface scope global | awk '$1 == "inet" { print $2,$4}')
ip=$(echo $address | awk '{print $1 }')
ip=${ip%%/*}
mask=$(route -n |grep 'U[ \t]' | head -n 1 | awk '{print $3}')
gateway=$(route -n | grep 'UG[ \t]' | awk '{print $2}')
dns=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')


#判断default_interface是否为空
if [ -z $default_interface ]
then
    default_interface=$interface
fi

#显示网络信息
echo -e "The current net info [dynamic]"
echo -e "------------------------------------------"
echo -e " device: $default_interface"
echo -e " ipaddr: $ip"
echo -e "netmask: $mask"
echo -e "gateway: $gateway"
echo -e "    dns: $dns"
echo -e "------------------------------------------"
echo -e ""
# set last ip to 200
IFS='.' read -r -a array <<< "$ip"
array[3]=200
newip=$(IFS=. eval 'echo "${array[*]}"')
echo "newip is $newip"

#网络配置
cp /etc/sysconfig/network-scripts/ifcfg-$default_interface /etc/sysconfig/network-scripts/ifcfg-$default_interface.bak
uuid=$(cat /etc/sysconfig/network-scripts/ifcfg-$default_interface |grep UUID|sed -e 's/"//g')

echo "IPV6INIT=yes"               > /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "IPV6_AUTOCONF=yes"         >> /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "BOOTPROTO=none"            >> /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "DEVICE=$default_interface" >> /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "ONBOOT=yes"                >> /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "$uuid"                     >> /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "TYPE=Ethernet"             >> /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "PROXY_METHOD=none"         >> /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "BROWSER_ONLY=no"           >> /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "IPADDR=$newip"             >> /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "NETMASK=$mask"             >> /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "GATEWAY=$gateway"          >> /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "DNS1=114.114.114.114"      >> /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "DEFROUTE=yes"              >> /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "IPV4_FAILURE_FATAL=no"     >> /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "IPV6_DEFROUTE=yes"         >> /etc/sysconfig/network-scripts/ifcfg-$default_interface
echo "IPV6_FAILURE_FATAL=no"     >> /etc/sysconfig/network-scripts/ifcfg-$default_interface

#DNS配置
cp /etc/resolv.conf /etc/resolv.conf.bak
echo "# Generated by NetworkManager" > /etc/resolv.conf
echo "nameserver 114.114.114.114" >> /etc/resolv.conf

#重启一下网络 使配置生效
systemctl restart network
sleep 5
ping -c 4 www.baidu.com
if [ $? != 0 ]
then
     echo -e "Error! Cant link to Internet"
     #break
fi
```

简单来说，根据dhcp自动配置的ip地址，将其最后一位换成200，改成静态ip写死。如果怕ip地址冲突，直接将获得的ip写成静态ip也可以。
然后是一些常见服务器参数的改写，最后是禁止并删除掉一次性脚本的自启动，然后删除掉自身。

如果需要做一些服务相关配置，在这里也可以初始化，比如配置cron定期检查更新。

上面ks文件设置了安装完毕后自动关机，在合适的环境下插上网线开机，就会自动运行上面的初始化脚本，安装好服务。

## 无线网卡

如果不是插网线，而是用无线网卡，这里的逻辑就比较复杂，必须让用户手动设置Wi-Fi。然后再手动运行脚本设置为静态ip。

在Package里面增加`NetworkManager-tui`这个包，init.sh里面判断如果ifup失败，就直接退出。

此时需要用户运行`nmtui`设置好Wi-Fi（注意Wi-Fi的ssid应为英文，不然显示是乱码）。然后运行如下脚本来将Wi-Fi设置成静态ip：

```
#获取当前网络信息
default_route=$(ip route show)
default_interface=$(echo $default_route | sed -e 's/^.*dev \([^ ]*\).*$/\1/' | head -n 1)
address=$(ip addr show label $default_interface scope global | awk '$1 == "inet" { print $2,$4}')
ip=$(echo $address | awk '{print $1 }')
ip=${ip%%/*}
mask=$(route -n |grep 'U[ \t]' | head -n 1 | awk '{print $3}')
gateway=$(route -n | grep 'UG[ \t]' | awk '{print $2}')
dns=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')


#判断default_interface是否为空
if [ -z $default_interface ]
then
    echo "no working network, exit! if you want to use Wi-Fi, please run nmtui to set"
    exit 1
fi

cfg_name=$(cd /etc/sysconfig/network-scripts && grep -l Wireless *|grep ifcfg)
echo "config file is $cfg_name"

#download iot-device
/bin/python3 /root/cron_update.py

#显示网络信息
echo -e "The current net info [dynamic]"
echo -e "------------------------------------------"
echo -e " device: $default_interface"
echo -e " ipaddr: $ip"
echo -e "netmask: $mask"
echo -e "gateway: $gateway"
echo -e "    dns: $dns"
echo -e "------------------------------------------"
echo -e ""
# set last ip to 200
IFS='.' read -r -a array <<< "$ip"
array[3]=200
newip=$(IFS=. eval 'echo "${array[*]}"')

#网络配置
cp /etc/sysconfig/network-scripts/$cfg_name /etc/sysconfig/network-scripts/$cfg_name.bak

sed -i "/.*dhcp.*/d" /etc/sysconfig/network-scripts/$cfg_name
echo "IPADDR=$newip"             >> /etc/sysconfig/network-scripts/$cfg_name
echo "NETMASK=$mask"             >> /etc/sysconfig/network-scripts/$cfg_name
echo "GATEWAY=$gateway"          >> /etc/sysconfig/network-scripts/$cfg_name
echo "DNS1=114.114.114.114"      >> /etc/sysconfig/network-scripts/$cfg_name

ifdown $cfg_name && ifup $cfg_name
sleep 5
ping -c 4 www.baidu.com
if [ $? != 0 ]
then
     echo -e "Error! Cant link to Internet"
fi

echo "current ip is $newip"
```

这里仍然是直接设置成200，实际使用的时候可以根据情况编辑。
