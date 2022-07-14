---
title: Zabbix配置记录
description:
toc: true
authors: ["tryao"]
tags: ["zabbix", "devops"]
categories: []
series: []
date: 2022-07-13T12:21:28+08:00
lastmod: 2022-07-13T12:21:28+08:00
featuredVideo:
featuredImage:
draft: false
---

## 安装服务

这里演示的是物理机环境监控场景，容器场景还是更推荐k8s+prom来搞。

版本是zabbix6.0 LTS，官方已经不提供CentOS7的安装包了，所以这里推荐使用docker安装，后面升级也比较方便。

推荐直接在裸机上安装MySQL8，因为数据库用docker装的话，需要配置的东西有点多，而且不方便与其他服务共用。

**特别注意**：不要使用alpine镜像，会遇到稀奇古怪的问题。

这里直接贴出来`docker-compose.yaml`的最小化安装内容，不含`java-gateway`和`snmptraps`，因为我这里没有需要监控的java服务。

```yaml
version: '3'
services:
  zabbix-server:
    image: zabbix/zabbix-server-mysql:6.0-ubuntu-latest
    container_name: zabbix-server
    volumes:
      - /etc/localtime:/etc/localtime
      - /opt/zabbix/alertscripts:/usr/lib/zabbix/alertscripts
      - /opt/zabbix/externalscripts:/usr/lib/zabbix/externalscripts
    restart: always
    privileged: true
    environment:
      - ZBX_LISTENPORT=10051
      - DB_SERVER_HOST=10.20.121.5
      - DB_SERVER_PORT=3333
      - MYSQL_DATABASE=zabbix
      - MYSQL_USER=root
      - MYSQL_PASSWORD=123456
      - MYSQL_ROOT_PASSWORD=123456
      - ZBX_CACHESIZE=1G
      - ZBX_HISTORYCACHESIZE=512M
      - ZBX_HISTORYINDEXCACHESIZE=16M
      - ZBX_TRENDCACHESIZE=256M
      - ZBX_VALUECACHESIZE=256M
      - ZBX_STARTPINGERS=64
      - ZBX_IPMIPOLLERS=1
    ports:
      - "10051:10051"
    networks:
      zabbix-net:
  zabbix-web:
    image: zabbix/zabbix-web-nginx-mysql:6.0-ubuntu-latest
    container_name: zabbix-web
    volumes:
      - /etc/localtime:/etc/localtime
      - /opt/zabbix/font/simfang.otf:/usr/share/zabbix/assets/fonts/DejaVuSans.ttf
    restart: always
    privileged: true
    environment:
      - ZBX_SERVER_NAME=IoT-Zabbix
      - ZBX_SERVER_HOST=zabbix-server
      - ZBX_SERVER_PORT=10051
      - DB_SERVER_HOST=10.20.121.5
      - DB_SERVER_PORT=3333
      - MYSQL_DATABASE=zabbix
      - MYSQL_USER=root
      - MYSQL_PASSWORD=123456
      - MYSQL_ROOT_PASSWORD=123456
      - PHP_TZ=Asia/Shanghai
    ports:
      - "8080:8080"
    networks:
      zabbix-net:
    links:
      - zabbix-server
networks:
  zabbix-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.22.0.0/24
```

一点准备工作，首先是安装docker服务，这个就不提了，然后：

```bash
mkdir -p /opt/zabbix/{alertscripts,externalscripts,font}
```

找个中文字体上传到`/opt/zabbix/font`下面，将`/opt/zabbix/font/simfang.otf`这句改成上传的字体名字。

这里假设MySQL的用户名密码是`root:123456`，根据自己需要修改。地址记得使用内网地址，肯定不是localhost.

准备完成之后，在`docker-compose.yaml`所在目录使用`docker-compose up -d`启动服务即可。

使用`docker-compose logs -f`查看日志，如果更新了配置文件，重新运行`docker-compose up -d`进行更新即可。

然后访问8080端口，默认用户名密码是`Admin:zabbix`，没问题的话可以登进去了。

## 安装agent

