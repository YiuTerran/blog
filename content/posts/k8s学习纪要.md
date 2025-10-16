---
title: K8s学习纪要
date: 2019-02-17
lastmod: 2019-02-14
slug: 8b9616e
draft: false
author:
  name: tryao
tags: ["k8s"]
collections: []
toc: true
math: true
lightgallery: false
---

近两年来，由于互联网规模再次扩大，原有的分布式技术（SOA、ESB等）都存在各种各样的缺陷，不能满足日益复杂的需求，所以各种新概念和框架应用而生，目前服务端最流行的是将复杂业务拆分微服务化，以减轻业务和代码的复杂度。在运维端，使用k8s和docker进行快速部署、扩容、监控、编排、回滚等常见运维操作，同时使用istio等Service mesh组件，达到分布式事务、track、router、限流、断路等常见服务需求。

## k8s及其概念

k8s的架构有一点类似linux的分层技术，比较复杂，所以最好边学变实践，不然根本记不住。**API对象**是K8s集群中的管理操作单元。K8s集群系统每支持一项新功能，引入一项新技术，一定会新引入对应的API对象，支持对该功能的管理操作。例如副本集Replica Set对应的API对象是RS。下面是各种API对象：

### pod

Pod是在K8s集群中运行部署应用或服务的最小单元，它是可以支持多容器的。

### Node

节点是所有Pod运行所在的工作主机，可以是物理机也可以是虚拟机。工作主机的统一特征是上面要运行kubelet管理节点上运行的容器。

### RS

副本集，在MongoDB中有此概念，这里其实差不多。提供服务的高可用性。

### Deployment

即部署，可以是创建一个新的服务，更新一个新的服务，也可以是滚动升级一个服务。部署通过创建新的RS，将流量转移到新的RS，然后逐渐关闭旧的RS来实现。

### Service

客户端直接访问的服务对象，长期伺服型。每个Service会对应一个集群内部有效的虚拟IP，集群内部通过虚拟IP访问一个服务。在K8s集群中微服务的负载均衡是由Kube-proxy实现的。Kube-proxy是K8s集群内部的负载均衡器。它是一个分布式代理服务器，在K8s的每个节点上都有一个。

### Job

Job是K8s用来控制批处理型任务的API对象，有点类似Oracle数据库中的Job，例如定时任务等。

### DaemonSet

后台支撑服务集，运行存储，日志和监控等在每个节点上支持K8s集群运行的服务。

### PetSet

有状态服务集，显然RS是无状态的，这样才能迅速deployment。但是对于db对象，更新的时候显然不能把数据扔了，这时候就需要用PetSet新建一个同名的pod，然后挂载存储继续服务。

### Federation

集群联邦，为提供跨Region跨服务商K8s集群服务而设计，适用于超大规模集群。

### Volume

类似docker的存储卷，但是更加抽象，pod支持多种存储卷，包括各种云服务的存储（如s3等）

### PV和PVC

持久存储卷（声明），用以抽象具体的存储逻辑。

### Secret

Secret是用来保存和传递密码、密钥、认证凭证这些敏感信息的对象。

### Namespace

为集群提供隔离功能的命名空间。

### RBAC访问授权

集群的管理需要一定的授权控制，引入常见的RBAC API对象

## 单机搭建k8s环境

单机使用minikube进行环境搭建，首先使用包管理器安装minikube和推荐的驱动`hyperkit`（或者你装virtualbox也可以)，然后运行`minikube start --vm-driver=hyperkit`激活管理器。 在`demo`文件下创建`server.js`，内容如下：

```
var http = require('http');

var handleRequest = function(request, response) {
  console.log('Received request for URL: ' + request.url);
  response.writeHead(200);
  response.end('Hello World!');
};
var www = http.createServer(handleRequest);
www.listen(8080);
```

显然这个js只是简单的创建了一个对任意请求返回`hello world`的http服务器，然后在`demo`文件夹下创建`Dockerfile`，内容如下：

```
FROM node:6.14.2
EXPOSE 8080
COPY server.js .
CMD node server.js
```

显然这里就是简单的从node环境中导出8080端口并运行上面的`server.js`。运行`minikube dashboard`可以打开网页控制台查看相关信息。

使用`kubectl create deployment hello-node --image=gcr.io/hello-minikube-zero-install/hello-node`创建一个部署信息，使用`kubectl get deployments`获取部署信息，使用`kubectl get pods`获取节点信息，使用`kubectl get events`获取事件日志，使用`kubectl config view`查看配置信息。

使用`kubectl expose deployment hello-node --type=LoadBalancer --port=8080`根据刚才的结点创建一个Service，默认情况下pod只能通过内部ip访问，如果想要在k8s外部（即客户端）来访问pod，需要将其导出为服务。现在使用`kubectl get services`即可看到`hello-node`的Service。最后使用`minikube service hello-node`即可访问该服务。

最后，使用`minikube addons enable/disable xxx`即可打开/关闭附加服务。使用`kubectl delete service hello-node`

kubectl最常用的命令格式：

- kubectl get - list resources
- kubectl describe - show detailed information about a resource
- kubectl logs - print the logs from a container in a pod
- kubectl exec - execute a command on a container in a pod

## 搭建副本集

使用`scale`命令进行副本集的扩展：`kubectl scale deployments/kubernetes-bootcamp --replicas=2`

## 滚动升级

使用`set image`进行升级，使用`rollout undo`进行回滚
