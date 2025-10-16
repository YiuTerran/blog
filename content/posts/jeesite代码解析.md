---
title: Jeesite代码解析
date: 2017-06-13
lastmod: 2017-06-23
slug: 6e0bd22
draft: false
author:
  name: tryao
tags: ["java"]
collections: []
toc: true
math: true
lightgallery: false
---

现在某个项目需要用到Java Web来写控制台，考虑到外包人员的能力，这边只能用传统的JSP技术来写了… 技术选项上用了jeesite这个成熟框架。该框架使用了最传统的SpringMVC + MyBatis，然后装了一堆框架，我会根据需求删掉其中大部分内容但是保留其基础框架。

## 基础知识补充

常见Java注解：

四个元注解包括：

- `Target`: 标示注解使用的位置；
- `Retention`: 标示在什么级别保留注解信息；
- `Documented`: 标示要讲注解记录在JavaDoc中；
- `Inherited`: 允许子类继承父类的注解；

## 基本架构

Java Web有一套成熟的抽象体系，自上到下分别是`Controller`(接入层) -> `Service`(服务层) -> `Entity`(数据实体层) -> `DAO`(数据操作层)。

### DAO

这里`DAO`底层是一个泛型接口`CrudDao<T>`，这里定义了一些常见的接口（增删改查）。

对于每个具体的表，定义了接口，并使用`MyBatisDao`注解，通过查看代码可以知道，这是一个自定义注解，且是一个`Component`元注解。在`spring-context.xml`中有：

```
<context:component-scan base-package="com.thinkgem.jeesite">
	<context:exclude-filter type="annotation" expression="org.springframework.stereotype.Controller"/>
</context:component-scan>
```

这里表示扫描除了`Controller`层以外的其他组件。`MyBatis`的配置为：

```
  <bean id="sqlSessionFactory" class="org.mybatis.spring.SqlSessionFactoryBean">
      <property name="dataSource" ref="dataSource"/>
      <property name="typeAliasesPackage" value="com.thinkgem.jeesite"/>
      <property name="typeAliasesSuperType" value="com.thinkgem.jeesite.common.persistence.BaseEntity"/>
      <property name="mapperLocations" value="classpath:/mappings/**/*.xml"/>
<property name="configLocation" value="classpath:/mybatis-config.xml"/>
  </bean>
```

`dataSource`是数据源，这里配置为MySQL的连接池，用的是`Druid`这个阿里的开源库（这里是单库）。`typeAliasesPackage`是映射的起始路径包，`typeAliasesSuperType`是实体类的父类，`mapper`的注释在`mappings`下面，组件自身的配置在`mybatis-config.xml`里。

在`resources/mappings`下面，定义了对应路径映射的model，这里的数据可能是代码生成器生成的（手动写的话工作量有点大啊…），以及各种`DAO`中定义接口的具体实现。这里的语法本质上是拼装sql…

这里有个问题，idea对MyBatis的支持不太好，需要自己找插件（但是收费），也有一些免费但是不太好用的。

#### MyBatis的SQL语法

