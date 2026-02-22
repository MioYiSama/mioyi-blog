---
title: Svelte Basics
tags: [frontend]
---

### Introduction

- Use `{}` to embed JS expressions

```svelte
<script>
  let src = '/tutorial/image.gif';
  let name = 'Rick Astley';
</script>

<p>Name: {name}</p>
<img src={src}/>

<!-- Syntactic sugar -->
<img {src} />
```

- Use `<style>` to add styles

```svelte
<p>This is a paragraph.</p>

<style>
  p {
    color: goldenrod;
    font-size: 2em;
  }
</style>
```

- Import and use components

```svelte
<script lang="ts">
  import Nested from './Nested.svelte';
</script>

<Nested />
```

- Turn strings into HTML code

```svelte
<p>{@html string}</p>
```

### Reactivity

- Creation and modification of "State"

> $... are called Runes

```svelte
<script>
  let count = $state(0);

  function increment() {
    count += 1;
  }
</script>
```

- "Deep State"

```svelte
<script>
  let numbers = $state([1, 2, 3, 4]);

  function addNumber() {
    numbers.push(numbers.length + 1);
  }
</script>
```

- "Derived State"

```svelte
<script>
  let numbers = $state([1, 2, 3, 4]);
  let total = $derived(numbers.reduce((t, n) => t + n, 0));
</script>
```

- State "Snapshot"

```svelte
<script>
  let numbers = $state([1, 2, 3, 4]);
  console.log($state.snapshot(numbers));

  // Use $inspect to automatically log a snapshot whenever the state changes
  $inspect(numbers).with(console.trace);
</script>
```

- "Effects"

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

- Using "State" outside of Svelte files

```js
export const counter = $state({
  count: 0,
});
```

### Component "Props"

- Declaring "Props"

```svelte
<script lang="ts">
  let { answer } = $props();
</script>
```

- Default values for props

```svelte
<script>
  let { answer = 'a mystery' } = $props();
</script>
```

- Passing props

```svelte
<PackageInfo
  name={pkg.name}
  version={pkg.version}
  description={pkg.description}
  website={pkg.website}
/>

<!-- Syntactic sugar -->
<PackageInfo {...pkg} />
```

### "Logic" in HTML

- Branching (`#if`, `:else if`, `:else`, `/if`)

```svelte
{#if count > 10}
  <p>{count} is greater than 10</p>
{:else if count < 5}
  <p>{count} is less than 5</p>
{:else}
  <p>{count} is between 5 and 10</p>
{/if}
```

- Iteration (`#each as`)

```svelte
<div>
  {#each colors as color, i} <!-- i is optional -->
    <button
      style="background: {color}"
      aria-label={color}
    >{i + 1}</button>
  {/each}
</div>
```

- Iteration with "Keys"

```svelte
{#each things as thing (thing.id)}
  <Thing name={thing.name}/>
{/each}
```

- Async

```svelte
{#await promise}
  <p>...rolling</p>
{:then number}
  <p>you rolled a {number}!</p>
{:catch error}
  <p style="color: red">{error.message}</p>
{/await}

<!-- If the promise won't be rejected, catch can be omitted -->
<!-- If you don't need to show content before the promise completes, you can use the shorthand -->
{#await promise then number}
  <p>you rolled a {number}!</p>
{/await}
```

### Events

- Listening to events

```svelte
<!-- Syntax: on<name> -->
<div onpointermove={onpointermove} />

<!-- Syntactic sugar -->
<div {onpointermove} />

<!-- Inline -->
<div
  onpointermove={(event) => {
    m.x = event.clientX;
    m.y = event.clientY;
  }}
/>
```

- Using "Capture" instead of "Bubbling" for event handling

```svelte
<div onkeydowncapture={(e) => alert(`<div> ${e.key}`)} >
  <input onkeydowncapture={(e) => alert(`<input> ${e.key}`)} />
</div>
```

- Components passing Event Handlers outward

```svelte
<script>
  let props = $props();
</script>

<button {...props}>
  Push
</button>
```

### (Two-way) Binding

- Syntax

```svelte
<script>
  let value = $state('world');
  let a = $state(0);
  let b = $state(0);
</script>

<input bind:value={value} />

<!-- Syntactic sugar -->
<input bind:value />

<!-- Syntactic sugar: a and b will be automatically converted to number -->
<input type="number" bind:value={a} />
<input type="range" bind:value={b} min="0" max="10" />
```

- `bind:group`: Radio/Checkbox group

```svelte
<script>
  let scoops = $state(1);
  let flavours = $state([]);
</script>

<!-- scoops is the selected value -->
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

<!-- flavours is an array of selected values -->
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

### Classes and Styles

- [clsx](https://github.com/lukeed/clsx) support

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

- Specifying child component styles in a parent component

```svelte
<!-- Child component Box -->
<style>
  .box {
    background-color: var(--color, #ddd);
  }
</style>

<!-- Parent component -->
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
<!-- After the element is mounted, call this action -->
<div use:f use:g={/* expression */}>
```

### Transitions

- Syntax

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

- Custom CSS transitions

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

- Custom JS transitions

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
    },
  };
}
```

- Transition events

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

- Global transitions

> By default, transitions only trigger when the immediate parent block's content is added or removed.

```svelte
<div transition:slide|global>
  {item}
</div>
```

- Key block

> Force a transition to trigger by completely destroying and recreating the content.

```svelte
{#key i}
  <p in:typewriter={{ speed: 10 }}>
    {messages[i] || ''}
  </p>
{/key}
```
