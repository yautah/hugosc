from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from content_publisher.simple_yaml import parse_yaml_mapping


@dataclass(frozen=True)
class WeChatConfig:
    enabled: bool
    app_id: str | None
    app_secret: str | None
    author: str
    default_template: str
    default_need_open_comment: int
    default_only_fans_can_comment: int


@dataclass(frozen=True)
class PublisherConfig:
    root: Path
    dist: Path
    hugo_content_dir: Path | None
    hugo_root: Path
    assets_image_dir: Path
    site: dict[str, Any]
    wechat: WeChatConfig
    baijiahao: dict[str, Any]


def load_config(config_path: Path) -> PublisherConfig:
    load_dotenv_file(config_path.parent / ".env")

    with config_path.open("r", encoding="utf-8") as handle:
        raw = parse_yaml_mapping(handle.read())

    paths = raw.get("paths", {})
    hugo_root = _find_hugo_root(config_path.parent)
    dist = _resolve(config_path.parent, paths.get("dist", "dist"))
    hugo_dir_raw = paths.get("hugo_content_dir") or ""
    hugo_content_dir = _resolve(config_path.parent, hugo_dir_raw) if hugo_dir_raw else None
    assets_image_dir_raw = paths.get("assets_image_dir") or ""
    assets_image_dir = (
        _resolve(config_path.parent, assets_image_dir_raw) if assets_image_dir_raw else hugo_root / "assets" / "images"
    )

    wechat_raw = raw.get("wechat", {})
    app_id_env = wechat_raw.get("app_id_env", "WECHAT_APP_ID")
    app_secret_env = wechat_raw.get("app_secret_env", "WECHAT_APP_SECRET")

    wechat = WeChatConfig(
        enabled=bool(wechat_raw.get("enabled", True)),
        app_id=os.getenv(app_id_env),
        app_secret=os.getenv(app_secret_env),
        author=str(wechat_raw.get("author", raw.get("site", {}).get("author", ""))),
        default_template=str(wechat_raw.get("default_template", "redream-obsidian-blue")),
        default_need_open_comment=int(wechat_raw.get("default_need_open_comment", 0)),
        default_only_fans_can_comment=int(wechat_raw.get("default_only_fans_can_comment", 0)),
    )

    return PublisherConfig(
        root=config_path.parent,
        dist=dist,
        hugo_content_dir=hugo_content_dir,
        hugo_root=hugo_root,
        assets_image_dir=assets_image_dir,
        site=raw.get("site", {}),
        wechat=wechat,
        baijiahao=raw.get("baijiahao", {}),
    )


def _resolve(root: Path, value: str) -> Path:
    path = Path(value).expanduser()
    return path.resolve() if path.is_absolute() else (root / path).resolve()


def _find_hugo_root(start: Path) -> Path:
    for candidate in [start, *start.parents]:
        if (candidate / "hugo.toml").exists() or (candidate / "config.toml").exists() or (candidate / "config.yaml").exists():
            return candidate
    return start


def load_dotenv_file(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)
