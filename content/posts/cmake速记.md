---
title: CMake速记
description:
toc: true
authors: ["tryao"]
tags: ["cmake", "c++"]
categories: []
series: []
date: 2023-01-09T16:42:44+08:00
lastmod: 2023-01-09T16:42:44+08:00
featuredVideo:
featuredImage:
draft: false
---

主要参考书籍《Modern CMake for C++》，以及《CMake Best Practices》，使用CMake版本3.25.

建议先看第一本，再看第二本。

## 使用

一般而言，cmake的使用方式非常简单。在命令行下使用

```bash
cmake -B <build tree> -S <source tree>
cmake --build <build tree>
```

其中`build tree`即build结果文件夹，可以直接用`build`，`source tree`则是源代码目录，一般就是`.`.

上面第一步是构建准备（配置阶段+生成阶段），第二步是真正的构建（包括compile/link/test/package）。

### 准备阶段

可以通过`-G`指定生成器，通过`cmake --help`可以看到可用的生成器列表，unix下习惯使用`Makefile`或者`Ninja`这两种生成器；windows下则习惯使用Visual Studio的各种版本IDE工程文件。

可以通过`-C`指定脚本文件，来预填充缓存信息；或者使用`-D k=v` 直接在命令行里面指定参数；

`-U`与`-D`的含义相反，是用来删除变量的，这两个参数都可以多次使用。

`--log-level=<level>`用来指定日志等级，可以通过`CMAKE_MESSAGE_LOG_LEVEL`来永久保留设置；

`--trace`跟踪模式，类似断点调试；

开发人员可以提供`CMakePresets.json`文件，用来预置相关选项，使用的时候通过`--preset=<preset>`来指定预设文件。

构建之后，可以通过`-L`列出已填充的变量，`-LA`会额外显示出高级变量，`-LH`会额外显示变量的帮助信息；注意通过`-D`指定的**自定义**变量，这里是看不到的；

### 构建阶段

需要传入的参数可以放在命令末尾。例如`-j`或者`--parallel`来指定并发构建数目。

先清理再构建：`--clean-first`.

多配置生成器，可以通过`--config <cfg>`来指定配置，包括`Debug, Release, MinSizeRel 或 RelWithDebInfo`，默认是Debug.

可以通过`-v`参数，打印更多信息。

### 安装

类似`make install`的效果，在cmake中是`cmake --install <dir> [options]`.

如果是多配置生成器，使用`--config <cfg>`来指定配置，一般是`Release`。

单个组件安装，则通过`--component <comp>`来指定组件的名字。

unix系统可以指定安装目录的默认权限，格式为`--default-directory-permissions <permissions>`，默认权限是755.

### 其他

cmake还提供了一些跨平台命令，使用`cmake -E`来执行，或者使用`cmake -P`来运行脚本。后者也可以用Python之类的完成，但是简单的任务可以考虑直接用cmake脚本来完成（后缀就是cmake），不过说实话cmake作为一门脚本语言真的很烂。

## 语法

### 基础

cmake的语法有点像bash，比如`#`和`${}`，不过这只是粗略看来，实际上坑很多。

注释：`#`，但是也可以是`[[]]`，这个其实是多行字符串的表达方式，类似python中的三引号。两个方括号之间可以加任意数量的`=`，只要最后两边对称。在左括号之前可以有一个`#`前缀：

```cmake
#[==[
message("hello world")
#]==]
```

这样，在第1行前面再加一个`#`就可以取消注释，比较方便调试大段代码（不过有IDE的时候这个功能实际上没什么用）。

上文的`message`是一个指令，习惯上用`snake_case`，不区分大小写。指令调用不是表达式，不能作为另外一个指令的参数。

双引号参数也能跨越多行，这点和大部分语言并不相同。甚至于，可以不带引号，这个是不推荐的使用方式。

### 变量

变量通过`set`和`unset`来赋值/取消赋值：

