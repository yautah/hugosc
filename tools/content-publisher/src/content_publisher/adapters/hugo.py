from __future__ import annotations

from pathlib import Path

from content_publisher.document import Article, body_for_platform, dump_front_matter


def render_hugo(article: Article) -> str:
    body = body_for_platform(article.body, "website")
    return f"---\n{dump_front_matter(article.front_matter)}\n---\n\n{body}"


def write_hugo(article: Article, dist_dir: Path) -> Path:
    out_dir = dist_dir / "hugo"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{article.slug}.md"
    out_path.write_text(render_hugo(article), encoding="utf-8")
    return out_path

