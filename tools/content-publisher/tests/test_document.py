import importlib.util
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from content_publisher import cli
from content_publisher.cli import build_local_outputs, check_article, create_wechat_draft, export_hugo, resolve_config_path, should_publish
from content_publisher.config import PublisherConfig, WeChatConfig
from content_publisher.document import Article
from content_publisher.document import body_for_platform
from content_publisher.images import (
    find_local_images,
    prepare_wechat_upload_image,
    replace_markdown_image_sources,
    resolve_cover_image_path,
)
from content_publisher.markdown_html import markdown_to_html
from content_publisher.simple_yaml import parse_yaml_mapping


def test_config(root: Path) -> PublisherConfig:
    return PublisherConfig(
        root=root,
        dist=root / "dist",
        hugo_content_dir=None,
        hugo_root=root,
        assets_image_dir=root / "assets" / "images",
        site={},
        wechat=WeChatConfig(True, "app-id", "app-secret", "author", "redream-obsidian-blue", 0, 0),
        baijiahao={},
    )


class DocumentTests(unittest.TestCase):
    def test_body_for_platform_keeps_only_matching_blocks(self):
        body = """A
<!-- platform:wechat -->
W
<!-- /platform -->
<!-- platform:website -->
S
<!-- /platform -->
B
"""
        self.assertEqual(body_for_platform(body, "wechat"), "A\nW\n\nB\n")

    def test_parse_yaml_mapping_with_nested_platform_config(self):
        parsed = parse_yaml_mapping(
            """
title: "新卡"
draft: false
categories:
  - 皇室战争
wechat:
  title: "公众号标题"
  digest: "摘要"
"""
        )
        self.assertEqual(parsed["title"], "新卡")
        self.assertFalse(parsed["draft"])
        self.assertEqual(parsed["categories"], ["皇室战争"])
        self.assertEqual(parsed["wechat"]["title"], "公众号标题")

    def test_should_publish_defaults_to_all_platforms(self):
        article = Article(Path("article.md"), {"title": "A"}, "Body")
        self.assertTrue(should_publish(article, "website"))
        self.assertTrue(should_publish(article, "wechat"))
        self.assertTrue(should_publish(article, "baijiahao"))

    def test_build_local_outputs_respects_publish_flags(self):
        with TemporaryDirectory() as temp_dir:
            article = Article(
                Path(temp_dir) / "article.md",
                {"title": "A", "slug": "a", "publish": {"website": True, "wechat": False, "baijiahao": True}},
                "Body\n",
            )
            result = build_local_outputs(article, test_config(Path(temp_dir)))

            self.assertEqual(result["website"]["publishing"], "external")
            self.assertNotIn("hugo", result["outputs"])
            self.assertNotIn("wechat", result["outputs"])
            self.assertIn("baijiahao", result["outputs"])
            self.assertEqual(result["skipped"], ["wechat"])

    def test_export_hugo_is_explicit_legacy_command(self):
        with TemporaryDirectory() as temp_dir:
            article = Article(Path(temp_dir) / "article.md", {"title": "A", "slug": "a"}, "Body\n")
            result = export_hugo(article, Path(temp_dir) / "dist")

            self.assertIn("hugo", result["outputs"])
            self.assertTrue(Path(result["outputs"]["hugo"]).exists())

    def test_check_article_reports_hugo_archetype_placeholders(self):
        article = Article(
            Path("index.md"),
            {
                "title": "",
                "image": "/images/2025/",
                "description": "",
                "slug": "5-ronin-decks",
                "draft": False,
            },
            "",
        )

        result = check_article(article)

        self.assertFalse(result["ok"])
        self.assertIn("Missing title.", result["errors"])
        self.assertIn("Missing description.", result["warnings"])
        self.assertIn("Image looks like a directory placeholder.", result["warnings"])
        self.assertIn("Article body is empty.", result["warnings"])

    def test_obsidian_images_are_found_and_replaced(self):
        with TemporaryDirectory() as temp_dir:
            article_path = Path(temp_dir) / "post" / "index.md"
            article_path.parent.mkdir()
            image_path = article_path.parent / "cover.png"
            image_path.write_bytes(b"image")

            images = find_local_images("![[cover.png|封面]]", article_path)

            self.assertEqual(len(images), 1)
            self.assertEqual(images[0].src, "cover.png")
            self.assertEqual(images[0].alt, "封面")
            self.assertEqual(images[0].path, image_path.resolve())
            self.assertEqual(
                replace_markdown_image_sources("![[cover.png|封面]]", {"cover.png": "https://img.example/cover.png"}),
                "![封面](https://img.example/cover.png)",
            )

    def test_cover_site_image_url_resolves_to_assets_image_file(self):
        with TemporaryDirectory() as temp_dir:
            article_path = Path(temp_dir) / "content" / "posts" / "index.md"
            assets_image_dir = Path(temp_dir) / "assets" / "images"

            self.assertEqual(
                resolve_cover_image_path("/images/2026/cover.png", article_path, assets_image_dir),
                (assets_image_dir / "2026" / "cover.png").resolve(),
            )

    def test_body_images_resolve_relative_to_article_directory(self):
        with TemporaryDirectory() as temp_dir:
            article_path = Path(temp_dir) / "content" / "posts" / "clashroyale" / "index.md"
            article_path.parent.mkdir(parents=True)
            body_image = article_path.parent / "battle.png"
            body_image.write_bytes(b"image")

            images = find_local_images("![battle](battle.png)", article_path)

            self.assertEqual(images[0].path, body_image.resolve())

    def test_prepare_wechat_upload_image_keeps_supported_formats(self):
        with TemporaryDirectory() as temp_dir:
            image_path = Path(temp_dir) / "image.png"
            image_path.write_bytes(b"image")

            self.assertEqual(prepare_wechat_upload_image(image_path, Path(temp_dir)), image_path)

    @unittest.skipUnless(importlib.util.find_spec("PIL"), "Pillow is not installed")
    def test_prepare_wechat_upload_image_converts_webp_to_jpeg(self):
        from PIL import Image

        with TemporaryDirectory() as temp_dir:
            source_path = Path(temp_dir) / "image.webp"
            Image.new("RGB", (8, 8), "red").save(source_path, "WEBP")

            upload_path = prepare_wechat_upload_image(source_path, Path(temp_dir))

            self.assertEqual(upload_path.suffix, ".jpg")
            self.assertTrue(upload_path.exists())

    def test_resolve_config_path_finds_tools_config_from_repo_root(self):
        with TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            config_path = root / "tools" / "content-publisher" / "publisher.config.yaml"
            config_path.parent.mkdir(parents=True)
            config_path.write_text("site:\n  author: test\n", encoding="utf-8")
            old_cwd = Path.cwd()
            try:
                import os

                os.chdir(root)
                self.assertEqual(resolve_config_path(None), config_path.resolve())
            finally:
                os.chdir(old_cwd)

    def test_create_wechat_draft_reports_progress(self):
        class FakeClient:
            def __init__(self, app_id, app_secret):
                pass

            def get_access_token(self):
                return "token"

            def upload_article_image(self, access_token, image_path):
                return f"https://img.example/{image_path.name}"

            def add_permanent_image_material(self, access_token, image_path):
                return "media-id"

            def add_draft(self, access_token, payload):
                return {"media_id": "draft-id"}

        with TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            article_path = root / "content" / "posts" / "article" / "index.md"
            article_path.parent.mkdir(parents=True)
            body_image = article_path.parent / "battle.png"
            body_image.write_bytes(b"image")
            cover_dir = root / "assets" / "images" / "2026"
            cover_dir.mkdir(parents=True)
            cover_path = cover_dir / "cover.png"
            cover_path.write_bytes(b"image")
            article = Article(
                article_path,
                {"title": "A", "slug": "a", "description": "D", "image": "/images/2026/cover.png"},
                "![battle](battle.png)\n",
            )
            cfg = test_config(root)
            logs: list[str] = []
            original_client = cli.WeChatClient
            try:
                cli.WeChatClient = FakeClient
                result = create_wechat_draft(article, cfg, log=logs.append)
            finally:
                cli.WeChatClient = original_client

            self.assertEqual(result["wechat"], {"media_id": "draft-id"})
            self.assertTrue(any("获取微信公众号 access_token" in line for line in logs))
            self.assertTrue(any("上传配图 1/1" in line for line in logs))
            self.assertTrue(any("上传封面图" in line for line in logs))
            self.assertTrue(any("创建公众号草稿" in line for line in logs))

    def test_markdown_to_html_renders_obsidian_image(self):
        html = markdown_to_html("![[cover.png|封面]]", image_style="max-width:100%;")
        self.assertEqual(html, '<p><img src="cover.png" alt="封面" style="max-width:100%;"></p>\n')

    def test_redream_obsidian_blue_template_renders_inline_styles(self):
        html = markdown_to_html(
            "## 标题\n\n正文 **重点**\n\n![封面](cover.png)\n",
            template="redream-obsidian-blue",
        )

        self.assertIn("rgba(15, 76, 129, 1)", html)
        self.assertIn("font-size:16px", html)
        self.assertIn("<figure", html)
        self.assertIn("<figcaption", html)
        self.assertIn("<strong", html)

    def test_redream_obsidian_blue_template_renders_unordered_list_elements(self):
        html = markdown_to_html(
            "- 第一项\n- 第二项\n",
            template="redream-obsidian-blue",
        )

        self.assertIn("<ul", html)
        self.assertIn("<li", html)
        self.assertIn("list-style-type:disc", html)
        self.assertNotIn("•", html)
        self.assertNotIn("- 第一项", html)

    def test_redream_obsidian_blue_template_renders_markdown_table(self):
        html = markdown_to_html(
            "| 时间 | 阶段 | 说明 |\n|---|---|---|\n| 2026 年 8 月 | Beta | 新一轮测试 |\n",
            template="redream-obsidian-blue",
        )

        self.assertIn("<table", html)
        self.assertIn("<thead>", html)
        self.assertIn("<tbody>", html)
        self.assertIn("<th", html)
        self.assertIn("<td", html)
        self.assertIn("border-collapse:collapse", html)
        self.assertNotIn("|---|", html)


if __name__ == "__main__":
    unittest.main()