```cmake
set("test" "TRUE")
message("test is ${test}")
unset("test")
```

引用变量是`${}`，比较蛋疼的是，这个引用其实是一种**替换**，从内到外进行替换，所以这里

```cmake
set("test1" "xxx")
set("n" "1")
message("${test${n}}")
```

结果是"xxx".

除了普通变量，还有环境变量`$ENV{}`和缓存变量`$CACHE{}`。前者比较容易理解，后者是在build tree上下文中共享的变量，当普通变量不存在时，会尝试获取缓存变量，可以理解为服务中存放在redis中的变量。

运行cmake脚本时，类似其他脚本，也可以传入参数。脚本中通过`${CMAKE_ARGV<n>}`来引用，通过`${CMAKE_ARGV}`获取变量个数。

环境变量的设置比较复杂：

```cmake
set(CACHE{var} value CACHE BOOL "something desc" FORCE)
```

BOOL那里是变量类型，也可以是`FILEPATH`(路径)/`STRING`(字符串)/`INTERNAL`(一行字符串)。FORCE关键字用于覆盖已有缓存，不加的话不会覆盖已有的，类似redis中的`setnx`。

### 作用域

主要两个作用域：

* 函数作用域：`function`的自定义函数，比较类似一般编程语言；
* 目录作用域：`add_subdirectory`嵌套其他目录中的`CMakeLists.txt`文件；

当创建嵌套作用域时，cmake会将当前作用域变量的副本复制到嵌套作用域，嵌套作用域执行完毕后，副本会被删除。有点类似函数调用的传值，特别注意的是，如果cmake找不到普通变量，就会尝试找缓存变量；而后者永远是传引用的（还是理解为redis中的key比较简单）。

可以通过`set(k v PARENT_SCOPE)`强行修改上一级作用域中的变量，有点类似传入引用，但是这个并不会修改本作用域的变量，比较坑。

显然，环境变量和缓存变量的作用域都是全局的。

### 列表

这是cmake中唯一内置的数据结构，表现形式是分号分割的字符串：

```cmake
set(myList "a;b;c;d")
message(${myList})
```

这个结果是"abcd"，因为后面不带引号传递变量时，会自动解包。

可以通过`list`指令来进行常用的列表操作，包括：

```cmake
list(LENGTH myList len) # myList的长度赋予变量len
list(GET myList 0 value) # 索引从0开始
list(JOIN <list> <glue> <out-var>) # 用分隔符连接字符串
list(SUBLIST <list> <begin> <length> <out-var>) # 子数组
list(FIND <list> <value> <out-var>) # 查找索引
list(APPEND <list> [<element>...]) # 追加数据
list(FILTER <list> {INCLUDE | EXCLUDE} REGEX <regex>) # 正则过滤
list(INSERT <list> <index> [<element>...]) # 插入元素
list(POP_BACK <list> [<out-var>...]) # 弹出尾部元素
list(POP_FRONT <list> [<out-var>...]) # 弹出头部元素
list(PREPEND <list> [<element>...]) # 前端增加元素
list(REMOVE_ITEM <list> <value>...) # 移除元素
list(REMOVE_AT <list> <index>...) # 按索引移除元素
list(REMOVE_DUPLICATES <list>) # 去重
list(TRANSFORM <list> <ACTION> [...]) # 变换
list(REVERSE <list>) # 翻转
list(SORT <list> [...]) # 排序
```

### 条件语句

```cmake
if(<condition>)
  <commands>
elseif(<condition>)
  <commands>
endif()
```

类似其他语言，不过`<condition>`判断布尔量的方式比较特别：

