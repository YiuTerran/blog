---
title: Rust学习纪要
description:
toc: true
authors: ["tryao"]
tags: ["rust"]
categories: []
series: []
date: 2023-02-10T09:50:48+08:00
featuredVideo:
featuredImage:
draft: true
---

我大概学了3次rust, 之前基本都是半途而废。第一次是卡在生命周期那里，第二次是卡在智能指针那里。

最近写了一段时间C++，再拿起rust的书，突然感觉没啥阻塞了。

说到底我还是不太习惯用无GC语言，而且之间IDE的支持一直很差，用起来比较崩溃(￣▽￣") 。这跟Haskell那种**真**学不会的情况还是有点差别的，估计啥时候我能看懂范畴论了，Haskell才能学会。Jetbrain现在也推出了Rustover这种专用IDE，找不到偷懒的理由了。

还有关键的一点，之前讨厌C++主要是因为太古老了，工具链落后，写起来有点浪费生命的感觉。Visual C++和Linux C++完全是两个物种，割裂的非常严重。最近发现CLion已经支持Makefile工程，加上有了vcpkg这种包管理器，对C++的抵触心理下降了很多，所以rust也能看进去了。当然Visual Studio还是只能支持CMake工程，Makefile工程还是不行的。感觉Jetbrain全家桶应该是这几年买的最值的东西了，尤其是我这种啥都想写的。

这里记录一下rust的关键难点，方便将来需要的时候拿来复习。

## 安装使用

这个没啥好说的，直接用官网或者brew等源管理工具安装rustup即可。如果没有魔法上网，可以用字节的[镜像](https://rsproxy.cn/#home)。

类似ipython这种命令行交互工具，可以使用cargo安装`evcxr_repl`.

编译单文件：`rustc main.rs`，会生成当前平台的二进制文件和pdb文件（调试）。rust不支持像go那种直接`go run`把单文件当脚本跑的方式来运行。

当然单文件没法用外部的包，所以一般情况下，我们还是创建工程。可以使用`cargo new`新建，类似`go mod init`，也可以直接用IDE新建。

工程就使用`cargo build`进行编译，需要在有`cargo.toml`的文件夹下运行该命令，这个设计类似nodejs. 想要直接跑进程，也可以用`cargo run`. 使用`cargo check`快速检查代码能不能编译。

`cargo build`默认编译的是含有`pdb`的debug模式，`cargo build --release`才是正式发布的版本，类似C++.

2023年rust编译的速度已经比以前提升很多了，hello world release版本编出来的大小大概是150k左右，对比之下C版本不开优化体积是1/2，开了优化体积是1/3.

## 基础语法

这里仅记录rust不符合一般编程语言的设计，和一般C系语言相同的设计，则不再赘述。

1. 通过`let`声明变量时，默认变量是**不可变的**，即只能在声明时赋值一次，后续需要改动的话，编译就会直接报错；
2. 如果想要可变，就要加上`mut`关键字，即`let mut x= b`；
3. 常量通过`const`声明，常量肯定是不可变的；
4. rust允许将一个变量重新声明，从而改变其类型。这个设计很奇怪，一般并不推荐使用。不过有时候需要用字符串做反序列化，可以用一下；
5. rust内置的变量类型非常简短，`i8`, `i16`, `u8`, `u16`等；`isize`和`usize`则类似golang中的`int`和`uint`，长度由cpu架构确定；
6. 数值类型一般使用`as`和`try_into()`来进行转换；
7. unit类型，即()，类似go中的struct{}；无返回值的函数默认返回的就是unit；
8. rust是基于表达式的语言，语句和表达式的区别是前者不返回值；**rust中大部分代码都是表达式**；甚至代码块也是一个表达式；代码块最后一个语句代表代码块的值（但是不要加上分号！）；
9. rust函数格式：`fn name(a:int, b:i32)->()`，特别的，如果返回一个`!`，表示永不返回的panic或者死循环函数，该函数可以用于需要任意返回值的场景；
10. 类似Python，不支持`++`操作符；
11. 使用`type a = b`可以别名，主要是为了更好的可读性；

## 所有权


1. Rust 中的每一个值都有一个 **所有者**（*owner*）。
2. 值在任一时刻有且只有一个所有者。
3. 当所有者（变量）离开作用域，这个值将被丢弃。


所有权的问题，可以从`unique_ptr`中得到体验：这个指针只能被def一次。

在rust中，如果使用`let s2=s1`这样的赋值语句，s1就失效了（如果s1在堆上的话；栈内是自动深拷贝，不可变引用也可以随意拷贝）。如果你需要保持两者都有效，应该用`let s2=s1.clone()`，进行深拷贝。

如果是栈上的数据，浅拷贝就等于深拷贝（通过`Copy` trait实现）。特别地，如果一个元组的所有元素都实现了Copy，元组也相当于实现了Copy。我们**自定义的数据结构也可以通过实现Copy来完成克隆语义**。

正常的函数调用，如果直接传递变量，其实就相当于c++中的`move`, 为了避免调用完函数变量就失效了，一般使用**引用**，这一点和C++一致。

我们知道C++中引用就相当于指针，`const`引用则不能修改原始值。rust中默认的引用就是不可变的，可变需要`mut`修饰符：`fn foo(param: &mut x)`；

> 可变引用有一个很大的限制：如果你有一个对该变量的可变引用，你就不能再创建对该变量的引用。
>
> 我们也不能在拥有不可变引用的同时拥有可变引用。
>
> 多个不可变引用是可以的。

一个struct的部分变量所有权被转移后，整个变量就无法使用了，但是变量的未被转移所有权的成员却仍然可以继续使用。

获取引用的两种方式：

```rust
let a = 1;
let ref b = a;
let c = &a;
```

## 字符串

Rust的字符串设计的非常复杂，比一般语言要复杂的多。

1. 首先字符都是Unicode，占用4个字节；但是字符串是UTF-8，长度是动态的；
2. 字符串字面量是str，一般以引用形式出现，即`&str`；
3. 标准库里面的则是String类型，但是除此之外，还有`OsString`, `CsString`等，一般以`String`结尾的是具有所有权的变量；以`Str`结尾的则是借用的变量；
4. String和&str之间的转换：

```rust
let a = String::from("hello world"); //或者"hello world".to_string();
let b = &a;
let c = a.as_str();
let d = &a[..]
```

5. 字符串切片语法和go语言基本一致，但是如果字符串里面有非英文字符的话，切片并不是按字符来的，很容易导致程序panic，比如“中国”两个字，别发通过s[1..]取出“国”字；甚至于，你没法通过标准库做到这一点，只能使用第三方库（如`utf_slice`)；
6. 字符串字面量本质上是字符串切片的不可变引用；
7. 字符串**不支持通过索引**访问，需要操作字符时，可以先用`.chars()`的方法转为字节数组，再通过索引来访问；或者使用第三方库；
8. String是可变字符串，所以可以`push_str()`或者直接`push(char)`；类似的还有`insert`和`insert_str`，这些都是直接原地操作的，不返回新串；
9. `replace`、`replacen`是返回新串的，但是`replace_range`又是原地操作，需要仔细区分；
10. 显然返回新串的才支持`&str`类型，原地操作需要`&mut String`才能执行；
11. `pop`, `remove`, `truncate`,`clear`都是直接原地操作；
12. `+`, `+=`右侧必须使用`&str`，左侧则必须是String，也可以直接调用`add`；
13. 可以使用`format!`进行字符串格式化，同时也支持类似Python的`r`前缀原生字符串；
14. 如果字符串内包含双引号，为了避免转义，可以在字符串前后增加若干个`#`，例如`r#"a" is allowed"#`；注意`{`和`}`是通过输入两遍来转义的，而不是`\`；
15. String是分配在堆上的，所以在离开作用域后会自动释放；
16. rust默认就支持多行字符串，直接用`""`引用的字符串默认就是多行的，如果你想不换行写很长的字符串，需要在尾部增加`\`；
17. 可以使用`b`修饰字符串得到字节字符串（即字节数组），但是字节数组并不能直接print，可以使用`str::from_utf8`将字节数组转回字符串；
18. 每个切片占用2个字（64位上就是16字节），第一个字是指向数据的指针，第二个是切片的长度；
19. &String可以被隐式转换为&str类型；

## 元组

1. 和Python中的tuple区别不大，不可变类型，支持解包；
2. 超过12个元素的tuple无法被打印；

## 结构体

即`struct`，和go的比较像，但是不区分可见度。

可以用一个结构体创建另一个，语法是：

```rust
#[derive(Debug)] //只有使用这个标记，才能使用`{:?}`打印结构体内容，或者使用dbg!宏
struct User {
    active: bool, //字段默认都是私有的，可以用pub关键字公开
    username: String,
    email: String,
    sign_in_count: u64
}

fn main(){
    let u1 = User {
        active: true,
        username: String::from("kk"),
        email: String::from("kk@gmail.com"),
        sign_in_count: 0,
    }
    let u2 = User {
        active: false,
        ..u1
    }
}
```

但是注意上面的语法会移动所有权。**如果是两个不同的结构体，即使字段相同，也不能用上面的语法**。

另外，结构体不支持将某个字段标记为可变，因此结构体本身一般是可变的。

元组结构体：

```rust
struct Point(i32, i32, i32);
let p = Point(0, 0, 0);
let q = p.0;
let Point(x, y, z) = p;
```

p很类似tuple.

rust也支持没有任何字段的结构体，在rust里面直接声明即可：

```rust
struct Empty;
```

不能在结构体里存储**引用**，除非加上生命周期声明。

## 方法

通过`impl`为结构体添加方法：

```rust
impl Point{
  	pub fn new() -> Self{
      //rust中不存在构造函数，new也不是关键字。这是关联函数，通过Point::new来调用，有点像其他语言的静态函数。
    }
    pub fn xxx(&self) -> i32{ //一般是&self或者&mut self
       //do something 
    }
}
```

现代语言都取消了C/C++中的`->`运算符，改为`.`代替。

可以通过`Self`关键字返回结构体自身，&self其实是`&self: Self`的缩写。

结构体可以有多个`impl`块，我们也可以为枚举实现方法。

另外，显然rust并不支持函数重载、默认参数，所以和Go一样，用的是C语言命名方式；

## 枚举与模式匹配

枚举的语法类似C++

```rust
enum IpAddrKind {
    V4,
    V6,
}
```

但是也可以将枚举值关联到具体的类型上：

```rust
struct IpV4Addr{
    //...
}
struct IpV6Addr{
    //...
}
enum IpAddrKind {
    V4(Ipv4Addr),
    V6(IpV6Addr),
}
```

当然关联基础类型、元组等都是可以的。也可以用`{}`关联结构体。

也可以用`impl`为枚举添加关联函数。

标准库定义了`Option`枚举，非常类似Haskell中的`Option`:

```rust
enum Option<T> {
    None,
    Some(T),
}
```

显然这是一个泛型枚举，这是内置在prelude中的类型，类似python的builtin函数，可以直接使用：`let k = Some(4)`，如果k可能为None就使用这种语法。

是的，类似Python，rust中使用`None`，而不是`null`.

Rust的枚举足够强大，与之匹配的是类似Haskell的模式匹配功能：

```rust
let i = match k {
    Some(x) => x+5, //注意结尾是逗号
    None => 0,
};
```

match还可以对数据结构进行拆包匹配。

模式匹配必须覆盖所有可能性，所以有一个兜底的`_`，类似其他语言中switch的`default`。

如果我们只想处理一个模式，可以用`if let`语法简写，比如判断不为None，可以简单的：

```rust
let mut x = Some(4);
if let Some(y) = x {
    x = Some(y + 1)
}
println!("{:?}", x)
//同时也可以用while let进行循环匹配
```

rust还提供了一个`match!`宏，用来判断模式是否匹配。

模式匹配在rust中无处不在，`let a = b`本质上就是模式匹配，所以可以解包；在函数传参时同样可以这样解包。

数组匹配：`let [x, ..] = arr`，元组也可以这么用；

匹配支持Guard，和haskell一致，即在match之后加上if进一步判断；

可以使用`@`将满足模式的结果绑定到一个新值上，方式是将`var @`放在模式前面

## 数组

1. 和Go/Java类似，分为静态数组(array)和动态数组(Vector)两类；
2. 静态数组：`let a = [1,2,3]`，可以直接用索引访问；
3. 可以使用`let a = [5;3]`,得到[5,5,5]，如果元素非基本类型（如String），则需要使用`std::array::from_fn`;
4. 数组同样支持切片，但是一般使用的是切片的不可变引用（长度固定）；
5. [T;n]是数组,[T]是切片,&[T]是切片引用；显然数组的长度也是数组类型的一部分；

## 控制结构

1. 类似go，rust的控制语句(if/for/while/loop)条件不需要使用括号；
2. if是表达式，可以返回值，所以可以用let a = if x {b} else {c}来模拟三目运算符；
3. for语句默认是move语义，所以：

> 1. for item in collection 等价于 for item in IntoIterator::into_iter(collection)，所有权转移
> 2. for item in &collection 等价于 for item in collection.iter()，即不可变引用
> 3. for item in &mut collection 等价于 for item in collection.iter_mut()，可变引用

4. 如果想要同时获取索引，则使用`for (i, v) in a.iter().enumerate()`；
5. break后面可以跟表达式，表示返回的值；



## 泛型与trait

与C++类似，rust的泛型语法如下：

```rust
fn largest<T>(list: &[T]) -> &T
```

trait则是对泛型行为的约束，其实可以理解为接口，不过略有不同。

```rust
pub trait Summary {
    fn summarize(&self) -> String;
}
```

为类型实现接口的语法：

```rust
impl Summary for YourType {
    
}
```

另外trait也支持默认方法（类似java）。

注意：**如果你想要为类型** `A` **实现特征** `T`**，那么** `A` **或者** `T` **至少有一个是在当前作用域中定义的！**因此你无法为标准库的类型添加标准库中的trait支持。

**Rust不支持函数重载、也不支持默认方法**，类似于go的设计，所以有时候写起来有点繁琐。go里面会用类似builder模式的`withXXX`来做初始化函数；rust也可以这么做。或者，使用`impl Default for YourType`，做一个默认值，配合上面提到的struct的`..`语法，也还能凑合用。当然还有一个邪门的方案（但是大量使用）就是用宏了。

> 有一说一，我觉得没有函数重载还好，没有默认值真的很不方便啊。

将trait作为参数：

```rust
pub fn notify(x: &impl Summary)
```

泛型配合trait：

```rust
pub fn notify<T: Summary>(x: &T) //特征约束
```

上面两个实际上是等价的。

如果想表达实现了多个接口，用`+`：

```rust
pub fn notify<T: Summary + Default>(x: &T) //多重约束
```

或

```rust
pub fn notify(x: &(impl Summary + Default)) //非泛型，类似于接口
```

也等价于：

```rust
pub fn notify<T>(x &T) where T: Summary + Default //where约束
```

为泛型类型实现方法时，也可以加上额外的trait约束，表示这个方法并非对所有泛型实体生效。

结构体和枚举同样支持泛型，内置的两个枚举都是泛型：

```rust
enum Option<T>{
  Some(T),
  None
}
enum Result<T, E> {
  Ok(T),
  Err(E)
}
```

在为泛型结构体添加泛型方法时，格式是`impl<T> Point<T>`，泛型方法可以使用额外的泛型参数。

也可以对泛型结构的特定类型实现不同的方法。

最后，数组的长度参数`[T;N]`也可以使用泛型参数，这被称为const泛型:`<T, const N:usize>`

泛型条件现在也支持const表达式，比如要求数组的长度不能超过多少字节等。

Rust的泛型是0抽象，在编译器会单态化，这会造成编译时间变长。

我们常用的`#derive[Debug]`，Debug其实就是一个trait，包含了默认方法。其他内置的特征往往也可以derive.

如果返回实现了某个接口的值，如果直接用`impl Interface`实际上还是只能返回同一种类型，需要使用`Box<dyn Interface>`或者`&dyn Interface`才行；dyn是动态分发的意思，表明运行期才知道具体返回的是啥，这种对象被称为**特征对象**。

并不是所有的特征都有特征对象，必须对象安全的特征才行，其要求包括：

> * 方法的返回类型不能是Self
> * 方法没有任何泛型参数

可以使用`type A;`在trait里面定义的类型，这个设计主要是为了可读性，可以用泛型参数替代。

泛型类型可以设置一个默认参数，即`<T=Self>`这种格式。

方法的完全限定调用语法：`<Dog as Animal>::method()`。

特征可以继承。

包装类型：可以使用struct A(B)，定义一个B的包装类型。

## 内置数据结构

主要就是Vec和HashMap，和Go一样，但是hashmap是需要自己手动引入的。

比较蛋疼的是，集合里面的元素也受所有权机制管控，所以在使用时一定要小心。此外就是集合被销毁时，内置的所有元素都会被销毁。

其他的要点和普通的数据结构并没有什么太大的区别。

## 错误处理

不可恢复的错误使用`panic!`抛出堆栈后退出程序。

使用`Result<T, E>`优雅的处理错误，配合`?`表达式进一步消除样板代码，类似`swift`的设计，解决了go里面的样板代码问题。

```rust
use std::fs::File;
use std::io::{self, Read};

fn read_username_from_file() -> Result<String, io::Error> {
    let mut username = String::new();

    File::open("hello.txt")?.read_to_string(&mut username)?;

    Ok(username)
}
```

如果你确定一定是Ok结果，也可以使用unwrap直接拿到值，但是此时如果出错的话会直接panic掉。用`except`也是同样的行为，不过可以自定义错误提示信息。

`?`本身其实是一个宏，它的作用就是展开Result，如果不是Err就执行，否则继续返回Err；该宏同样可以用于Option的展开。切记该符号需要一个变量来承载正确的值。

## 生命周期

生命周期标注并不会改变任何引用的实际作用域，只是为了让编译器理解程序。

在最开始，所有的引用类型都要标识生命周期，后来随着rust编译器的发展，很多情况下已经不再需要手动标注了，但是当编译器发现有歧义时，还是会报错。消除生命周期提示的三个原则分别是：

1. **每一个引用参数都会获得独自的生命周期**；
2. **若只有一个输入生命周期(函数参数中只有一个引用类型)，那么该生命周期会被赋给所有的输出生命周期**，也就是所有返回值的生命周期都等于该输入生命周期；
3. **若存在多个输入生命周期，且其中一个是 `&self` 或 `&mut self`，则 `&self` 的生命周期被赋给所有的输出生命周期**；

从第3个可以看出，一般方法是不需要自己标出生命周期的，但是你也可以自己标出（根据自己的特殊需求）：

```rust
struct Test<'a> {
  part: &'a str,
}

impl<'a> Test<'a>{
  fn test<'b>(&'a self, param: &'b str)->'a str{
    self.part
  }
}
```

多个参数共用一个生命周期时，编译器会试图取他们中活的较短的那个（即交集）。

多个参数使用不同的生命周期时，往往需要手动指定他们之间的关系，比如`<'a: 'b, 'b>`，这表明`'a`活的比`'b`更久。

你可以用`'static`标明参数是一个全局生命周期的变量。

## 包结构管理

package（可以理解为项目）对应一个`Cargo.toml`文件，一个package包含一个或多个crate（包）.

> *src/main.rs* 就是一个与包同名的二进制 crate 的 crate 根。
>
> 包目录中包含 *src/lib.rs*，则包带有与其同名的库 crate，且 *src/lib.rs* 是 crate 根。
>
> 如果有多个二进制文件要生成，则都放在`src/bin`目录下。

`crate`是编译时的最小单位，这个单词原意是箱子的意思，实际上我们可以理解为一个库或者二进制文件夹。单rs文件可以编译，是因为将单文件视为一个crate.

crate的下一级是模块(mod)，模块的隐式约定是一个文件（模块名即文件名）或者一个文件夹（模块名是文件夹的名字，文件夹下必须有mod.rs）。

模块的代码默认私有，如果想要公开，使用`pub`修饰`mod`；使用`use`引用模块或者模块中的类型。

如果显式声明mod，则用起来类似C++中的namespace:

```rust
mod level1 {
    pub fn test(){
        
    }
    pub mod level2{
        super::test();
    }
}
```

但是一般不是这么用的，而是使用隐式mod：

```rust
mod level2;
```

编译器会自动查找名为`level2.rs`的文件。

一些规则：

1. 一个 module 内的所有 item 默认为**私有**，除非显式加上 `pub` 关键字；
2. module 之外的用户只能看见 `pub` module 的 `pub` item ；
3. 同一个 module 内部同级 item 相互可以看见（无论是否私有）；
4. **父级 module 不能看见子级 module 的私有 item ，而子级 module 可看见所有祖先 module 的 item（无论是否私有）**；
5. 结构体定义前使用 `pub` 可让结构体本身变成公共的结构体，**但是内部的字段依旧保持私有**；
6. 将枚举/trait定义为公共的时，则整个类型都是公共的；
7. 对于**外部的 crate**，我们必须显式地使用 `use` 语句来声明其使用。`use`支持嵌套路径，例如：`use std::{cmp::Ordering, io};`
8. 支持`use  xxx as y`的alias；
9. 支持通过`pub use`进行重导出；即将引入到当前模块的模块重新导出给当前模块的使用者；
10. 可以在`pub`后面增加可见范围，即`pub(in path)`，进一步约束可见性；

这里说实话设计有点复杂，也过于灵活了，我们只需要记住一般的使用方法（最佳实践）：

1. 对于微型crate，可以将所有逻辑都放在`src/lib.rs`里，这里作为总入口；
2. 对于小型crate，将不同逻辑平铺放在`src`下的不同rs文件里，此时对应的文件名即是隐式的mod名，最后在`src/lib.rs`里使用`pub mod xxx`将其暴露出去即可；
3. 对于一般规模的项目，将不同的mod放在`src/`的不同目录中，此时目录名即是隐式的mod名，每个目录里面放一个`mod.rs`来声明该mod，最后在`src/lib.rs`里面做汇总；目录下也可以添加其他文件，每个文件作为一个mod，该mod是目录那一层mod的子级别；
4. 对于超大规模的项目，需要使用Cargo的`workspace`机制，建立多个crate。这些crate会共用相同的**target**文件夹，每个crate按上面的规则进行组织；
5. 私有的crate，可以在cargo.toml里面指定git仓库，如：

```toml
[dependencies]
foo-apis = { git = "https://github.com/foo/foo-apis.git", branch = "master"}
```

当然，也可以使用本地路径，如：

```toml
[dependencies]
foo_lib = { path = "../foo" }
```

以明星项目`ripgrep`为例：

```toml
[workspace]
members = [
  "crates/globset",
  "crates/grep",
  "crates/cli",
  "crates/matcher",
  "crates/pcre2",
  "crates/printer",
  "crates/regex",
  "crates/searcher",
  "crates/ignore",
]
```

顶层目录下有`creates`文件夹里面是上面的模块对应的文件夹。以globset为例：

进去之后是一个`src`文件夹：里面有多个rs文件，其中有个`lib.rs`，里面声明了：

```rust
mod fnv;
mod glob;
mod pathutil;

#[cfg(feature = "serde1")]
mod serde_impl;
```

除了`core`之外，其他的文件夹也类似。core是二进制入口，`main.rs`显然是main函数的入口。在cargo.toml里面你可以看到：

```toml
[[bin]]
bench = false
path = "crates/core/main.rs"
name = "rg"
```

具体的配置方法参考[这里](https://course.rs/cargo/reference/workspaces.html)。

可以通过`crate`开头的方式进行绝对路径引用。

## 迭代器

常用的三种迭代器：

* `into_iter`会拿走所有权
* `iter`是不可变借用
* `iter_mut`是可变借用

迭代器需要实现`Iterator`特征，一个类型如果实现了`IntoIterator`，才可以转为迭代器。

## 智能指针

1. 最简单的智能指针：Box，他的目的就是显式地将数据分配到堆上，还可以用来实现特征对象；
1. **你需要一个在运行期初始化的值，但是可以全局有效，也就是和整个程序活得一样久**，那么就可以使用 `Box::leak`；
1. 智能指针实现了`Deref`特征，可以直接使用`*`获取指向。也就是`*`与`*(x.deref())`效果是一致的；
1. rust会自动进行`deref`的隐式转换，比如`&String`自动转为`&str`；
1. 可以通过实现`Drop`特征来完成类似C++中析构行为，当变量被销毁后，会自动调用该函数；当然你也可以手动调用`drop`方法/函数；
1. 你无法为一个结构体同时实现`Copy`和`Drop`；
1. Rust要求一个值只能有一个所有者，其他的都是借用（可变或者不可变），这个有时候不太方便。可以用`Rc<T>`实现引用计数，当我们**希望在堆上分配一个对象供程序的多个部分使用且无法确定哪个部分最后一个结束时，就可以使用 `Rc` 成为数据值的所有者**；使用`Rc::clone`进行复制；使用`Rc::strong_count`获取当前引用计数值；
1. Rc本质上获取的是不可变引用，需要修改的话需要配合`RefCell`来使用；
1. Arc与Rc区别在于它是线程安全的，所以消耗太大；类似C++，还有一个`Weak`智能指针；
1. Cell和RefCell都是为了实现内部可变性的智能指针。两者的区别是，前者用于实现了Copy特征的对象；后者则用于所有对象；
1. 习惯上单线程使用`Rc<RefCell<T>>`来完成复杂逻辑；注意`RefCell`并不是线程安全的；
1. **对于父子引用关系，可以让父节点通过 `Rc` 来引用子节点，然后让子节点通过 `Weak` 来引用父节点**；
1. 可以使用`*const T`和`*mut T`来声明裸指针；

## 并发编程

1. rust内置的协程模型仍然是`1:1`的，`M:N`可以使用tokio；
2. 多线程内部可变性一般使用`Arc<Mutex<T>>`来实现；
3. 
