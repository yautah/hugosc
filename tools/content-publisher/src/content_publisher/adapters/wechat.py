from __future__ import annotations

from pathlib import Path

from content_publisher.config import PublisherConfig
from content_publisher.document import Article, body_for_platform
from content_publisher.images import replace_markdown_image_sources
from content_publisher.markdown_html import markdown_to_html


def render_wechat_html(
    article: Article,
    cfg: PublisherConfig | None = None,
    image_replacements: dict[str, str] | None = None,
) -> str:
    body = body_for_platform(article.body, "wechat")
    if image_replacements:
        body = replace_markdown_image_sources(body, image_replacements)

    return markdown_to_html(
        body,
        unwrap_links=True,
        image_style="max-width:100%;height:auto;",
        template=wechat_template(article, cfg),
    )


def write_wechat(
    article: Article,
    dist_dir: Path,
    cfg: PublisherConfig | None = None,
    image_replacements: dict[str, str] | None = None,
) -> Path:
    out_dir = dist_dir / "wechat"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{article.slug}.html"
    out_path.write_text(render_wechat_html(article, cfg, image_replacements), encoding="utf-8")
    return out_path


def build_draft_payload(article: Article, cfg: PublisherConfig, content_html: str, thumb_media_id: str) -> dict:
    wechat_meta = article.front_matter.get("wechat", {}) or {}
    title = str(wechat_meta.get("title") or article.title)
    digest = str(wechat_meta.get("digest") or article.description)[:120]

    return {
        "articles": [
            {
                "title": title,
                "author": str(wechat_meta.get("author") or cfg.wechat.author),
                "digest": digest,
                "content": content_html,
                "content_source_url": str(wechat_meta.get("content_source_url") or cfg.site.get("source_url", "")),
                "thumb_media_id": thumb_media_id,
                "need_open_comment": int(wechat_meta.get("need_open_comment", cfg.wechat.default_need_open_comment)),
                "only_fans_can_comment": int(
                    wechat_meta.get("only_fans_can_comment", cfg.wechat.default_only_fans_can_comment)
                ),
            }
        ]
    }


def cover_src(article: Article) -> str | None:
    wechat_meta = article.front_matter.get("wechat", {}) or {}
    return wechat_meta.get("cover") or article.front_matter.get("image")


def wechat_template(article: Article, cfg: PublisherConfig | None = None) -> str:
    wechat_meta = article.front_matter.get("wechat", {}) or {}
    if wechat_meta.get("template"):
        return str(wechat_meta["template"])
    if cfg:
        return cfg.wechat.default_template
    return "redream-obsidian-blue"
