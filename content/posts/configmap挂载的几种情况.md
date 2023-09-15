---
title: Configmap挂载的几种情况
description:
toc: true
authors: [“tryao"]
tags: ["k8s"]
categories: []
series: []
date: 2023-09-15T09:33:41+08:00
lastmod: 2023-09-15T09:33:41+08:00
featuredVideo:
featuredImage:
draft: false
---

ConfigMap挂载的用法比较多，很容易记混淆，这里简单做个梳理：

## 将某个key的值挂载为环境变量

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-test-pod
spec:
  containers:
    - name: test-container
      image: gcr.io/google_containers/busybox
      command: [ "/bin/sh", "-c", "env" ]
      env:
        - name: SPECIAL_LEVEL_KEY
          valueFrom:
            configMapKeyRef:
              name: special-config
              key: special.how
        - name: SPECIAL_TYPE_KEY
          valueFrom:
            configMapKeyRef:
              name: special-config
              key: special.type
              optional: true
  restartPolicy: Never
```

这里在`command`里可以通过`$(SPECIAL_TYPE_KEY)`的格式来引用这些环境变量作为命令行参数。

## 整个ConfigMap挂载为目录

这种情况最简单，每个key都会生成一个同名文件：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-test-pod
spec:
  containers:
    - name: test-container
      image: gcr.io/google_containers/busybox
      command: [ "/bin/sh", "-c", "cat /etc/config/special.how" ]
      volumeMounts:
      - name: config-volume
        mountPath: /etc/config
  volumes:
    - name: config-volume
      configMap:
        name: special-config
  restartPolicy: Never
```

## 将某个key挂载为文件

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-test-pod
spec:
  containers:
    - name: test-container
      image: gcr.io/google_containers/busybox
      command: [ "/bin/sh","-c","cat /etc/config/special-key" ]
      volumeMounts:
      - name: config-volume
        mountPath: /etc/config
  volumes:
    - name: config-volume
      configMap:
        name: special-config
        items:
        - key: special.how
          path: path/to/special-key
  restartPolicy: Never
```

如果`/etc/config`下有同名文件（使用path中最后一级为文件名，这里即`special-key`），会覆盖掉。

默认情况下`key`的名字和`path`是一样的，可以不指定`path`，而修改path相当于对key进行了**重命名**。

## 多个ConfigMap挂载到同一个目录

直接使用上面的方法，如果多个configmap需要挂载到同一个目录，后挂载的会将之前的覆盖掉，必须使用`subPath`来解决这个问题：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-test-pod
spec:
  containers:
    - name: test-container
      image: gcr.io/google_containers/busybox
      command: [ "/bin/sh", "-c", "cat /etc/config/special.how" ]
      volumeMounts:
      - name: config1
        mountPath: /etc/config
        subPath: key1
      - name: config2
        mountPath: /etc/config
        subPath: key2
  volumes:
    - name: config1
      configMap:
        name: configmap1
    - name: config2
      configMap:
        name: configmap2
  restartPolicy: Never
```

这里就是从`configmap1`中选出key为`key1`的键值挂载到`/etc/config`下，然后又从`configmap2`中选出`key2`挂载。

这里的`subPath`起到筛选的作用，如果对应的key不存在，则什么都不挂载。但是pod内会创建`mountPath`指定的文件夹。`subPath`需要和`path`保持一致才能正确匹配到，而不是和`key`进行匹配。

## 特殊情况

如上文所述，正常情况下，使用`path`进行重命名；`mountPath`指定存储目录，`subPath`则进行筛选。

但是如果在`mountPath`里面直接指定文件名，则会对最终挂载的**文件**再次进行重命名。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-test-pod
spec:
  containers:
    - name: test-container
      image: gcr.io/google_containers/busybox
      command: [ "/bin/sh","-c","cat /etc/config/special-key" ]
      volumeMounts:
      - name: config-volume
        mountPath: /etc/config/x.txt
        subPath: path/to/special-key
  volumes:
    - name: config-volume
      configMap:
        name: special-config
        items:
        - key: special.how
          path: path/to/special-key
  restartPolicy: Never
```

如上，最终挂载的文件会变成`x.txt`，而不再是`special-key`.

说实话这个技术最好不要用到，通过path重命名+subPath筛选，就能满足需求了。使用mountPath直接指定文件名这个方法有点绕，容易造成误解。