> * 如果condition是引号变量或者方括号变量，则仅当字符串为`ON`,`Y`,`YES`或者`TRUE`时，对应bool值true，其他字符串均为false；如果是数字，则非0数字皆为true；
> * 如果condition是不带引号的变量，仅当字符串为空，`OFF`,`NO`,`FALSE`,`N`,`IGNORE`,`NOTFOUND`或者以`-NOTFOUND`结尾的字符串时，对应false，其余字符串均对应true；数字的判断逻辑同上；
>
> 强烈建议不要使用第二个逻辑，即将所有参数都加上引号。

逻辑操作符：`AND`, `OR`, `NOT`，类似python.

判断变量是否已经定义：`if(DEFINED <xxx>)`，也可以判断CACHE和ENV变量。

数值比较操作符：EQUAL, LESS, LESS_EQUAL, GREATER和GREATER_EQUAL，如果用数值和字符串作比较，可以和**以数值作为前缀的字符串**比较，其他情况都返回false.

可以比较版本号，操作符是在上述操作符的基础上增加`VERSION_`前缀。

字符串直接比较，在上述操作符前增加`STR`前缀。

可以用`MATCHES`做正则匹配，匹配的组在`CMAKE_MATCH_<N>`变量里。

可以用`in_LIST<var>`判断值是否在列表中。

可以用`command<command-name>`判断指令是否可用。

可以用`target<target-name>`判断target是否存在，用`test<test-name>`判断测试是否存在，用`POLICY<policy-id>`判断cmake策略是否存在。

可以用`EXISTS<path>`判断文件/目录是否存在；用`<file1>IS_NEWER_THAN<file2>`判断哪个文件更新；用`IS_DIRECTORY`,`IS_SYMLINK`和`IS_ABSOLUTE`判断路径信息。

### 循环语句

比较类似其他语句，包括：

```cmake
while(<condition>)
	<commands>
endwhile()
foreach(i range 0 10 1) # 迭代范围是闭区间，与python不同
	<commands>
endforeach()
foreach(item in LISTS myList ITEMS xx) # xx是追加在myList后面的迭代值
	<commands>
endforeach()
```

压缩列表：

可以用来模拟map，由于cmake仅支持list不支持map，所以只能用两个list的索引匹配来映射map. 3.17之后可以用以下语法来同时遍历两个列表：

```cmake
foreach(num IN ZIP_LISTS LIST1 LIST2)
	message("left is ${num_0}, right is ${num_1}")
endforeach()
# 或者可以用两个变量：
foreach(key value IN ZIP_LISTS LISTS1 LIST2)
	message("left is ${key}, right is ${value}")
endforeach()
```

需要注意的是，如果两个LIST的长度不一样，短列表对应的变量是不存在的。

### 宏和函数

即自定义指令，概念比较类似C语言中的宏和函数。大家都知道C语言中的宏是不推荐使用的，显然这里也一样。

```cmake
function(myFunc arg1 arg2)
	<commands>
endfunction()
```

函数的内置变量包括：

• CMAKE_CURRENT_FUNCTION: 当前函数的名字

• CMAKE_CURRENT_FUNCTION_LIST_DIR: 当前函数对应的文件夹

• CMAKE_CURRENT_FUNCTION_LIST_FILE： 当前函数对应的文件

• CMAKE_CURRENT_FUNCTION_LIST_LINE：当前行数

类似bash，参数也可以通过`$ARG<n>`来访问，通过`${ARGV}`获取完整的参数列表。除了动态参数的函数，其他情况下不建议使用这个方式来传参。

### 编程范式

和C语言一样，函数要先声明才能引用，所以正常来说必须这样：

```cmake
cmake_minimum_required(VERSION 3.20.0)
project(test)

function(f1)
endfunction()

function(f2)
endfunction()

f1()
f2()
```

如果想要先写主程序再写代码，可以使用marco技巧：

```cmake
cmake_minimum_required(VERSION 3.20.0)
project(test)

macro(main)
f1()
f2()
endmacro()

function(f1)
endfunction()

function(f2)
endfunction()

main()
```

由于宏只是替换，所以可以在宏里面访问全局变量。

### 实用命令

#### message命令

