---
title: Jsonnet试用
description:
toc: true
authors: ["tryao"]
tags: ["jsonnet", "json"]
categories: []
series: []
date: 2023-12-29T10:21:59+08:00
lastmod: 2023-12-29T10:21:59+08:00
featuredVideo:
featuredImage:
draft: false
---

`jsonnet`这个语言很有意思，它存在的目的就是为了编辑配置。其实使用任何一门带有字符串模板的语言都能完成类似的目的，但是`jsonnet`的好处是它的封闭性：不要使用额外的依赖完成配置。

## 安装

`jsonnet`有两个版本的编译器，一个是C++的，一个是Go的，推荐使用Go的，安装比较简单：

```bash
go install github.com/google/go-jsonnet/cmd/jsonnet@latest
```

如果你使用go语言写脚本，可以直接代码里使用：

```go
import "github.com/google/go-jsonnet"
```

## 语法

jsonnet的语法和json是一致的，但是增加了很多扩展：

* 支持C/Python风格的注释支持；
* 允许使用`|||`增加多行字符串，类似Python中的`'''`；
* 可以在行尾使用多余的逗号；
* 类似yaml，支持单引号和双引号；
* 类似js/yaml，key可以不加引号；

### 变量

变量使用`local`关键字，类似lua，需要注意的是：

* 如果变量定义在json里面（挨着字段），尾部要使用逗号；
* 否则，使用分号；

引用其他变量：

* 使用`self`引用当前结构中的变量，也可以直接使用变量名字；
* 使用`$`引用根中的变量（从json的根节点开始算）；
* 引用其他字段的变量可以用`.foo`或者`['foo']`的格式，如`$.foo`或者`$['foo']`；有点类似`jquery`；
* 允许使用数组或者字符串切片（类似Python）；

变量计算：

* 强类型：`1 == '1'`返回false；
* 但是使用`+`连接时，如果有一个是字符串，则会全部转为字符串拼接；
* `==`是深层值比较；
* 支持Python风格的字符串格式化；
* 支持C风格的位计算、逻辑计算、数学计算；
* 支持Python 风格的 `in`操作符；
* 变量转bool原则和Python类似，即`if x`的计算；

另外，jsonnet还支持一种特殊风格的字符串格式化：

```json
{
    ex1: 1+2,
    str: |||
    s=%(ex1)0.2f
   ||| % self,
}
```

这里把`self`当作变量传进去，然后在字符串里面提取出字段用来渲染，有点类似python里面的`.format`，但是语法不一样。

### 函数

jsonnet是一门图灵完备的语言，所以它也有函数，语法有点类似js中的`function`:

```
local fuc(k1, k2=3) = 
  local k3 = k1 + k2;
  [k1, k2, k3];
```

注意：函数必然会返回一个值，所以最后一个值标示函数的结束。

### 条件语句

支持类似Python的`if xx then zz else yy`的语法，默认`else null`

### 动态key

如果key也需要动态计算，可以使用：

```python
{
    [if x then 'k1']: 'v',
}
```

上面如果x是false，则key是`null`，此时会排除对应的key.

需要注意的是，key里面无法使用`self`或者需要运行时计算的变量，这是因为需要先构建key才能生成object，此时`self`还不存在。

### 列表生成

支持Python风格的列表生成表达式，官网的例子：

```python
local arr = std.range(5, 8);
{
  array_comprehensions: {
    higher: [x + 3 for x in arr],
    lower: [x - 3 for x in arr],
    evens: [x for x in arr if x % 2 == 0],
    odds: [x for x in arr if x % 2 == 1],
    evens_and_odds: [
      '%d-%d' % [x, y]
      for x in arr
      if x % 2 == 0
      for y in arr
      if y % 2 == 1
    ],
  },
  object_comprehensions: {
    evens: {
      ['f' + x]: true
      for x in arr
      if x % 2 == 0
    },
    // Use object composition (+) to add in
    // static fields:
    mixture: {
      f: 1,
      g: 2,
    } + {
      [x]: 0
      for x in ['a', 'b', 'c']
    },
  },
}
```

### 文件导入

被导入的文件习惯上使用`.libsonnet`后缀，但是实际上任意后缀都可以。

文件的内容是纯文本、json文件或者jsonnet文件都可以。如果是`yaml`，可以用`std.parseYaml`将其转为json。

### 异常

直接使用`error`抛出异常，或者使用`assert xxx: message`抛出断言异常。

出现error会立即中断配置文件生成。

### 外部变量

可以通过

```bash
jsonnet --ext-str x=y --ext-code z=true
```

传入外部变量进行渲染，代码里面使用`std.extVar('x')`获取传进来的参数值。

也可以通过

```bash
jsonnet --tla-str x=y --tla-code z=true
```

传入外部变量，此时生成配置的top level需要是一个function，用来接受传过来的数据：

```js
function(x, z=false){
    //object content
}
```

### 面向对象

jsonnet支持object的继承（显然jsonnet并没有class），实际上就是用新的object的值覆盖旧的。

有一些特殊语法：

* `::`，标示这个key不会在最终生成的object里，但是可以用来引用或者计算；也可以用来移除super中的字段；
* `+:`，覆盖super object这个字段的部分值；或者如果super中这个字段是一个列表的话，往里面添加一个值；
* `super`，引用父变量中的字段；
* 两个object相加，`+`是可以省略的；

之所以说有面向对象的特性，是因为`self`是动态解释的。

