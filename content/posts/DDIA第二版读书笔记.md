---
title: DDIA第二版读书笔记
date: 2025-11-25T08:47:45+08:00
slug: 5d498ad
draft: true
author:
  name: tryao
tags: []
collections: []
toc: true
math: true
lightgallery: false
---

第二版还没写完，[在线链接](https://ddia.vonng.com/ch1/)。

书中大大部分概念均已熟悉，这里记录一些没接触过的知识点

<!--more-->

## 图数据库

![example](https://ddia.vonng.com/fig/ddia_0306.png)

这张图表示的一对夫妻Lucy和Alain，相关的地点信息（出生、居住）。

图结构里，每个顶点包含：

- 唯一标识符
- 标签（字符串），描述此顶点表示的对象类型
- 一组出边
- 一组入边
- 属性集合（键值对）

每条边包含：

- 唯一标识符
- 边开始的顶点（*尾顶点*）
- 边结束的顶点（*头顶点*）
- 描述两个顶点之间关系类型的标签
- 属性集合（键值对）

使用关系型数据库建模：

```sql
CREATE TABLE vertices (
    vertex_id integer PRIMARY KEY,
    label text,
    properties jsonb
);

CREATE TABLE edges (
    edge_id integer PRIMARY KEY,
    tail_vertex integer REFERENCES vertices (vertex_id),
    head_vertex integer REFERENCES vertices (vertex_id),
    label text,
    properties jsonb
);

CREATE INDEX edges_tails ON edges (tail_vertex);
CREATE INDEX edges_heads ON edges (head_vertex);
```

使用图数据库插入数据：

```cypher
CREATE
    (namerica :Location {name:'North America', type:'continent'}),
    (usa :Location {name:'United States', type:'country' }),
    (idaho :Location {name:'Idaho', type:'state' }),
    (lucy :Person {name:'Lucy' }),
    (idaho) -[:WITHIN ]-> (usa) -[:WITHIN]-> (namerica),
    (lucy) -[:BORN_IN]-> (idaho)
```

前面是定点，后面是边。

需求：*查找所有从美国移民到欧洲的人的姓名*。

sql方案：

```sql
WITH RECURSIVE

    -- in_usa 是美国境内所有位置的顶点 ID 集合
    in_usa(vertex_id) AS (
        SELECT vertex_id FROM vertices
            WHERE label = 'Location' AND properties->>'name' = 'United States' ❶ 
      UNION
        SELECT edges.tail_vertex FROM edges ❷
            JOIN in_usa ON edges.head_vertex = in_usa.vertex_id
            WHERE edges.label = 'within'
    ),
    
    -- in_europe 是欧洲境内所有位置的顶点 ID 集合
    in_europe(vertex_id) AS (
        SELECT vertex_id FROM vertices
            WHERE label = 'location' AND properties->>'name' = 'Europe' ❸
      UNION
        SELECT edges.tail_vertex FROM edges
            JOIN in_europe ON edges.head_vertex = in_europe.vertex_id
            WHERE edges.label = 'within'
    ),
    
    -- born_in_usa 是所有在美国出生的人的顶点 ID 集合
    born_in_usa(vertex_id) AS ( ❹
        SELECT edges.tail_vertex FROM edges
            JOIN in_usa ON edges.head_vertex = in_usa.vertex_id
            WHERE edges.label = 'born_in'
    ),
    
    -- lives_in_europe 是所有居住在欧洲的人的顶点 ID 集合
    lives_in_europe(vertex_id) AS ( ❺
        SELECT edges.tail_vertex FROM edges
            JOIN in_europe ON edges.head_vertex = in_europe.vertex_id
            WHERE edges.label = 'lives_in'
    )
    
    SELECT vertices.properties->>'name'
    FROM vertices
    -- 连接以找到那些既在美国出生又居住在欧洲的人
    JOIN born_in_usa ON vertices.vertex_id = born_in_usa.vertex_id ❻
    JOIN lives_in_europe ON vertices.vertex_id = lives_in_europe.vertex_id;
```

❶: 首先找到 `name` 属性值为 `"United States"` 的顶点，并使其成为顶点集 `in_usa` 的第一个元素。

❷: 从集合 `in_usa` 中的顶点跟随所有传入的 `within` 边，并将它们添加到同一集合中，直到访问了所有传入的 `within` 边。

❸: 从 `name` 属性值为 `"Europe"` 的顶点开始执行相同操作，并构建顶点集 `in_europe`。

❹: 对于集合 `in_usa` 中的每个顶点，跟随传入的 `born_in` 边以查找在美国某个地方出生的人。

❺: 类似地，对于集合 `in_europe` 中的每个顶点，跟随传入的 `lives_in` 边以查找居住在欧洲的人。

❻: 最后，通过连接它们来将在美国出生的人的集合与居住在欧洲的人的集合相交。

图数据库方案：

```cypher
MATCH
    (person) -[:BORN_IN]-> () -[:WITHIN*0..]-> (:Location {name:'United States'}),
    (person) -[:LIVES_IN]-> () -[:WITHIN*0..]-> (:Location {name:'Europe'})
RETURN person.name
```

图数据库查询标准GQL已经发布，基本上是参照Cypher设计的。

## 三元组储存

使用主、谓、宾格式存储，与图数据库很类似。

```turtle
@prefix : <urn:example:>.
_:lucy a :Person.
_:lucy :name "Lucy".
_:lucy :bornIn _:idaho.
_:idaho a :Location.
_:idaho :name "Idaho".
_:idaho :type "state".
_:idaho :within _:usa.
_:usa a :Location.
_:usa :name "United States".
_:usa :type "country".
_:usa :within _:namerica.
_:namerica a :Location.
_:namerica :name "North America".
_:namerica :type "continent".
```

将上图翻译成三元组存储，语言是turtle。这种语言是RDF（资源描述框架）中编码数据的一种格式。

等价于：

```sql
@prefix : <urn:example:>.
_:lucy a :Person; :name "Lucy"; :bornIn _:idaho.
_:idaho a :Location; :name "Idaho"; :type "state"; :within _:usa.
_:usa a :Location; :name "United States"; :type "country"; :within _:namerica.
_:namerica a :Location; :name "North America"; :type "continent".
```

RDF模型使用SPAQL语言查询，这种语言早于cypher，所以语法比较像：

```SPARQL
PREFIX : <urn:example:>

SELECT ?personName WHERE {
 ?person :name ?personName.
 ?person :bornIn / :within* / :name "United States".
 ?person :livesIn / :within* / :name "Europe".
}
```

RDF 不区分属性和边，而只是对两者都使用谓语。

## 向量数据库

用于科学计算或者AI分析，如TileDB。
