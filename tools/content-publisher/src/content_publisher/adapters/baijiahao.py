from __future__ import annotations

from pathlib import Path

from content_publisher.document import Article, body_for_platform
from content_publisher.markdown_html import markdown_to_html


def render_baijiahao_html(article: Article) -> str:
    body = body_for_platform(article.body, "baijiahao")
    return markdown_to_html(body, unwrap_links=True, image_style="max-width:100%;height:auto;")


def write_baijiahao(article: Article, dist_dir: Path) -> Path:
    out_dir = dist_dir / "baijiahao"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{article.slug}.html"
    out_path.write_text(render_baijiahao_html(article), encoding="utf-8")
    return out_path
