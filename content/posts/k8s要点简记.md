---
title: K8s要点简记
description:
toc: true
authors: ["tryao"]
tags: ["k8s"]
categories: []
series: []
date: 2023-02-10T09:30:19+08:00
lastmod: 2023-02-10T09:30:19+08:00
featuredVideo:
featuredImage:
draft: false
---

22年的时候需要使用CICD的时候，看了一遍k8s相关的知识点。买了一本《深入剖析Kubernetes》，大致熟悉了常用的概念。

最近因为工作调动需要做云原生相关的开发，有必要重新复习一遍相关概念，并深入部分章节的细节。

## 容器部分

### 容器原理

容器是云原生时代的进程。

之前大家都是在ECS这种虚拟机里面部署应用，操作系统一般是CentOS/Debian之类的Linux系统，服务通过Supervisor/Systemd等进程管理工具进行管理，CPU/内存等容量规划是以虚拟机为单位的，环境一般使用bash/python脚本进行初始化，监控、服务集群扩容和缩容都是运维手动配置。

容器最开始是为了解决环境问题（为应用创建隔离的运行环境），有点类似Python的virtualEnv，它的底层原理是基于Linux的资源隔离机制，也就是：

1. Namespace. 通过`clone`创建进程时，可以传入`CLONE_NEWPID`参数，此时这个进程会“看到”一个新的进程空间，在这里他的进程pid是1。在这个进程空间里，它是被隔离的，只能看到操作系统配置的东西；当然在宿主机看来这就是一个普通的进程；
2. CGroups. 用来为进程设置资源限制，如内存、CPU、磁盘、带宽等，同时还具有优先级设置、审计以及进程挂起、恢复等功能；cgroups通过文件系统实现，可以在`/sys/fs/cgroup`下看到各种资源目录，在里面建立文件夹，系统会自动创建对应的资源限制文件；将进程pid写入`tasks`即可；
3. rootfs. 用来与宿主机隔离文件系统，基于Linux的`pivot_root`/`chroot`指令；

显然，宿主机上所有容器共享同一个内核。

Docker on Windows/Mac实际是基于kvm实现的，和linux的docker完全不同。

### 镜像原理

docker所谓的镜像，其实就是一种rootfs的压缩包，它的创新点主要是引入了层(`layer`)的概念，后者就是增量的rootfs。

docker通过联合挂载(union mount)技术将这些层挂载到统一的挂载点上，这通过文件系统的支持（如AuFS）来实现。

镜像从下到上分别是只读层、Init层和读写层：

* 一般只读层就是操作系统镜像，如`ubuntu:latest`;
* Init层是启动时写入容器的配置，如hostname、hosts等；
* 可读写层则是普通用户创建镜像时修改的部分；

由于只读层的文件不能真正被修改或者删除，所以可读写层如果想要修改只读层的东西，aufs实际上是通过创建`whiteout`文件，把只读层的文件遮挡起来。比如`foo`文件对应的位置创建一个`.wh.foo`文件，这种屏蔽一般称为白障。只读层的挂载方式也称为`ro+wh`.

Docker用来制作rootfs的工具称为`Dockerfile`，例如：

```dockerfile
From python:2.7-slim
WORKDIR /app
ADD . /app
RUN pip install --trusted-host pypi.python.org -r requirements.txt
EXPOSE 80
ENV NAME world
CMD ["python", "app.py"]
```

这是一个python服务的打包过程，同目录应当有`app.py`和`requirements.txt`两个文件，进入目录，通过`docker build -t <tag> .`命令即可生成docker镜像。

### 常用命令

使用`docker run -p 4000:80 helloworld`来运行镜像，并将镜像的80端口映射到宿主机的4000端口。

使用`docker ps`命令即可看到在运行的进程。如果在镜像里做了某些操作，想要把正在运行的镜像提交成一个新的镜像，可以使用`docker commit`命令。

可以通过`docker inspect --format '{{.State.Pid}}' <container-id>`命令，获取宿主机上容器的pid.在`/proc/<pid>`下面可以看到宿主机上该容器相关的进程文件。

运行`docker exec -it <container-id> /bin/sh`可以进行镜像的bash，进行某些操作，该操作的原理是利用了`setns`的系统调用。

通过`--net container:<container-id>`参数可以将一个容器加入另一个容器的网络空间，如果是`--net host`则直接共享宿主机的网络栈。

docker镜像仓库可以使用公有的docker hub，也可以使用自建的harbor(vmvare做的).

### 文件系统打通

有时候宿主机和容器需要交换持久化数据，即文件访问。

Docker Volume用于将宿主机中文件挂载到容器内访问，一般通过`docker run`命令启动容器时，使用`-v <host-path>:<container-path>`传入挂载映射关系。

这个挂载实际上是在rootfs准备好之后，`chroot`执行之前，由`dockerinit`进程完成的。之后才是通过`execv`系统调用，让应用进程取代自己成为pid=1的容器进程。

## k8s设计概要

