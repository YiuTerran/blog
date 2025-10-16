---
title: Gradle速成
date: 2021-06-23
lastmod: 2021-06-24
slug: debaa09
draft: false
author:
  name: tryao
tags: ["java"]
collections: []
toc: true
math: true
lightgallery: false
---

## groovy语法简介

先装个groovy，`brew install groovy`，然后`groovysh`进入命令行。注意dock里面会出现一个图标，这点比较蛋疼。

- 语法其实蛮类似js，但是是强类型，用`def`声明变量支持类型推断，也可以直接声明类型；
- 内置List`[]`和Map`[:]`，Map用索引操作符和dot效果一致。使用`<<`向List/Map中append元素；
- 支持闭包，直接用`def a = {k-> println k}`声明，隐藏参数`it`.
- 支持类似bash的字符串格式化，即`${var}`;支持三引号的多行字符串；单双引号使用类似bash；
- 支持范围赋值`1..5`，支持直接写出正则（类似js），用 `=~`判断match；
- 类默认public；**顶级表达式支持省略括号**；
- 支持属性，可以直接赋值，但是也会隐式生成getter和setter以便和java保持兼容;
- 支持命名参数，默认构造函数可以直接通过命名赋值；
- 多属性赋值支持with语法；
- 支持`?`非空判断，支持直接用`==`判断等于，判断同一个对象用`is`；
- 更强的switch（类似模式匹配）；
- True/False的判断类似python；
- groovy的方法重载，命中优先的是运行时类型（而不是声明时类型）；

## gradle基本概念

1. projects和tasks，范围概念，从`<<`语法来看，tasks显然是一个List，可以通过`doFirst`和`doLast`在头部和尾部插入任务；
2. task可以配置type，相当于父类；
3. task里面写具体的groovy代码，执行具体的业务；
4. 可以动态创建task；
5. task可以被跳过，使用`onlyIf`或者抛出`StopExecutionException`，或者将task的`enabled`属性设为false；
6. 定义任务的inputs和outputs属性，Gradle会通过快照对比，确定该任务是否需要执行。一个例子是C++的单文件编译，如果代码没有修改的话，就不需要再编译了。合理设置会大幅提升编译速度；
7. 可以用`finalizedBy`来指定finally任务；
8. `file`函数总是相对于Gradle文件的路径，
9. Gradle的运行有配置阶段和执行阶段，可以加入对应的hook函数；
10. 任务之间用`dependsOn`声明依赖，也可以用`taskA.mustRunAfter taskB`之类的声明强依赖；
11. 可以直接声明函数供其他调用；

## java构建

Gradle是一个配置工具，可以用来编译打包各种类型的项目。如果要用来搞java，就加入`apply plugin: 'java'`引入java插件，它会自动引入各种task。比如使用`gradle build`跑编译。

源文件路径：

```
sourceSets{
    //修改默认目录，下面还是和默认位置一样，如需配置其他目录修改即可
    main{
        java{
            srcDir 'src/java'
        }
        resources{
            srcDir 'src/resources'
        }
    }
}
```

依赖，指明maven中央仓库：

```
repositories {
    mavenCentral()
}
```

然后加入依赖：

```
dependencies {
    compile group: 'commons-collections', name: 'commons-collections', version: '3.2'
    testCompile group: 'junit', name: 'junit', version: '4.+'
}
```

最后是编译task、测试task和打包task。

## gradle配置项

类似`pom.xml`，Gradle有个`build.gradle`的配置文件。

gradle这个项目严格来说做的**很差**，各版本之间兼容性不佳，所以最好直接看需要使用版本的官方文档，网上的教程极可能不适合你在用的版本。

这玩意儿很难不让人想起前端领域的webpack.
