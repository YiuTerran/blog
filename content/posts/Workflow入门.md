---
title: Workflow入门
date: 2020-05-21
lastmod: 2020-06-07
slug: 5d82301
draft: false
author:
  name: tryao
tags: ["java"]
collections: []
toc: true
math: true
lightgallery: false
---

目前业务需要引入工作流引擎，现在开始调研相关技术和概念。目前开源的工作流引擎基本都是base在BPMN这套概念上的，所以对其深入了解是必须的（其实也很简单）。

入门文档最好的材料是[国产的某个paas官方中文文档](https://docs.awspaas.com/reference-guide/aws-paas-process-reference-guide/index.html)，比较翔实。

## 选型

这块其实可选的很少，最知名的是Activiti，目前最新版本是7，亮点是支持k8s集成等云原生组件；然后就是Activiti早期版本fork出来的camunda；最后是Activiti后期版本fork出来的flowable.

这里我选择flowable，因为资料比较丰富，而且自带的前端界面有中文，方便内部使用。目前我们遇到的问题是不太清楚客户的具体需求，所以要使用工作流引擎保证可扩展性，但是不需要用户自己配置工作流（而是我们替他们配置好），所以自带的中文界面就比较重要了。这样是最简单快速的集成方案，后续可以自己实现一套前后端增删改查的接口，集成到自己的平台上。

那么这里主要描述如何将flowable集成到我们目前的系统里（一个SpringBoot项目，单db，暂时还没拆分成微服务）。

目标是：

1. 搞清楚如何通过自带的界面创建表单、流程；
2. 如何把flowable整合到现有的业务中；
3. 理清楚flowable创建表格/数据的意义，自己开发对应的API；

## 准备工作

因为是测试，所以先切换到一个新分支进行开发。然后根据[官方指南](https://flowable.com/open-source/docs/bpmn/ch05a-Spring-Boot/)，先把maven依赖集成到项目中：

```
<dependency>
    <groupId>org.flowable</groupId>
    <artifactId>flowable-spring-boot-starter</artifactId>
    <version>${flowable.version}</version>
</dependency>
```

我这里用的是最新的6.5.0版本，倒入依赖，重新编译项目。发现Jar包比原来大了13M左右，这个引擎的依赖还是挺多的…

在配置文件里加入

```
flowable.async-executor-activate=false
flowable.database-schema-update=true
# 必要的字体设置
```

注意后面那个必须设置为true，即使要手动建表。不过默认就是true，所以可以不设置。

## 第一次运行

`mvn clean install`之后，`mvn -o spring-boot:run -Drun.profiles=dev`试图跑起来，结果发现缺失某个依赖，加上：

```
<dependency>
    <groupId>com.fasterxml.jackson.module</groupId>
    <artifactId>jackson-module-jaxb-annotations</artifactId>
</dependency>
```

然后再跑，报bean`taskExecutor`报冲突。

这里可以自己配置一下异步线程，避免和自己定义的默认线程池冲突。

```
@Configuration
public class FlowableConfig {
    @Process
    @Bean
    public TaskExecutor processTaskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(3);
        executor.setMaxPoolSize(10);
        executor.setQueueCapacity(100);
        executor.setKeepAliveSeconds(60);
        String threadNamePrefix = "flowable-task-";
        executor.setThreadNamePrefix(threadNamePrefix);

        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(120);
        executor.initialize();
        return executor;
    }

    @Cmmn
    @Bean
    public TaskExecutor cmmnTaskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(1);
        executor.setMaxPoolSize(5);
        executor.setQueueCapacity(100);
        executor.setKeepAliveSeconds(60);
        String threadNamePrefix = "flowable-cmmn-";
        executor.setThreadNamePrefix(threadNamePrefix);

        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(120);
        executor.initialize();
        return executor;
    }
}
```

再跑，会报表不存在的错误。在datasource后面加上`&nullCatalogMeansCurrent=true`，让程序自己建表。

不过建议还是手动建表，因为默认的编码有点问题。mysql的原始sql在https://raw.githubusercontent.com/flowable/flowable-engine/flowable-6.5.0/distro/sql/create/all/flowable.mysql.all.create.sql，下下来改一下编码到utf8mb4，然后手动建表。

现在再跑，应该一切正常了。可以看到flowable的表都是大写的，不管是字段还是表名。

## 概念

[官方中文指南在此](http://www.shareniu.com/flowable6.5_zh_document/bpm/index.html)

首先BPMN图形本质上是一段xml代码，然后我们又知道xml可以与bean映射，所以这就完美融合了，即BPMN就是“代码生成器”。

### 基本步骤

首先通过手动或者springboot的自动注册生成`ProcessEngine`对象，即规则引擎的工厂（线程安全）。然后手动编写流程bpmn对应的xml，或者通过界面生成也行。

然后利用服务部署这个流程。

每个流程有一个唯一id，调用流程就是通过id启动流程。把参数传进去，开始状态机的转换。

未完待续
