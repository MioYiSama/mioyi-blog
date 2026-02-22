---
title: "没有 Shadow DOM 使用 slot"
tags: [前端]
---

```svelte
<svelte:options customElement={{ tag: "example", shadow: "none" }} />

<div
  {@attach (slot) => {
    slot.appendChild($host().firstElementChild!);
  }}
></div>
```
