---
title: Kcl试用
description:
toc: true
authors: ["tryao"]
tags: ["k8s"]
categories: []
series: []
date: 2024-01-02T09:26:30+08:00
lastmod: 2024-01-02T09:26:30+08:00
featuredVideo:
featuredImage:
draft: false
---

kcl是蚂蚁金服开源的配置DSL，诞生比较晚，所以吸纳了已有的`jsonnet`、`hcl`、`cue`等方案的优点。

## 安装

对于linux：

```bash
wget -q https://kcl-lang.io/script/install-cli.sh -O - | /bin/bash
```

这个脚本本质上还是从github中下载发行版，所以也需要翻墙。

不过由于是单文件分发，所以可以直接下载上传到阿里云，甚至直接放到git里也不是不行（不过版本要更新，会占用git体积，放svn更好）。

或者你可以试试ghproxy:

```bash
wget https://mirror.ghproxy.com/https://github.com/kcl-lang/kcl/releases/download/v0.7.2/kclvm-v0.7.2-linux-amd64.tar.gz && mv kclvm.*.tar.gz kclvm.tar.gz && tar xvf kclvm.tar.gz && sudo mv kclvm/bin/* /usr/local/bin/ && sudo mv /usr/local/bin/kclvm_cli /usr/local/bin/kcl
```

或者用go：

```bash
go install kcl-lang.io/cli/cmd/kcl@latest
```

有支持idea和vscode的插件，可以从[这里](https://kcl-lang.io/zh-CN/docs/user_docs/getting-started/kcl-quick-start)查看具体安装方法，不过由于语言较新，插件目前功能有限。

## 语法

和ytt不同，kcl不是基于yaml扩展的，而是完全使用了自己的一套语法，官方向导参考[这里](https://kcl-lang.io/zh-CN/docs/reference/lang/tour). 总的来说还是基于Python语法进行扩展的。缩进使用1个tab或者4个空格。

### 变量

```python
k = v
```

如果是非导出变量，类似Python：

```python
_k = v
```

value支持k8s后缀，即`P, T, G M, K, k, m, u, n`，以及`Pi, Ti, Gi, Mi, Ki`.

`units`里面甚至定义了进行单位转换的函数，如`units.to_K(1000)`，输出是`1K`.

也可以使用类似Python的类型转换。

除了`None`以外，kcl还支持`Undefined`，类似js的设计。此时key不会输出到生成文件中。

类型使用Python3的语法：

```python
k: int | str
```

也支持`any`类型。甚至还支持类型别名：

```python
type IntOrString = int | str
```

因此可以这样定义枚举：

```python
type Color = "Red" | "Yellow" | "Blue"
```

可以使用`typeof`内置函数获取类型。也可以使用`as`进行类型转换。

**变量的计算顺序是按依赖顺序来的，而不是声明顺序**，这点和传统编程语言差别较大。

### 字符串

类似Python，支持单引号、双引号和三引号。

支持插值字符串，也支持`"".format`语法：

```python
world = "world"
a = "hello {}".format(world)
b = "hello ${world}"
```

`$`本身需要使用`$$`进行转义。

还可以指定变量展开的方式：

```python
myDict = {
    "key1" = "value1"
    "key2" = "value2"
}
myList = [1, 2, 3]
c = "mydict: ${myDict: #json}"
d = "myList: ${myList: #yaml}"
```

注意上面展开之后是字符串。即：

```python
c = 'mydict: {"key1": "value1", "key2": "value2"}'
```

支持raw string，即`r`前缀的字符串，和Python一样。此时`\`转义和`$`插值都被视为普通字符串，这个一般在正则表达式中使用。

长字符串可以使用如下语法：

```python
k = "11111111" + \
    "22222222" + \
    "33333333"
```



### 列表

支持几乎所有Python的列表语法，包括生成表达式、解包、切片。

### 字典

虽然字典中使用`=`而不是`:`，但是语法和Python类似.

`for k, v in `不需要使用`.items()`，直接用就可以。

**注意**：使用`:`也可以赋值，但它标识合并数据。

### 三元操作符

类似Python的`a = k1 if exp else k2`，不过可以没有else，此时生成配置中`a`被移除掉。

支持类似rust中的`s?.k`，如果s是None，则整体为Undefined.

### Quantifier表达式

类似java的stream，支持`all`, `any`, `map`和`filter`，前面两者生成bool值，后面用来映射。

但是感觉后面两者其实没啥用，列表表达式足够了。

### 结构体

使用`schema`定义结构体，类似Python中的`class`.

```python
type Sex = "man" | "women"
schema Person[_firstName:str, _lastName:str]:
    """文档注释语法和Python一样
    """
    firstName: _firstName
    lastName: _lastName
    age: int = 0
    sex?: Sex = "man"
    
    check: # 字段检查
        age > 0
        age < 200
```

使用：

```python
person = Person("bill", "gates")
```

实例化支持覆盖：

```python
p2 = person {
    firstName = "harry"
}
```

继承：

```python
schema Worker(Person):
    bankCard: str
```

仅支持单继承。

结构体显然可以映射成函数：输出就是构造的结构体，例如`Fibonacci`函数如下：

```python
schema Fib[n:int]:
    n1 = n - 1
    n2 = n - 2
    if n == 0:
        value = 0
    elif n == 1:
        value = 2
    else:
        value = Fib(n1).value + Fib(n2).value
```

则`fib = Fib(8).value`就是计算第8个数。

`schema`的实例：`.instances()`

### MixIn

定义协议和mixin，在schema中混入：

```python
protocol PersonProtocol:
    firstName: str
    lastName: str
    fullName?: str

mixin FullNameMixin for PersonProtocol:
    fullName = "{} {}".format(firstName, lastName)
    
schema Person:
    mixin [FullNameMixin]
```

### 动态字段

```python
schema Person:
    name: str
    age: int
    [...str]: str
```



### 断言

内置的有assert语法，和Python一样。

### 装饰器

目前不支持用户自定义装饰器，有几个内置的装饰器：

* `@deprecated`，标记属性被废弃；
* `@info`标记额外信息

### 包

和Python一样使用`import`导入。

除了内置的包之外，还支持通过[`kpm`](https://github.com/kcl-lang/kpm)安装一些第三方包，比如k8s, 语法类似`go mod`，如：

```bash
kpm init my-package
kpm add k8s:1.26
```

最后使用`kpm rum`编译整个包。

如果是复杂的object可以考虑用这个方案，简单的直接写就行。

此外，kpm的包是发布在`ghcr.io`上的，需要配置代理才能下载。

## 注意事项

kcl的版本号还在`0.x`，变动比较频繁，官方文档很多是走不通的，需要自己确认。

比如`kcl`命令需要自己重命名，`kcl mod`命令已被`kpm`替换等等。

感觉kpm设计的有点过于复杂了，对于较小的包，使用标准的kcl就够了。

此外，在使用中还发现一个问题：**变量名称中无法包含`-`**，但是这个在yaml中是合法的。

因此有些yaml就无法转为kcl文件，我给官方提了一个issue，希望他们能改正。



