#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Convert Claude Code JSONL conversation logs into readable Markdown.

Usage:
    uv run scripts/jsonl_to_markdown.py <file.jsonl> [<file.jsonl> ...]
    uv run scripts/jsonl_to_markdown.py logs/conversation/

When given a directory, converts every *.jsonl file inside (non-recursive).
Each <name>.jsonl produces a sibling <name>.md.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SYSTEM_REMINDER_RE = re.compile(r"<system-reminder>.*?</system-reminder>", re.DOTALL)
TOOL_RESULT_PREVIEW_CHARS = 600


def strip_system_reminders(text: str) -> str:
    return SYSTEM_REMINDER_RE.sub("", text).strip()


def truncate(text: str, limit: int = TOOL_RESULT_PREVIEW_CHARS) -> str:
    text = text.rstrip()
    if len(text) <= limit:
        return text
    return text[:limit] + f"\n... [truncated, {len(text) - limit} more chars]"


def format_tool_input(tool_name: str, tool_input: dict) -> str:
    """Render a concise summary of a tool_use input block."""
    if not isinstance(tool_input, dict):
        return f"`{tool_input}`"

    preferred_keys = [
        "command", "description", "file_path", "path", "pattern", "query",
        "url", "prompt", "skill", "args", "old_string", "new_string", "content",
    ]

    lines: list[str] = []
    shown = set()
    for key in preferred_keys:
        if key in tool_input:
            value = tool_input[key]
            shown.add(key)
            if isinstance(value, str):
                preview = truncate(value, 300)
                if "\n" in preview or len(preview) > 80:
                    lines.append(f"- **{key}**:\n  ```\n  {preview.replace(chr(10), chr(10) + '  ')}\n  ```")
                else:
                    lines.append(f"- **{key}**: `{preview}`")
            else:
                lines.append(f"- **{key}**: `{json.dumps(value)[:200]}`")

    for key, value in tool_input.items():
        if key in shown:
            continue
        try:
            rendered = json.dumps(value)
        except (TypeError, ValueError):
            rendered = str(value)
        lines.append(f"- **{key}**: `{rendered[:200]}`")

    return "\n".join(lines) if lines else "_(no input)_"


def format_tool_result(content) -> str:
    """Abbreviate a tool_result content block."""
    if isinstance(content, str):
        return truncate(content)
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, dict):
                if item.get("type") == "text":
                    parts.append(item.get("text", ""))
                elif item.get("type") == "image":
                    parts.append("[image omitted]")
                else:
                    parts.append(f"[{item.get('type', 'unknown')} block]")
            else:
                parts.append(str(item))
        return truncate("\n".join(parts))
    return truncate(str(content))


def render_user_message(msg: dict) -> str | None:
    """Return markdown for a user message, or None if it should be skipped."""
    content = msg.get("content", "")

    if isinstance(content, str):
        stripped = strip_system_reminders(content)
        if not stripped:
            return None
        return f"## User\n\n{stripped}\n"

    if isinstance(content, list):
        text_parts: list[str] = []
        has_tool_result = False
        has_non_tool_content = False
        for block in content:
            if not isinstance(block, dict):
                continue
            btype = block.get("type")
            if btype == "text":
                text = strip_system_reminders(block.get("text", ""))
                if text:
                    text_parts.append(text)
                    has_non_tool_content = True
            elif btype == "tool_result":
                has_tool_result = True
            else:
                has_non_tool_content = True

        if has_tool_result and not has_non_tool_content:
            return None

        if not text_parts:
            return None

        return "## User\n\n" + "\n\n".join(text_parts) + "\n"

    return None


def render_assistant_message(msg: dict) -> str | None:
    """Return markdown for an assistant message, or None if empty."""
    content = msg.get("content", "")
    sections: list[str] = []

    if isinstance(content, str):
        if content.strip():
            sections.append(content.strip())
    elif isinstance(content, list):
        for block in content:
            if not isinstance(block, dict):
                continue
            btype = block.get("type")
            if btype == "text":
                text = block.get("text", "").strip()
                if text:
                    sections.append(text)
            elif btype == "thinking":
                continue
            elif btype == "tool_use":
                tool_name = block.get("name", "unknown")
                tool_input = block.get("input", {})
                sections.append(
                    f"### 🔧 Tool: `{tool_name}`\n\n{format_tool_input(tool_name, tool_input)}"
                )
            elif btype == "tool_result":
                sections.append(
                    f"### 📥 Tool Result\n\n```\n{format_tool_result(block.get('content', ''))}\n```"
                )

    if not sections:
        return None
    return "## Assistant\n\n" + "\n\n".join(sections) + "\n"


def convert_file(jsonl_path: Path) -> Path:
    out_path = jsonl_path.with_suffix(".md")
    parts: list[str] = [f"# Conversation: {jsonl_path.stem}\n"]

    tool_results_by_id: dict[str, str] = {}

    with jsonl_path.open("r", encoding="utf-8") as fh:
        # First pass: collect tool_results keyed by tool_use_id so we can
        # render them alongside the matching assistant tool_use.
        lines = fh.readlines()

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("type") != "user":
            continue
        content = obj.get("message", {}).get("content", "")
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_result":
                tool_use_id = block.get("tool_use_id")
                if tool_use_id:
                    tool_results_by_id[tool_use_id] = format_tool_result(
                        block.get("content", "")
                    )

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        obj_type = obj.get("type")
        msg = obj.get("message", {})

        if obj_type == "user":
            rendered = render_user_message(msg)
            if rendered:
                parts.append(rendered)
        elif obj_type == "assistant":
            rendered = render_assistant_message_with_results(msg, tool_results_by_id)
            if rendered:
                parts.append(rendered)

    markdown = "\n---\n\n".join(parts).rstrip() + "\n"
    out_path.write_text(markdown, encoding="utf-8")
    return out_path


def render_assistant_message_with_results(
    msg: dict, tool_results_by_id: dict[str, str]
) -> str | None:
    """Render assistant message, inlining matched tool_results."""
    content = msg.get("content", "")
    sections: list[str] = []

    if isinstance(content, str):
        if content.strip():
            sections.append(content.strip())
    elif isinstance(content, list):
        for block in content:
            if not isinstance(block, dict):
                continue
            btype = block.get("type")
            if btype == "text":
                text = block.get("text", "").strip()
                if text:
                    sections.append(text)
            elif btype == "thinking":
                continue
            elif btype == "tool_use":
                tool_name = block.get("name", "unknown")
                tool_input = block.get("input", {})
                tool_id = block.get("id", "")
                block_md = (
                    f"### 🔧 Tool: `{tool_name}`\n\n"
                    + format_tool_input(tool_name, tool_input)
                )
                if tool_id in tool_results_by_id:
                    block_md += (
                        f"\n\n**Result:**\n\n```\n"
                        + tool_results_by_id[tool_id]
                        + "\n```"
                    )
                sections.append(block_md)

    if not sections:
        return None
    return "## Assistant\n\n" + "\n\n".join(sections) + "\n"


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 1

    targets: list[Path] = []
    for arg in argv[1:]:
        p = Path(arg)
        if p.is_dir():
            targets.extend(sorted(p.glob("*.jsonl")))
        elif p.is_file():
            targets.append(p)
        else:
            print(f"warning: skipping missing path {p}", file=sys.stderr)

    if not targets:
        print("no .jsonl files found", file=sys.stderr)
        return 1

    for jsonl_path in targets:
        out = convert_file(jsonl_path)
        print(f"wrote {out}")

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
