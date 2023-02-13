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
* `kubectl patch`直接给API对象打补丁，补丁有具体的语法，详情可以查询文档；

## k8s编排原理

### Pod原理

Pod是一个逻辑概念，并没有对应的实体，实际操作的仍然是容器，或者说Linux Namespace和CGroup.一组共享网络Namespace的Pod，并且可以共享Volume的容器，被称为Pod.

所有pod，k8s都需要先创建一个*Infra container*，其他容器共享该容器的网络Namespace，这个容器由汇编语言写成，永远处于暂停状态，所以消耗的资源极少。pod的生命周期与infra容器一致，用户容器的进出流量也可以视为通过infra容器完成。

正是因为有了infra容器这个隐藏的container，Volume才可以定义在pod层级。

Pod的定义，一方面是为了调度方便（多个容器），另一方面是为了所谓的**容器设计模式**。也就是容器=进程，pod=进程组/虚拟机的设计。

通过`initContainers`，可以在pod中预定义多个容器，用来初始化环境，需要注意`initContainers`每次都会启动，如果是一次性的初始化需要检测是否需要跳过。

initContainers一定会先于pod启动，并按着定义的顺序严格执行；但是**containers里面规定的多个容器则没有明确的启动顺序**，所以如果有依赖问题，需要检测指定容器是否已经就绪。

多个container协作的设计模式，又称为**sidecar模式**。

### Pod字段

按着Pod=虚拟机这种模拟来理解，很容易明白哪些配置需要定义在pod级别，哪些是container级别。一些pod级别的常用字段（spec下面）：

* `nodeSelector`，调度条件，如`diskType:ssd`，标明该pod只能在打有这个标签的节点上被调度。已废弃，使用`affinity.nodeAffinity`代替；
* `nodeName`，这个字段是k8s赋予的，有值的时候就会认为已调度；
* `hostAliases`，host定义；
* `containers`，容器级别的定义；
* `volumes`，卷声明；
* `terminationGracePeriodSeconds`，优雅关闭等待时长；
* `backoffLimit`，最大重启次数；
* `activeDeadlineSeconds`，最大运行市场（一般Job里面使用）；

volumes声明为`emptyDir:{}`，则会在宿主机上创建一个临时目录绑定到该volume的name上；volumes也可以声明为`hostPath`，通过`path: /xxx`来直接映射宿主机的目录。这两种volume是最常用的的，但是数据卷有时候需要分布式文件系统，此时就要使用其他方式（如PVC）来声明了。

container级别的常用字段：

* `imagePullPolicy`，默认是always，可以设置为`never`或者`ifNotPresent`；
* `lifecycle`，生命周期，如：`postStart`、`preStop`，用于定义容器生命周期各个阶段回调的命令；需要注意的是`postStart`启动的时候，容器的CMD可能还未结束；
* `livenessProbe`，存活探针。支持http探测（200或者其他）或者bash命令（通过返回0或者非0）探测，甚至tcp探测（端口存活）；
* `readinessProbe`，
* `restartPolicy`，重新创建pod的策略，默认是`Always`，可以设置为`OnFailure`或者`Never`。注意`onFailure`的条件是所有容器都异常了，`Always`则是任意一个容器异常；如果需要保留案发现场，则可以设置为Never；
* `volumeMounts`，卷挂载。将pod级别的卷声明根据需要挂载到容器里，通过`mountPath`指定挂载路径；
* `resources`，容器的资源声明，`requests`和`limits`来声明最小和最大限制；

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

* `Secret`: 将密码保存在etcd里，可以打开加密；
* `ConfigMap`: 一般的配置；
* `Downward API`: 将pod的信息暴露到容器里，必须是容器启动前就能确定下来的信息，不支持运行时更改；

以上都是通过`kubectl create xxx`创建（或apply），然后通过volume挂载到pod中。当然也可以通过环境变量注入，但是后者不具备自动更新的能力。

ServiceAccoutToken是一种特殊的Secret，k8s默认会隐式注入到所有容器里，这样容器中的应用可以通过kubectl控制k8s.

### Deployment

用于部署的API对象，pod水平伸缩滚动更新依赖于该类API对象。

Deployment并不是直接控制Pod对象，而是通过Replica对象来控制。

对于用户而言，就是通过`replicas`定义副本数量，通过`spec.selector.matchLabels`匹配pod定义。

