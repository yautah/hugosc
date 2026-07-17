from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse


MARKDOWN_IMAGE_RE = re.compile(r"!\[(?P<alt>[^\]]*)\]\((?P<src>[^)\s]+)(?:\s+\"[^\"]*\")?\)")
OBSIDIAN_IMAGE_RE = re.compile(r"!\[\[(?P<target>[^\]]+)\]\]")


@dataclass(frozen=True)
class LocalImage:
    alt: str
    src: str
    path: Path


def find_local_images(markdown_body: str, article_path: Path) -> list[LocalImage]:
    images: list[LocalImage] = []
    for match in MARKDOWN_IMAGE_RE.finditer(markdown_body):
        src = match.group("src").strip()
        if _is_remote_or_special(src):
            continue
        images.append(LocalImage(alt=match.group("alt"), src=src, path=resolve_image_path(src, article_path)))
    for match in OBSIDIAN_IMAGE_RE.finditer(markdown_body):
        src, alt = _split_obsidian_target(match.group("target"))
        if _is_remote_or_special(src):
            continue
        images.append(LocalImage(alt=alt, src=src, path=resolve_image_path(src, article_path)))
    return images


def resolve_image_path(src: str, article_path: Path) -> Path:
    path = Path(src)
    if path.is_absolute():
        return path
    return (article_path.parent / path).resolve()


def resolve_cover_image_path(src: str, article_path: Path, assets_image_dir: Path) -> Path:
    site_image_src = src.removeprefix("/")
    if site_image_src.startswith("images/"):
        return (assets_image_dir / site_image_src.removeprefix("images/")).resolve()
    return resolve_image_path(src, article_path)


def replace_markdown_image_sources(markdown_body: str, replacements: dict[str, str]) -> str:
    def replace_markdown(match: re.Match[str]) -> str:
        src = match.group("src").strip()
        new_src = replacements.get(src)
        if not new_src:
            return match.group(0)
        return f"![{match.group('alt')}]({new_src})"

    def replace_obsidian(match: re.Match[str]) -> str:
        src, alt = _split_obsidian_target(match.group("target"))
        new_src = replacements.get(src)
        if not new_src:
            return match.group(0)
        return f"![{alt}]({new_src})"

    markdown_body = MARKDOWN_IMAGE_RE.sub(replace_markdown, markdown_body)
    return OBSIDIAN_IMAGE_RE.sub(replace_obsidian, markdown_body)


def prepare_wechat_upload_image(image_path: Path, temp_dir: Path) -> Path:
    if image_path.suffix.lower() != ".webp":
        return image_path
    output_path = temp_dir / f"{image_path.stem}.jpg"
    _convert_to_jpeg(image_path, output_path)
    return output_path


def _convert_to_jpeg(input_path: Path, output_path: Path) -> None:
    try:
        from PIL import Image, ImageOps
    except ImportError as exc:
        raise RuntimeError("Cannot upload WebP to WeChat. Install Pillow first: pip install Pillow") from exc

    with Image.open(input_path) as image:
        image = ImageOps.exif_transpose(image)
        if image.mode in {"RGBA", "LA"} or (image.mode == "P" and "transparency" in image.info):
            rgba = image.convert("RGBA")
            background = Image.new("RGB", rgba.size, "white")
            background.paste(rgba, mask=rgba.getchannel("A"))
            image = background
        else:
            image = image.convert("RGB")
        image.save(output_path, "JPEG", quality=92, optimize=True, progressive=True)


def _is_remote_or_special(src: str) -> bool:
    parsed = urlparse(src)
    return bool(parsed.scheme in {"http", "https", "data"}) or src.startswith("#")


def _split_obsidian_target(target: str) -> tuple[str, str]:
    parts = target.split("|", 1)
    src = parts[0].strip()
    alt = parts[1].strip() if len(parts) > 1 else Path(src).stem
    return src, alt
