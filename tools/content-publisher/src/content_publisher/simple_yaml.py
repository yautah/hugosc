from __future__ import annotations

from typing import Any


def parse_yaml_mapping(text: str) -> dict[str, Any]:
    root: dict[str, Any] = {}
    stack: list[tuple[int, dict[str, Any]]] = [(-1, root)]
    last_key_by_indent: dict[int, str] = {}
    lines = text.splitlines()
    index = 0
    while index < len(lines):
        raw = lines[index]
        index += 1
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        stripped = raw.strip()

        if stripped.startswith("- "):
            parent_indent = indent - 2
            while stack and parent_indent <= stack[-1][0]:
                stack.pop()
            parent = stack[-1][1]
            key = last_key_by_indent.get(parent_indent)
            if key is None:
                continue
            if not isinstance(parent.get(key), list):
                parent[key] = []
            parent[key].append(_parse_scalar(stripped[2:].strip()))
            continue

        if ":" not in stripped:
            continue
        key, value = stripped.split(":", 1)
        key = key.strip()
        value = value.strip()

        while stack and indent <= stack[-1][0]:
            stack.pop()
        current = stack[-1][1]
        last_key_by_indent[indent] = key
        if value:
            current[key] = _parse_scalar(value)
        else:
            current[key] = {}
            stack.append((indent, current[key]))
    return root


def dump_yaml_mapping(data: dict[str, Any], indent: int = 0) -> str:
    lines: list[str] = []
    prefix = " " * indent
    for key, value in data.items():
        if isinstance(value, dict):
            lines.append(f"{prefix}{key}:")
            lines.append(dump_yaml_mapping(value, indent + 2))
        elif isinstance(value, list):
            lines.append(f"{prefix}{key}:")
            for item in value:
                lines.append(f"{prefix}  - {_format_scalar(item)}")
        else:
            lines.append(f"{prefix}{key}: {_format_scalar(value)}")
    return "\n".join(line for line in lines if line != "")


def _parse_scalar(value: str) -> Any:
    if value in {"true", "True"}:
        return True
    if value in {"false", "False"}:
        return False
    if value in {"null", "Null", "~"}:
        return None
    if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
        return value[1:-1]
    try:
        return int(value)
    except ValueError:
        return value


def _format_scalar(value: Any) -> str:
    if value is True:
        return "true"
    if value is False:
        return "false"
    if value is None:
        return "null"
    text = str(value)
    if not text or text[0] in {"@", "`", "&", "*", "!", "|", ">", "%", "{", "[", ","} or ": " in text:
        return '"' + text.replace('"', '\\"') + '"'
    return text
