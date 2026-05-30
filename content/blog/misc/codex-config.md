---
title: Codex Config
tags: [misc]
---

> https://chatgpt.com/share/6a1a5336-a6a8-83ea-add7-78820e1c75b8

```toml
#:schema https://developers.openai.com/codex/config-schema.json

# ================ Model, Reasoning & Provider ================
model = "gpt-5.5"
review_model = "gpt-5.5"
personality = "pragmatic"

model_reasoning_effort = "high"
plan_mode_reasoning_effort = "xhigh"
model_reasoning_summary = "detailed"
model_verbosity = "high"
model_supports_reasoning_summaries = true

# ================ Approval, Sandbox, Permissions & Project Trust ================
approval_policy = "on-request"
approvals_reviewer = "auto_review"

sandbox_mode = "workspace-write"
sandbox_workspace_write.network_access = true
sandbox_workspace_write.exclude_slash_tmp = false
sandbox_workspace_write.exclude_tmpdir_env_var = false

windows.sandbox = "elevated"
windows.sandbox_private_desktop = true

default_permissions = ":workspace"

# ================ Network & Web Search ================
web_search = "live"
tools.web_search.context_size = "high"

# ================ Shell, Execution Environment & Local Tools ================

# ================ Apps, Connectors, Plugins & Skills ================
features.apps = false
features.connectors = false
features.plugins = false

# ================ MCP Servers & OAuth ================
features.enable_mcp_apps = false

# ================ Hooks Lifecycle ================
features.hooks = false

# ================ Multi-Agent ================
features.multi_agent = true

# ================ Memories ================
features.memories = true

# ================ General Behavior, Project Docs & Feature Toggles ================
check_for_update_on_startup = false
features.codex_git_commit = true
features.js_repl = true
features.terminal_resize_reflow = true
features.mentions_v2 = true
features.undo = true
features.fast_mode = false
features.prevent_idle_sleep = true

# ================ Logs, History, Feedback & Telemetry ================
analytics.enabled = false
feedback.enabled = false
history.persistence = "save-all"

# ================ TUI, Notifications, Appearance & Prompt Status ================
tui.status_line = [
    "model-with-reasoning",
    "current-dir",
    "permissions",
    "context-used",
]
tui.status_line_use_colors = true
notice.hide_full_access_warning = false
notice.hide_world_writable_warning = false
notice.hide_rate_limit_model_nudge = false
show_raw_agent_reasoning = true
hide_agent_reasoning = false
tui.show_tooltips = false
tui.model_availability_nux."gpt-5.5" = 4
```
