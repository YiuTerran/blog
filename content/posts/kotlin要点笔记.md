---
title: Kotlin要点笔记
description:
toc: true
authors: ["tryao"]
tags: ["kotlin"]
categories: []
series: []
date: 2023-03-05T12:58:37+08:00
lastmod: 2023-03-05T12:58:37+08:00
featuredVideo:
featuredImage:
draft: false
---

实际上学习kotlin的动力一直不足，因为java is enough. 不过最近打算写一个QQ机器人玩，现在流行的框架是基于kotlin的，虽然可以用HTTP API进行桥接，但是这样部署太麻烦，而且性能有影响，索性简单的学习一下kotlin，然后直接扩展。用的教材是阿里的《kotlin核心编程》。

## 语法要点

1. var声明变量，val声明常量（即java里面的final，注意不是immutable），格式类似golang，除了类型前面要加冒号；
2. val声明的变量可以不立即赋值；
3. 支持通过`fun`定义函数，也支持函数闭包，格式也类似golang，不过返回类型之前要加`:`；
4. 类似C++，函数支持默认参数；
5. 函数类型声明的格式和函数不一样，返回类型之前要用`->`；特别的，没有返回值也要写`->Unit`
6. 返回值同样可以是函数，所以这个格式有点像haskell，如`(Int) ->((Int)->Unit)`，可以简化为`(Int)->(Int)->Unit`，这样就更像Haskell了；
7. 通过`class::func_memeber_name`来引用函数或者成员变量，
   1. lambda表达式的格式非常类似函数声明：`func f (x:Int,y:Int)->Int={x,y->x+y}`，或者更简单点`val f ={x:Int,y:Int: x+y}`；即用`{}`括起来的表达式；
8. 单个参数可以不声明，隐式的为`it`；
9. func与lambda的区别：
   1. fun在没有等号，只有花括号时，就是最常见的函数实现，必须带return；
   2. fun有等号，没有花括号时，表示单表达式函数体，此时无须带return；
   3. 如果是等号同时有花括号，无论使用val还是fun，都表示lambda表达式；
   4. lambda可以定义接收者，语法是`val sum: Int.(int) -> Int = {other->plus(other)}`;
10. kotlin的闭包是可以修改外部变量的，比java合理；
11. 如果一个函数只有一个参数，且参数是函数，则调用该函数时，无须传入外层的括号：

```kotlin
func t(block: ()->Unit){
    block()
}
t{
    println("hello world")
}
```

11. 如果一个函数有多个参数，最后一个参数是函数时，也可以省略最后一个参数直接传入内容，如：

```kotlin
func t(s:String, block:(String)->Unit){
    block(s)
}
t("hello world"){
    s->println(s)
}
```

12. 与C++类似，kotlin中很多流程控制语句是一个表达式，即会返回值，所以他可以用类似Python的方式实现3目运算：`val t = if(x>3) 5 else 7`；
13. kotlin设计`Unit`代替`void`，就是为了让所有函数调用都有返回值（即成为表达式）；
14. 枚举是类，语法有点像C++11：`enum class Day{}`; 如果要加方法的话，最后一个枚举要加一个`;`
15. kotlin支持模式匹配，语法有点像rust，关键词是`when`，当然它也是一个表达式：

```kotlin
val k = when(day){
    Day.MON -> 1
    Day.THU -> 2
    else -> 3
}
```

16. 内置range表达式，类似rust，如`for (k in 1..10 step 2)`，倒着用`10 downTo 1 step -2`；全闭区间；
17. 如果想用左闭右开区间，用`1 unitl 10`；
18. 数组遍历，如果想带上下标，用`array.withIndex()`，类似Python的`enumerate`；
19. 支持中缀函数，类似Haskell，形式是`infix func`。声明条件比较苛刻：
    1. 必须是成员函数或者扩展函数，这样函数左侧的对象是确定的
    2. 只能有一个参数，即函数右侧的参数
    3. 该参数不能有默认值
20. kotlin的可变参数用`vararg`来表示，比较特别的是，它不需要一定是最后一个参数；有点像Python的`(*args, **kwargs)`；
21. kotlin的字符串支持下标访问；支持三引号（类似Python）；支持字符串模板（类似bash）；
22. 支持`==`判断结构相等（相当于java里面的`equal`)，`===`判断引用相等(相当于java的`==`)；
23. kotlin支持内联函数，但是设计的很复杂，一般情况下尽量不要使用，除了泛型注入类型；
24. inline可以让lambda表达式非局部返回，即直接return父函数的结果；语法糖是`return @func`

## 面向对象

上面可以看出kotlin实际上是支持函数式编程的，所以不是纯OO语言，但是也支持类。

1. 默认函数是public的，但是默认成员是private的；
2. 所有变量必须显式初始化；
3. 接口中的属性不能直接复制，需要写成`val c get()=100`而不是`val c =100`；
4. 声明对象无须`new`，类似Python；
5. 可以使用`init`函数块来进行初始化，属于构造函数的一部分，而且可以有多个；
6. 构造函数可以放在类名后面声明：

```kotlin
class Bird(weight: Double, age: Int, color: String="blue"){
    val weight = weight
    val age = age
    val color: String
    init{
        this.color = color
    }
}
```

7. 延迟初始化：不可变成员的初始化延迟到对象被创建出来之后，如：

```kotlin
val color: String by lazy{
    if(age > 10) "blue" else "green"
}
```

默认线程安全，仅能用来初始化不可变变量；第一次被调用时，才会被初始化。

8. 对于var变量，可以用lateinit来延迟初始化，但是不能用于基础数据类，只能用包装类：

