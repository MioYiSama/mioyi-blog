---
title: Svelte 基础
tags: [前端]
---

### 介绍

- 使用`{}`嵌入JS表达式

```svelte
<script>
  let src = '/tutorial/image.gif';
  let name = 'Rick Astley';
</script>

<p>Name: {name}</p>
<img src={src}/>

<!-- 语法糖 -->
<img {src} />
```

- 使用`<style>`加入样式

```svelte
<p>This is a paragraph.</p>

<style>
  p {
    color: goldenrod;
    font-size: 2em;
  }
</style>
```

- 导入和使用组件

```svelte
<script lang="ts">
  import Nested from './Nested.svelte';
</script>

<Nested />
```

- 将字符串变成HTML代码

```svelte
<p>{@html string}</p>
```

### 响应式

- 「状态」的创建和修改

> $... 被称作Runes（符文）

```svelte
<script>
  let count = $state(0);
  
  function increment() {
    count += 1;
  }
</script>
```

- 「深状态」

```svelte
<script>
  let numbers = $state([1, 2, 3, 4]);

  function addNumber() {
    numbers.push(numbers.length + 1);
  }
</script>
```

- 「派生状态」

```svelte
<script>
  let numbers = $state([1, 2, 3, 4]);
  let total = $derived(numbers.reduce((t, n) => t + n, 0));
</script>
```

- 状态「快照」

```svelte
<script>
  let numbers = $state([1, 2, 3, 4]);
  console.log($state.snapshot(numbers));
  
  // 使用 $inspect 在状态每次变化时自动记录快照
  $inspect(numbers).with(console.trace);
</script>
```

- 「副作用」

```svelte
<script>
  let elapsed = $state(0);
  let interval = $state(1000);

  $effect(() => {
    const id = setInterval(() => {
      elapsed += 1;
    }, interval);

    return () => clearInterval(id);
  });
</script>
```

- 在Svelte文件外使用「状态」

```js
export const counter = $state({
  count: 0
});
```

### 组件的「属性」

- 声明「属性」

```svelte
<script lang="ts">
  let { answer } = $props();
</script>
```

- 属性的默认值

```svelte
<script>
  let { answer = 'a mystery' } = $props();
</script>
```

- 传递属性

```svelte
<PackageInfo
  name={pkg.name}
  version={pkg.version}
  description={pkg.description}
  website={pkg.website}
/>

<!-- 语法糖 -->
<PackageInfo {...pkg} />
```

### HTML中的「逻辑」

- 分支（`#if`, `:else if`, `:else`, `/if`）

```svelte
{#if count > 10}
  <p>{count} is greater than 10</p>
{:else if count < 5}
  <p>{count} is less than 5</p>
{:else}
  <p>{count} is between 5 and 10</p>
{/if}
```

- 遍历（`#each as`）

```svelte
<div>
  {#each colors as color, i} <!-- i为可选 -->
    <button
      style="background: {color}"
      aria-label={color}
    >{i + 1}</button>
  {/each}
</div>
```

- 带「键」的遍历

```svelte
{#each things as thing (thing.id)}
  <Thing name={thing.name}/>
{/each}
```

- 异步

```svelte
{#await promise}
  <p>...rolling</p>
{:then number}
  <p>you rolled a {number}!</p>
{:catch error}
  <p style="color: red">{error.message}</p>
{/await}

<!-- 若promise不会被拒绝，catch可省略 -->
<!-- 若不需要在promise完成前显示内容，可以简写 -->
{#await promise then number}
  <p>you rolled a {number}!</p>
{/await}
```

### 事件

- 监听事件

```svelte
<!-- 语法：on<name> -->
<div onpointermove={onpointermove} />

<!-- 语法糖 -->
<div {onpointermove} />

<!-- 内联 -->
<div
  onpointermove={(event) => {
    m.x = event.clientX;
    m.y = event.clientY;
  }}
/>
```

- 使用「捕获」而非「冒泡」进行事件处理

```svelte
<div onkeydowncapture={(e) => alert(`<div> ${e.key}`)} >
  <input onkeydowncapture={(e) => alert(`<input> ${e.key}`)} />
</div>
```

- 组件向外传递Event Handler

```svelte
<script>
  let props = $props();
</script>

<button {...props}>
  Push
</button>
```

### （双向）绑定

- 语法

