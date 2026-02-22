---
title: Svelte 进阶
tags: [前端]
---

### 响应式进阶

- 原始状态

> 特点：属性和内容的变化不会触发更新

```svelte
let data = $state.raw(poll());
```

- 响应式的类

```js
class Box {
  width = $state(0);
  height = $state(0);
  area = $derived(this.width * this.height);

  constructor(width, height) {
    this.width = width;
    this.height = height;
  }

  embiggen(amount) {
    this.width += amount;
    this.height += amount;
  }
}

class Box {
  #width = $state(0);
  #height = $state(0);
  area = $derived(this.#width * this.#height);

  constructor(width, height) {
    this.#width = width;
    this.#height = height;
  }

  get width() {
    return this.#width;
  }

  get height() {
    return this.#height;
  }

  set width(value) {
    this.#width = Math.max(0, Math.min(MAX_SIZE, value));
  }

  set height(value) {
    this.#height = Math.max(0, Math.min(MAX_SIZE, value));
  }

  embiggen(amount) {
    this.width += amount;
    this.height += amount;
  }
}
```

- 自带的响应式的类

> 支持Map, Set, Date, URL, URLSearchParams

```js
import { SvelteDate } from 'svelte/reactivity';

let date = new SvelteDate();
```

- ~~store~~

### 内容复用

- `#snippet`

> snippet也可以作为属性传递给子组件

```svelte
<table>
  <tbody>
    {#snippet monkey(emoji, description)}
      <tr>
        <td>{emoji}</td>
        <td>{description}</td>
        <td>\\u{emoji.charCodeAt(0).toString(16)}\\u{emoji.charCodeAt(1).toString(16)}</td>
        <td>&amp#{emoji.codePointAt(0)}</td>
      </tr>
    {/snippet}

    {@render monkey('🙈', 'see no evil')}
    {@render monkey('🙉', 'hear no evil')}
    {@render monkey('🙊', 'speak no evil')}
  </tbody>
</table>
```

- 将snippet作为组件的属性

```svelte
<FilteredList
  data={colors}
  field="name"
  {header}
  {row}
></FilteredList>

{#snippet header()}
<!-- ... -->
{/snippet}

{#snippet row()}
<!-- ... -->
{/snippet}

<!-- 语法糖：在组件内部声明的snippet会自动成为这些组件的属性 -->
<FilteredList
  data={colors}
  field="name"
>
  {#snippet header()}
  <!-- ... -->
  {/snippet}

  {#snippet row()}
  <!-- ... -->
  {/snippet}
</FilteredList>
```

### 动效

- Tween

```svelte
<script>
  import { Tween } from 'svelte/motion';
  import { cubicOut } from 'svelte/easing';

  let progress = new Tween(0, {
    duration: 400,
    easing: cubicOut
  });
</script>

<progress value={progress.current}></progress>

<button onclick={() => (progress.target = 0)}>
  0%
</button>

<button onclick={() => (progress.target = 1)}>
  100%
</button>
```

- Spring

```svelte
<script>
  import { Spring } from 'svelte/motion';

  let coords = new Spring({ x: 50, y: 50 }, {
    stiffness: 0.1,
    damping: 0.25
  });

  let size = new Spring(10);
</script>

<svg
  onmousemove={(e) => {
    coords.target = { x: e.clientX, y: e.clientY };
  }}
  onmousedown={() => (size.target = 30)}
  onmouseup={() => (size.target = 10)}
  role="presentation"
>
  <circle
    cx={coords.current.x}
    cy={coords.current.y}
    r={size.current}
  />
</svg>
```

### （双向）绑定进阶

- contenteditable

> 支持绑定textContent和innerHTML

```svelte
<div bind:innerHTML={html} contenteditable></div>
```

- each块

```svelte
{#each todos as todo}
  <li class={{ done: todo.done }}>
    <input
      type="checkbox"
      bind:checked={todo.done}
    />

    <input
      type="text"
      placeholder="What needs to be done?"
      bind:value={todo.text}
    />
  </li>
{/each}
```

- Media元素

```svelte
<audio
  {src}
  bind:currentTime={time}
  bind:duration
  bind:paused
></audio>
```

- Dimensions

> 支持clientWidth, clientHeight, offsetWidth, offsetHeight
> 
> 只读绑定

```svelte
<div bind:clientWidth={w} bind:clientHeight={h}>
</div>
```

- DOM元素

> 只读绑定

