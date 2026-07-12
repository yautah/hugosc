from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path

from content_publisher.adapters.baijiahao import write_baijiahao
from content_publisher.adapters.hugo import write_hugo
from content_publisher.adapters.wechat import build_draft_payload, cover_src, render_wechat_html, write_wechat
from content_publisher.clients.wechat import WeChatClient
from content_publisher.config import load_config
from content_publisher.document import load_article
from content_publisher.images import find_local_images, prepare_wechat_upload_image, resolve_cover_image_path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="content-publish")
    subparsers = parser.add_subparsers(dest="command", required=True)
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument(
        "--config",
        default=None,
        help="Path to publisher config YAML. If omitted, the CLI searches common project locations.",
    )

    build_parser = subparsers.add_parser(
        "build",
        parents=[common],
        help="Generate local WeChat and Baijiahao outputs from an existing Hugo article.",
    )
    build_parser.add_argument("article", help="Path to the source Markdown article.")

    check_parser = subparsers.add_parser(
        "check",
        parents=[common],
        help="Validate an existing Hugo article before cross-platform publishing.",
    )
    check_parser.add_argument("article", help="Path to the source Markdown article.")

    hugo_export_parser = subparsers.add_parser(
        "hugo-export",
        parents=[common],
        help="Legacy helper: export a Markdown source into dist/hugo.",
    )
    hugo_export_parser.add_argument("article", help="Path to the source Markdown article.")

    draft_parser = subparsers.add_parser(
        "wechat-draft",
        parents=[common],
        help="Upload images and create a WeChat draft.",
    )
    draft_parser.add_argument("article", help="Path to the source Markdown article.")

    args = parser.parse_args(argv)
    article = load_article(Path(args.article).resolve())

    if args.command == "check":
        result = check_article(article)
    else:
        cfg = load_config(resolve_config_path(args.config))
        if args.command == "build":
            result = build_local_outputs(article, cfg)
        elif args.command == "hugo-export":
            result = export_hugo(article, cfg.dist)
        elif args.command == "wechat-draft":
            result = create_wechat_draft(article, cfg)
        else:
            parser.error(f"Unknown command: {args.command}")
            return 2

    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def build_local_outputs(article, cfg) -> dict:
    outputs: dict[str, str] = {}
    skipped: list[str] = []
    if should_publish(article, "wechat"):
        outputs["wechat"] = str(write_wechat(article, cfg.dist, cfg))
    else:
        skipped.append("wechat")
    if should_publish(article, "baijiahao"):
        outputs["baijiahao"] = str(write_baijiahao(article, cfg.dist))
    else:
        skipped.append("baijiahao")
    metadata_path = _write_metadata(article, cfg.dist, {}, None, skipped)
    outputs["metadata"] = str(metadata_path)
    return {
        "article": str(article.path),
        "website": {
            "source": str(article.path),
            "publishing": "external",
            "note": "Website publishing is handled by the Hugo repository workflow.",
        },
        "outputs": outputs,
        "skipped": skipped,
    }


def export_hugo(article, dist: Path) -> dict:
    hugo_path = write_hugo(article, dist)
    return {
        "article": str(article.path),
        "outputs": {
            "hugo": str(hugo_path),
        },
    }


def check_article(article) -> dict:
    errors: list[str] = []
    warnings: list[str] = []
    fm = article.front_matter

    if not str(fm.get("title") or "").strip():
        errors.append("Missing title.")
    if not str(fm.get("slug") or "").strip():
        errors.append("Missing slug.")
    if not str(fm.get("description") or "").strip():
        warnings.append("Missing description.")

    image = str(fm.get("image") or "").strip()
    if not image:
        warnings.append("Missing image.")
    elif image.endswith("/"):
        warnings.append("Image looks like a directory placeholder.")

    if not article.body.strip():
        warnings.append("Article body is empty.")

    return {
        "article": str(article.path),
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
    }


