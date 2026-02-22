---
title: "slot without shadow dom"
tags: [frontend]
---

```svelte
<svelte:options customElement={{ tag: "example", shadow: "none" }} />

<div
  {@attach (slot) => {
    slot.appendChild($host().firstElementChild!);
  }}
></div>
```