然后`apply`就行，k8s会自动完成滚动更新，相关命令：

* `kubectl rollout undo`，版本回滚；
* `kubectl rollout history`，查看版本历史；
* `kubectl rollout undo xxx --to-revision=N`，回滚到某个具体的历史版本；
* `kubectl rollout pause`和`kubectl rollout resume`，暂停部署和恢复部署；

通过查看deployment对象的状态可以确定部署是否完成。

这里k8s的工作原理类似一个死循环，不断检查API对象的状态，如果不满足yaml中的声明，就动态调整直到满足为止。

### StatefulSet

与ReplicaSet对应的有状态Pod，主要指代两种状态：

1. 拓扑状态，即pod有严格的启动顺序，重建需要保持顺序的问题。这个statefulSet默认就能解决。解决方式是对pod赋予唯一的名称(hostname：`<name>-N`，N是编号)，访问pod通过headless service对应的唯一域名来访问，创建pod时保持名称不变即可；
2. 存储依赖，即应用有需要落地的数据，当pod重建后能恢复这些数据；这个需要其他技术来辅助；

由于Volume的编写过于复杂，所以这里又抽象出两个新概念：

* PVC: PersistentVolumeClaim，即对存储的需求描述，大小、挂载方式等；在volume中只要指定这个pvc就行；
* PV：真正的volume细节，一般是运维编写；

PVC例子：

```yaml
spec:
  volumes:
    - name: pv-storage
      persistentVolumeClaim:
        claimName: pv-claim
```

实际使用中一般只需要说明需要的PVC：

```yaml
spec:
  volumeClaimTemplate:
  - metadata:
      name: xxx
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi
```

这里就指定了权限和大小，k8s会自动寻找合适的PV绑定到PVC上，PVC的名字是`xxx-<podname>`.

所以对于第2个问题，直接指定PVC即可。由于绑定到Pod的PVC的命名也有与Pod相同的编号，重建pod时找到符合该规律的PVC挂载上去即可。

特别注意的是，`StatefulSet`要求使用同一个容器镜像，如果容器镜像不同，需要使用`Operator`.既然是同一个镜像，那么按着pod名称中的序号0,1,2...就可知道启动的顺序，这样就可以把需要先启动的放前面。常见的需求是主从集群，0为主，1,2为从这种设计。

StatefulSet的滚动更新与ReplicaSet不同，有严格的销毁和启动顺序，销毁按着序号倒序进行。可以在`rollingUpdate`里按序号指定部分更新（灰度）。

### DaemonSet

宿主机守护进程，在k8s上每个节点上都会运行且只运行一个pod，当然“每个节点”不是很准确，应该是拥有满足`spec.selector.matchLabels`筛选pod的每个结点。

DaemonSet启动的很早，因此可以通过`spec.tolerations`指定污点来忽略某些限制。

类似Deployment，支持版本管理。不同的是，Deployment的一个版本对应一个ReplicaSet，DaemonSet直接控制Pod，所以实现方式不一样。

DaemonSet版本管理使用的对象是`ControllerRevision`， 可以通过`get`/`describe`该对象查看具体的版本信息。StateFulSet也是使用该对象实现版本管理的。

### Job和CronJob

一次性或者周期性调度的任务。Job直接控制Pod，CronJob则控制Job. 一些特殊字段：

* `spec.parallelism`定义job可以启动多少个pod进行并发计算；

* `spec.completions`定义job至少完成的pod数目；
* `spec.concurrencypolicy`，cronjob对job重合的处理，默认为`Allow`，可以设置为`Forbid`或者`Replace`；

CronJob的最小检查周期是10s，定义最小周期则是1分钟。

如果从上次运行时间到现在，CronJob创建失败次数超过了100，这个CronJob将不会再被调度；如果设置了`spec.startingDeadlineSeconds: n`，则检查的时间点就会固定到n秒之前，次数则固定是100，不可设置。这个参数还表示cronJob容许的延迟启动时间。

### 声明式API

前文已经说过，尽量是用`kubectl apply`来实现CURD，而不是直接用`create/replace/patch`等命令，这是因为有并发处理同一个API对象的情况。k8s会在apply时自动处理各种冲突，最终达到需求的状态。

### 自定义API资源

