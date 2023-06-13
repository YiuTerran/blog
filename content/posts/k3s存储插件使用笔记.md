---
title: K3s存储插件使用笔记
description:
toc: true
authors: ["tryao"]
tags: ["k8s"]
categories: []
series: []
date: 2023-06-12T09:20:20+08:00
lastmod: 2023-06-12T09:20:20+08:00
featuredVideo:
featuredImage:
draft: false
---

## 原理

k8s存储主要依赖PV和PVC的机制，前者由运维人员声明可用的存储，如：

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 10.244.1.4
    path: "/"
```

后者是用户（开发人员）声明的需求：

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: manual
  resources:
    requests:
      storage: 1Gi
```

两者的匹配机制：

1. 存储要求的容量必须满足需求；
2. `spec.storageClassName`必须完全匹配；
3. 权限要求能够匹配上；

绑定成功之后，在Pod里面就可以正常使用这个PVC了：

```yaml
apiVersion: v1
kind: pod
metadata:
  labels:
    role: web-frontend
spec:
  containers:
    - name: web
      image: nginx
      ports:
        - name: web
          containerPort: 80
      volumeMounts:
        - name: nfs
          mountPath: /usr/share/nginx/html
  volumes:
    - name: nfs
      persistentVolumeClaim:
        claimName: nfs
```

1. `spec.containers.volumeMounts`这里将卷名为`nfs`的卷挂载到容器中的指定目录；
2. `spec.volumes`中声明了上面用的名为`nfs`的volume；
3. 上面那个volume实际上对应了`persistentVolumeClaim.claimName`；

k8s中内置了一个循环调度器，会定期检查并绑定PV和PVC，即使Pod启动的时候PVC还没有成功绑定PV，等到有合适可用的磁盘时也会自动绑定成功。

PV的实现方式非常多，主要包括**块存储**和**文件存储**两类，两者的区别是前者类似是磁盘，需要格式化成文件系统之后才能使用，后者则可以直接使用（如NFS）；

## Dynamic Provisioning

上面那种手动声明PV的方式，被称为Static Provisioning. 一般只有服务规模比较小的时候使用，大型集群里面有成千上万个pod，每个需要成百上千的PV，人工创建PV的成本太高，所以一般并不使用。

StorageClass是创建PV的模板，主要包括：

1. PV的属性，如存储类型、Volume的大小等；
2. 创建PV需要的插件，如Ceph等；

例如：

```yaml
apiVersion: ceph.rook.io/v1beta1
kind: Pool
metadata:
  name: replicapool
  namespace: rook-ceph
spec:
  replicated:
    size: 3
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: block-service
provisioner: ceph.rook.io/block
parametes:
  pool: replicapool
  clusterNamespace: rook-ceph
```

使用这个StorageClass:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: example
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: block-service
  resources:
    requests:
      storage: 30Gi
```

这里核心的就是`spec.storageClassName`这个字段，使用`kubectl apply -f pvc.yaml`，就可以看到对应的pvc了。

使用`kubectl describe pv <pvc-volume>`可以看到对应的PV.

需要注意的是，使用静态供应的时候，storageClassName是名称匹配的，并不是模板匹配。

## LocalPV

考虑到资源隔离和可用性等问题，不应直接把host-path用作LocalPV，一般情况下，一个LocalPV对应一个外挂磁盘。

LocalPV的格式很简单：

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /mnt/disks/vol1
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/hostname
            operator: In
            values:
              - node-1
```

显然上面的`local-path`指定了本地路径，下面的节点亲和性需求上强制要求了使用这个PV的Pod只能在`node-1`上运行。

如果将LocalPV声明为一个StorageClass，其格式如下：

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
```

上面其实就是k3s内置的LocalPV的格式（移除了metadata中的大部分内容），这里值得注意的是`volumeBindingMode`的延迟绑定设计。

通过`WaitForFirstConsumer`的声明，PV和PVC的绑定会被延迟到调度Pod的时候，而不是在声明PVC之后立刻绑定。这是由于节点亲和性的需求导致的。

使用这个StorageClass的PVC格式和普通的PVC并无二致：

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: example-local-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-path
```

## 移除PV

移除PV的流程和创建PV正好相反，如果是静态声明的LocalPV，流程是：

1. 删除使用PV的Pod；
2. 从宿主机移除挂载；
3. 删除PVC；
4. 删除PV；

静态创建/删除PV的流程都比较繁琐，可以使用k8s提供的`External Provisioner`中的某个静态Provisioner自动扫描磁盘完成PV声明。

## CSI

k8s中除了kubelet等几个核心组件之外，大部分组件都是插件化的，存储也不例外，可以自己根据CSI接口自行创建。

k3s默认的StorageClass `local-path`就是通过CSI自己实现的，`metadata.annotations.storageclass.kubernetes.io/is-default-class`设为`"true"`即可设置为默认StorageClass.

## k3s默认配置

刚说了k3s默认的`local-path`是一个LocalPV，他的默认数据路径其实在安装的时候可以修改，有个`--default-local-storage-path`的参数指明，如果不改的话默认是`/var/lib/rancher/k3s/storage`.

在k3s安装好之后，也可以通过修改`/var/lib/rancher/k3s/server/manifests/local-storage.yaml`中的`configmap`，将`nodePathMap`中的`paths`改为需要的路径。

k3s删除了k8s自带的大部分存储插件，如果是分布式文件存储，推荐使用`Longhorn`.

## Longhorn

官方文档见：https://longhorn.io/docs/1.4.2/，目前还是沙箱阶段。

安装使用helm3即可：

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version $LONGHORN_VERSION
kubectl patch sc longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

其中最后是将longhorn的default StorageClass配置取消掉，因为k3s默认是使用`local-path`的，没必要改成默认longhorn.

longhorn默认的配置可以在安装时修改，见[这里](https://longhorn.io/docs/1.4.2/advanced-resources/deploy/customizing-default-settings/)，大部分时候使用默认配置即可。如果有很多node，但是只有部分node想充当分布式存储服务器（建议最少3个），可以通过[NodeSelector](https://longhorn.io/docs/1.4.2/advanced-resources/deploy/node-selector/)进行修改。

安装完成之后可以通过ingress将其前端页面暴露出来，不过这个页面没有认证机制，有一定的安全风险：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-ingress
  namespace: longhorn-system
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: longhorn-frontend
            port:
              number: 80
```

上面的配置直接占用了ingress的根path，虽然github上说longhorn支持通过subpath访问，但是我实际测试的时候是一片空白页…

longhorn默认使用的磁盘路径是`/var/lib/longhorn`，一般我们会将数据盘直接挂载到这个路径下；或者你也可以根据[这里](https://longhorn.io/docs/1.4.2/volumes-and-nodes/multidisk/)的提示修改路径或者添加多磁盘支持。

longhorn需要配置的东西其实很少，直接创建PVC时指定StorageClass为`longhorn`即可。其他备份、快照等功能使用可以参考[这篇](https://mritd.com/2021/03/06/longhorn-storage-test)博客。
