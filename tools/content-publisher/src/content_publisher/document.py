from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from content_publisher.simple_yaml import dump_yaml_mapping, parse_yaml_mapping


FRONT_MATTER_RE = re.compile(r"\A---\s*\n(?P<yaml>.*?)\n---\s*\n(?P<body>.*)\Z", re.S)
PLATFORM_BLOCK_RE = re.compile(
    r"<!--\s*platform:(?P<platform>[a-zA-Z0-9_-]+)\s*-->(?P<body>.*?)<!--\s*/platform\s*-->",
    re.S,
)
EXCESS_BLANK_LINES_RE = re.compile(r"\n{3,}")


@dataclass(frozen=True)
class Article:
    path: Path
    front_matter: dict[str, Any]
    body: str

    @property
    def slug(self) -> str:
        if self.front_matter.get("slug"):
            return str(self.front_matter["slug"])
        return self.path.stem

    @property
    def title(self) -> str:
        return str(self.front_matter.get("title") or self.slug)

    @property
    def description(self) -> str:
        return str(self.front_matter.get("description") or "")


def load_article(path: Path) -> Article:
    raw = path.read_text(encoding="utf-8")
    match = FRONT_MATTER_RE.match(raw)
    if not match:
        raise ValueError(f"{path} must start with YAML Front Matter delimited by ---")
    front_matter = parse_yaml_mapping(match.group("yaml"))
    if not isinstance(front_matter, dict):
        raise ValueError(f"{path} Front Matter must be a YAML mapping")
    return Article(path=path, front_matter=front_matter, body=match.group("body"))


def body_for_platform(body: str, platform: str) -> str:
    def replace(match: re.Match[str]) -> str:
        block_platform = match.group("platform").strip().lower()
        return match.group("body").strip() + "\n" if block_platform == platform else ""

    filtered = PLATFORM_BLOCK_RE.sub(replace, body)
    return EXCESS_BLANK_LINES_RE.sub("\n\n", filtered).strip() + "\n"


def dump_front_matter(front_matter: dict[str, Any]) -> str:
    return dump_yaml_mapping(front_matter).strip()