即CRD(custom resource definition)，用户可以自定义API对象，格式如下：

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: network.samplecrd.k8s.io
spec:
  group: samplecrd.k8s.io
  version: v1
  names:
    kind: Network
    plural: networks #复数
  scope: Namespaced
```

这里需要做一些云原生开发，即golang写插件。由于涉及到编程，此处细节会单独开blog来写。

### RBAC

k8s的权限控制也是基于RBAC制定的，主要概念：

* Role：角色，对应了具体的权限集；
* Subject: 主题，被赋予角色的对象；
* RoleBinding：上面两个的绑定关系；

Role的定义格式：
```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: mynamespace # 必须指定namespace，默认是default
  name: example-role
rules:
  - apiGroups: [""]
    resources: ["pods"] # 资源组
    resourceName: ["mysql"] # 资源的名称
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]  # 权限动词
```

RoleBinding的定义：

```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: example-rolebinding
  namespace: mynamespace # 也必须指定namespace
subjects:
  - kind: User
    name: example-user
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: example-role
  apiGroup: rbac.authorization.k8s.io
```

如果想在所有namespace里都生效，需要使用`clusterRole`和`clusterRoleBindings`.

与User相比，习惯上更多使用`ServiceAccount`来分配权限，用户在pod里通过`spec.serviceAccountName`来引用该对象。

### 准入控制器

Admission Controllers，在RBAC校验通过之后，对象被持久化之前调用，主要用来过滤非只读请求。

可以通过webhook自定义准入控制器。

### Operator

由于有状态服务过于复杂，经常需要在yaml里面写逻辑。所以另外一种更编程友好的方法是使用Operator来完成。这其实就是一种CRD配合自定义控制器的完全自定义方式。

涉及到编程，这里不再赘述。一般Stateful搞不定的，就要使用Operator来定义了。

## k8s存储原理

PV和PVC的匹配机制：

* PV必须满足PVC的大小限制；
* 二者的`storageClassName`必须一致（如果没声明，则为空字符串）；

k8s中专门处理持久化存储的控制器叫`Volume Controller`，其维护多个控制循环，其中一个循环会持续尝试绑定PV和PVC，即`PersistentVolumeController`.所谓绑定，就是将PV对象的名字填入PVC的`spec.volumeName`字段。

### Dynamic Provisioning

人工创建PV的方式被称为`Static Provisioning`，只能对小规模集群使用人工管理。

动态分配的核心在于名为`StorageClass`的API对象，其定义主要包括两个部分：

* PV的属性，如存储类型、Volume的大小等；
* 所需存储插件，如Ceph等，对应字段是`provisioner`；

k8s官方支持存储插件很多，如果实在是不支持，也可以自己开发。

### Local PV

直接使用宿主机磁盘的PV，理论上IO性能最好，但是存在数据丢失风险。使用时需要注意：

1. 一个PV一块盘，不应当使用宿主机的主硬盘；
2. 只能使用Static Provisioning，即预先创建PV才能绑定到PVC；
3. 需要延迟绑定，通过`StorageClass.volumeBindMode: WaitForFirstConsumer`延迟PV和PVC的绑定；

PV示例：

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage # 存储类
  local:
    path: /mnt/disks/vol1
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions: # pod仅能在当前节点运行
          - key: kubernetes.io/hostname
            operator: In
            values:
              - node-1
```