message是最常用的，可以增加额外的mode参数，即：`message(<mode> "text")`

mode包括：

• FATAL_ERROR: 将停止处理和生成。

• SEND_ERROR: 将继续处理，但跳过生成。

• WARNING: 继续处理。

• AUTHOR_WARNING: CMake 警告。继续处理。

• DEPRECATION: 若 启 用 了 `CMAKE_ERROR_DEPRECATED `或 `CMAKE_WARN_DEPRECATED` 变量，将做出相应处理。

• NOTICE 或省略模式 (默认): 将向 stderr 输出一条消息，以吸引用户的注意。

• STATUS: 将继续处理，建议用于用户的主要消息。

• VERBOSE: 将继续处理，用于通常不是很有必要的更详细的信息。

• DEBUG: 将继续处理，并包含在项目出现问题时可能有用的详细信息。

• TRACE: 将继续处理，并建议在项目开发期间打印消息。通常，在发布项目之前，将这些类型

的消息删除。

换句话说，这是一个log工具，可以选择日志等级。`cmake`指令的`–log-context`参数可以打印message对应的上下文（函数名等），用来调试。

如果想要不同层级之间的缩进，可以用`list(APPEND CMAKE_MESSAGE_INDENT " ")`，这样打印起来更加直观。

#### include命令

类似C语言的include，命令格式：

```cmake
include(<file|module> [OPTIONAL] [RESULT_VAR <var>])
```

如果使用了optional，可以增加一个变量返回是否include成功（成功返回路径，失败返回NOTFOUND）。

文件默认从当前工作目录解析相对路径，也可以用`${CMAKE_CURRENT_LIST_DIR}/<filename>.cmake`指定绝对路径。

注意include不会创建单独的作用域，修改该文件中的变量会影响调用作用域。

#### include_guard命令

防止被重复include，放在最前面。可选模式：`include_guard([DIRECTORY|GLOBAL])`.

顾名思义，DIRECTORY保护当前目录及其以下，GLOBAL保护整个构建流程。

#### file命令

类似python中的`open`，内置的文件读写功能。

#### execute_process命令

启动子进程。

注意这里不再保证跨平台可用，需要提示用户安装对应的依赖。

## 构建项目

