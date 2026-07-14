# SCBase 运维手册

本文记录 SCBase 日常内容维护、首页编排、奖励数据更新和上线检查方式。产品方向与开发计划以 `scbase-2.0-spec.md` 为准；本文只保留可直接执行的运维约定。

## 1. 基本原则

- 不直接编辑 `public/`，它是 Hugo 构建产物并已加入 `.gitignore`。
- 不直接编辑 `resources/_gen/`，它是 Hugo 生成的资源缓存。
- 首页置顶与热门顺序由运维人工维护，模板不检查重复序号。
- 同一内容不要同时配置 `home_pinned` 和 `home_popular`。
- 删除首页编排时应删除对应 Front Matter 字段，不要保留空值。
- 图片、页面路径或数据调整后必须执行一次完整 Hugo 构建。

## 2. 新建和维护文章

文章继续使用 Leaf Bundle，每篇文章使用独立目录和 `index.md`：

```bash
hugo new content/posts/clashroyale/2026-07-15/example-slug/index.md
```

目录结构：

```text
content/posts/clashroyale/2026-07-15/example-slug/
├── index.md
├── battle-1.webp
└── battle-2.webp
```

- 正文图片放在 `index.md` 同级目录，以相对路径引用。
- 正文图片引用示例：`![](battle-1.webp)`。
- 远程图片应确认长期可用；重要图片优先本地化。
- 文章封面由 Front Matter 的 `image` 指定，当前统一放在 `assets/images/<年份>/`。
- Front Matter 中填写 Hugo 资源路径，例如 `image: "/images/2026/cover.webp"`。

新文章至少确认以下字段：

```yaml
title: "文章标题"
description: "面向读者和搜索引擎的内容摘要"
date: 2026-07-15T12:00:00+08:00
updated: 2026-07-15T12:00:00+08:00
image: "/images/2026/cover.webp"
categories:
  - 皇室战争
tags:
  - 攻略
keywords:
  - 皇室战争攻略
draft: false
```

`description` 应直接说明读者能获得什么，不要写成个人编辑记录。

## 3. 首页置顶内容

置顶区域固定展示 5 篇文章，只从 `content/posts/` 中选择。

在文章 Front Matter 中添加：

```yaml
home_pinned: 1
```

- 使用 `1-5` 控制展示顺序，数字越小越靠前。
- `1` 是左侧主图，`2-5` 是右侧四张小图。
- 如果配置不足 5 篇，模板使用未重复的最新文章补位。
- 独立功能页面目前不能加入置顶，只支持文章。
- 调整顺序时同时检查其余文章，避免出现重复序号。

取消置顶：

```diff
- home_pinned: 1
```

## 4. 首页热门内容

热门轮播固定展示 5 项，支持文章和普通 Hugo 页面。

在目标内容 Front Matter 中添加：

```yaml
home_popular: 1
```

- 使用正整数控制顺序，数字越小越靠前。
- 首页只展示排序后的前 5 项，可以保留 `6`、`7` 等候补顺序。
- 热门配置不足 5 项时，模板使用未进入置顶和热门的最新文章补位。
- 热门内容不会再次进入首页“最新资讯”。
- 调整顺序时必须保证序号唯一。

普通文章配置示例：

```yaml
title: "皇室战争安装指南"
image: "/images/2026/install-guide.webp"
home_popular: 2
```

取消热门：

```diff
- home_popular: 2
```

### 4.1 将独立页面加入热门

独立页面不需要伪装成 `posts`。只要它位于 `content/`、属于 Hugo Regular Page，并配置 `home_popular`，就能进入热门轮播。

奖励总入口的当前配置位于 `content/rewards.md`：

```yaml
title: "超级细胞免费奖励"
image: "images/rewards/rewards-cover.webp"
home_popular: 1
layout: rewards
```

注意事项：

- 独立页面必须有 `title`、`date` 和 `image`，热门卡片会读取这些字段。
- 图片应放在 `assets/` 中，Front Matter 填写相对于 `assets/` 的路径。
- 热门封面推荐使用 16:9，当前奖励封面为 `assets/images/rewards/rewards-cover.webp`。
- 配置新入口前应移除旧文章中重复的 `home_popular`，避免首页出现两个相似入口。
- 首页热门候选逻辑位于 `layouts/partials/home/portal-data.html`。

## 5. 最新资讯

