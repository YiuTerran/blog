---
title: OpenEuler20安装达梦8数据库
date: 2026-01-05T15:16:49+08:00
slug: 987f986
draft: false
author:
  name: tryao
tags: ["devops"]
collections: []
toc: true
math: true
lightgallery: false
---

达梦8不支持docker安装，这里记录一下二进制安装的方式。

<!--more-->

在服务器上下载CentOS版本的镜像：

```
wget https://download.dameng.com/eco/adapter/DM8/202512/dm8_20251208_x86_CentOS7_64.zip
```

解压，之后有个iso文件，需要挂载到某个路径：

```bash
mkdir /soft
mount -o loop xxx.iso /soft
cp /soft/DMInstall.bin /tmp
umount /soft
# 安装目录
mkdir -p /data/dm
```

创建专用的用户：

```
groupadd -g 56781 dinstall
useradd -u 56781 -g dinstall -m -d /home/dmdba -s /bin/bash dmdba
chown dmdba:dinstall /data/dm /tmp/DMInstall.bin
chmod 755 /tmp/DMInstall.bin
```

切换到该用户并安装：

```
su dmdba
/tmp/DMInstall.bin -i
```

安装步骤：

1. 选简体中文
2. 无key，填n
3. 时区：y，默认时区21
4. 典型安装
5. 输入上面准备好的目录：/data/dm
6. 输入y

完成之后，切换到root用户，执行提示的*/dm/script/root/root_installer.sh*

下面初始化数据库实例（dmdba用户），假设数据直接放在home目录下：

```sh
dminit PATH=/home/dmdba/data EXTENT_SIZE=32 PAGE_SIZE=32 CASE_SENSITIVE=Y CHARSET=1 LOG_SIZE=1024 DB_NAME=DAMENG INSTANCE_NAME=DMSERVER PORT_NUM=5236 BLANK_PAD_MODE=0 SYSDBA_PWD=<YOUR_PASSWORD> SYSAUDITOR_PWD=<YOUR_PASSWORD>
```

具体参数可以使用`dminit help`查看。

初始化完成之后，使用root进入`/data/dm/script/root`下注册服务：

```bash
./dm_service_installer.sh -t dmserver -dm_ini /dmdata/DAMENG/dm.ini -p DMSERVER
```

这样，`/data/dm/bin`下就有一个二进制文件DmServiceDMSERVER，运行`./DmServiceDMSERVER start`启动数据库即可，默认端口5236。

运行命令行工具连接：

```bash
disql SYSDBA/<YOUR_PASSWORD>
```

之后创建表空间：

```sql
create tablespace portal datafile '/home/dmdba/data/DAMENG/portal.dbf' SIZE 128 AUTOEXTEND ON NEXT 100 MAXSIZE 10240;
```

表空间规定的是物理存储限制。

之后创建用户（数据库）：

```
-- 创建用户portal，设置密码和表空间
CREATE USER "portal" IDENTIFIED BY "9fVBpXJqRaFY" DEFAULT TABLESPACE "PORTAL";
```

给用户授权：

```
GRANT "PUBLIC", "RESOURCE" TO "portal";
```

用户会自动创建同名的schema，使用该用户连接即可建表。
