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

### 奖励同步工作流

当前可使用 [ClashLoot](https://clashloot.com/) 及其皇室战争、荒野乱斗、部落冲突列表作为奖励发现和状态对比来源。第三方列表只用于发现线索；最终必须检查奖励详情及官方领取地址，`redeem_url` 不能填写第三方详情页。

同步遵循“差异更新”，不要用来源站内容全量覆盖站内数据：

- 来源站与 SCBase 都存在的奖励，保留 SCBase 已校验的中文标题、类型、图片和说明，只复核领取状态与链接。
- 来源站新增的奖励，新增 YAML 记录并下载对应图片。
- 来源站已经移除或明确失效的奖励，将 `status` 改为 `expired`，保留历史记录和图片。
- 对状态存疑、领取条件不明确或官方链接无法核验的奖励，不直接标记为有效。

每次同步按以下顺序执行：

1. 分别检查皇室战争、荒野乱斗和部落冲突的当前奖励列表，不要只检查站点首页。
2. 以奖励 ID、官方领取链接和奖励内容联合比对 `data/rewards.yaml`，列出新增、仍有效、失效和待复核四组。
3. 对既有奖励只更新 `status`、`verified_at`、`expires_at` 或确有变化的官方领取链接，不覆盖人工校验过的标题和图片。
4. 为新增奖励分配稳定且唯一的 ID：皇室战争使用 `cr-*`，荒野乱斗使用 `bs-*`，部落冲突使用 `coc-*`。
5. 下载新增奖励的原图并转换为 WebP，分别保存到对应游戏目录。文件名直接使用奖励 ID，例如 `cr-324.webp`，不得包含第三方站点名称。
6. 在新增记录的 `image` 中填写 Hugo 资源路径，例如 `images/rewards/clashroyale/cr-324.webp`；文件实际位置应为 `assets/images/rewards/clashroyale/cr-324.webp`。
7. 检查 `type` 和 `type_label` 是否符合实际内容，例如卡牌不要标成宝箱、战旗不要写成旗帜。
8. 将确认失效的记录改为 `expired`，不要删除 YAML 记录，也不要立即删除历史图片。
9. 将 `source.synced_at` 和本次核验过的 `verified_at` 更新为当天日期。
10. 执行 Hugo 构建，在 `/rewards/` 下逐一切换三个游戏标签，核对数量、标题、图片和领取按钮。

### 图片与 Git 检查

Hugo 使用 `resources.Get` 从 `assets/` 读取奖励图片。图片不存在时页面不会中断构建，而会回退到对应游戏图标，因此“本地正常、线上显示游戏图标”通常意味着新增图片没有进入 Git。

提交前必须同时检查数据和图片：

```bash
git status --short -- data/rewards.yaml assets/images/rewards/
hugo --gc --minify
git diff --check
git diff --cached --check
```

精确暂存本次变更，避免遗漏图片：

```bash
git add -- data/rewards.yaml assets/images/rewards/
git diff --cached --stat
```

该命令只暂存奖励数据和奖励图片，不会带入文章或其他页面改动。暂存后，新增图片应在 `git status` 中显示为 `A`，不能保持 `??`。提交后再用以下命令确认新增资源已经被 Git 跟踪：

```bash
git ls-files -- assets/images/rewards/
```

上线后至少抽查所有新增奖励，并确认页面展示的是奖励实图而不是皇室战争盾牌、荒野乱斗骷髅或部落冲突盾牌等回退图标。

奖励标签数量由模板自动统计，`expired` 不计入数量，也不会显示在列表中。

相关页面：

```text
/rewards/
/rewards/clash-royale/
/rewards/brawl-stars/
/rewards/clash-of-clans/
```

## 7. 皇室战争卡牌与卡组

详细架构和数据源边界见 [`scbase-clash-royale-cards-decks-spec.md`](scbase-clash-royale-cards-decks-spec.md)。原型数据位于：

```text
data/clashroyale/cards.yaml
data/clashroyale/card-source-manifest.yaml
data/clashroyale/card-details/<key>.yaml
data/clashroyale/card-variants/<parent>-<kind>.yaml
data/clashroyale/decks.yaml
assets/images/clashroyale/cards/
assets/images/clashroyale/cards/variants/
```

维护约定：

- 卡牌 `key` 是稳定主键，中文名变化时不要修改 key。
- 新卡牌图片保存为本地 WebP，文件名与 key 一致。
- 卡牌目录字段保存在 `cards.yaml`；从 Fandom 解析出的逐级数值和平衡记录保存在对应的 `card-details/<key>.yaml`，作为可重复构建的数值快照。
- 人工提炼的卡牌特点、使用要点和对局思路只保存在 `card-editorials/<key>.yaml`。该目录不参与 Fandom 同步，避免原创内容被自动脚本覆盖。
- 自动解析无法稳定处理的复合平衡记录，保存在 `card-history-overrides/<key>.yaml`，覆盖自动生成结果。
- 觉醒和精英形态保存在 `card-variants/`，使用基础卡牌 `key` 作为 `parent_key`；文件名和形态 `key` 使用 `<parent>-evolution` 或 `<parent>-hero`。
- 形态图片保存到 `assets/images/clashroyale/cards/variants/`，页面地址固定为 `/clashroyale/cards/<parent>/evolution/` 或 `/clashroyale/cards/<parent>/hero/`。
- 形态属于基础卡牌的子实体，不要加入 `cards.yaml`，也不要计入卡牌百科的基础卡牌总数。
- 卡牌页面入口统一位于 `content/clashroyale/cards/`：基础卡使用 `<key>.md`，形态使用 `<parent>-evolution.md` 或 `<parent>-hero.md`，栏目入口使用 `_index.md`。
- 不要为每张基础卡建立带 `_index.md` 的子目录，否则 Hugo 会把卡牌识别为 section，额外生成 RSS，并绕过卡牌详情模板。
- 页面文件虽然采用扁平命名，但 front matter 中的 `url` 必须继续保持 `/clashroyale/cards/<key>/`、`/evolution/` 和 `/hero/` 的公开层级。
- `card-source-manifest.yaml` 是来源发现清单，不直接用于页面展示；英文名只作为内部来源匹配字段。
- 平衡记录按日期倒序，仅记录影响实战数值或机制的调整，并更新来源核验日期。
- 自动同步只写入能够可靠结构化的简单数值调整；复杂重做、问题修复和无法准确中文化的记录必须人工核对后补充。
- 自动生成的详情路由默认 `noindex: true`。补充原创策略、克制关系和搭配内容后，将 `noindex` 改为 `false`，并将 `generated_card_data` 改为 `false`，避免下次同步覆盖该路由的 Front Matter。
- 卡组必须包含 8 张不同卡牌，引用的 key 必须已经存在。
- 卡组 `id` 和 `slug` 不因胜率、赛季或排序变化而修改。
- `average_elixir` 和 `cycle_elixir` 必须由校验器复核。
- `decks.yaml` 只用于校验卡组身份、费用和渲染组件，不作为前台固定卡组库。
- 卡组榜单必须使用获授权数据，或由官方 API 战斗日志自行聚合；不得填写模拟排名。
- 第三方统计必须同时记录来源、周期、模式、分段、样本量和更新时间。
- 未取得书面授权前，不抓取或转载 RoyaleAPI 的实时排行数据。

新增或修改数据后执行：

```bash
ruby tools/sync-clash-card-sources.rb --write-manifest
ruby tools/build-clash-card-data.rb --write --images
npm run validate:clash-data
hugo --minify
```

日常不需要频繁重抓 Fandom。只有新增卡牌、觉醒/精英上线、平衡性调整或发现数值错误时，再运行同步和构建脚本。补充普通卡牌固定模块时，只编辑 `card-editorials/<key>.yaml`，然后运行：

```bash
npm run validate:clash-data
ruby tools/validate-clash-data.rb --require-editorials
hugo --minify
```

其中 `--require-editorials` 是批量固定卡牌时使用的严格检查，会列出还缺少卡牌特点、使用要点和对局模块的基础卡牌；常规校验不强制所有卡都已经完成原创内容。

同步脚本负责生成基础卡牌参数、等级属性和平衡记录。人工提炼的基础卡牌特点、使用要点与对局分析必须放在 `data/clashroyale/card-editorials/<key>.yaml`，不要直接写入自动生成的 `card-details` 文件。形态数据当前采用人工核验，完整保存在 `card-variants/<key>.yaml`。校验器会检查 126 张基础卡牌及所有形态的重复 key、父卡牌、详情路由、图片、动态等级数据、中文标签、内容结构和平衡记录顺序，以及卡组的 8 卡完整性、卡牌引用、平均圣水和四卡循环。截至 2026-07-15，基础卡牌工作流与 55 个已上线形态均已完成；后续新增卡牌或形态时必须重新运行完整审计。

如果自动生成的平衡记录缺失复合改动，应在 `data/clashroyale/card-history-overrides/<key>.yaml` 增加完整中文覆盖记录。文件需要填写 `source_url` 和按日期倒序排列的 `items`；重新运行卡牌同步时，覆盖记录优先于自动解析结果，不会被覆盖。

历史记录允许使用 `buff`、`nerf`、`adjustment`、`release`、`visual`、`evolution` 和 `hero` 类型。除对战改动外，每张卡还应收录首次上线、卡牌图片更换、觉醒上线和精英形态上线（存在时）；任何等级上限调整都无需记录。

当前页面：

```text
/clashroyale/cards/
/clashroyale/cards/<key>/
/clashroyale/cards/<key>/evolution/
/clashroyale/cards/<key>/hero/
/clashroyale/decks/
/clashroyale/decks/hog-cycle-classic/
```

## 8. 图片管理

- `assets/images/`：需要 Hugo 裁剪、转换、压缩或指纹处理的站点资源。
- 文章同级图片：文章正文使用的 Page Resource。
- `static/`：只放必须原样复制、无需 Hugo 处理的文件。
- `public/`：构建产物，不放源图片，也不提交 Git。

首页置顶和热门封面会由 Hugo 自动裁剪。重要入口应单独准备封面，不要直接拿正文小图或透明图标作为首页封面。

## 9. 本地预览与上线检查

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
npm run validate:clash-data
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

## 10. 常见问题

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

### 奖励图片显示为游戏图标

- 检查 YAML 中的 `image` 是否以 `images/rewards/` 开头，并与 `assets/images/rewards/` 下的实际文件名完全一致。
- 检查扩展名和大小写，避免 YAML 写 `.webp`、实际文件仍是 `.png`。
- 执行 `git status --short -- assets/images/rewards/`，确认新图片不是未跟踪的 `??` 状态。
- 执行 `git ls-files -- assets/images/rewards/`，确认图片已经进入仓库索引。
- 重新执行 Hugo 构建；如果本地正常而线上仍是回退图标，检查包含图片的提交是否已经推送并完成部署。