推荐安装zabbix-agent2，去[阿里云的zabbix镜像](https://mirrors.aliyun.com/zabbix/)那里下载zabbix-agent2的安装包，然后直接安装即可。

安装完之后先`vim /usr/lib/systemd/system/zabbix-agent2.service`，将`User=zabbix`和`Group=zabbix`这两行都改成root。官方推荐的使用`override.conf`的方案我试了没用，不知道啥原因。

然后修改`/etc/zabbix/zabbix_agent2.conf`，把`Server`和`ServerActive`改成实际服务所在的网段/地址。此外，可以根据需要修改Hostname字段。

然后`systemctl enable zabbix_agent2 && systemctl start zabbix_agent2`启动agent并激活自启动。

由于agent在物理网络，zabbix-server在容器内运行，所以默认的`Zabbix Server`主机无法探测到agent，需要手动修改Host地址。

可以通过在`Zabbix Server`所在的主机上安装`zabbix-get`工具，来调试与agent所在机器的连接情况。

## 配置自动注册

在`配置-动作-Autoregistration actions`这里，添加一个动作，自动将符合条件的主机添加到主机群组和链接到模板(`Linux by Zabbix agent`)上。

## 创建模板

对自己的应用创建监控模板，主要是日志监控和Prometheus的Metrics监控。

日志监控参考官方文档即可，注意`logrt`只支持文件名正则，前面的文件路径必须是固定的。

Prometheus的监控也是直接看文档就行，注意需要先创建一个`HTTP代理`，这个是由服务端主动拉取的，和agent没啥关系。

然后再对HTTP代理获取的metric做预处理，需要新建若干个`相关项目`，在`PreProcessing`里面选择`Prometheus pattern`进行过滤即可。

## 配置告警

首先要在`管理-报警媒介类型`里面添加钉钉或者微信告警。写一个告警的脚本，然后将其放在`/opt/zabbix/alertscripts`下面。注意：如果是Python的脚本，必须在zabbix-server的容器里有Python环境才能运行，这个就要修改对应的docker file了。推荐使用`PyInstaller`打包成二进制文件，或者直接使用go来写脚本。

在消息模板里面填入消息的模板，例如钉钉可以使用markdown通知，所以配置问题发生和恢复的消息模板分别如下：

```
- **问题: {TRIGGER.NAME}**
- **状态: {TRIGGER.STATUS}**
- **等级: {TRIGGER.SEVERITY}**

- 主机名: {HOST.NAME}
- 监控取值: {ITEM.LASTVALUE} 
- 告警时间: {EVENT.DATE} {EVENT.TIME}
- 事件ID: {EVENT.ID}
```

```
- **问题: {TRIGGER.NAME}**  
- **状态: {TRIGGER.STATUS}**
- **等级: {TRIGGER.SEVERITY}**

- 主机名: {HOST.NAME}
- 监控取值: {ITEM.LASTVALUE}
- 告警时间: {EVENT.DATE} {EVENT.TIME}
- 恢复时间: {EVENT.RECOVERY.DATE} {EVENT.RECOVERY.TIME}
- 持续时间: {EVENT.AGE}
- 事件ID: {EVENT.ID}
```

然后去`管理-用户`里面，找到需要配置的用户，在报警媒介里增加一个告警条件，点击`更新`就完成了告警的配置。

## 自动发现服务实例

如果服务在一台机器上只部署一个实例，则直接创建模板，然后将模板关联到主机上即可。

但是经常有一台机器上跑多个服务实例的需求，比如Redis或者各种web服务，此时目录或者端口都是不固定的，想要监控就需要使用[自动发现(LLD)](https://www.zabbix.com/documentation/6.0/zh/manual/discovery/low_level_discovery)了。

这里以多个服务需要监控日志为例，首先写一个脚本获取这些动态的参数，对于日志而言主要就是日志的文件夹，下面是一个通过进程名获取文件夹和进程PID的脚本：

```python
#!/usr/bin/python3

import sys
import json
import subprocess
from os import path


def parse_env(process_name, work_dir):
    env = ""
    if 'test' in work_dir:
        env = 'test'
    elif 'dev' in work_dir:
        env = 'dev'
    if 'MediaServer' in process_name:
        env += work_dir[-2:]
    return env


def get_work_dirs(process_name):
    lines = subprocess.getoutput(
        ('''ps -fe|grep '%s' | grep -v grep|'''
         '''awk '{out=$2;for(i=8;i<=NF;++i){out=out" "$i};print out}' ''') % process_name)
    data = []
    for line in lines.splitlines():
        s = line.strip()
        parts = s.split(" ")
        pid = parts[0]
        for p in parts[1:]:
            if process_name in p:
                exe = p
                break
        dir = path.dirname(exe)
        if not dir:
            continue
        data.append({
            "{#WORK_DIR}": dir,
            "{#PID}": pid,
            "{#ENV}": parse_env(process_name, dir),
        })
    return data


if __name__ == '__main__':
    d = []
    if len(sys.argv) > 1:
        d = get_work_dirs(sys.argv[1])

    print(json.dumps(d, indent=2))

```

其中`parse_env`主要是用户填充监控项的名字，因为`WORK_DIR`一般比较长，不太适合直接放在标题里。

将`get_workdir.py`放在`/etc/zabbix/zabbix_agent2.d`下面，然后修改`zabbix_agent2.conf`，添加一个用户变量：

> UserParameter=workdir.proc[*],/etc/zabbix/zabbix_agent2.d/get_workdir.py $1

然后使用`zabbix_agent2 -R userparameter_reload`重载一下配置。

去zabbix server上使用类似`zabbix_get -s '127.0.0.1' -k 'workdir.proc[sip-server]'`的命令，查看返回的结果，一切正常说明自定义监控项已经扩展完毕。下面去zabbix上添加自动发现规则。

去`配置-模板`，选择或者新建一个模板，然后切到`自动发现规则`选项卡，点击创建发现规则。

标题随便写，类型选择`Zabbix客户端(主动式)`，然后关键是这里的键值，这里填入`workdir.proc[sip-server]`，即可获取`sip-server`这个服务相关的上下文。

后面的预处理、LLD宏，过滤器等选项卡，都是为了对脚本返回的数据做一些预处理。如果在脚本里面已经处理好，这里什么都不用做。

下面建立一个监控器原型，比如要监控日志里面的`ERROR`，就建立如下监控项：

- 名称：Sip Server {#ENV} Error Log
- 类型：Zabbix Agent(Active)
- 键值：`log[{#WORK_DIR}/logs/error.log,ERROR,,1000,skip,,120,,]`
- 信息类型：日志
- 更新间隔：10s
- 日志时间格式： yyyy-MM-ddThh:mm:ss

然后建立对应的触发器原型，这里我们设定只要出现`ERROR`就应该告警：

* 名称：SIP Service {#ENV} Error Log
* 等级：Average
* 问题：`find(/Video SIP Service/log[{#WORK_DIR}/logs/video-gb28181-sipserver-error.log,ERROR,,1000,skip,,120,,],10s,,"ERROR")=1`
* 恢复：`nodata(/Video SIP Service/log[{#WORK_DIR}/logs/video-gb28181-sipserver-error.log,ERROR,,1000,skip,,120,,],60s)=1`

即60s没有ERROR则自动恢复.

也可以在`图形原型`里面添加需要的图，这里就不写过程了。