```kotlin
lateinit var color: String
```

9. 可以通过`constructor`显式声明构造方法，这被称为**从构造方法**，主构造方法就是类名后面那个，语法类似C++的初始化列表：

```kotlin
constructor(other: Some)this(some.color){
    //...
}
```

10. 继承的语法类似C++而不是java，用`:`，默认类并不能被继承，需要加上`open`关键字；
11. kotlin的protect不能被package访问，而是使用关键字`internal`；
12. `sealed`表示密封类，它其实是枚举的一种扩展：当值为有限情况时，主要用于状态匹配；
13. kotlin一个文件里可以定义多个类，如果用private修饰类，表示类的作用域就是当前文件；
14. 指定某个具体的父类：`super<Base>.func()`；
15. kotlin的接口可以定义成员，覆盖的时候同样要带上`overrite`；
16. 如果要在kotlin中声明一个内部类，必须加上`inner`修饰符。这和java的设计是相反的：java需要加上static关键字才是嵌套类，默认就是内部类；
17. 内部类可以访问外部类的成员，嵌套类则是完全独立的；可以用内部类解决多重继承问题；
18. 类似C#，kotlin支持委托，语法上就是上面提到的`by`：

```kotlin
class Bird(flyer: Flyer, animal: Animal): CanFly by flyer, CanEat by animal{}
```

其实有点像组合，或者Go里面的结构体嵌套；

18. kotlin支持数据类，类似lombok中的`@Data`注解，语法是`data class`，java后续版本中有`record`关键字；
19. kotlin支持自动解包，类似`val(a,b,c)=o1`；数组、数据类都支持自动解包；
20. 内置`Pair`和`Triple`；
21. 移除了`static`关键字，但是引入了`object`关键字；
22. 引入**伴生对象**概念，就是属于类的对象，使用`companion object`+花括号声明，类似java中的所有static变量+static初始化；
23. 使用object可以直接声明单例；
24. 类似Haskell，kotlin引入了ADT的概念，这主要通过`sealed class`实现，配合模式匹配和解构来使用；
25. kotlin的when可以嵌套；
26. kotlin的类型默认都是非空的，需要加上`?`来表示可为null，如`var k: String?`；
27. 使用这些变量时，也可以在后面加上`?`表示非空判定（类似java里面的Optional，Swift和Rust里面有类似的设计）；默认值使用`?:`来赋予（可以使用表达式）；
28. 非空断言：`!!`，断言失败抛出NPE异常；
29. 使用`is`和`as`来做类型判断和转换，这个语法和Rust也很类似；
30. 可以用`as?`来尝试转换，失败则返回null；
31. 所有类型的父类是`Any`；java中所有的对象转到kotlin都被视为**平台类型**，即不知道是否非空的；
32. `Nothing`是没有实例的类型，位于最底层，实际上只能为null；
33. 可以对类的**实例**进行方法扩展，语法是：

```kotlin
fun ClassA.toJson():String{
    
}
```

扩展本质上注入静态方法；

34. kotlin支持运算符重载，函数名有点像Python，语法：

```kotlin
operator func ClassA.plus(rhs:ClassA):classA{
    
}
```

35. 同名的情况下，扩展方法的优先级低于类成员；
36. 当在扩展函数里调用this时，指代的是接收者类型的实例；如果想要强行指定类的实例，使用`this@ClassA`的语法；
37. 扩展函数始终是静态调度，不支持多态（因为是静态实现）；
38. 标准库中有`with`, `apply`, `run`, `let`, `takeIf`等扩展函数；其中`let`一般用于非空判断的执行逻辑；
39. 不要滥用扩展功能；

## 数据结构

1. 不含有内置数组，直接用`Array`类，使用`arrayOf<>`来生成；建议优先使用`intArrayOf`之类的特化，性能更好；
2. 一般的集合和java中一样，只是分为可变和不可变两种了；默认是**不可变**的，`Mutable`前缀的才是可变的；
3. `mapOf(1 to 2)`，这里的to分割键值对；
4. 直接使用函数式接口处理数据会创建很多临时数据结构（因为函数式编程讲究的是不可变）；需要用`asSequence()`转成序列再处理；
5. sequence是惰性求值的，类似Haskell中的设计。当然java中的stream也是惰性求值的；
6. 因为支持惰性求值，所以也支持无限长序列，如`val naturalNum=generateSequences(0){it + 1}`；

## 泛型编程

1. kotlin泛型的语法和java区别不大，只是类型约束这里用`:`而不是`extend`；
2. 可以使用内联函数避免泛型擦除，语法是：

```kotlin
inline fun<reified T> getType(){
    return T::class.java
}
```

这种函数无法在java中被调用；

3. 如果在定义的泛型类和泛型⽅法的泛型参数前⾯加上out关键词，说明这个泛型类及泛型⽅法是协变，简单来说类型A是类 型B的子类型，那么`Generic<A>`也是`Generic<B>`的⼦类型；
4. 关键词`in`用于实现泛型逆变；作用和上面正好相反；

## 元编程

对于kotlin而言，由于不支持宏或者模板，剩下能讨论的元编程其实就只剩反射了。

1. 反射这块的内容用的时候再查，这里不做记录，因为平时用的不多；值得一提的是kotlin有个`KClass`，里面是kotlin特有的类型；
2. 使用`annotation`创建注解，用法和java类似；

## 异步支持

1. kotlin支持协程，用法：

```kotlin
launch{
    delay(1000L) //类似线程中使用sleep
}
```

2. 当然实际使用的时候，还是主要用`async`, `await`关键字；
3. kotlin内置了Actor支持，当然也可以用akka；