```svelte
<script>
  let value = $state('world');
  let a = $state(0);
  let b = $state(0);
</script>

<input bind:value={value} />

<!-- 语法糖 -->
<input bind:value />

<!-- 语法糖：a和b会被自动转换为number -->
<input type="number" bind:value={a} />
<input type="range" bind:value={b} min="0" max="10" />
```

- `bind:group`：单选/多选框

```svelte
<script>
  let scoops = $state(1);
  let flavours = $state([]);
</script>

<!-- scoops为被选中的value -->
{#each [1, 2, 3] as number}
  <label>
    <input
      type="radio"
      name="scoops"
      value={number}
      bind:group={scoops}
    />

    {number}
  </label>
{/each}

<!-- flavours为被选中的value的数组 -->
{#each ['a', 'b', 'c'] as flavour}
  <label>
    <input
      type="checkbox"
      name="flavours"
      value={flavour}
      bind:group={flavours}
    />

    {flavour}
  </label>
{/each}
```

- `<select multiple>`

```svelte
<select multiple bind:value={flavours}>
  {#each ['a', 'b', 'c'] as flavour}
    <option>{flavour}</option>
  {/each}
</select>
```

### 类与样式

- [clsx](https://github.com/lukeed/clsx)支持

```svelte
<button
  class={["card", { flipped }]}
  onclick={() => flipped = !flipped}
>
```

- `style:`

```svelte
<button
  class="card"
  style:transform={flipped ? 'rotateY(0)' : ''}
  style:--bg-1="palegoldenrod"
  style:--bg-2="black"
  style:--bg-3="goldenrod"
  onclick={() => flipped = !flipped}
>
```

- 在父组件中指定子组件样式

```svelte
<!-- 子组件 Box -->
<style>
  .box {
    background-color: var(--color, #ddd);
  }
</style>

<!-- 父组件 -->
<div class="boxes">
  <Box --color="red" />
  <Box --color="green" />
  <Box --color="blue" />
</div>
```

### Actions

```js
export function f(node) {
  // ...
}

export function g(node, param) {
  // ...
}
```

```svelte
<!-- 元素挂载后，调用该action -->
<div use:f use:g={/* 表达式 */}>
```

### 过渡动画

- 语法

```svelte
<script>
  import { fade, fly } from 'svelte/transition';

  let visible = $state(true);
</script>

<label>
  <input type="checkbox" bind:checked={visible} />
  visible
</label>

{#if visible}
  <p transition:fade>
    Fades in and out
  </p>

  <p transition:fly={{ y: 200, duration: 2000 }}>
    Flies in and out
  </p>

  <p in:fly={{ y: 200, duration: 2000 }} out:fade>
    Flies in, fades out
  </p>
{/if}
```

- 自定义CSS过渡动画

```svelte
<script>
  import { fade } from 'svelte/transition';
  import { elasticOut } from 'svelte/easing';

  let visible = $state(true);

  function spin(node, { duration }) {
    return {
      duration,
      css: (t, u) => {
        const eased = elasticOut(t);

        return `
          transform: scale(${eased}) rotate(${eased * 1080}deg);
          color: hsl(
            ${Math.trunc(t * 360)},
            ${Math.min(100, 1000 * u)}%,
            ${Math.min(50, 500 * u)}%
          );`
      }
    };
  }
</script>
```

- 自定义JS过渡动画
- 自定义JS过渡动画

```js
function typewriter(node, { speed = 1 }) {
  const valid = node.childNodes.length === 1 && node.childNodes[0].nodeType === Node.TEXT_NODE;

  if (!valid) {
    throw new Error(`This transition only works on elements with a single text node child`);
  }

  const text = node.textContent;
  const duration = text.length / (speed * 0.01);

  return {
    duration,
    tick: (t) => {
      const i = Math.trunc(text.length * t);
      node.textContent = text.slice(0, i);
    }
  };
}
```

- 过渡动画的事件

```svelte
<p
  transition:fly={{ y: 200, duration: 2000 }}
  onintrostart={() => status = 'intro started'}
  onoutrostart={() => status = 'outro started'}
  onintroend={() => status = 'intro ended'}
  onoutroend={() => status = 'outro ended'}
>
  Flies in and out
</p>
```

- 全局过渡

> 默认情况下，只有元素内部的内容的增删会触发过渡

```svelte
<div transition:slide|global>
  {item}
</div>
```

- Key block

> 通过彻底销毁并重建内容来强制触发过渡动画

```svelte
{#key i}
  <p in:typewriter={{ speed: 10 }}>
    {messages[i] || ''}
  </p>
{/key}
```