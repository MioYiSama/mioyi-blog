---
title: TypeScript Configuration
tags: [frontend]
---

```jsonc {filename="tsconfig.json"}
{
  "compilerOptions": {
    // Type Checking
    "strict": true,
    "allowUnreachableCode": false,
    "allowUnusedLabels": false,
    "exactOptionalPropertyTypes": true,
    "noFallthroughCasesInSwitch": true,
    "noImplicitOverride": true,
    "noImplicitReturns": true,
    "noPropertyAccessFromIndexSignature": true,
    "noUncheckedIndexedAccess": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,

    // Modules
    "module": "esnext",
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    
    // Emit
    "noEmit": true,

    // JavaScript Support
    "allowJs": false,

    // Interop Constraints
    "erasableSyntaxOnly": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true,

    // Language and Environment
    "lib": ["ESNext", "DOM", "DOM.Iterable", "DOM.AsyncIterable"],
    "target": "esnext",

    // Completeness
    "skipLibCheck": true
  }
}
```

In addition, the official TS documentation does not recommend paths, but recommends Node Subpath Imports instead.

> [!NOTE]
> "... Note that this feature does not change how import paths are emitted by tsc, so paths should only be used to inform TypeScript that another tool has this mapping and will use it at runtime or when bundling ..."

```json {filename="package.json"}
{
  "type": "module",
  "imports": {
    "#*": "./src/*"
  }
}
```