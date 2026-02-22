---
title: Advanced Svelte
tags: [frontend]
---

### Advanced Reactivity

- Raw State

> Characteristics: Changes to properties and content will not trigger updates

```svelte
let data = $state.raw(poll());
```

- Reactive Classes

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

- Built-in Reactive Classes

> Supports Map, Set, Date, URL, URLSearchParams

```js
import { SvelteDate } from 'svelte/reactivity';

let date = new SvelteDate();
```

- ~~store~~

### Content Reuse

- `#snippet`

> snippets can also be passed to child components as props

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

- Passing snippets as component props

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

<!-- Syntactic sugar: snippets declared inside a component automatically become props for those components -->
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

### Motion

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

### Advanced (Two-way) Binding

- contenteditable

> Supports binding textContent and innerHTML

```svelte
<div bind:innerHTML={html} contenteditable></div>
```

- each blocks

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

- Media elements

```svelte
<audio
  {src}
  bind:currentTime={time}
  bind:duration
  bind:paused
></audio>
```

- Dimensions

> Supports clientWidth, clientHeight, offsetWidth, offsetHeight
>
> Read-only bindings

```svelte
<div bind:clientWidth={w} bind:clientHeight={h}>
</div>
```

- DOM Elements

> Read-only bindings

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

- Making component props bindable

```js
let { value = $bindable(''), onsubmit } = $props();
```

- Component Instances

```svelte
<!-- Child Component -->
<script>
  export function f() {}
</script>

<!-- Parent Component -->
<script>
  let child;
</script>

<Child bind:this={child} />
<button onclick={child.f}>Button</button>
```

### Advanced Transitions

- Deferred Transitions

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

- Animations (`animate:`)

> Provides animation effects for elements that are not transitioning

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
<!-- Set -->
<script>
  import { setContext } from 'svelte';

  setContext('key', value);
</script>

<!-- Get -->
<script>
  import { getContext } from 'svelte';

  const value = getContext('key');
</script>
```

### Special Elements

- `<svelte:window>`

  - Can add event listeners
  - Can bind innerWidth, innerHeight, outerWidth, outerHeight, scrollX, scrollY, online (window\.navigator.onLine). All are read-only except scrollX and scrollY.
- `<svelte:document>`

  - Can add event listeners
- `<svelte:body>`

  - Can add event listeners
- `<svelte:head>`

  - Allows adding content to the HTML `<head>`
  - In SSR mode, it will be returned separately from other HTML content
- `<svelte:element>`

  - Can specify the type of the element via the `this` property

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
  - Used to handle component loading errors

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

Decouples code from component instances

- Code will only run when the module is first evaluated
- Can use `export` to export (but cannot use default export, as the default export is the component itself)
