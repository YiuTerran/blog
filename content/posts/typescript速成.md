---
title: Typescript速成
description:
toc: true
authors: []
tags: []
categories: []
series: []
date: 2024-11-11T14:56:12+08:00
lastmod: 2024-11-11T14:56:12+08:00
featuredVideo:
featuredImage:
draft: false
---

## 安装&使用

```bash
npm install -g typscript
tsc hello.ts
```

生成1个js文件。

教程推荐：https://wangdoc.com/typescript/

## 类型和对象

### 基础

1. 使用`let ok: boolean = false`和`let ok = new Boolean(1)`不同，前者是基本类型，后者是对象。类似C#/Java中的装箱和拆箱。
2. 可以用void标识函数的任意返回值类型；
3. `undefined`和`null`是所有类型的子类型，默认情况下可以给任意类型（除了Object类型）；
4. tsc编译时加上`--strictNullChecks`选项，可以让其只能赋给any/unknown类型；
5. 内置类型：boolean, string, number, bigint, symbol，最后两个对应的类没法直接构造数据；
6. 可以将变量声明为`any`，相当于使用js的弱类型；但是any会带来类型污染，可以用`unknown`类型代替，此时用之前需要判断类型，类似Go的`interface{}`必须`switch x.(type)`才能用一样，在ts里面就是`if(typeof a == 'string')`；
7. never类型标识不可能存在的类型，不接受任何赋值（交叉类型时有点用）；
8. 联合类型。类似Python，可以写出`a|b`，标识变量可以有多种类型；
9. 值类型：值也可以作为一个类型，可以用来写枚举，`let sex: 0| 1`;
10. 交叉类型：可以把两个interface合并；
11. 使用`type`给类型取别名，`type A=number|string`；
12. 使用`typeof`获取值的TypeScript类型，注意这里是类型而不是字符串；
13. 但是ts兼容js的typeof用法，此时返回的是字符串。二者的区别是前者一般用于类型声明，编译之后就没了；
14. 元组仍然使用中括号声明：`const s:[string, string, boolean] = ['a', 'b', true]`，这就导致元组必须显式声明，否则会被推断为一个数组；
15. 最后x个元组元素可以配置为可选的，方式是在类型尾部增加`?`；
16. N个元素如果类型一样，可以用`...`接数组或者数组表示任意多个元素；
17. 只读的值类型，可以作为元组使用，也可以作为数组使用，例如`const arr=[1, 2] as const`，此时arr的长度和类型都是固定的；
18. symbol类型一般是给库作者使用的，普通用户用到的机会不大；

### 接口

1. 接口(interface)，typescript的接口类似C中的struct：

```typescript
interface Person{
	name: string;
	age?: number; //问号标识可以不赋值
    [propName: string]: any; //任意属性取string类型的值
}
```

2. 在interface中定义了任意属性之后，其他确定/可选属性的类型必须是任意属性类型的子集。上面例子中，string和number都是any的子集；

3. 只能有一个任意属性定义，如果有多个类型，则使用联合类型（或者用any）；

4. 用`readonly`修饰属性名，标识只能在创建时赋值。

### 数组

1. 格式为：`let array: number[] = [1, 2, 3]`；
2. 也可以用泛型格式：`let array: Array<number> = [1, 2, 3]`；
3. 甚至还可以用接口：

```typescript
interface NumberArray {
    [index: number]: number;
}
let array: NumberArray = [1, 2, 3];
```

4. 如果数组初始值是空数组，且没有声明类型，在向里面push元素时，会自动推断元素类型，此时可以放入不同类型的元素（推断为联合类型）。但是当初始值非空时，再push不同类型的元素会直接报错；
5. const声明的数组和对象其实是可以改变元素的，需要使用readonly修饰类型：`const arr: readonly number[] = [1, 2, 3]`，此时数组是不可变的；
6. 但是readonly和泛型数组是不兼容的；

### 函数