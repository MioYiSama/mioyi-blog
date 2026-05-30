---
title: Codex配置
tags: [杂项]
---

> https://chatgpt.com/share/6a1a5336-a6a8-83ea-add7-78820e1c75b8

```toml
#:schema https://developers.openai.com/codex/config-schema.json

# ================ 模型、推理与服务提供商 ================
model = "gpt-5.5"
review_model = "gpt-5.5"
personality = "pragmatic"

model_reasoning_effort = "high"
plan_mode_reasoning_effort = "xhigh"
model_reasoning_summary = "detailed"
model_verbosity = "high"
model_supports_reasoning_summaries = true

# ================ 审批、沙箱、权限与项目信任 ================
approval_policy = "on-request"
approvals_reviewer = "auto_review"

sandbox_mode = "workspace-write"
sandbox_workspace_write.network_access = true
sandbox_workspace_write.exclude_slash_tmp = false
sandbox_workspace_write.exclude_tmpdir_env_var = false

windows.sandbox = "elevated"
windows.sandbox_private_desktop = true

default_permissions = ":workspace"

# ================ 网络与 Web 搜索 ================
web_search = "live"
tools.web_search.context_size = "high"

# ================ Shell、执行环境与本地工具 ================

# ================ Apps、连接器、插件与技能 ================
features.apps = false
features.connectors = false
features.plugins = false

# ================ MCP 服务器与 OAuth ================
features.enable_mcp_apps = false

# ================ Hooks 生命周期 ================
features.hooks = false

# ================ 多 Agent ================
features.multi_agent = true

# ================ Memories 记忆 ================
features.memories = true

# ================ 通用行为、项目文档与功能开关 ================
check_for_update_on_startup = false
features.codex_git_commit = true
features.js_repl = true
features.terminal_resize_reflow = true
features.mentions_v2 = true
features.undo = true
features.fast_mode = false
features.prevent_idle_sleep = true

# ================ 日志、历史、反馈与遥测 ================
analytics.enabled = false
feedback.enabled = false
history.persistence = "save-all"

# ================ TUI、通知、外观与提示状态 ================
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
