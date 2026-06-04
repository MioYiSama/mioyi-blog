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
  "ui_font_size": 20.0,
  "buffer_font_size": 18.0,
  "theme": {
    "mode": "dark",
    "light": "One Light",
    "dark": "Catppuccin Mocha"
  },
  "icon_theme": {
    "mode": "system",
    "light": "Catppuccin Mocha",
    "dark": "Catppuccin Mocha"
  },
  "tabs": {
    "git_status": false,
    "file_icons": true,
    "close_position": "left"
  },
  "agent": {
    "sidebar_side": "right",
    "dock": "right"
  },
  "project_panel": {
    "dock": "left"
  },
  "outline_panel": {
    "dock": "left"
  },
  "git_panel": {
    "dock": "left"
  },

  // Debloat
  "collaboration_panel": {
    "button": false
  },
  "session": {
    "trust_all_worktrees": true
  },
  "telemetry": {
    "diagnostics": false,
    "metrics": false
  },
  "edit_predictions": {
    "mode": "subtle"
  },

  // Specific Settings
  "languages": {
    "Go": {
      "language_servers": ["gopls", "golangci-lint"]
    },
    "Python": {
      "language_servers": ["ty", "ruff"]
    },
    "Kotlin": {
      "language_servers": ["kotlin-lsp"]
    },
    "CSS": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        }
      ]
    },
    "GraphQL": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        }
      ]
    },
    "Handlebars": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        }
      ]
    },
    "HTML": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        }
      ]
    },
    "JavaScript": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        },
        {
          "code_action": "source.fixAll.oxc"
        }
      ]
    },
    "JSON": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        }
      ]
    },
    "JSON5": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        }
      ]
    },
    "JSONC": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        }
      ]
    },
    "Less": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        }
      ]
    },
    "Markdown": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        }
      ]
    },
    "MDX": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        }
      ]
    },
    "SCSS": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        }
      ]
    },
    "TypeScript": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        }
      ]
    },
    "TSX": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        }
      ]
    },
    "Vue.js": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        }
      ]
    },
    "YAML": {
      "format_on_save": "on",
      "prettier": {
        "allowed": false
      },
      "formatter": [
        {
          "language_server": {
            "name": "oxfmt"
          }
        }
      ]
    }
  },
  "lsp": {
    "golangci-lint": {
      "initialization_options": {
        "command": [
          "golangci-lint",
          "run",
          "--output.json.path",
          "stdout",
          "--show-stats=false",
          "--output.text.path="
        ]
      }
    },
    "oxlint": {
      "initialization_options": {
        "settings": {
          "configPath": null,
          "run": "onType",
          "disableNestedConfig": false,
          "fixKind": "safe_fix",
          "unusedDisableDirectives": "deny"
        }
      }
    },
    "oxfmt": {
      "initialization_options": {
        "settings": {
          "fmt.configPath": null,
          "run": "onSave"
        }
      }
    },
    "tinymist": {
      "initialization_options": {
        // Enable background preview
        // Server will be running on 127.0.0.1:23635
        "preview": {
          "background": {
            "enabled": true
          }
        }
      },
      "settings": {
        "exportPdf": "onSave",
        "outputPath": "$root/$name"
      }
    }
  },
  "agent_servers": {
    "opencode": {
      "type": "registry",
      "favorite_config_option_values": {
        "model": [
          "opencode-go/deepseek-v4-pro",
          "opencode-go/kimi-k2.6",
          "opencode-go/glm-5.1",
          "opencode-go/qwen3.7-max"
        ]
      },
      "default_config_options": {
        "model": "opencode-go/kimi-k2.6"
      }
    }
  },
  "ssh_connections": [
    {
      "host": "mioyi",
      "args": [],
      "projects": [
        {
          "paths": ["/root/docker"]
        }
      ]
    }
  ]
}
```
