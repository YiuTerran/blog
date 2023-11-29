---
title: React学习笔记
description:
toc: true
authors: ["tryao"]
tags: ["frontend","react"]
categories: []
series: []
date: 2023-11-29T11:23:08+08:00
lastmod: 2023-11-29T11:23:08+08:00
featuredVideo:
featuredImage:
draft: true
---

最近公司要求后端统一学习前端，乘机复习一下前端知识。上次写前端还是vue1的时候，已经有6、7年没碰前端了吧。

技术是一个圈这句话，在前端身上尤为明显。

10年前，或者更早的时候，最流行的是jQuery，直接改dom；后面出现angular成为三大框架的雏形；现在又开始流行web component，强调框架无关的组件了。

至于react，最开始定位是一个UI操作库，主要是为了声明式的修改DOM，后面慢慢的变成直接推荐Next.js这种框架了。

## 核心概念

* 组件(components)
* 属性(props)
* 状态(state)

### 组件

react中组件就是一个function，返回UI元素（即jsx片段）。jsx需要注意以下几点：

* 必须是一个完整的元素，即有根节点。可以考虑加一个`<div>`或者空节点：`<></>`；
* jsx内部使用驼峰明明而不是下划线（但是`data-*`除外）；
* 避开js关键词冲突，如class对应className；
* 组件名称首字母必须大写；

使用`ReactDOM.render(component, location)`将组件渲染到dom中即可。例如：

```jsx
<script type="text/jsx">
const app = document.getElementById("app");
function Header(){
    return <h1>Hello world</h1>
}
ReactDOM.render(<Header />, app);
</script>
```

显然，类似普通的HTML，组件可以嵌套组合。

### 属性

有了组件之后，属性就很容易理解，就是在组件里传入的参数，如：

```jsx
function HomePage(){
    return (
    	<div>
        	<Header title="world"></Header>
        </div>
    )
}
```

这里title就是一个props，在Header中如何使用：

```jsx
function Header(props){
    return <h1>Hello {props.title}</h1>
}
```

或者直接拆包：

```jsx
function Header({title}){
    return <h1>{`Hello ${title}`}</h1>
}
```

>es的拆包（即所有的解构赋值）设计的过于复杂，比Python难用多了，主要是他有歧义性：
>
>let x;
>
>{x} = {x : 3}
>
>会报错，必须写成
>
>({x} = {x: 3})
>
>即加上括号才行。但是圆括号本身不能出现在模式里，

遍历：

```jsx
function HomePage(){
    const names = ['a', 'b', 'c'];
    return (
    	<div>
        	<Header title="world"/>
            <ul>
            	{names.map((name)=>{
                    <li key={name}>{name}</li>
                })}
            </ul>
        </div>
    );
}
```

可以配合lambda表达式简化语法。

### 状态

state表示UI组件的状态，react是单向数据流，通过`useState`来获取组件的状态。

```jsx
function HomePage(){
    const [likes, setLikes] = React.useState(0);
}
function handleClick(){
    setLikes(likes + 1);
}
return (
	<div>
    	<button onClick={handleClick}>Likes ({likes})</button>
    </div>
)
```

上例就是初始化一个state，初始值是0，likes对应值，setLikes对应修改UI的函数。

onClick是点击回调，后者调用`setLikes`更新likes的值，react会自动进行元素的渲染。

UI相关的所有元素，都使用state来存储。

比较有趣的是，变量在渲染时是重新计算的，如果你写：

```jsx
const [x, setX] = react.useState('')
const [y, setY] = react.useState('')
const z = x + '' + y
return (
	<div>
    	<label>result is <b>{z}</b></label>
    </div>
)
```

如果x和y关联到一个输入框，回调的时候重新设置，那么z的值是会随之改变的（也就是说看起来是const，但是实际上并不是）。

由于是声明式语法，react在渲染的时候并不一定和你想的一样，比如不同的button复用同一个textarea，切换button时需要清空数据，或者保留各自的数据。此时需要自行定义相关函数。

给组件设置不同的key，react会将同一个组件视为不同的，从而重新渲染。