![image-20230110152346150](https://csceciti-iot-dev.oss-cn-beijing.aliyuncs.com/docs/image-20230110152346150.png)

文中推荐的项目结构如上图。

设置C++标准：

```cmake
set_property(TARGET <target> PROPERTY CXX_STANDARD <standard>) #设置标准版本，也可以用target_compile_features配置
set(CMAKE_CXX_STANDARD_REQUIRED ON) # 强制打开标准检测
set(CMAKE_CXX_EXTENSIONS OFF) # 关闭非标特性
```

禁止内构建：

```cmake
if(PROJECT_SOURCE_DIR STREQUAL PROJECT_BINARY_DIR)
	message(FATAL_ERROR "In-source builds are not allowed")
endif()
```

生成器表达式，一种邪恶的语法：

```cmake
$<IF:condition,true_string,false_string>
$<IF:codition,true_string,>
$<condition:true_string>
$<expression:arg1,arg2>
```

### 编译配置

首先是目标：

* add_executable: 创建可执行文件
* add_library：创建库，包括三种不同的库，如果不设置的话，需要在cmake运行时传入`BUILD_SHARED_LIBS`参数；注意库名称需要全局唯一；
* add_custom_target: 自定义目标，执行脚本之类的任务

目标配置常用指令：

* target_compile_features(): 需要具有特定功能的编译器来编译此目标，例如`cxx_std_17`表示17标准，修饰符PUBLIC/INTERFACE适用于头文件也需要新标准特性的场景；

* target_sources(): 向已定义的目标添加源，只能手动添加文件列表，没有特别方便的办法；
* target_include_directories(): 设置预处理器的包含路径，用来给预处理器解析`#include<>`或`#include ""`中指定的header；有一个system参数用来标记文件夹是否标准的系统目录；
* target_compile_definitions(): 设置预处理定义，即C中的`#define`定义，可以通过cmake脚本注入数据；也可以通过`configure_file`将配置文件生成为头文件；
* target_compile_options(): 特定于编译器的选项，一般是打开各种优化配置；默认的有debug和release模式；
* target_precompile_headers(): 预编译头文件；
* set_target_properties()：配置目标属性；

`target_sources`在添加源文件时，一般使用`PRIVATE`修饰符；`PUBLIC`/`INTERFACE`一般给库目标使用。前者会把源文件附加到依赖当前库的目标上（一般不需要，相当于对外暴露实现，一般只需要暴露头文件）；后者更特殊，一般原来添加纯头文件库；

对应的，`target_include_directories`一般使用`PUBLIC`修饰符，除非是纯粹的头文件才使用INTERFACE；



### 链接配置

链接的配置其实只有`target_link_libraries`。

编译生成的ELF文件是独立的，需要通过链接器进行整合，从而重定位.data, .text等区段。有以下几种类型的库：

* 静态库(.lib/.a)，最简单的，使用`add_library(<name> STATIC [<sources> …])`来添加目标；
* 动态库(.so/.dll)，将上面的`STATIC`替换成`SHARED`即可；
* 模块库，一种特殊的动态库，可以通过在代码中使用`LoadLibrary`或者`dlopen/dlsym`动态加载的库，将上面的`STATIC`替换成`MODULE`即可；
* 对象库，关键字替换为`OBJECT`即可，这种库不会生成真正的库，仅用来分离代码模块。因此不会进行链接，仅有编译过程；

特别注意，所有依赖动态库或者模块库的，在链接的配置里要加上位置无关代码标志：

```cmake
set_target_properties(dependency_target
    PROPERTIES POSITION_INDEPENDENT_CODE
    ON)
```

否则在运行时会出现一些问题。

动态库习惯上需要在目标上设置构建版本和API版本，如：

```cmake
set_target_properties(
target
PROPERTIES VERSION ${PROJECT_VERSION}
SOVERSION ${PROJECT_VERSION_MAJOR}
)
```

这样最后创建的so文件会使用版本号作为后缀。

如果是debug版本，可以额外加上一个后缀d：

```cmake
set_target_properties(
target
PROPERTIES DEBUG_POSTFIX d)
```

符号可见性问题：

gcc/clang默认头文件中所有符号可见，但是vs默认所有符号都不可见，不过可以强制使用`CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS`将其转为一致。

更好的方法是将`CXX_VISIBILITY_PRESET`设为`HIDDEN`，然后使用`generate_export_header`宏进行显式的导出：

```cmake
add_library(hello SHARED)
set_property(TARGET hello PROPERTYCXX_VISIBILITY_PRESET "hidden")
set_property(TARGET hello PROPERTYVISIBILITY_INLINES_HIDDEN TRUE)
include(GenerateExportHeader)
generate_export_header(hello EXPORT_MACRO_NAME HELLO_EXPORT EXPORT_FILE_NAME export/hello/export_hello.hpp)
target_include_directories(hello PUBLIC "${CMAKE_CURRENT_BINARY_DIR}/export")
```

在代码里需要使用一个明确的标记:

```c++
#include "hello/export_hello.hpp"
class HELLO_EXPORT Hello{
    
};
```

包含导出的文件，并与上面的`EXPORT_MACRO_NAME`指定的宏名称一致即可。



命名冲突问题：

在链接二进制文件或者静态库时，命名经常会冲突，此时链接器会直接报错，简单的处理办法是使用C++的命名空间。

如果链接器提示未定义符号，多半是链接依赖的顺序错了。

如果有循环依赖，可以在链接时重复添加库。

### 管理依赖

主要介绍find_package指令的使用。