“最新资讯”不需要手动配置：

- 数据只来自 `content/posts/`。
- 按文章日期倒序排列。
- 自动排除已经进入置顶和热门的内容。
- 首页最多展示 12 篇。
- 独立页面不会进入最新资讯。

## 6. 免费奖励数据

奖励数据统一维护在：

```text
data/rewards.yaml
```

奖励图片统一维护在：

```text
assets/images/rewards/
├── clashroyale/
├── brawlstars/
├── clashofclans/
└── rewards-cover.webp
```

单条奖励结构：

```yaml
- id: cr-310
  game: clashroyale
  title: "2 张浪人传奇卡"
  original_title: "x2 Ronin Legendary Cards"
  type: resource
  type_label: "宝箱"
  redeem_type: official_page
  redeem_url: "https://store.supercell.com/..."
  image: "images/rewards/clashroyale/cr-310.webp"
  status: active
  verified_at: "2026-07-14"
  expires_at: ""
```

字段约定：

- `id`：站内唯一 ID，皇室战争使用 `cr-*`，荒野乱斗使用 `bs-*`，部落冲突使用 `coc-*`。
- `game`：只能使用 `clashroyale`、`brawlstars` 或 `clashofclans`。
- `redeem_type`：使用 `direct_link`、`official_page` 或 `store_code`。
- `redeem_url`：必须指向可以核验的官方领取链接或官方商店。
- `image`：必须使用本地 Hugo 资源路径，不引用外部图片 CDN。
- `status`：有效奖励使用 `active`；失效奖励使用 `expired`。
- `verified_at`：最后一次人工确认日期。
- `expires_at`：已知截止日期时填写，否则留空。

更新奖励时：

1. 核验领取链接仍然有效。
2. 下载并保存本地 WebP 图片。
3. 使用简洁且不包含第三方站点名称的文件名。
4. 更新 `data/rewards.yaml` 中的奖励记录。
5. 更新 `source.synced_at`。
6. 将失效奖励设为 `expired`，不要直接删除历史记录。
7. 执行 Hugo 构建并检查三个游戏标签后的数量。

奖励标签数量由模板自动统计，`expired` 不计入数量，也不会显示在列表中。

相关页面：

```text
/rewards/
/rewards/clash-royale/
/rewards/brawl-stars/
/rewards/clash-of-clans/
```

## 7. 图片管理

- `assets/images/`：需要 Hugo 裁剪、转换、压缩或指纹处理的站点资源。
- 文章同级图片：文章正文使用的 Page Resource。
- `static/`：只放必须原样复制、无需 Hugo 处理的文件。
- `public/`：构建产物，不放源图片，也不提交 Git。

首页置顶和热门封面会由 Hugo 自动裁剪。重要入口应单独准备封面，不要直接拿正文小图或透明图标作为首页封面。

## 8. 本地预览与上线检查

本地预览：

```bash
hugo server
```

完整构建：

```bash
hugo --cleanDestinationDir --minify
```

提交前至少执行：

```bash
hugo --cleanDestinationDir --minify
git diff --check
git status --short
```

人工检查：

1. 首页置顶和热门顺序是否正确。
2. 首页是否出现重复内容。
3. 热门卡片封面是否正确裁切。
4. 最新资讯是否仍有 12 篇且没有重复。
5. 奖励入口和三个游戏标签是否正常。
6. 桌面端和移动端是否存在横向溢出。
7. 浏览器控制台是否出现资源加载错误。

## 9. 常见问题

### 首页顺序和预期不一致

检查是否存在重复的 `home_pinned` 或 `home_popular` 数字。当前不做自动冲突校验。

### 配置了热门但没有显示

- 确认字段不是空值。
- 确认排序是否落在前 5。
- 确认该内容没有同时进入置顶。
- 独立页面应确认它是 Hugo Regular Page，并具有日期和封面。

### 首页封面显示为空

- 检查 `image` 是否指向 `assets/` 中存在的文件。
- 不要填写本机绝对路径。
- 检查图片是否为 Hugo 支持的格式。
- 执行干净构建，确认模板没有输出资源错误。

### 奖励数量不正确

- 检查 `game` 字段拼写。
- 检查奖励是否被标记为 `expired`。
- 检查 YAML 缩进和列表结构。
- 执行 Hugo 构建后重新查看生成页面。