```svelte
<script>
  let canvas;

  $effect(() => {
    const context = canvas.getContext('2d');
    // ...
  });
</script>

<canvas bind:this={canvas} width={32} height={32}></canvas>
```

- 让组件属性可绑定

```js
let { value = $bindable(''), onsubmit } = $props();
```

- 组件元素

```svelte
<!-- 子组件 -->
<script>
  export function f() {}
</script>

<!-- 父组件 -->
<script>
  let child;
</script>

<Child bind:this={child} />
<button onclick={child.f}>Button</button>
```

### 过渡动画进阶

- 延时过渡

```js
import { crossfade } from 'svelte/transition';
import { quintOut } from 'svelte/easing';

export const [send, receive] = crossfade({
  duration: (d) => Math.sqrt(d * 200),

  fallback(node, params) {
    const style = getComputedStyle(node);
    const transform = style.transform === 'none' ? '' : style.transform;

    return {
      duration: 600,
      easing: quintOut,
      css: (t) => `
        transform: ${transform} scale(${t});
        opacity: ${t}
      `
    };
  }
});
```

```svelte
<li
  in:receive={{ key: todo.id }}
  out:send={{ key: todo.id }}
/>
```

- 动画（`animate:`）

> 为不进行过渡的元素提供动画效果

```svelte
<li
  class={{ done: todo.done }}
  in:receive={{ key: todo.id }}
  out:send={{ key: todo.id }}
  animate:flip
>
```

### Context

```svelte
<!-- 设置 -->
<script>
  import { setContext } from 'svelte';

  setContext('key', value);
</script>

<!-- 获取 -->
<script>
  import { getContext } from 'svelte';

  const value = getContext('key');
</script>
```

### 特殊元素

- `<svelte:window>`
  
  - 可添加事件监听器
  - 可绑定innerWidth, innerHeight, outerWidth, outerHeight, scrollX, scrollY, online（window.navigator.onLine）。除了scrollX和scrollY均为只读绑定
- `<svelte:document>`
  
  - 可添加事件监听器
- `<svelte:body>`
  
  - 可添加事件监听器
- `<svelte:head>`
  
  - 可以往HTML的`<head>`中加入内容
  - SSR模式下会与其他HTML内容分开返回
- `<svelte:element>`
  
  - 可通过`this`属性指定该元素的类型

```svelte
<script>
  const options = ['h1', 'h2', 'h3', 'p', 'marquee'];
  let selected = $state(options[0]);
</script>

<svelte:element this={selected}>
  I'm a <code>&lt;{selected}&gt;</code> element
</svelte:element>
```

- `<svelte:boundary>`
  - 可用于处理组件加载错误的情况

```svelte
<svelte:boundary onerror={(e) => console.error(e)}>
  <FlakyComponent />

  {#snippet failed(error, reset)}
    <p>Oops! {error.message}</p>
    <button onclick={reset}>Reset</button>
  {/snippet}
</svelte:boundary>
```

### `<script module>`

让代码从组件实例中分离出来

- 代码只会在模块首次被Evaluate的时候运行
- 可以使用export导出（但不能使用默认导出，因为默认导出是组件自身）
	PUBLIC	f	{"tags": ["Frontend"], "property": {"hasCode": true}}
1	9dc7fBTTjuVLUCDDW6zqfc	1	1747915586	1747916992	NORMAL	#Frontend
# Framework Agnostic Icon

Packages:

```bash
pnpm add -D @fortawesome/fontawesome-svg-core @fortawesome/free-brands-svg-icons @fortawesome/free-solid-svg-icons
```

Definition:

```svelte
<script lang="ts">
  import { type IconDefinition } from "@fortawesome/fontawesome-svg-core";

  type IconProps = {
    icon: IconDefinition;
    size?: number;
    className?: string;
  };

  const { icon, size = 32, className = "fill-black" }: IconProps = $props();

  let [width, height, , , data] = icon.icon;
</script>

<svg
  width={size}
  height={size}
  viewBox={`0 0 ${width} ${height}`}
  class={[className, "dark:invert"]}
>
  <path d={data as string} />
</svg>
```

Usage:

```svelte
<script lang="ts">
  import { faUser } from "@fortawesome/free-solid-svg-icons";
  import Icon from "../components/Icon.svelte";
</script>

<p class="m-0 flex p-0">Hello</p>

<Icon icon={faUser} />
<Icon icon={faUser} size={64} />
<Icon icon={faUser} className="fill-blue-400" />
```