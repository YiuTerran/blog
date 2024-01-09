---
title: Python技术栈更新
description:
toc: true
authors: ["tryao"]
tags: ["python", "web", "crawler"]
categories: []
series: []
date: 2024-01-09T09:35:01+08:00
lastmod: 2024-01-09T09:35:01+08:00
featuredVideo:
featuredImage:
draft: false
---

有段时间没用Python写工程了，基本都是写脚本，最近接了个活帮忙搞个爬虫相关项目，需要更新一下技术栈，做个笔记。

* web开发：`fastapi`, 其实还可以接着用flask，不过前者对asyncio支持更完善一些，顺便学一下新东西；至于django还是太重了，写单体估计有点用；
* 数据库ORM：仍然可以继续使用`sqlalchemy`，最新的是2.0版本，已经支持asyncio；
* 爬虫：爬虫相关的技术栈变化不大…scrapy其实不太好用，封装的太厚，而且`twisted`早就过时了。自己写的话就：
  * 用`aiohttp`做网络请求；
  * `dom`解析：仍然是基于`lxml`的技术栈，主要还是`xpath`和`css-selector`来获取元素；
  * 浏览器模拟（动态网页）：`Playwright`代替了`Selenium`等古早的框架；
  * 打包：用docker就行；
  * 验证码破解：这个相关的网站蛮多的，但是好不好使需要测试一下才知道。包括：`yesCapture`, `2Capture`和穿云等；
  * 其他反爬技术：这个只能随机应变了，现在很多网站都做了反爬，具体手段不一，需要尝试解决；

## [FastAPI](https://fastapi.tiangolo.com/zh/)

fastapi顾名思义，专注于提供API框架，不关心模版引擎、ORM之类的东西，但是自带了API文档(即`swagger`集成)。所以代码非常简单，不需要Django那套复杂的框架：

```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
async def root():
  return "hello world"
```

就完事了。运行方式：`uvicorn main:app --reload`，默认8000端口，并支持`/docs`和`redoc`两种文档格式，当然还有`/openapi.json`这种原始数据。

### 参数格式

#### 路径参数

路径参数类似java:

```python
@app.get("/items/{item_id}")
async def read_item(item_id: int):
  return {"item_id": item_id}
```

不过很遗憾的是，路由优先级是依赖**声明的顺序**的，而不是像java那样可以保证静态路由优先级高于动态路由。所以必须要注意这一点。

类型声明可以指定枚举值：

```python
from enum import Enum, unique

@unique
class Name(str, Enum):
  Wang = "WangXiaoMing"
  Li = "LiXiaoLang"
```

fastAPI支持路径参数里面含有`/`，即未经转义的路径，这个设计与java不一致。即

```python
@app.get("/files/{file_path:path}")
```

这里的`path`说明匹配任意路径。

#### QueryString

不在路径里的其他参数默认都是queryString，如：

```python
from typing import Union

@app.get("/items")
async def list_item(page=1, size=10, name: Union[str, None] = None):
  pass
```

这里的name就是一个查询参数。

#### Body

body不支持`Get`请求，需要定义一个dto来接收参数：

```python
from pydantic import BaseModel

class Item(BaseModel):
  name: str
  description: str|None = None
  price: float
```

然后将接收参数声明为`Item`即可：

```python
@app.post("/items")
async def create_item(item:Item):
  pass
```

默认使用json序列化。

**注意**：如果有多个pydantic模型，会自动进行合并，这一般不会是你想要的。

### 参数校验

#### QueryString

使用`Query`声明：

```python
from fastapi import Query

@app.get("/items")
async def read_items(q:str = Query(min_length=3))
```

并且Query这里支持`alias`参数，允许变量名和实际参数不一致。

#### Path Param

类似的，导入`Path`即可，参数和`Query`类似。

也可以使用`Annotated`注入元数据，如：

```python
from fastapi import Query, Path
from typing import Annotated

@app.get("/items/{item_id}")
async def read_items(
	item_id: Annotated[int, Path(min_length=5)],
  q: Annotated[str|None, Query(max_length=10)]
)
```

#### Body

也有一个类似的`Body`参数。但是习惯上我们一般在类定义时就定义字段校验，类似java：

```python
from pydantic import BaseModel, Field

class Item(BaseModel):
  name: str = Field(default=None, min_length=1)
  age: int = Field(min=1)
```

`pydantic`里面还包括一些常见的校验类型，比如邮箱、url等，可以直接导入使用。

如果是动态的参数，可以使用`Dict[str, object]`来接收，或者直接用dict也行。

#### 其他

`Header`和`Cookie`也有类似的函数可供导入。

### 响应

在装饰器里面使用`response_model`声明返回类型。

### 错误处理

支持全局异常处理：

```python
from fastapi import FastAPI, Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel

app = FastAPI()


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=jsonable_encoder({"detail": exc.errors(), "body": exc.body}),
    )
```

有点类似Python，不过好处是不需要捕获那么多异常。

### 依赖项

这个算是fastapi独创的东西，它抽象了共同参数（不依赖于类），过滤器等一般web框架的组件。

这里面内容有点多，还是直接看官方文档吧。

## Playwright



