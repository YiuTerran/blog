---
title: SpringMvc4 Rest Api最佳实践
date: 2017-07-16
lastmod: 2019-08-29
slug: 0637125
draft: false
author:
  name: tryao
tags: ["java"]
collections: []
toc: true
math: true
lightgallery: false
---

因为项目的需求更改，部分API与JSP之间的交互方式由直接渲染改成ajax，所以需要调研SpringMVC在Rest上最佳实践。下面是汇总的内容，参考了网上的一些文章。

## 所谓IOC

Spring最常提起的是AOP和IOC两大作用，他们主要解决了……Emmm，Java语言设计的问题。由于Java是Pure OO语言，很多时候写起来非常繁琐。Spring IOC一个大工厂，在配置文件或者代码里把类注册成Bean（可以指定构造函数的参数和bean的id等），然后框架再把这些Bean注入到`@Autowired`(按类型注入)，`@Resource`(按名称)等注解的变量（也可以使用XML配置的方式注入）。

默认情况下，注册的都是一个单例，spring每次创建新对象时都使用同一个对象。也可以在xml中配置为`prototype`，这时候就是每次new一个新的对象了。另外spring mvc另外加了两个生命周期：session和request，分别表示为单次请求和session有效期内的对象。使用`@Scope`修改生命周期（作用域）。

可以使用`@PostConstruct`和`@PreDestroy`注册两个回调方法，在spring实例化Bean（并装配）后回调对象对应的方法。

一般使用`@Component`注册bean，`@Service`, `@Controller`和`@Repository`都是其别名。

此外，还可以使用配置类(`@Configuration`)代替xml注册bean(`@Bean`)，在其注解的方法内进行恰当的初始化，并返回一个对象注册为Bean. `@Configuration`具有`@Component`的作用，在类里面也可以直接注入。但是如果想要引用其他配置类的Bean，需要使用`@import`.

## 所谓AOP

可以简单理解为python中的装饰器…由于Java语法不支持装饰器，想要完成类似装饰器的用法，只能通过反射。比如，先声明一个类，完成主要的工作，称为target. 再通过一个类实现`org.springframework.aop.MethodBeforeAdvice`，其参数中捕获target的参数完成前置工作。最后通过spring的`ProxyFactory`生成代理工厂，设置target并添加advice，最后用代理工厂生成实例。

需要注意的是，Java本身的动态代理是基于接口的。对于没有实现任何接口的类，只能通过CGLIB通过继承进行代理，但是后者显然不支持final类。spring在生成对象时会优先选择JDK代理，不行再尝试CGLIB代理。

当然，除了在代码中使用，也可以用xml配置（实际上Java很多代码都可以通过xml实现，这也是非常惹人生厌的地方）。

最后，还可以用一种特殊的声明方式：`AspectJ`。这种方式的好处是，对方法的调用者而言，这种增强是透明的。也就是说，他可以直接用`getBean(target)`来获取bean实例，然后在调用方法的时候，实际上调用的是代理增强后的方法。也就是说，更加解耦。

## 分层

顾名思义，就是传统的MVC。model层就是一般的POJO(DO)，DAO层一般用mybatis，service层用`@Service`注册，view层用`@RestController`注册rest api，用`@RequestMapping`绑定路由。使用`@PathVaribale`取url中的参数，用`@RequestHeader`取header中的数据，用`@CookieValue`取cookie中的数据，用`@RequestBody`将json转为object，用`@ResponseBody`将返回值转为json.

参数有效性检测一般用`JSR-303`，使用`@NotNull`、`@Max`, `@Min`, `@Length`等注解，使用`@Valid`配合上面的`@RequestBody`一次性完成检测和转换。
