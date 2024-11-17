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

推荐教程：https://zh-hans.react.dev/

## 核心概念

* 组件(components)
* 属性(props)
* 状态(state)

### 组件

react中组件就是一个function，返回UI元素（即jsx片段）。jsx需要注意以下几点：

* 必须是一个完整的元素，即有根节点。可以考虑加一个`<div>`或者空节点：`<></>`；
* jsx内部使用驼峰命名而不是下划线（但是`data-*`除外）；
* 避开js关键词冲突，如class对应className；
* 组件名称首字母必须大写；
* **不要嵌套定义组件，只在最上层定义组件**；

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

可以使用`{}`引入javascript对象、表达式或css样式。

组件应该是**纯函数**，即不修改任何全局的东西，重复执行具有幂等效果。

你不应该期望你的组件以任何特定的顺序被渲染，以任何顺序渲染它的结果都应该是对的。

事件处理程序当然可以不是纯函数，如果你的代码无法找到合适的事件处理程序用来产生副作用，也可以使用`useEffect`在渲染之后运行（最好别用）。

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

或者直接拆包（下面使用了字符串插值）：

```jsx
function Header({title='world'}){
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

**注意**：单项数据流，意味着对于子组件而言，这些props是只读的，不能修改这些参数。props的内容在每次渲染时都会被父组件刷新。如果用tsx, props设置readonly即可防止无意中犯错。

### 状态

#### state

state表示UI组件的状态，react是单向数据流，通过`useState`来获取组件的状态。

局部变量的更改不会触发重新渲染，也无法持久保存，所以需要state来替换简单的声明局部变量。

**state只能在组件的顶层使用**，有点像C语言的变量声明在最上面的习惯。

**state 完全私有于声明它的组件**，父组件无法更改它。

```jsx
function HomePage(){
    const [likes, setLikes] = React.useState(0); //likes是一个简单的变量，setLikes则是修改变量的函数，0是变量的初始值
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

onClick是点击回调，后者调用`setLikes`更新likes的值，react会自动进行元素的渲染。

需要特别注意的是，**setLikes并不会立刻更改like的值**，而是通知react再下一次渲染时，将like的值修改为likes+1，所以重复调用setLikes一般是没有效果的。即：**一个 state 变量的值永远不会在一次渲染的内部发生变化**。

如果想要重复调用setLikes并都生效，你需要传入的不是变量的值，而是更新变量的函数。即：

```js
function handleClick(){
    setLikes(n => n + 1);
    setLikes(n => n + 1);
}
```

这个更新函数可以重复多次工作，注意更新函数必须是**纯函数**。

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

如果x和y关联到一个输入框，回调的时候重新设置，那么z的值是会随之改变的（也就是说看起来是const，但是实际上并不是，这是因为重新渲染时x和y的初始值都变了）。

**相同位置的相同组件的state是复用的**（这个位置指的是组件在DOM树中的位置，可以理解为xpath）。可以通过给组件指定不同的`key`参数，强制重新渲染组件。key只需要在父组件内部是唯一的就行，不需要全局唯一。

如果一个state在多个组件之间共用，应该将其放在父组件处来声明。

#### Reducer

除了`useState`之外，react还提供了更高级的`useReducer`来简化复杂状态管理，所谓`reducer`实际上就是一个状态机：`(state, action) => newState`，需要注意的是，reducer必须是一个幂等函数。举个例子：

```jsx
function example(state, action){
    switch(action.type){
        case 'add':
            return {...state, count: state.count+1}
        case 'sub':
            return {...state, count: state.count-1}
        default:
            return state
    }
}
```

由于state经常是一个复杂的数据结构，所以用了js的解包语法，上面实际上等价于：

```jsx
function example(state, action){
    switch(action.type){
        case 'add':
            state.count++
        case 'sub':
            state.count--
    }
    return state
}
```

**需要注意**：如果state是一个对象，那么setObj的时候，需要全量set。这时候就经常要用到**对象展开复制语法，也就是`...`**。对于数组，可以使用类似Java中的Stream方法，克隆出一个新的对象。

实际使用的方法：

```jsx
const [state, dispatch] = useReducer(reducer, initState)
```

右边第一个参数就是上面介绍的状态机函数，第二个是控件的初始状态，一般是一个复杂对象（因为简单state使用`useState`就可以了）。

jsx那边只需要在事件触发的callback里调用dispatch就行，如`dispatch({type: 'add'})`。

#### Context

如果想在较深的父子组件间定义共享的状态，一般使用context，使用方法：

1. 通过 `export const MyContext = createContext(defaultValue)` 创建并导出 context。
2. 在无论层级多深的任何子组件中，把 context 传递给 `useContext(MyContext)` Hook 来读取它。
3. 在父组件中把 children 包在 `<MyContext.Provider value={...}>` 中来提供 context。

context其实有点像全局变量，当它包含的数据变更时，所有使用该变量的组件都会重新渲染。

#### 结合两者

1. **创建** context。
2. 将 state 和 dispatch **放入** context，需要创建2个context。
3. 在组件树的任何地方 **使用** context。

#### Immer

由于state是不可变的，修改复杂object或者array都需要进行一些深拷贝，有时候写起来很麻烦。

可以使用`npm install use-immer`，然后`import {useImmer} from 'use-immer'`，用`useImmer`代替`useState`。

该函数返回的set函数，可以直接修改原来的数据结构，当然是使用更新函数修改。

另外该库还提供了`useImmerReducer`来简化reducer的使用。

### 列表

渲染列表一般使用map，但是注意必须指定key属性，即：

```jsx
return (
	const items = people.map(person => 
    	<li key={person.id}>
      		xxx
       </li>
	)
);
```

同时注意`=>`右侧如果有花括号，函数体必须加上return。

注意最好不要用数组的索引作为id，除非这个数组是只读的。

另外就是不要在运行时在生产这个key。

### 事件

事件处理和js中没什么差别，仍然遵从冒泡模型。

如果想要阻止向上传播，可以用`e => e.stopPropagation()`，和js中也一样。

如果非要捕获（即使下层调用了阻止传播），则捕获事件名+`Capture`这个名字。

阻止默认行为使用`e.preventDefault()`，和js一样。

### Ref

当需要组件记住某些信息，但是不想让这些信息触发重渲染时，使用ref(`const ref=useRef(null)`)。

此外，ref还可以用来直接操作DOM，使用ref.current获取当前目标，此时在需要引用的组件上指定ref属性进行赋值。

### Effect

用来和外部系统同步，effect将在渲染之后异步运行一些代码，类似于渲染之后的回调，可以做一些特殊工作。

尽量少使用effect。

* useEffect()不加第二个参数,则每次更新组件状态的时候都会执行(所以不能没有参数的时候setState()，因为这样会触发无限循环)。使用场景:可以用于监听事件。

* useEffect()第二个参数为空数组。类似于mounted(),只会执行一次。 使用场景:可以用于页面初始化请求。

* useEffect()第二个参数不为空数组。类似于watch，当数组中变量改变的时候执行，使用场景:watch。

### 自定义HOOK

与内置hook一样，自定义hook需要以use开头，hook可以返回任意值。

自定义hook共享的是状态逻辑相关代码，换句话说，是纯函数。

## NextJS

react只是一个UI框架，并不涉及到ajax、路由之类的东西，所以需要一个完整的框架来实现整个web项目，目前官方推荐的就是NextJS.

NextJS默认使用**服务端**组件，如果想要使用客户端组件，需要将其独立成单独的文件，并在文件最前端加上`'use client';`

NextJS默认使用文件路由，直接用文件夹路径就行，很简单。 

NextJS推荐使用tailwindcss，不过也支持css modules. 国内使用后者更多，前者适合初创团队使用。

## UmiJS

国内一般还是mako + umijsv4 + antd，做纯客户端模式比较简单。官方教程见[这里](https://umijs.org/docs/guides/getting-started)。

公司用的还是3.x，教程可以看[这里](https://v3.umijs.org/zh-CN/docs/getting-started)。

## DVA

基于redux的一个框架，可配合umi使用。

dva通过module的概念来管理模型，配合state/reducer和effect使用。

```js
export const model = {
  namespace: "model", //文件名
  state: {},
  reducer:{ //同步方法，就是react的reducer
    
  },
  effects: { //异步操作，调用接口需要在这里
    *deleteOne({payload}, {call, select, put}){ //Generator必须以*开头，第一个参数是dispatch的数据
      yield payload.x+1; //yield会计算并返回，下一次调用next时进行到下一个yield，直到return
      yield payload.x+5; //yield表达式本身总是返回undefined。调用next时可以传入一个参数，代替上次计算的真实yield表达式值
      const n = yield select((state) => state.test.num) //select用来从state中选择数据
      yield put({ //put类似dispatch
        type: 'addNum',
        payload:{
          
        }
      })
    }
  },
  subscriptions: { //订阅数据源
    setup({dispatch, history, query}{
    	       
    })
  }
}
```

如果在一个 effect 中，函数 B 的入参需要依赖于函数 A 的执行结果，可以使用 **@@end** 来阻塞当前的函数。

model经过`connect`之后，可以在组件里面通过`this.props`获取state。

通过reducer修改state，在页面通过dispatch调用，即`this.props.dispatch({type: 'model/deleteOne', payload: 'hello'})`，被调用的可以是reducer，也可以是effect。

dva核心的五个元素：

* State：即模型里面的state
* View：React组件构成的视图层
* Action：一个对象，描述事件
* connect：绑定State到View
* dispatch：发送Action到stae

和umi3在一起使用时，可以用`useDispatch`直接获取dispatch函数，然后使用useSelector直接获取state中的值：`const x=useSelector(state=>state.x)`。
