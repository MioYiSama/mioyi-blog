---
title: VSCode & Zed Configuration
tags: [misc]
---

## VSCode

```json {filename="settings.json"}
{
  "editor.codeActionsOnSave": {
    "source.organizeImports": "explicit"
  },
  "editor.cursorSmoothCaretAnimation": "on",
  "editor.fontLigatures": true,
  "editor.formatOnSave": true,
  "editor.linkedEditing": true,
  "editor.mouseWheelZoom": true,
  "editor.quickSuggestions": {
    "strings": "on"
  },
  "editor.smoothScrolling": true,
  "explorer.confirmDelete": false,
  "explorer.confirmDragAndDrop": false,
  "extensions.ignoreRecommendations": true,
  "files.associations": {
    "*.css": "tailwindcss"
  },
  "files.encoding": "utf8",
  "files.eol": "\n",
  "notebook.codeActionsOnSave": {
    "source.organizeImports": "explicit"
  },
  "security.workspace.trust.enabled": false,
  "terminal.integrated.smoothScrolling": true,
  "window.autoDetectColorScheme": true,
  "workbench.editor.tabActionLocation": "left",
  "workbench.iconTheme": "catppuccin-mocha",
  "workbench.list.smoothScrolling": true,
  "workbench.preferredDarkColorTheme": "Catppuccin Mocha",
  "workbench.preferredLightColorTheme": "Catppuccin Latte"
}
```

## Zed

```json {filename="settings.json"}
// Zed settings
//
// For information on how to configure Zed, see the Zed
// documentation: https://zed.dev/docs/configuring-zed
//
// To see all of Zed's default settings without changing your
// custom settings, run `zed: open default settings` from the
// command palette (cmd-shift-p / ctrl-shift-p)
{
  "base_keymap": "JetBrains",
  "restore_on_startup": "launchpad",

  // Appearance
  "buffer_font_family": "SF Mono",
  "buffer_font_size": 18.0,
  "ui_font_family": "SF Pro",
  "ui_font_size": 16.0,
  "theme": {
    "light": "Github Light",
    "dark": "Github Dark"
  },
  "icon_theme": {
    "mode": "system",
    "light": "Catppuccin Latte",
    "dark": "Catppuccin Mocha"
  },
  "tabs": {
    "git_status": false,
    "file_icons": true,
    "close_position": "left"
  },

  // Editor
  "diagnostics": {
    "inline": {
      "enabled": true
    }
  },
  "sticky_scroll": {
    "enabled": true
  },
  "hover_popover_delay": 100,
  "minimap": {
    "show": "auto"
  },
  "colorize_brackets": true,
  "toolbar": {
    "code_actions": false,
    "quick_actions": false
  },
  "preview_tabs": {
    "enable_preview_from_project_panel": false,
    "enable_preview_multibuffer_from_code_navigation": true,
    "enable_keep_preview_on_code_navigation": true
  },
  "tab_bar": {
    "show_tab_bar_buttons": false,
    "show_nav_history_buttons": false
  },
  "title_bar": {
    "show_sign_in": false,
    "show_user_menu": false,
    "show_menus": false,
    "show_branch_name": false
  },
  "git_panel": {
    "tree_view": true
  },
  "terminal": {
    "cursor_shape": "bar"
  },

  // Language
  "prettier": {
    "allowed": true
  },
  "languages": {
    "Python": {
      "language_servers": ["ty", "!basedpyright", "..."]
    }
  },

  // Debloat
  "disable_ai": true,
  "collaboration_panel": {
    "button": false
  },
  "session": {
    "trust_all_worktrees": true
  },
  "telemetry": {
    "diagnostics": false,
    "metrics": false
  }
}
```
