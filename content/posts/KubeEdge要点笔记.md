---
title: KubeEdge要点笔记
description:
toc: true
authors: ["tryao"]
tags: ["k8s","edge"]
categories: []
series: []
date: 2023-02-21T15:07:54+08:00
lastmod: 2023-02-21T15:07:54+08:00
featuredVideo:
featuredImage:
draft: false
---

## 安装流程

首先要在云端安装k8s，理论上只需要master节点，可以没有worker，换句话说可以是一个单节点集群（但是要关闭NoSchedule的taint）。

k8s迭代的非常快，kubeEdge适配的版本会落后3~4个大版本，因此k8s的版本不能太新。这里使用的是k8s v1.22.16，对应的是kubeEdge的v1.12.2. 事实上我先尝试了v1.23+1.13的组合，但是kubeEdge的代码质量确实不太行，1.13甚至无法正常卸载…

另外，注意并不能用k3s代替k8s来充当master，至少用keadm来安装是不行的。

这里使用helm来安装，因为用二进制安装很麻烦，keadm不像kubeadm那样支持直接使用配置文件初始化，而且**keadm安装时需要翻墙**，这是一个golang写的二进制文件，而不是bash脚本，没法直接改，在云上翻墙十分麻烦，我放弃了。

#### 云端

从[这里](https://github.com/kubeedge/kubeedge/tree/master/manifests/charts)将整个cloudcore文件夹clone下来（或者用[这个](https://download-directory.github.io/)工具打包)，上传到服务器。然后编辑`values.yaml`，修改镜像版本（我这里用的是v1.12.2），并填入服务器地址（advertiseAddress那里），最后跑一下：

```
helm upgrade --install cloudcore ./cloudcore --namespace kubeedge --create-namespace -f ./cloudcore/values.yaml
```

当然是在文件夹外面一层跑。

等到pod成为running状态，用`ss -nalp|grep 1000`可以看到`10001-10004`，就说明部署成功了。此时运行`keadm gettoken`获取云端join token备用。

如果上面出现问题， 可以先卸载：

```bash
helm uninstall cloudcore -n kubeedge
kubectl delete ns kubeedge
```

重新配置之后再安装即可。

### 边缘端

边缘端只能使用docker来安装，因此先安装好docker并配置：

```js
// /etc/docker/daemon.json
{
    "registry-mirrors": [
        "https://dockerproxy.com",
		"https://mirror.baidubce.com"
    ]
}
```

然后下载keadm的二进制文件并上传到机器，注意应该和上面helm安装的服务端版本一致。

然后运行：

```bash
keadm join --cloudcore-ipport=192.168.3.202:10000 --token=cc8a5df855bb7b6a2e407f0dd9f81fa3152b4e3a25b7360871c79b4938972464.eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2Nzc0NjM1NjR9.UqJNchqPc-9SKhhQaXzcMx0HnMZ4ZL6F81RjNV-9B_A
```

在云端查看nodes，可以看到edge.

如果云端使用containerd，边缘端最好改成一致的，在运行keadm join时，可以指定`-r containerd`

在边缘端运行`journalctl -u edgecore`，以及`systemctl status edgecore`，一切正常即说明安装完毕。