<img src="https://csceciti-iot-devfile.oss-cn-shenzhen.aliyuncs.com/docs/%E6%88%AA%E5%B1%8F2023-02-11%2020.48.41.png" alt="截屏2023-02-11 20.48.41" style="zoom:50%;" />

k8s由master和node两类节点构成，分别称为控制节点和计算节点。

master由3个组件构成，control-manager负责编排，apiserver提供接口，scheduler负责容器调度；

计算节点核心是kubelet组件，它与下面的容器运行时（如docker）通过CRI的接口来交互；和网络层以及存储层通过CNI和CSI的接口来交互。通过这些接口的抽象，可以更换底层实际的实现，所以在k8s中docker可以随时替换成别的运行时。

device plugin是k8s用来调度硬件（如GPU）的插件，kubelet通过gRPC与之交互。

k8s源自Google内部的borg系统，但是实际上后者并没有容器镜像这种东西，而是直接用Namespace+CGroup限制应用程序。borg对于k8s的指导作用主要体现在master节点上。

习惯上，k8s的使用方法是：

1. 通过一个任务编排对象（如pod、cronJob等）描述你的任务对象；
2. 为1中的人物定义一些运维能力对象，如Service/Ingress/HPA等；

这就是所谓的声明式API，1和2中的对象又称为API对象。

## k8s集群搭建

k8s的官方推荐部署工具是`kubeadm`（还有kOPs和Kubespray），建立集群的方式非常简单：

```bash
# init master
kubeadm init [--config kubeadm.yaml]
# join node to master
kubeadm join <master ip:port>
```

当然需要自己提前安装运行时（如containerd，如果使用DockerEngine则需要额外安装`cri-dockered`适配器），此外需要打开一些端口。master节点包括：

| 协议 | 方向 | 端口范围  | 目的                    | 使用者               |
| ---- | ---- | --------- | ----------------------- | -------------------- |
| TCP  | 入站 | 6443      | Kubernetes API server   | 所有                 |
| TCP  | 入站 | 2379-2380 | etcd server client API  | kube-apiserver, etcd |
| TCP  | 入站 | 10250     | Kubelet API             | 自身, 控制面         |
| TCP  | 入站 | 10259     | kube-scheduler          | 自身                 |
| TCP  | 入站 | 10257     | kube-controller-manager | 自身                 |

node节点包括：

| 协议 | 方向 | 端口范围    | 目的              | 使用者       |
| ---- | ---- | ----------- | ----------------- | ------------ |
| TCP  | 入站 | 10250       | Kubelet API       | 自身, 控制面 |
| TCP  | 入站 | 30000-32767 | NodePort Services | 所有         |

NodePort默认使用30000~32767的端口，这里可以根据需要开放。截止v1.26，k8s单个集群的限制如下：

- 每个节点的 Pod 数量不超过 110
- 节点数不超过 5,000，节点的主机名不能相同
- Pod 总数不超过 150,000
- 容器总数不超过 300,000

`kubeadm`在宿主机运行kubelet，然后使用容器化部署其他组件。

默认情况下kube-apiserver仅支持HTTPS通信，因此kubeadm会自动生成对应的证书，路径在`/etc/kubernetes/pki`；master节点其他组件的配置文件也都在`/etc/kubernetes`下。

kubeadm会通过pod的方式启动其他master组件，由于此时k8s集群还不存在，这里运行pod的方式是所谓的`static pod`，其yaml路径在`/etc/kubernetes/manifest`下。

之后，需要安装CNI和CSI的插件，使用`kubectl apply -f`命令即可。

习惯上，k8s通过使用kubectl命令，与api对象（即yaml文件）进行交互。

API对象有`Metadata`字段，即对象的元数据，其中`Labels`用来做标记该API对象筛选依据；而`Annotations`则一般是k8s在运行过程中自动添加在API对象上的。

pod是k8s最小运行单元，1一个pod可以包含多个容器（使用同一个namespace）。

## 常用命令

* `kubectl get`用来获取指定的API对象，如`kubectl get pods -l app=nginx`，用来通过label过滤pods；
* `kubectl describe`用来查看对象的详细信息，如`kubectl describe pod <pod-name>`；
* `kubectl create -f <name>`生成配置文件，name可以标明对象的种类，如`nginx-deployment.yaml`；
* `kubectl apply -f <name>`，应用配置。k8s会自动探测这种应用是更新还是创建；
* `kubectl delete -f <name>`，删除API对象；
* `kubectl exec -it <pod-name> -- /bin/bash`，类似`docker exec`，进入pod中（容器的namespace中）；
* `kubectl scale deployment xxx --replicas=N`，水平伸缩（直接apply一个deployment也可以）；
* `kubectl rollout status`，滚动查看API对象的状态；
* `kubectl edit`直接编辑etcd中的API对象定义；
* `kubectl set`直接修改某个字段，如`image`；

## k8s编排原理

### Pod原理

Pod是一个逻辑概念，并没有对应的实体，实际操作的仍然是容器，或者说Linux Namespace和CGroup.一组共享网络Namespace的Pod，并且可以共享Volume的容器，被称为Pod.

