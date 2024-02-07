---
title: Dotnet GUI开发
description:
toc: true
authors: ["tryao"]
tags: []
categories: []
series: []
date: 2024-02-01T11:35:06+08:00
lastmod: 2024-02-01T11:35:06+08:00
featuredVideo:
featuredImage:
draft: true
---

微软官方的跨平台GUI框架MAUI不支持linux，一般还是使用`Avalonia`，此外还有一个`UNO Platform`框架，对比可见[此文](https://zhuanlan.zhihu.com/p/638115608).

目前C#最新版是12，.NET最新的LTS版本是.NET 8.

## 安装

ubuntu22.04的源里目前只有dotnet7，想要装8的话需要使用微软官方的源，安装方式如下：

```bash
# Download Microsoft signing key and repository
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb

# Install Microsoft signing key and repository
sudo dpkg -i packages-microsoft-prod.deb

# Clean up
rm packages-microsoft-prod.deb

# Update packages
sudo apt update && sudo apt install dotnet-sdk-8.0

# 使用国内源
dotnet nuget remove source nuget.org
dotnet nuget add source https://mirrors.cloud.tencent.com/nuget/ -n tencent_nuget
```

然后，如果要写`Avalonia`应用的话，建议使用`Rider`编辑器，并安装相关插件和模板：

```bash
dotnet new install Avalonia.Templates
```

## 基础

C#的基础知识可以看[这本](https://dl.ebooksworld.ir/books/CSharp.12.and.NET.8.9781837635870.EBooksWorld.ir.pdf)比较新的书，或者直接看MSDN也行，微软的文档水平还是没得挑的。

C#语言整体和Java比较像，内置的包管理NuGet比maven好用一点，大部分概念和Java也比较一致。

支持tuple因此可以返回多个值。默认值传递，但是也可以使用`ref`, `in`, `out`修饰符。

比Java更好的是，支持AOT编译成原生程序，类似Golang，可以无运行时启动。

## Avalonia

这个框架可以理解为C#版本的flutter，主要还是用skia进行绘制，不依赖平台的界面库。所以好处是在各个平台保持一致性，坏处是性能不如原生的程序。

Avalonia和WPF的很多基础概念是一致的，所以可以通过阅读wpf的书籍快速熟悉相关概念，wpf和COM、silverlight、mfc、winform、visualbasic甚至WindowsPhone一样，早就被微软扔进历史的垃圾堆，很久没更新了，看10年前的资料都行。说到这里不得不吐槽一句，当年幸亏没跟着微软搞技术，不然估计现在找不到工作。 而且微软现在也在搞跨平台UI，即MAUI这个项目，但是他又不愿意投入很大精力，到现在还是个四不像，不如直接收购了Analonia或者UNO Platform.

 Avalonia官方的指南写的比较糙，建议先看《深入浅出WPF》，了解一下xlms的语法和常用的标签。这里记录一下重点备忘：

### 命名空间

这是xml的设计，避免名称冲突的，如：

```xml
<Window x:Class="WpfApplication.Window1"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:local="clr-namespace:WpfApplication1"
        Title="Window1" Height="300" Width="300">
</Window>
```

`xmlns:`之后的是映射的名称，类似`import xx as x`的作用，下面引用命名空间的变量时，也要加上命名空间限定。

### 资源

类似全局变量，如可以设置全局style：

```xml
<Window.Resources>
	<Style x:Key="{x:Type Button}" TargetType="{x:Type Button}">
    	<Setter Property="Width" Value="60"/>
        <Setter Property="Height" Value="36"/>
        <Setter Property="Margin" Value="5"/>
    </Style>
</Window.Resources>
```

### x命名空间

常用的一些东西都在x里面，但是`String`并不在，需要通过

```xml
xmlns:sys="clr-namespace:System;assembly=mscorlib"
```

引入.其中`clr-namespace:`也可以用`using:`替代.

#### x:Class

根节点用来绑定代码中的类的，类必然是`partial`的

#### x:ClassModifier

用来修改Class的可见性的，默认是public

#### x:Name

就是标签的名称，有的标签有`Name`这个属性，两者是相通的。建议统一使用`x:Name`来命名。

该名称会创建成类成员变量。

#### x:FieldModifier

与`x:Name`配合，修改成语变量的可见性，默认是`internal`.

#### x:Key

一般用于在Resource里面定义kv值，方便在其他地方复用，如：

```xml
<Window.Resources>
	<sys:String x:Key="myString">Hello World</sys:String>
</Window.Resources>
```

引用方式：

```xml
<TextBox Text="{StaticResource ResourceKey=myString}" />
```

代码里面使用`this.FindResource("myString") as string`也可以引用。

#### x:Shared

如果`x:Key`旁边额外使用`x:Shared="false"`标记元素，则每次获取对象时，获取的是对象的副本，而不是引用。

#### x:Type

即用字符串来表达一种类型，例如：

```xml
<StackPanel>
    <local:MyButton Content="Show" UserWindowType="{x:Type local:MyWindow}" Margin="5"/>
</StackPanel>
```

这里的`local:MyWindow`即类的名字，作为一种类型赋给`UserWindowType`这个参数（类型是`Type`）。

#### x:null

对应语言中的null常量

#### x:array

即直接声明数组，例如：

```xml
<ListBox Margin="5">
	<ListBox.ItemsSource>
    	<x:Array Type="sys:String">
        	<sys:String>Tim</sys:String>
            <sys:String>Tom</sys:String>
            <sys:String>Victor</sys:String>
        </x:Array>
    </ListBox.ItemsSource>
</ListBox>
```

#### x:Static

用以引用定义在代码中的static成员，例如：

```xml
<TextBlock FontSize="32" Text="{x:Static local:Window1.ShowText}"
```

#### x:XData

用以显式声明xml元素，以供其他地方引用，例如：

```xml
<Window.Resources>
	<XmlDataProvider x:Key="InventoryData" XPath="Inventory/Books">
    	<x:XData>
        	<Supermarket xmlns="">
            	<Fruits>
                	<Fruit Name="Peach"/>
                </Fruits>
            </Supermarket>
        </x:XData>
    </XmlDataProvider>
</Window.Resources>
```

### 控件

这个和一般GUI的控件其实区别不大，这里只记录一些特别的设计。

* 像素单位：默认肯定是px，如果在数值后面加上`*`，则表示按比例计算。这个比例按父元素的行或者列的整体高度来计算的；
* 默认的`1*`也可以直接写作`*`，`Auto`则是直接撑满父元素；
* 如果不使用主题，直接布局的话，建议使用`Grid`进行（其实相当于html中使用表格布局）；

### 布局

#### Grid

```xml
<Grid Margin="10">
	<Grid.ColumnDefinitions>
    	<ColumnDefinition Width="Auto" MinWidth="120"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="80"/>
        <ColumnDefinition Width="4"/>
        <ColumnDefinition Width="80"/>
    </Grid.ColumnDefinitions>
    <Grid.RowDefinitions>
    	<RowDefinition Height="25"/>
        <RowDefinition Height="4"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="4"/>
        <RowDefinition Height="25"/>
    </Grid.RowDefinitions>
</Grid>
```

第一个Auto的意思其实是这一列的宽度由Grid里面的控件宽度来决定。

用的时候：

```xml
<TextBlock Text="Input:" Grid.Column="0" Grid.Row="0" VerticalAlignment="Center"/>
<ComboBox Grid.Column="1" Grid.Row="0" Grid.ColumnSpan="4"/>
<TextBox Grid.Column="0" GridRow="2" Grid.ColumnSpan="5" BorderBrush="Black"/>
<Button Content="ok" Grid.Column="2" Grid.Row="4"/>
<Button Content="cancel" Grid.Column="4" Grid.Row="4"/>
```

指定行列就行，如果跨多个，使用`Span`来指定跨度。

#### StackPanel

用于在纵向或者横向堆叠元素，紧凑排列。

如果将其中某个元素移除，后面的自动移动补全。

#### Canvas

通过X/Y坐标显式定位，一般不使用。

#### DockPanel

用以冻结控件位置，就像Mac的dock或者Windows的任务栏一样。

#### WrapPanel

流式布局，放不下的话会自动换行。

### 数据绑定

在xml中通过

```xml
<TextBox x:Name="txt" Text="{Binding Path=Value,ElementName=slider1}" BorderBrush="Black" Margin="5"/>
```

绑定到变量。

Binding有个属性是`Mode`，可以指定数据流向，包括：

* TwoWay: 双向绑定
* OneWay: 从数据到UI的单项绑定
* OneTime: 数据初始化会绑定，后面不会传播
* OneWayToSource: 从UI到数据的单项绑定
* Default: 默认可以交互的UI控件是TwoWay，不能交互的是OneWay

WPF里面有**Source**参数，用以指定数据源，但是Avalonia并没有这个属性。

