---
title: Vue3笔记
description:
toc: true
authors: []
tags: []
categories: []
series: []
date: 2025-03-14T16:36:27+08:00
lastmod: 2025-03-14T16:36:27+08:00
featuredVideo:
featuredImage:
draft: false
---

react的设计过于简陋，生态乱七八糟，好处是组件库（如antd）的质量比较高。

vue3的设计要完整的多，性能（如vite）也好得多，不需要学习一堆没有的东西（如next.js）。

## 核心概念

vue3的核心其实挺简单的，学会单文件式组件（SFC）的使用即可。核心就是几个宏：

```vue
<script setup>
  import { ref } from 'vue';
  const m = defineModel();
  const props = defineProps(["param1", "param2"]);
  const events = defineEmits(["evt1", "evt2"]);
  defineOptions({
      inheritAttrs: false
  })
  const localVar = ref('');
</script>
```

下面就是写`<template>`的html和`<style>`，`ref`、`watch`等方法其实有点像react了。



props是类似go中Context的显式传递上下文，除了这种方案外，vue3还支持依赖注入：

```vue
<script setup>
  import { provide } from 'vue';
  provide('message', 'hello world');
</script>
```

需要用的地方：

```vue
<script setup>
  import { inject } from 'vue';
  const msg = inject('message');
</script>
```

如果害怕字符串冲突，也可以使用`Symbol`获取唯一名称作为依赖名称；