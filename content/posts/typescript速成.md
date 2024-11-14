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

## 基础

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
19. 使用`as`进行类型转换，或者使用`<string> p`这种形式；
20. 使用`!`后缀进行非空断言；
21. 支持模板字符串，语法是````

## 数组

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

## 函数

1. 首先兼容js中的普通函数：

```typescript
function hello(txt: string):void{
	console.log('hello' + txt);
}
```

2. 等价于：

```typescript
const hello: (txt:string)=>void = function(txt){
  //...
}
```

注意这里参数名是必须写的，和C语言不一样。包括用type给函数取别名，也要带上参数名。当然实际用的时候的参数名，可以名字不一样。

3. 函数的实际参数个数，可以少于指定的参数，即只适用前面N个。类似JS的设计，后面都是undefined。
4. `Function`可以匹配所有函数；
5. 函数支持可选参数(?)，默认参数和重载；
6. 支持高阶函数；
7. 支持断言函数，语法比较奇怪：

```typescript
type AssertIsNumber = (value: unknown) => asserts value is number;
```

8. 类似地，还有类型保护函数：

```typescript
type isNumber = (value: unknown) => values is number;
```

两者的区别是，后者会返回一个bool值；前者啥也不返回，直接抛出异常。

## 对象

1. const对象无法修改成员；
2. 可选属性使用`?`修饰；
3. 可选属性在使用之前要判断是不是undefined，可以用`??`操作符设一个默认值；
4. 属性使用readonly修饰，标识只读；
5. 如果一个对象变量有两个引用，其中一个变量是只读的，修改非只读的变量会影响只读变量；可以使用`as const`强制转为只读；
6. 动态属性约束：

```typescript
type Obj = {
    [property:string]: string
}
```

7. 动态属性可以声明多个类型，但是不能和字符串索引的值类型冲突。换句话说，上面这个示例，如果想增加一个`[property:number]`对应的值必须也是string；
8. 同样的，如果混合使用动态属性和固定属性，固定属性的值类型也必须和字符串动态索引的值类型一致；
9. 解构赋值：

```typescript
let {a, b, c} = d
```

如果对象d里面有a/b/c三个属性，可以直接解出来（感觉没啥用）。

可以在`a`后面加上`: x`，相当于变量的名字叫x。

10. 结构类型原则，如果对象A的属性对象B都有，那么B兼容A，或者称B是A的子类型。其实就是ducktype的设计；

11. ts不允许动态添加属性，必须在声明时一次性确定所有属性。实际上你可以用Map来动态加属性；或者使用`...`合成一个对象；

    

## 接口

1. object是直接定义的对象，可以看做匿名struct；
1. 接口(interface)，其实就是普通的具名struct：

```typescript
interface Person{
	name: string;
	age?: number; //问号标识可以不赋值
    [propName: string]: any; //任意属性取string类型的值
}
```

2. 在interface中定义了任意属性之后，其他确定/可选属性的类型必须是任意属性类型的子集。上面例子中，string和number都是any的子集；
3. inerface内部可以使用new关键字，表示构造函数；
4. interface可以使用extends继承；甚至可以继承type、class；
5. **多个同名的interface会自动合并**，用来给外部对象进行注入；
6. interface支持`this`关键字；
7. `type`可以用来扩展原始数据类型，但是`interface`不行；
8. `type`可以设计复杂类型，比如前文说的联合类型、交叉类型，这个`interface`是不支持的；

## 类

1. type和interface其实都很难用，还是`class`比较符合C系语法。可以直接将方法定义在class中；
2. 使用`constructor`关键字声明构造函数；支持`this`关键字；
3. class不仅可以implement interface，还可以实现class，此时后者被视为一个interface；
4. **如果class与interface同名，interface会被合并到class的定义里**；
5. 支持`get`和`set`；
6. 确定两个类的兼容关系时，只检查实例成员，不考虑静态成员和构造方法；
7. 属性初始化最好放在构造函数里。ts默认是先初始化构造函数，然后再初始化全局属性；与ES2022正好相反；
8. 支持抽象类；
9. 支持private/public和protected访问等级控制。
10. 类的本质是构造函数；
11. accessor是一个修饰符，可以用来装饰私有属性，自动生成set/get，类似Java里面loombok的@Getter@Setter

## 泛型

1. 与Java/C++的泛型语法类似，可以指定默认参数；
2. 可以使用extend指名T满足的接口或者类型；
3. 可以用`infer`关键字从对象中推断出类型；

## 枚举

1. enum既是一个类型，又是一个值；
2. Enum成员可以不赋值，自动递增，类似go的iota；
3. 同名Enum会自动合并；
4. 可以使用keyof取出Enum的key值，作为一个联合类型返回（左侧必须是type xxx）；
5. 如果要的是Enum成员值，则使用`in`运算符；
6. 反向映射，可以直接用`枚举名[值]`的方式获取枚举的key，仅对数值enum生效；

## 模块

1. 如果文件包括`export`或者`import`语句，则视为一个模块；否则，视为一个全局脚本；
2. 模块内部的所有变量、函数和类对外都不可件，需要显式的export才行；
3. 兼容es6的import语法：

> export {a, b, c};
>
> import {a, b, c} from xxx
>
> import * as t from xxx; //使用t.a来引用
>
> export default d; //等价于export { d as default};
>
> import d import xxx; //不需要花括号，直接拿到default导出
>
>  export {a, b } from xxx; // 导入再导出，一般用于库的聚合导出，方便外部用户引入
>
> //仍然可以使用require语法动态导入CommonJS模块（NodeJS模块），或者用import函数也行

4. ts允许export type, interface, class，为了避免混淆，在import类型时，可以在前面加上`type`关键字，即`import {type a} from xxx`，或者直接使用`import type {a} from xxx`也行；
5. 使用`import x = require('fs')`这种语法导入NodeJs模块，等价于`import * as fs from 'fs'`；
6. 使用`export = a`语法输出NodeJs模块;

## 命名空间

已经废弃的特性，不再推荐使用

## 装饰器

1. 和Python的装饰器类似，使用`@xxx`语法，xxx是一个函数，会自动接受value和context参数，value是被装饰的对象，context就是上下文；
2. context对象的属性，跟被装饰对象的类型有关。必然会有kind和name两个属性；
3. kind支持：
   1. class
   2. method
   3. getter
   4. setter
   5. field
   6. accessor
4. 如果修饰的是类，可以调用context的`addInitializer`函数，来修改类的初始化逻辑；
5. 如果修饰的是方法，还可以调用private/static属性，判断是否为私有/静态成员；
6. 属性装饰器如果返回值，只能返回一个函数用来初始化属性，函数的参数是属性的初始值；
7. accessor装饰器可以返回一个对象，用来取代默认的`get()`和`set()`方法；
8. 装饰器的执行顺序是，先评估所有装饰器表达式的值，再将其应用于当前类。应用装饰器时，顺序依次为方法装饰器和属性装饰器，然后是类装饰器；

## declare关键字

1. declare用来通知编译器某个变量的类型，这个变量是定义在其他文件里的（比如全局文件）；
2. 类似C语言中的定义，等待链接时才知道具体定义在哪；
3. 可以用.d.ts文件用来集中进行declare，在里面直接declare module并指明加载路径。自己的脚本里面使用`///<reference path="xxx.d.ts">`加载；
4. 上述方法对库作者很常用，
