---
title: Rust学习纪要
description:
toc: true
authors: ["tryao"]
tags: ["rust"]
categories: []
series: []
date: 2023-02-10T09:50:48+08:00
lastmod: 2023-09-25T09:50:48+08:00
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

这个没啥好说的，直接用官网或者brew等源管理工具安装rustup即可。

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
4. rust允许将一个变量重新声明，从而改变其类型。这个设计很奇怪，但是确实是这样的；
5. rust内置的变量类型非常简短，`i8`, `i16`, `u8`, `u16`等；`isize`和`usize`则类似golang中的`int`和`uint`，长度由cpu架构确定；
6. rust的char是4字节的，表示一个Unicode标量；如果你想表示单字节，显然应该用u8；
7. 内置array和tuple；tuple和python的设计类似：`let tup:(i32, i64, u8) = (500, 6.4, 1)`，支持索引访问(用`.`），也支持解包；
8. array是分配在栈上的，类似C++，`let a:[i32; 5] = [1,2,3,4,5]`，分号后面是长度，这个语法也有一点奇怪；数组使用索引访问，语法和C++一样；
9. rust是基于表达式的语言，语句和表达式的区别是前者不返回值；rust中大部分代码都是表达式；甚至代码块也是一个表达式；代码块最后一个语句代表代码块的值（但是不要加上分号！）；
10. 和go类似，控制语句不需要加上括号；rust不支持将非bool值自动转换成bool，这和C++/python也不一样；
11. 可以用简单的`if a {0} else {1}`实现三元运算符；
12. loop可以加标签，方法是在loop前面加上`'label:'`，之后break的时候就可以指明break的是哪个loop，类似goto；
13. rust中的for循环比较类似python；也支持`foo.iter().enumerate()`；

## 所有权

> 1. Rust 中的每一个值都有一个 **所有者**（*owner*）。
> 2. 值在任一时刻有且只有一个所有者。
> 3. 当所有者（变量）离开作用域，这个值将被丢弃。

所有权的问题，可以从`unique_ptr`中得到体验：这个指针只能被def一次。

在rust中，如果使用`let s2=s1`这样的赋值语句，s1就失效了（如果s1在堆上的话）。如果你需要保持两者都有效，应该用`let s2=s1.clone()`，进行深拷贝。

如果是栈上的数据，浅拷贝就等于深拷贝（通过`Copy` trait实现）。特别地，如果一个元组的所有元素都实现了Copy，元组也相当于实现了Copy。我们自定义的数据结构也可以通过实现Copy来完成克隆语义。

正常的函数调用，如果直接传递变量，其实就相当于c++中的`move`, 为了避免调用完函数变量就失效了，一般使用**引用**，这一点和C++一致。

我们知道C++中引用就相当于指针，`const`引用则不能修改原始值。rust中默认的引用就是不可变的，可变需要`mut`修饰符：`fn foo(param: &mut [String])`；

> 可变引用有一个很大的限制：如果你有一个对该变量的可变引用，你就不能再创建对该变量的引用。
>
> 我们也不能在拥有不可变引用的同时拥有可变引用。
>
> 多个不可变引用是可以的。

rust也支持数据Slice，即切片。语法是`[0..5]`，前闭后开区间。字符串的切片类型是`&str`，字符串字面值也是这个类型。

一般数组的切片，比如`[i32]`就是`&[i32]`.

## 结构体

即`struct`，和go的比较像。

可以用一个结构体创建另一个，语法是：

```rust
struct User {
    active: bool,
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

但是注意上面的语法会移动所有权。如果是两个不同的结构体，即使字段相同，也不能用上面的语法。

元组结构体：

```rust
struct Point(i32, i32, i32);
let p = Point(0, 0, 0);
let x = p.0;
```

p很类似tuple.

rust也支持没有任何字段的结构体，类似go里面的`struct{}`，在Haskell里面称为`()`，即unit. 在rust里面直接声明即可：

```rust
struct Empty;
```

不能在结构体里存储**引用**，除非加上生命周期声明。

通过`impl`为结构体添加方法（类似C++），在rust里面称为关联函数：

```rust
impl Point{
    fn xxx(&self) -> i32{
       //do something 
    }
}
```

现代语言都取消了C/C++中的`->`运算符，改为`.`代替。

如果参数不是`&self`或者`mut &self`开头的，则是静态方法。

可以通过`Self`关键字返回结构体自身。

结构体可以有多个`impl`块。

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
    Some(x) => x+5,
    None => 0,
};
```

模式匹配必须覆盖所有可能性，所以有一个兜底的`_`，类似其他语言中switch的`default`。

如果我们只想处理一个模式，可以用`if let`语法简写，比如判断不为None，可以简单的：

```rust
let mut x = Some(4);
if let Some(y) = x {
    x = Some(y + 1)
}
println!("{:?}", x)
```

## 包结构管理

package对应一个`Cargo.toml`文件，一个package包含一个或多个crate.

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
9. 支持通过`pub use`进行重导出；
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

## 内置数据结构

类似C++，rust内置了常用的集合。

`Vec`就是泛型的vector，可以使用`let v=vec![1,2,3]`这种宏来快速创建；

rust支持在遍历时修改：

```rust
let mut v = vec![1,2,3];
for i in &mut v {
    *i += 10
}
```

泛型里如何存储不同的类型：使用枚举，这类似C++中的联合。

rust不支持**字符串索引**，应该使用字符串的`.chars`或者`.bytes`方法明确访问的是字节还是字符；

内置的另一种数据结构是`Hashmap`。

## 错误处理

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

**Rust不支持函数重载、也不支持默认方法**，类似于go的设计，所以有时候写起来有点繁琐。go里面会用类似builder模式的`withXXX`来做初始化函数；rust也可以这么做。或者，使用`impl Default for YourType`，做一个默认值，配合上面提到的struct的`..`语法，也还能凑合用。当然还有一个邪门的方案（但是大量使用）就是用宏了。

> 有一说一，我觉得没有函数重载还好，没有默认值真的很不方便啊。

将trait作为参数：

```rust
pub fn notify(x: &impl Summary)
```

泛型配合trait：

```rust
pub fn notify<T: Summary>(x: &T)
```

上面两个实际上是等价的。

如果想表达实现了多个接口，用`+`：

```rust
pub fn notify<T: Summary + Default>(x: &T)
```

或

```rust
pub fn notify(x: &(impl Summary + Default))
```

也等价于：

```rust
pub fn notify<T>(x &T)
where T: Summary + Default
```

为泛型类型实现方法时，也可以加上额外的trait约束，表示这个方法并非对所有泛型实体生效。