StorageClass示例：

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer # 延迟绑定声明
```

最后删除PV的顺序：

1. 删除使用PV的Pod；
2. 移除磁盘(unmount);
3. 删除PVC；
4. 删除PV；

可以通过k8s的StaticProvisioner来自动化LocalPV的相关操作。

### CSI插件编写

涉及到编程，先跳过

## k8s网络原理

容器的network namespace默认是隔离的，通信需要经过交换网络。

docker的实现方式是在宿主机创建一个名为docker0的网桥，网桥工作在二层网络，根据mac地址转发数据包。

然后docker为每个容器创建一对Veth Pair，这种虚拟设备成对出现，都插在docker0网桥上，一端在宿主机里，另一端在容器里(eth0)。发往任一端的数据包，在另一端都能收到，且无视namespace隔离。

对于跨主机网络，这个docker0就力不能及了，这时候就需要Flannel项目出马。

### Flannel

该项目是一个框架，有多种后端实现，用于解决跨主机容器通信问题。

#### UDP后端

flannel进程会在每个宿主机上监听一个UDP端口，并创建一个名为`flannel0`的虚拟设备，这是一个3层TUN设备，主要作用是在OS kernel层和user层之间传递ip数据包，具体来说就是将ip包在内核和flannel进程之间传递。

每个宿主机上的容器都属于该宿主机被分配的子网，flannel进程可以根据目标ip地址对应的子网找到其宿主机，然后将ip包转发给对应宿主机的flannel进程即可。后者会将数据包传入内核，根据路由表将数据转给docker0网桥。

由于数据需要多次在内核态和用户态之间切换，导致性能太低，所以已被逐渐废弃。

### VXLAN后端

非常类似UDP后端，VXLAN会在宿主机上设置一个特殊的网络设备`VTEP`，不过它是工作在二层。

### k8s对上述方案的兼容

k8s肯定不会直接用docker0，而是通过CNI接口来进行网络通信，默认创建的网桥是`cni0`.

为宿主分配子网可以使用`kubeadm init --pod-network-cidr=<ipv4/n>`来指定，也可以创建完成之后通过`kube-controller-manager`来指定。

CNI具体的配置须放在宿主机的`/etc/cni/net.d/`中，格式类似：

```js
{
    "name": "cbr0",
    "plugins":[
        {
            "type": "flannel",
            "delegate":{ //托管给内置的插件
                "hairpinMode": true, //打开发夹模式，允许自己访问自己
                "isDefaultGateway": true
            }
        },
     	{
            "type": "portmap",
            "capabilities":{
                "portMappings": true,
            }
        }
    ]
}
```

容器网络相关的逻辑并不在`kubelet`中，而是在具体的CRI中，对于docker就是`dockershim`，目前已经弃用。

目前k8s网络不支持多个CNI复用。

Infra容器创建之后会执行`SetUpPod`，该函数用于为CNI插件准备参数。对于flannel，他需要的参数分为两部分：

* 各种环境变量，其中最重要的是CNI_COMMAND，可选的值是DEL或者ADD，表示把容器添加到CNI网络，或者从中移除；
* 上面配置文件中的配置信息；

参数加载完毕之后，CRI就会调用CNI插件，对于flannel而言，由于这个插件是内置在k8s网络里，所以实际上只是对配置参数做了一些补充。

之后，CNI插件就会调用bridge插件，后者会检查CNI网桥是否存在，没有则创建一个cni0. 之后，创建Veth Pair，将其中一端放在宿主机上，另一端放在infra容器里。

特别注意在infra容器的那段需要设置`hairpinMode: true`，即允许容器通过Service自己访问自己。

之后bridge插件调用ipam插件，为容器分配子网中某个ip地址，并绑定到容器的eth0上。

最后，CNI插件将ip地址这些信息返回给CRI，kubelet再将这些信息添加到Pod的相关字段上。

### host-gw后端

将宿主机ip作为flannel子网的下一条地址，即将宿主机当做路由器来用。这个思路其实类似物理组网。

优势是性能损失更低（10%左右），缺点是要求宿主机集群之间二层互通，而VXLan仅要求三层互通。一般公有云环境更推荐这种模式。

对于复杂项目，可以考虑使用calico项目，该项目使用BGP协议进行大规模路由表维护，避免人工维护成本。

由于BGP网络极其复杂，这里不再详述。

### 网络隔离

k8s通过API对象`NetPolicy`来控制网络隔离，该对象通过`spec.podSelector`来匹配pod，并进行白名单管控。

使用起来其实很类似IaaS中的“安全组”。

### Service原理

service是由kube-proxy和iptables共同实现的。

推荐打开kube-proxy的IPVS模式以提高性能，纯iptables在大量pod时性能较差。

Service的`spec.type`支持以下几种模式：

* ClusterIP，最常用的的模式。如果设为None，则为headless模式，否则通过随机负载均衡访问；
* NodePort，强行暴露pod的端口到宿主机；每个节点只能部署一个pod示例；
* LoadBalancer，对接公有云时使用；
* ExternalName，类似在DNS中直接加CNAME；
* ExternalIp，直接在`spec.externalIps`里面声明可以访问的ip地址，该地址会路由到对应的service；

对于4层协议，如果想获取客户端的真实ip，需要将`spec.externalTrafficPolicy`设置为local.

### Ingress对象

即总的负载均衡入口。

