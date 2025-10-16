---
title: Java Web基础学习
date: 2017-06-12
lastmod: 2017-06-13
slug: 24e58f7
draft: false
author:
  name: tryao
tags: ["java"]
collections: []
toc: true
math: true
lightgallery: false
---

做java项目有两个月了，一直忙着修复业务上的东西，java的web基础这块没怎么看。最近在coding时涉及底层较多，必须抽时间看看底层的一些东西了。

## Servlet

### 结构概览

java的web底层主要是指servlet和filter，前者替代了普通的CGI（for C/C++，perl），相当于python中的wsgi。
和`Servlet`关系很大的是web.xml文件，所有的servlet必须在web.xml中声明、配置初始化参数，做url映射。url映射采用最大前缀匹配，如果两个完全一样，用靠前声明的那个匹配。类似django中的`settings.py`.

ServletFilter是Servlet的一种extension，用于在Servlet被调用之前检查Request对象，并修改Request Header和Request内容；以及在Servlet被调用之后检查Response对象，修改Response Header和Response的内容（一种中间件）。Filter也需要配置url mapping，其调用顺序是其在web.xml中声明的顺序，习惯上filter被声明在所有servlet之前。

Servlet异常处理，可以配置`<error-page>`将status-code导向不同的html页面，或者干脆导向一个自定义类，然后在该错误处理类中使用`Integer status_code=(Integer)req.getAttribute("javax.servlet.error.status_code");`得到错误码，然后根据错误码做处理；而java程序中的异常可以通过try…catch捕获，然后forword一个专门的处理类中。

session id应该只对当前servlet有效，虽然确实有方法使其跨servlet共享，但是不推荐使用。

### 代码书写

首先实现一个servlet（继承`HttpServlet`），实现`init`和`service`方法，在后者中实现web服务的逻辑处理。然后在`web.xml`中注册该servlet的类，将之与url相关联。

### 处理流程

外层web服务器（Tomcat等）在收到http请求后，根据url路径找到对应的servlet，实例化（如果不存在）。

实例化的servlet对象处理请求，并返回响应（或者转发给其他servlet）.

请求全部处理完毕后，Tomcat会根据需求销毁servlet（正常运行的服务不会销毁）。Java是多线程模型，并发的请求会使用新的线程来处理。

### JSP

类似其他语言中的模板，不过模板一般是获得结果，然后进行渲染。JSP本质是一种特殊的Servlet，所以在接收到请求后，JSP文件会被编译为Java的字节码。

语法：

1. `<%...%>`：Java代码片段，用于定义0~N条Java语句，方法中能够写什么，这里面就能放什么；
2. `<%= %>`：Java 表达式，用于输出一条表达式或变量的结果。`response.getWriter().print()` 方法中能够写什么，这里面就能够写什么；
3. `<%! … %>` ：声明，用来创建类的成员变量和成员方法，Java类中能够写什么，这里面就能够写什么，要注意的是，里面的内容不在`_jspService()` 方法之内，直接被JSP转化后的类体包含。

在`<% %>` 和 `<%= %>` 脚本中定义的Java 代码都会放在JSP 的 `_jspService()` 方法中（实际上就是Servlet中的`service` 方法），而`<%! %>` 脚本中定义的却会放到生成类的成员位置的。

## Spring3

spring存在的意义是因为Java不够灵活。

1. Spring通过xml来增强Java的灵活性，减少因配置更改导致的重新编译需求；
2. Spring支持面向切面编程（也就是Python中的装饰器），方便进行拦截；
3. 同样，通过AOP，可以管理数据库连接，以及事务回滚等等；
4. 此外，Spring还提供了一系列工具包，如果JDBC连接；SpringMVC的web框架；
5. 良好的可扩展性，可以方便的与其他JavaEE框架结合使用；

简单来说，Spring通过XML定义了一套新的语言，该语言能被无缝整合到Java程序中。

### IoC

所谓的依赖反转。

按着HTTP的请求应答模型，正常情况下，Tomcat等web服务器就请求直接塞给servlet，获得应答返回给客户端。但是Spring为了增强灵活性，在这里加了一层，也即是所谓的“容器”。

这个容器（BeanFactory）本质上就是对象的托管工厂，根据请求容器创建对象（Bean），并进行一系列的注入等操作，并进行对象的生命周期管理。对于web而言显然Servlet被包含在这些Bean中。

初始化的流程是可配置化的，默认在一系列xml配置文件中。

### 一般流程

Spring是按着接口进行类的管理的，一般情况下，需要有一个接口类（假设叫`HelloApi`）。

一个实现了个该接口的普通类（假设就叫`HelloImpl`）。

在spring对应的xml中配置bean，大致如下：

```
<bean id="hello" class="cn.javass.spring.chapter2.helloworld.HelloImpl"></bean>
```

`id`是组件的名字，最后：

```
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;
public class HelloTest {
       @Test
       public void testHelloWorld() {
             //1、读取配置文件实例化一个IoC容器
             ApplicationContext context = new ClassPathXmlApplicationContext("helloworld.xml");
             //2、从容器中获取Bean，注意此处完全“面向接口编程，而不是面向实现”
              HelloApi helloApi = context.getBean("hello", HelloApi.class);
              //3、执行业务逻辑
              helloApi.sayHello();
       }
}
```

