# Obsidian Hugo Publisher

一个轻量多平台发布器：把 Hugo/Obsidian 的 `content/posts/.../index.md` 作为唯一内容源，生成微信公众号 HTML/草稿、百家号可粘贴 HTML 和发布记录。

## MVP 范围

- 解析 YAML Front Matter。
- 识别正文里的本地图片引用。
- 检查 Hugo archetype 预置字段是否已经补全。
- 生成微信公众号兼容 HTML。
- 上传微信公众号正文图片并替换为微信图片 URL。
- 上传封面图为永久素材，并创建微信公众号草稿。
- 为百家号输出可粘贴 HTML，后续再接 API。
- 保留显式 `hugo-export` 命令，用于以后从外部 Markdown 导入时生成 Hugo Markdown。

## 项目结构

```text
src/content_publisher/
├── cli.py                  # 命令行入口
├── config.py               # 配置与 .env 环境变量
├── document.py             # Markdown + Front Matter 解析
├── images.py               # 本地图片发现和路径解析
├── markdown_html.py         # 标准库 Markdown HTML 子集
├── adapters/
│   ├── hugo.py             # 旧导入流的 Hugo 输出
│   ├── wechat.py           # 微信 HTML + 草稿 payload
│   └── baijiahao.py        # 百家号 HTML 预留
└── clients/
    └── wechat.py           # 微信公众号 API
```

## 安装

当前 MVP 只依赖 Pillow，用于把微信不支持的 WebP 图片临时转换成 JPEG。

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
cp publisher.config.example.yaml publisher.config.yaml
cp .env.example .env
```

也可以不安装，直接在项目目录执行：

```bash
PYTHONPATH=src python3 -m content_publisher.cli build examples/article.md
```

在 `.env` 中填入：

```text
WECHAT_APP_ID=...
WECHAT_APP_SECRET=...
```

`.env` 已在 `.gitignore` 中，真实密钥不要写进 Markdown、YAML 或 GitHub 仓库。

## 使用

主流程是先用 Hugo 创建文章：

```bash
hugo new posts/clashroyale/2026-07-12/5-ronin-decks/index.md
```

然后在 Obsidian 里编辑这份 `index.md`。网站发布仍然走现有流程：提交并 `git push`，由 GitHub Actions/Vercel 自动发布。

仓库根目录提供了交互式入口：

```bash
./pub
```

也可以直接指定文章：

```bash
./pub content/posts/clashroyale/2026-07-12/5-ronin-decks/index.md
```

菜单里可以选择检查文章、生成公众号预览、创建公众号草稿，或组合执行。

发布前检查 archetype 里的占位字段：

```bash
content-publish check content/posts/clashroyale/2026-07-12/5-ronin-decks/index.md
```

生成本地跨平台副产物：

```bash
content-publish build content/posts/clashroyale/2026-07-12/5-ronin-decks/index.md
```

`build` 会读取 Front Matter 里的 `publish` 开关。没写 `publish` 时默认生成微信和百家号输出。网站发布不再生成 `dist/hugo/*.md`，因为 `content/posts/.../index.md` 本身就是 Hugo 源文件。

公众号默认样式模板是 `redream-obsidian-blue`，复刻当前常用的「无衬线 / 16px / 经典蓝 / obsidian」阅读风格。样式参考记录在 `references/wechat-redream-obsidian-blue.md`。

上传微信图片并创建草稿：

```bash
content-publish wechat-draft content/posts/clashroyale/2026-07-12/5-ronin-decks/index.md
```

如果以后需要从外部 Markdown 导入到 Hugo，可以显式使用旧导出命令：

```bash
content-publish hugo-export examples/article.md
```

不传 `--config` 时，CLI 会依次查找当前目录的 `publisher.config.yaml`、`publisher-config.yaml`，以及 `tools/content-publisher/` 下的同名配置文件。需要使用其他位置时再显式传 `--config`。

输出目录默认是 `dist/`：

```text
dist/
├── wechat/new-card-clue.html
├── baijiahao/new-card-clue.html
└── metadata/new-card-clue.json
```

## Front Matter 约定

```yaml
---
title: "网站标题"
description: "摘要"
slug: article-slug
image: "/images/2026/cover.png"
publish:
  website: true
  wechat: true
  baijiahao: true
wechat:
  title: "公众号标题"
  digest: "公众号摘要"
  cover: cover.jpg
  template: redream-obsidian-blue
baijiahao:
  title: "百家号标题"
---
```

平台专属内容可以用 HTML 注释包起来。普通内容会保留，其他平台块会被删除：

```html
<!-- platform:wechat -->
只出现在公众号的内容。
<!-- /platform -->
```

支持的平台名：`website`、`wechat`、`baijiahao`。

正文图片放在文章 `index.md` 的同级目录，正文里可以使用标准 Markdown 语法，也可以使用 Obsidian 常见的嵌入语法：

```markdown
![对战截图](battle.png)
![[battle.png|对战截图]]
```

Front Matter 里的 `image` 是 Hugo 网站使用的封面 URL，需要在 Obsidian Properties 里按文章设置。公众号上传封面时，CLI 会把 `/images/2026/cover.png` 映射到本地文件 `assets/images/2026/cover.png`。`assets_image_dir` 默认指向 Hugo 仓库的 `assets/images`，也可以在 `publisher.config.yaml` 里覆盖。

微信公众号接口不接受 WebP 图片。正文图或封面图如果是 `.webp`，CLI 会在上传前临时转成 `.jpg`，不会修改原始文章文件。

## 微信接口说明

MVP 使用微信公众号官方接口：

- `cgi-bin/token` 获取 `access_token`。
- `cgi-bin/media/uploadimg` 上传正文图片，返回正文可用图片 URL。
- `cgi-bin/material/add_material?type=image` 上传封面永久素材，返回 `media_id`。
- `cgi-bin/draft/add` 创建草稿。

公众号接口权限会受账号类型和后台配置影响。如果调用失败，命令会输出微信返回的 `errcode` 和 `errmsg`。
