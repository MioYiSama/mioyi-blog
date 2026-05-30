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

自定义provider（以OpenRouter为例）：

> 环境变量中需包含 `OPENROUTER_API_KEY`

```toml
#:schema https://developers.openai.com/codex/config-schema.json

# ================ 模型、推理与服务提供商 ================
model_provider = "openrouter"
model_catalog_json = "~/.codex/model-catalog.openrouter.json"

model_providers."openrouter".name = "OpenRouter"
model_providers."openrouter".base_url = "https://openrouter.ai/api/v1"
model_providers."openrouter".env_key = "OPENROUTER_API_KEY"
model_providers."openrouter".wire_api = "responses"

personality = "pragmatic"
model_reasoning_effort = "xhigh"
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
tui.show_tooltips = false
notice.hide_full_access_warning = false
notice.hide_world_writable_warning = false
notice.hide_rate_limit_model_nudge = false
show_raw_agent_reasoning = true
hide_agent_reasoning = false
```

catalog生成脚本：

```py
#!/usr/bin/env python3
"""
Convert OpenRouter /api/v1/models into a Codex model_catalog_json file.

Usage:
  python3 openrouter_to_codex_catalog.py \
    --output ~/.codex/model-catalog.openrouter.json

Then in ~/.codex/config.toml:
  model_catalog_json = "/Users/yourname/.codex/model-catalog.openrouter.json"
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


OPENROUTER_MODELS_URL = "https://openrouter.ai/api/v1/models"

BASE_INSTRUCTIONS = (
    "You are Codex, a coding agent. Help the user modify, understand, test, "
    "and improve code in the current workspace."
)

REASONING_LEVELS = [
    {"effort": "low", "description": "Fast responses with lighter reasoning"},
    {"effort": "medium", "description": "Balanced reasoning"},
    {"effort": "high", "description": "Deeper reasoning"},
    {"effort": "xhigh", "description": "Maximum reasoning"},
]


def fetch_json(url: str) -> dict[str, Any]:
    headers = {
        "User-Agent": "openrouter-to-codex-catalog/1.0",
        "Accept": "application/json",
    }

    # OpenRouter's models endpoint is generally public, but this supports
    # private/provider-filtered results if OPENROUTER_API_KEY is present.
    api_key = os.environ.get("OPENROUTER_API_KEY")
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    req = urllib.request.Request(url, headers=headers)

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = resp.read().decode("utf-8")
            return json.loads(body)
    except Exception as exc:
        raise SystemExit(f"Failed to fetch {url}: {exc}") from exc


def with_query(url: str, params: dict[str, str]) -> str:
    parsed = urllib.parse.urlparse(url)
    existing = dict(urllib.parse.parse_qsl(parsed.query, keep_blank_values=True))
    existing.update(params)
    query = urllib.parse.urlencode(existing)
    return urllib.parse.urlunparse(parsed._replace(query=query))


def clean_text(value: Any, default: str = "") -> str:
    if value is None:
        return default
    text = str(value).replace("\r\n", "\n").strip()
    return text if text else default


def int_or_none(value: Any) -> int | None:
    try:
        if value is None:
            return None
        return int(value)
    except (TypeError, ValueError):
        return None


def model_context_length(model: dict[str, Any]) -> int | None:
    top_provider = model.get("top_provider") or {}
    return (
        int_or_none(top_provider.get("context_length"))
        or int_or_none(model.get("context_length"))
    )


def codex_input_modalities(model: dict[str, Any]) -> list[str]:
    architecture = model.get("architecture") or {}
    raw = architecture.get("input_modalities") or ["text"]

    allowed = []
    for item in raw:
        if item == "text":
            allowed.append("text")
        elif item == "image":
            allowed.append("image")

    # Codex only has text/image input modality enum. If OpenRouter says only
    # file/audio/etc., keep text as a conservative fallback for chat usage.
    return allowed or ["text"]


def has_text_output(model: dict[str, Any]) -> bool:
    architecture = model.get("architecture") or {}
    outputs = architecture.get("output_modalities") or ["text"]
    return "text" in outputs


def supports_reasoning(model: dict[str, Any]) -> bool:
    params = set(model.get("supported_parameters") or [])
    return bool({"reasoning", "include_reasoning"} & params)


def supports_tools(model: dict[str, Any]) -> bool:
    params = set(model.get("supported_parameters") or [])
    return "tools" in params


def make_codex_model(
    model: dict[str, Any],
    priority: int,
    enable_parallel_tools: bool,
) -> dict[str, Any] | None:
    model_id = clean_text(model.get("id"))
    if not model_id:
        return None

    ctx = model_context_length(model)

    reasoning = supports_reasoning(model)
    tool_support = supports_tools(model)

    item: dict[str, Any] = {
        "slug": model_id,
        "display_name": clean_text(model.get("name"), model_id),
        "description": clean_text(model.get("description"), f"OpenRouter model: {model_id}"),

        # Reasoning metadata. Leave null/empty for models that do not advertise reasoning.
        "default_reasoning_level": "medium" if reasoning else None,
        "supported_reasoning_levels": REASONING_LEVELS if reasoning else [],

        # Codex agent/tool metadata.
        "shell_type": "shell_command",
        "visibility": "list",
        "supported_in_api": True,
        "priority": priority,

        # Newer Codex versions may expect these collection fields.
        "additional_speed_tiers": [],
        "service_tiers": [],
        "default_service_tier": None,

        "availability_nux": None,
        "upgrade": None,
        "base_instructions": BASE_INSTRUCTIONS,
        "model_messages": None,

        # Be conservative for non-OpenAI models unless OpenRouter exposes
        # exact compatibility. You can override these manually per model.
        "supports_reasoning_summaries": False,
        "default_reasoning_summary": "none",
        "support_verbosity": False,
        "default_verbosity": None,

        # Keep patch/shell tools available for Codex.
        "apply_patch_tool_type": "freeform",
        "web_search_tool_type": "text",
        "truncation_policy": {"mode": "tokens", "limit": 10000},

        # OpenRouter advertises "tools", but not every backend handles parallel
        # tool calls cleanly. Default is off unless --enable-parallel-tools is used.
        "supports_parallel_tool_calls": bool(tool_support and enable_parallel_tools),

        "supports_image_detail_original": "image" in codex_input_modalities(model),
        "context_window": ctx,
        "max_context_window": ctx,

        # Let Codex derive 90% from context_window when null.
        "auto_compact_token_limit": None,
        "effective_context_window_percent": 95,

        "experimental_supported_tools": [],
        "input_modalities": codex_input_modalities(model),
        "supports_search_tool": False,
        "tool_mode": None,
    }

    return item


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert OpenRouter models to Codex model-catalog JSON."
    )
    parser.add_argument(
        "--url",
        default=OPENROUTER_MODELS_URL,
        help=f"OpenRouter models URL. Default: {OPENROUTER_MODELS_URL}",
    )
    parser.add_argument(
        "--output",
        default=str(Path.home() / ".codex" / "model-catalog.openrouter.json"),
        help="Output path. Default: ~/.codex/model-catalog.openrouter.json",
    )
    parser.add_argument(
        "--modalities",
        default="all",
        help='Value for output_modalities query parameter. Default: "all". '
             'Use "text" if you only want text-output models.',
    )
    parser.add_argument(
        "--include-non-text-output",
        action="store_true",
        help="Include image/audio/embedding-only models. Usually not useful for Codex.",
    )
    parser.add_argument(
        "--include-expired",
        action="store_true",
        help="Include models with expiration_date set.",
    )
    parser.add_argument(
        "--enable-parallel-tools",
        action="store_true",
        help="Set supports_parallel_tool_calls=true for models advertising tools.",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON with indentation.",
    )

    args = parser.parse_args()

    url = args.url
    if args.modalities:
        url = with_query(url, {"output_modalities": args.modalities})

    payload = fetch_json(url)
    models = payload.get("data")
    if not isinstance(models, list):
        raise SystemExit("Unexpected OpenRouter response: missing top-level data list")

    codex_models: list[dict[str, Any]] = []
    skipped_non_text = 0
    skipped_expired = 0

    for raw in models:
        if not isinstance(raw, dict):
            continue

        if raw.get("expiration_date") and not args.include_expired:
            skipped_expired += 1
            continue

        if not args.include_non_text_output and not has_text_output(raw):
            skipped_non_text += 1
            continue

        converted = make_codex_model(
            raw,
            priority=len(codex_models),
            enable_parallel_tools=args.enable_parallel_tools,
        )
        if converted:
            codex_models.append(converted)

    catalog = {"models": codex_models}

    output = Path(args.output).expanduser()
    output.parent.mkdir(parents=True, exist_ok=True)

    with output.open("w", encoding="utf-8") as f:
        if args.pretty:
            json.dump(catalog, f, ensure_ascii=False, indent=2)
            f.write("\n")
        else:
            json.dump(catalog, f, ensure_ascii=False, separators=(",", ":"))
            f.write("\n")

    print(f"Wrote {len(codex_models)} models to {output}")
    if skipped_expired:
        print(f"Skipped expired/deprecated models: {skipped_expired}")
    if skipped_non_text:
        print(f"Skipped non-text-output models: {skipped_non_text}")
    print()
    print("Add this to ~/.codex/config.toml:")
    print(f'model_catalog_json = "{output}"')

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```