多个容器构成pod，需要先创建一个*Infra container*，其他容器共享该容器的网络Namespace，这个容器由汇编语言写成，永远处于暂停状态，所以消耗的资源极少。pod的生命周期与infra容器一致，用户容器的进出流量也可以视为通过infra容器完成。

正是因为有了infra容器这个隐藏的container，Volume才可以定义在pod层级。

Pod的定义，一方面是为了调度方便（多个容器），另一方面是为了所谓的**容器设计模式**。也就是容器=进程，pod=进程组/虚拟机的设计。

通过`initContainers`，可以在pod中预定义多个容器，用来初始化环境，这就是所谓的sidecar模式。

### Pod字段

按着Pod=虚拟机这种模拟来理解，很容易明白哪些配置需要定义在pod级别，哪些是container级别。一些pod级别的常用字段（spec下面）：

* `nodeSelector`，调度条件，如`diskType:ssd`，标明该pod只能在打有这个标签的节点上被调度；
* `nodeName`，这个字段是k8s赋予的，有值的时候就会认为已调度；
* `hostAliases`，host定义；
* `containers`，下面是容器级别的定义，当然；

container级别的常用字段：

* `imagePullPolicy`，默认是always，可以设置为`never`或者`ifNotPresent`；
* `lifecycle`，生命周期，如：`postStart`、`preStop`，用于定义容器生命周期各个阶段回调的命令；需要注意的是`postStart`启动的时候，容器的CMD可能还未结束；
* `livenessProbe`，存活探针。支持http探测（200或者其他）或者bash命令（通过返回0或者非0）探测，甚至tcp探测（端口存活）；
* `restartPolicy`，重新创建pod的策略，默认是`Always`，可以设置为`OnFailure`或者`Never`。注意`onFailure`的条件是所有容器都异常了，`Always`则是任意一个容器异常；如果需要保留案发现场，则可以设置为Never；

由于字段太多，开发人员编写API对象难度较大，此时运维人员可以预定义一些参数，这就是所谓的`PodPreset`。这也是一类API对象，他可以通过`spec.selector.matchLabels`匹配开发人员创建的API对象。注意preset需要先于pod创建。

### Pod的状态

即pod.status.phase

* Pending. API对象已创建成功，但是尚未调度成功；
* Running. API对象已调度成功；
* Succeed. 已成功执行，一般是Job节点；
* Failed. **所有**容器进程以非0状态码退出；
* Unknown. 未知状态，apiserver无法获取pod状态，一般是主从通信出了问题；

此外，还有一组conditions字段，包括：`PodScheduled`, `Ready`, `Initialized`和`Unschedulable`.两个字段需要结合来看。

### Pod配置

pod中用户容器的配置，一般通过`project volume`的方式注入进去，包括：

* Secret: 将密码保存在etcd里，可以打开加密；
* ConfigMap: 一般的配置；
* Downward API: 将pod的信息暴露到容器里，必须是容器启动前就能确定下来的信息，不支持运行时更改；

以上都是通过`kubectl create xxx`创建（或apply）. 也可以通过环境变量注入，但是环境变量不具备自动更新的能力。

ServiceAccoutToken是一种特殊的Secret，k8s默认会隐式注入到所有容器里，这样容器中的应用可以通过kubectl控制k8s.

### Deployment

用于部署的API对象，pod水平伸缩滚动更新依赖于该类API对象。

Deployment并不是直接控制Pod对象，而是通过Replica对象来控制。

对于用户而言，就是通过`replicas`定义副本数量，通过`matchLabel`机制匹配pod定义。

然后`apply`就行，k8s会自动完成滚动更新，相关命令：

* `kubectl rollout undo`，版本回滚；
* `kubectl rollout history`，查看版本历史；
* `kubectl rollout undo xxx --to-revision=N`，回滚到某个具体的历史版本；
* `kubectl rollout pause`和`kubectl rollout resume`，暂停部署和恢复部署；

通过查看deployment对象的状态可以确定部署是否完成。

这里k8s的工作原理类似一个死循环，不断检查API对象的状态，如果不满足yaml中的声明，就动态调整直到满足为止。

### StatefulSet

有状态Pod，主要指代两种状态：

1. 拓扑状态，即pod有严格的启动顺序，重建需要保持顺序的问题。这个statefulSet默认就能解决。解决方式是对pod赋予唯一的名称(`<name>-N`，N是编号)，访问pod通过headless service对应的唯一域名来访问，创建pod时保持名称不变即可；
2. 存储依赖，即应用有需要落地的数据，当pod重建后能恢复这些数据；这个需要其他技术来辅助；

由于Volume的编写过于复杂，所以这里又抽象出两个新概念：

* PVC: PersistentVolumeClaim，即对存储的需求描述，大小、挂载方式等；在volume中只要指定这个pvc就行；
* PV：真正的volume细节，一般是运维编写；

所以对于第2个问题，直接指定PVC即可。绑定到Pod的PVC的命名也有与Pod相同的编号，重建pod时找到符合该规律的PVC挂载上去即可。