使用容器读取`xml`配置文件，然后通过名字查找Bean，利用反射创建对应的实例（生成的是接口的实例）。

上文中的`ApplicationContext`是`BeanFactory`的子类，Spring针对不同的场景内置了大量不同的Bean工厂，以适应不同的场景。

如果构造器有参数，可以在xml的`bean`的结点中放入`constructor`结点，进行参数注入。

除了普通类以外，Bean还可以作用于静态/普通工厂类。只是xml中的配置文件项略有不同而已。

在初始化（生成对象）后，还可以通过`property`结点注入属性（setter）.

如果想要使用`Bean`技术，必须遵从其命名规范，不然找不到对应的方法/对象。如下：

- 该类必须是一个普通Java类（POJO），不受Java规范外其他规范约束；
- 该类必须要有公共的无参构造器，如public HelloImpl4() {}；
- 属性为private访问级别，不建议public，如private String message;
- 属性必要时通过一组setter（修改器）和getter（访问器）方法来访问；
- setter方法，以“set” 开头，后跟首字母大写的属性名，如`setMesssage`,简单属性一般只有一个方法参数，方法返回值通常为`void`;
- getter方法，一般属性以“get”开头，对于boolean类型一般以“is”开头，后跟首字母大写的属性名，如`getMesssage`，`isOk`；
- 还有一些其他特殊情况，比如属性有连续两个大写字母开头，如“URL”,则setter/getter方法为：`setURL`和`getURL`，其他一些特殊情况请参看“Java Bean”命名规范。

得益于xml的强大，可以注入的数据类型，除了基本类型外， 还有`list`、`set`和`map`等集合类，甚至可以引用其他Bean.

### bean xml语法

1. 首先使用`<bean>`构建一个bean，指定`id`（全局唯一）和`class`。如果该bean对应的类需要使用静态工厂方法，使用`factory-method="xxxx"`属性；如果需要实例工厂方法，则必须在前面先声明工厂类的bean，然后在这里指定`factory-bean`；bean的scope分为两类：`prototype`和`singleton`。显然单例的bean全局只有一个，原型的则每次产生新的。
2. 使用`<constructor-arg>`调用构造器进行初始化，可以使用`index`属性指定构造器参数次序，或者直接用`type`按参数类型进行匹配（就像正常调用重载方法时那样），或者用`name`指定参数的名字。使用`value`注入需要的值。
3. 使用`<property>`调用对应的`setter`来注入各种属性。如果注入的是常量，直接用`value`赋值就行；如果注入的是其他bean的**名字**，使用`idref bean='xxx'`；如果注入的是其他bean对应类的实例，需要使用`ref bean='xxx'`;还可以注入`list`,`set`, `array`和`map`，甚至`prop`(`java.util.Properties`) ；如果想要注入`null`，必须使用`<null/>`标签，直接写当然是字符串。
4. 使用`lazy-init`可以对bean进行延迟初始化；
5. 使用`depends-on`指定依赖的bean来影响初始化/销毁的顺序；
6. 自动装配：为了减少配置文件的长度，spring支持自动装配。简单来说可以根据参数的名称自动找到对应bean的名称；
7. 此外，spring还支持method注入。这个主要是为了解决单例bean调用原型bean导致的一系列问题；

### Resource接口

spring为外部资源抽象了一系列的接口

### Spring表达式

为Java语言提供了`eval`功能，类型动态语言的功能
在bean中可以使用SpEL，格式为`#{}`，表达式放在大括号中
可以在Java语言中使用`@Value(#{})`注释进行注入

### AOP

Spring是面向接口编程的，这是装饰器模式的基础。

所谓装饰器模式，指的是对于一个`HelloApi`接口，定义一个装饰器也实现`HelloApi`接口，其构造器也是需要一个`HelloApi`对象。这样，我们将需要装饰的对象传入装饰器对象，通过调用装饰器的接口方法来实现装饰。

Spring通过注解/xml的方式完成装饰器的注入，就是所谓的AOP. 使用流程：

1. 写一个切面类；
2. 定义连接点（具体什么场景下在哪里被调用），切入点表达式形如`execution(* com.spring.service.*.*(..))`，匹配语法：`*`表示一级上的任意字符，`..`表示任意级的任意字符，`+`指定类型的子类型；这里的语法很复杂，可以参见[这里](http://blog.csdn.net/wangpeng047/article/details/8556800)；
3. 定义通知的回调方法
4. 通知顺序：前置通知→环绕通知连接点之前→连接点执行→环绕通知连接点之后→返回通知→后通知；如果发生异常：异常通知→后通知

### JDBC支持

Spring扩展了原生的jdbc支持，但是一般情况下我们在生产环境会和ORM结合使用

### 简化配置

一般使用注释来简化配置文件，常见注释包括：

1. Required：必须注入的属性，修饰setter；
2. Autowired： 自动装配，可以后面跟上`(required=true)`，自动装配有点坑爹，谨慎使用

## Spring MVC

Spring MVC是一套常见的MVC web框架，主要涉及了几个层次……

## Apache Shiro

一个权限认证系统

## SiteMeth

一个服务端渲染的页面装饰框架
