# Obsidian / Hugo 入库与更新

## 唯一稿源

- 活跃 Obsidian 库是仓库的 `content/`。常规文章放在 `content/posts/<game>/YYYY-MM-DD/<slug>/index.md`，正文配图同目录。
- `scbase/.obsidian` 是旧目录，`public/` 是构建产物；不在它们里面写稿或复制第二份正文。
- 已有文章在原路径更新。修改题目不改 slug、目录或 URL，除非用户要求迁移。
- 游戏路径按实际内容选用 `clashroyale`、`brawlstars`、`clashofclans`、`squadbusters`、`moco`。其他游戏先检查现有栏目，不能由 archetype 默认值误归为皇室战争。

## 头部格式

参考 `archetypes/posts.md` 和同栏目近期稿件，但不照搬占位字段或示例正文。archetype 的 `draft: false` 不是本地新稿的安全默认值。

```yaml
---
title: "准确交代事实的中文标题"
description: "可直接用于摘要的简短说明"
date: "2026-10-15T10:00:00+08:00"
updated: "2026-10-15T10:00:00+08:00"
slug: article-slug
image: /images/2026/article-slug.webp
game: clashroyale
content_type: news
evergreen: false
categories:
  - 皇室战争
tags:
  - 皇室战争
  - 资讯
wechat:
  template: redream-obsidian-blue
draft: true
---
```

日期示例只展示格式，创建时使用真实日期和 Asia/Shanghai 时区。`date` 是首次稿件日期，更新时保留；事实或正文实质变化更新 `updated`，不批量刷新无关稿件时间。`content_type` 按实际稿件选择 `news`、`feature` 或 `guide`。不为了满足模板增加 FAQ、广告、置顶、关键词堆砌或无效相关链接。

封面 `image` 需要经过 [配图规则](images-layout.md)验证。缺图时明确标记待补，不填写目录占位符；可以交付未完成图片的草稿，准备发布时必须补齐。公众号标题可以单独使用 `wechat.title`，不迫使网站标题也采用同一个 hook。

标题、描述、tag 等 frontmatter 中的内容，应根据正文进行有效的提炼，要充分考虑 seo 以及 google adsense 的优化，描述部分应是对读者友好的有效描述，而不是给编辑自己看的机械式归纳和总结。

## 原稿更新

- 阅读用户当前文件，保留其标题、增删段落、顺序和明确选定的值；只改请求涉及的部分。
- 事实更正同步检查摘要、FAQ、封面文字、图注和相关段落，也检查有效的 `wechat.title`、`wechat.digest`、`wechat.cover` 和 `wechat.content_source_url`。保留用户的独立平台编辑，但修正本次事实/版本变化导致的过期信息；有冲突先明确指出。
- 预案和最终稿是否分开，遵循 [月度平衡规则](clashroyale-balance.md)，不机械覆盖历史预案。
- 稳定 URL 和站内链接优先；关联路径从现有源文件和实际构建结果核对，不手猜日期层级。

## 跨会话状态

仅在有多阶段更新或未解决事实问题时维护 `generated/editorial/<slug>.json`；微小改字不强制建立记录。这里保存本地编辑进度，不另存正文，不放进文章目录随 Hugo 发布。交付后用户还会二次编辑，新会话以原稿当前内容为准，不用旧记录覆盖用户修改。

记录最小字段如下，可增补但不能填写虚构值。

```json
{
  "source": "content/posts/clashroyale/YYYY-MM-DD/article-slug/index.md",
  "stage": "awaiting_user_edit",
  "verified_at": null,
  "pending": [],
  "sources": []
}
```

`verified_at` 为实际核验时间，`pending` 记录具体缺口，`sources` 记录关键链接及核验范围。`stage` 可用 `researching`、`local_draft`、`awaiting_user_edit`。入库完成不代表已经由用户审定或发布。


## 检查范围

- 入库运行 Skill 的只读稿件检查器，核对本地字段和图片引用；不调用发布器。保留 `wechat.template` 等兼容字段，供用户后续手动 `pub` 使用。
- 新稿及头部/图片变化用 `hugo --buildDrafts --destination <临时目录>` 验证，并检查目标页面，成功构建不代表封面一定显示。
- 小幅纯文本、列表或图片位置修改，检查 Markdown 和相关预览即可。不要把无关全站告警自动当作本篇错误。
- 网站发布仍按用户授权的仓库流程进行。日常写稿不自行推送或变更 `noindex`、广告、全站模板。