def create_wechat_draft(article, cfg, log=print) -> dict:
    if not cfg.wechat.enabled:
        raise SystemExit("WeChat is disabled in config.")
    if not should_publish(article, "wechat"):
        raise SystemExit("WeChat publishing is disabled for this article.")
    if not cfg.wechat.app_id or not cfg.wechat.app_secret:
        raise SystemExit("Missing WeChat credentials. Set WECHAT_APP_ID and WECHAT_APP_SECRET in .env or environment.")

    log("获取微信公众号 access_token...")
    client = WeChatClient(cfg.wechat.app_id, cfg.wechat.app_secret)
    access_token = client.get_access_token()
    log("access_token 获取成功。")

    with tempfile.TemporaryDirectory(prefix="content-publisher-wechat-") as temp_dir_raw:
        temp_dir = Path(temp_dir_raw)
        replacements: dict[str, str] = {}
        images = find_local_images(article.body, article.path)
        total_images = len(images)
        if total_images:
            log(f"发现正文配图 {total_images} 张。")
        else:
            log("正文没有需要上传的本地配图。")
        for index, image in enumerate(images, start=1):
            if not image.path.exists():
                raise FileNotFoundError(f"Image not found: {image.path}")
            log(f"上传配图 {index}/{total_images}: {image.src}")
            upload_path = prepare_wechat_upload_image(image.path, temp_dir)
            replacements[image.src] = client.upload_article_image(access_token, upload_path)
            log(f"配图上传完成 {index}/{total_images}: {image.src}")

        cover = cover_src(article)
        if not cover:
            raise SystemExit("Missing cover image. Set image or wechat.cover in Front Matter.")
        cover_path = resolve_cover_image_path(str(cover), article.path, cfg.assets_image_dir)
        if not cover_path.exists():
            raise FileNotFoundError(f"Cover image not found: {cover_path}")
        log(f"上传封面图: {cover}")
        upload_cover_path = prepare_wechat_upload_image(cover_path, temp_dir)
        thumb_media_id = client.add_permanent_image_material(access_token, upload_cover_path)
        log("封面图上传完成。")

        log("生成公众号 HTML...")
        html = render_wechat_html(article, cfg, replacements)
        payload = build_draft_payload(article, cfg, html, thumb_media_id)
        log("创建公众号草稿...")
        draft_result = client.add_draft(access_token, payload)
        log("公众号草稿创建完成。")

        wechat_path = write_wechat(article, cfg.dist, cfg, replacements)
        log(f"写出本地公众号 HTML: {wechat_path}")
    metadata_path = _write_metadata(article, cfg.dist, replacements, draft_result, [])
    log(f"写出发布 metadata: {metadata_path}")
    return {
        "article": str(article.path),
        "outputs": {
            "wechat": str(wechat_path),
            "metadata": str(metadata_path),
        },
        "wechat": draft_result,
    }


def should_publish(article, platform: str) -> bool:
    publish = article.front_matter.get("publish")
    if publish is None:
        return True
    if isinstance(publish, dict):
        return bool(publish.get(platform, True))
    return bool(publish)


def resolve_config_path(config: str | None) -> Path:
    if config:
        path = Path(config).expanduser().resolve()
        if not path.exists():
            raise FileNotFoundError(f"Config file not found: {path}")
        return path

    cwd = Path.cwd()
    candidates = [
        cwd / "publisher.config.yaml",
        cwd / "publisher-config.yaml",
        cwd / "tools" / "content-publisher" / "publisher.config.yaml",
        cwd / "tools" / "content-publisher" / "publisher-config.yaml",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate.resolve()

    raise FileNotFoundError(
        "Config file not found. Create publisher.config.yaml or pass --config tools/content-publisher/publisher.config.yaml."
    )


def _write_metadata(
    article,
    dist: Path,
    image_replacements: dict[str, str],
    draft_result: dict | None,
    skipped: list[str],
) -> Path:
    out_dir = dist / "metadata"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{article.slug}.json"
    payload = {
        "source": str(article.path),
        "slug": article.slug,
        "title": article.title,
        "skipped": skipped,
        "image_replacements": image_replacements,
        "wechat_draft": draft_result,
    }
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return out_path


if __name__ == "__main__":
    sys.exit(main())