官方教程[在此](http://www.mybatis.org/mybatis-3/zh/sqlmap-xml.html)

用例子说明：

```
//`User` is Entity
interface UserDao extends CurdDao<User> {
    public User get(String id);
}
<sql id="userColumns">  # sql片段
    a.id,
    a.company_id AS "company.id",   # compony是`User`的一个成员
    a.office_id AS "office.id",
    a.login_name,
    a.password,
    a.create_by AS "createBy.id",
    a.create_date,
    a.update_by AS "updateBy.id",
    a.update_date,
    a.del_flag,
    c.name AS "company.name",
    c.parent_id AS "company.parent.id",
    c.parent_ids AS "company.parentIds",
</sql>

<sql id="userJoins">  # sql片段
    LEFT JOIN sys_office c ON c.id = a.company_id
</sql>

	<select id="get" resultType="User" parameterType="string">  # id对应Dao中方法的名字，resultType是
		SELECT
			<include refid="userColumns"/>
		FROM sys_user a
		<include refid="userJoins"/>
		WHERE a.id = #{id}
	</select>

<select>
```

熟悉了很快就能上手，一般情况下，自动映射可以处理绝大多数问题，只有特别复杂的结果集需要自定义`resultMap`.

### ehcache

Java中常用的cache，支持单机也支持分布式，但是分布式配置较为复杂，一般还是使用Redis居多。

这里ehcache的使用看得我一脸懵逼，好像直接缓存了POJO类，然后取出来后直接强制转换回来就可以了。理论上这不对啊，缓存肯定要序列化的…然后仔细研究了一下Java的序列化（类似Python的`pickle`）。

结果发现只要标记了`Serializable`的类都可以被序列化，但是如果类被修改了，就要注意是不是修改`serialVersionUID`了。必须要修改（一般是递增）该ID的情况有（来自Java官方网站）：

- 删除了成员
- 修改了类的继承层次
- 将一个非静态成员改成静态，或者将一个非忽略成员改成忽略(transient)
- 修了了原始类型成员的类型声明
- 修改了`writeObject`或者`readObject`方法
- 将类从`Serializable`改为`Externalizable`，或者移除了标记
- 将类改为枚举类型

但是以下情况无须修改：

- 增加成员：新增成员会使用默认值
- 增加类：也是使用默认值
- 移除类
- 增加`writeObject/readObject`方法
- 移除`writeObject/readObject`方法
- 增加`java.io.Serializable`
- 修改成员的修饰符
- 将成员由静态改为非静态，或者忽略改成非忽略

其实这些并不是很好记忆…所以更好的使用经验是，不要试图序列化整个类存在缓存中，而是只缓存一些必须的变量，然后用这些变量构造对象，变量使用Java标准库内置的数据结构，这些数据结构默认都是可序列化的。

### Entity

这一层本质上是db上对应表的model，但是和Python不一样，这里和表不是一一对应的，而是一个整合的数据集。

换句话说，每个`Entity`可能对应很多个表，这里的抽象思路和Python不一样。Entity是一个POJO，而不是继承某个类而得来。当然我还是更喜欢Python的抽象思路，Model原子性和Table保持一致，可以自由组合。

项目抽象了`BaseEntity`，在此基础上又总结了集中常见的数据模型。

### 事务

使用Spring的事务管理，最后只要在方法上使用`@Transactional`注解就可以使用一个事务式的方法（只能在`public`方法上使用），这个注解只会在被外部调用时触发。

关于事务方法和非事务方法之间的相互调用，参考[stackoverflow](https://stackoverflow.com/questions/6222600/transactional-method-calling-another-method-without-transactional-anotation)

`@Transactional` 默认只对 unchecked exception 异常进行回滚操作，checked、unchecked 异常使用不当造成事务无效，抛出的异常应该是`RuntimeException`的子类。

### Service层

Service层处理实际的业务逻辑，这里抽象了基类`BaseService`里面定义了方法用来鉴权；
CurdService层是简单增删改查的服务，这是一个泛型类，泛型参数是`Dao`和`Entity`；
对于树形数据结构，还特别定义了`TreeService`对应了`TreeDao`和`TreeEntity`；

## 流程解析

1. 直接运行项目，会自动打开浏览器，跳转到登录页。这个应该是在哪里配置的，暂时不明；
2. 首页会匹配到`modules/sys/web/LoginController`里面的`index`方法；
3. 该类继承自`BaseController`，这里定义了`logger`, `adminPath`, `frontPath`和`urlSuffix`，这些变量是从bean里面注入的. 同时定义了一些通用的方法；
4. 所以index方法中的`RequestMapping`, `${adminPath}`会被渲染为`a`，另外这个注释来自SpringMVC；
5. `RequiresPermissions`是使用`Apache shiro`进行鉴权，详见鉴权流程；
6. 如果用户没有登陆，会跳转到`a/login`，后者最终跳转到`modules/sys/sysLogin`；
7. 如果用户已经登陆，会跳转到`modules/sys/sysIndex`，即网站的首页；
8. 如果是mobile登陆，这里不再使用服务端渲染，还是返回了一个Json串；

其他的模块也类似，入口都在模块下的`web`包里面。`Controller`层调用`Service`层（一般是Autowired注入的），`Controller`有个共同基类`BaseController`，这是一个POJO，里面定义了一些公用的方法，如参数鉴定、view渲染和异常处理。

参数鉴定用的是`JSR303`里面规定的的一些注解，这些约束被写在`Entity`中。

## Controller与JSP的交互

`Controller`与`JSP`这一层的联系通过大量注释和隐含条件完成。

由于JSP是很集成化的东西，所以前端表格直接和后端Entity是对应的，前端用JQuery直接修改DOM元素做渲染，用户输入——JQuery修改界面——用户提交——后端从表格中取出模型形成数据——处理完毕返回新数据构成的页面。

后端使用`ModelAttribute`注入模型，前端可以直接引用模型里面的元素。前端使用的后端模型中的元素作为querystring或者post中的元素，后端也可以声明为对应方法的参数。

## 鉴权流程

使用了组件`Apache Shiro`，这个东西定义了通用的鉴权模型，参考[这篇blog](http://howiefh.github.io/2015/05/12/shiro-note/)。

几个概念：

1. `Authentication`，一般指登陆，验证用户名和密码；
2. `Authorization`，授权，验证权限；
3. `Subject`，被管理的主体，一般指的是用户；
4. `SecurityManager`，实际鉴权者，`Subject`被绑定到`SecurityManager`；
5. `Realm`，领域，类似于DAO，最终落地的鉴权者。`Realm`是Plugable的，开发者主要负责实现这一块；
6. `Authenticator`，认证器。包含一些常见的、默认的鉴权实现（如密码、SSO等）；
7. `Authrizer`，授权器。包含一些常见的权限、角色设计（一个用户多个角色，权限是以`:`分割的字符串）；
8. `SessionManager`，可配置的Session管理器，可以通过简单的配置放在Redis中；
9. `CacheManager`，系统缓存管理器，也可以简单的配置到Redis中；
10. `Principal`，身份，一般是用户名、邮箱；
11. `Credential`，凭证，一般是密码；

使用流程如下：

1. 定义配置文件，本项目中与spring结合，为`spring-context-shiro.xml`；
2. 大部分都是标准配置，注释掉的部分可以用redis作为sessionManager和CacheManager。在`SecurityManager`里面配置了`realm`，即为自己实现的`SystemAuthorizingRealm`；
3. 该类继承自`AuthorizingRealm`。`doGetAuthenticationInfo`是登陆验证，验证账号密码；`doGetAuthorizationInfo`是权限验证，这里也是用了自带的`SimpleAuthorizationInfo`；
4. 权限这里，根据用户角色，获取其前端菜单列表，每个菜单元素对应着一个权限字符串（如`sys:role:view`对应查看角色列表，`sys:role:create`对应创建新角色等）；
5. 由于用户角色、权限等信息需要在所有页面使用，所以这里注册了一个单例`SystemService`，来随时获取这些信息；
6. 在需要验证权限的地方，调用`hasRole`或者`isPermitted`等函数来验证权利（或者使用注解）.JSP里面也有相关的语法。

## 数据字典

这里采用了一个设计，所有常量被存放在数据库中，而不是在代码中使用枚举。`sys_dict`表中根据`type`存放了所有枚举值，所以枚举的`value`类型被统一为`String`。

## 问题

1. 分页。这里分页有明显的性能问题，直接查找了所有数据，然后在内存中分页（以及排序），在数据集非常大的时候这是不可取的。应该在`BaseEntity`里面存入`limit`, `offset`和`orderBy`，然后在sql里面根据这些参数来写sql；
2. id. ID应该用自增主键，主要是出于性能考虑。MySQL的uuid主键性能很差，这是由innoDB底层实现决定的。
