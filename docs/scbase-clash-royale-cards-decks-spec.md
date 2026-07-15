# SCBase 皇室战争卡牌与卡组系统 Spec

状态：原型阶段  
版本：0.3  
更新：2026-07-15

## 1. 目标

在皇室战争二级频道内建立两类长期资料：

- **卡牌百科**：提供卡牌基本信息、机制、定位、使用建议、克制关系和版本变更记录。
- **卡组榜单**：按模式、统计周期和环境展示 Top 20-30 卡组，提供组成、使用率、胜率、样本量、趋势和复制入口。

系统要同时满足：

- Hugo 静态构建和 Vercel 部署不变。
- 数据可以进入 Git，能够审阅、回滚和追踪更新时间。
- 页面适合中文搜索、站内搜索和移动端速查。
- 将来可以接入独立采集服务，不重写 URL、数据主键和页面组件。
- 明确区分卡组身份和榜单快照。卡组不是长期内容，失去当前环境数据支撑后不进入主列表。

## 2. 非目标

第一阶段不做：

- 玩家账号登录、收藏、评分或个性化推荐。
- 浏览器直接调用需要密钥的官方 API。
- 在 Hugo 构建时实时抓取 Fandom、StatsRoyale 或 RoyaleAPI。
- 未获授权时复制 RoyaleAPI 的排行、胜率、图片或数据库。
- 一次性补齐全部卡牌详情和所有等级的完整数值表。

## 3. 参考产品结论

### 3.1 RoyaleAPI

[RoyaleAPI 热门卡组](https://royaleapi.com/decks/popular)证明卡组排行至少需要这些维度：统计周期、对战模式、天梯区间、排序方式、平均圣水、四卡循环、觉醒数量、包含或排除卡牌、样本量和更新时间。卡组列表适合快速比较，详情页适合承载组成、玩家样本和复制入口。

但 RoyaleAPI 已于 2020 年停止开发者 API，并建议开发者改用官方 API；其条款也禁止未经许可重新发布、复制或再分发站内材料：

- [停止开发者 API 的公告](https://royaleapi.com/blog/sunset-api)
- [RoyaleAPI 服务条款](https://royaleapi.com/tos)

因此，SCBase 可以参考其交互和数据维度，也可以将其作为外部参考链接，但不能把页面抓取作为正式数据接口。实时排行只有两条合规路线：获得书面授权，或使用官方 API 自建采样与聚合。

### 3.2 StatsRoyale

[StatsRoyale 热门卡组](https://statsroyale.com/zh/decks/popular)可作为“按竞技场、模式和环境浏览”的产品参考。当前页面依赖前端渲染且没有适合 SCBase 的公开数据契约，不纳入正式数据管道。

### 3.3 Fandom

[Card Overviews](https://clashroyale.fandom.com/wiki/Card_Overviews)按类型、稀有度、圣水和竞技场组织卡牌；[Mini P.E.K.K.A.](https://clashroyale.fandom.com/wiki/Mini_P.E.K.K.A.)展示了单卡页面应包含的基本信息、机制数值、策略、历史、专精和图库。

Fandom 文本通常允许在遵守署名和相同方式共享条件下复用，但图片经常属于单独授权或合理使用，不能默认批量搬运。SCBase 的处理原则：

- 事实字段可以核验后结构化保存。
- 中文简介、策略和克制内容由 SCBase 原创撰写，不复制原文。
- 保存来源 URL、抓取时间和可用时的页面修订号。
- 不直接镜像 Fandom 图片，除非逐个确认文件授权。
- 需要改写 Fandom 文本时，在页面显示来源和许可说明。

参考：[Fandom 内容复用说明](https://support.fandom.com/hc/en-us/articles/360035075654-I-want-to-reuse-text-or-images-from-a-Fandom-wiki)。

### 3.4 官方 API

[Clash Royale 官方开发者 API](https://developer.clashroyale.com/)适合作为卡牌目录、玩家、排名和战斗日志等机器数据的上游。它不直接提供 RoyaleAPI 式的全局热门卡组榜单；要得到类似数据，需要选择玩家样本、持续拉取战斗日志、去重并按时间和模式聚合。

生产环境中，API 密钥只能放在固定出口 IP 的服务器端。Hugo 和浏览器只读取处理后的公开 JSON，不接触密钥。

## 4. 信息架构

```text
/clashroyale/
├── /clashroyale/cards/               卡牌百科
│   └── /clashroyale/cards/<slug>/    单张基础卡牌
│       ├── evolution/                 觉醒形态（存在时）
│       └── hero/                      精英形态（存在时）
└── /clashroyale/decks/               卡组榜单
    └── /clashroyale/decks/<slug>/    单套卡组
```

入口安排：

- 皇室战争频道首屏：增加“卡组榜单”和“卡牌百科”两个主入口。
- 皇室战争频道中部：可展示当前模式榜首、最近更新卡牌，不展示固定的经典卡组集合。
- 首页：不展示完整榜单；后续只把“热门卡组榜”作为常用入口。
- 文章页：卡组攻略可以关联 `deck_ids`，卡牌解析可以关联 `card_keys`。
- Fuse 搜索：卡牌、卡组上线后加入现有索引，类型分别显示“卡牌”和“卡组”。

## 5. 数据分层

### 5.1 卡牌主数据

路径：`data/clashroyale/cards.yaml`

```yaml
- key: mini-pekka
  official_id: null
  name: 迷你皮卡
  name_en: Mini P.E.K.K.A.
  type: troop
  rarity: rare
  elixir: 4
  arena: training-camp
  image: images/clashroyale/cards/mini-pekka.webp
  summary: 单体伤害较高的近战部队，适合防守反击。
  roles: [单体输出, 防守反击]
  targets: ground
  status: active
  updated_at: 2026-07-15
  sources:
    - kind: fandom
      url: https://clashroyale.fandom.com/wiki/Mini_P.E.K.K.A.
      retrieved_at: 2026-07-15
```

字段原则：

- `key` 是站内稳定主键，不随中文名变化。
- `official_id` 接入官方目录后补齐，不用第三方序号代替。
- 类型、稀有度、圣水、竞技场等事实字段与编辑性内容分开。
- `summary`、`roles`、优缺点和打法由 SCBase 维护。
- 觉醒、精英等形态不计入基础卡牌目录，也不创建同名重复卡牌；它们通过 `parent_key` 归属于基础卡牌，并使用独立子页面。

完整字段候选：

```text
key, official_id, name, name_en, aliases, type, rarity, elixir,
arena, max_level, image, variants, summary, roles, targets,
range, hit_speed, move_speed, deploy_time, troop_count,
strengths, weaknesses, status, updated_at, sources
```

### 5.2 卡牌数值与变更

卡牌主文件不保存所有等级和历史记录。每张有详情页的卡牌使用独立文件：

```text
data/clashroyale/card-details/<key>.yaml
```

详情文件按单位保存战斗参数和逐级属性，并附带平衡调整时间线。普通卡牌只有主单位；石头人、熔岩猎犬、科学怪哥布林等卡牌还需将召唤、分裂或协同单位拆为独立数据组。平衡记录按日期倒序排列，只收录影响对战机制或数值的改动；等级上限、换图和专精任务等全局或展示变化不进入主时间线。

自动解析无法可靠翻译复合改动时，在 `data/clashroyale/card-history-overrides/<key>.yaml` 维护完整中文记录及来源地址。覆盖记录必须包含该卡牌所有影响实际对战的数值、攻击逻辑、部署方式和机制改动，同时收录卡牌首次上线、卡牌图片更换、觉醒上线和精英形态上线四类关键节点。普通描述、角色立绘和所有等级上限调整继续排除。

人工提炼的中文玩法内容独立保存于 `data/clashroyale/card-editorials/<key>.yaml`，固定包含卡牌特点、使用要点、适合应对、需要提防和搭配思路。该目录不参与 Fandom 数值同步，避免人工内容被覆盖。详情页依次展示卡牌特点、战斗参数与等级属性、实战指南，平衡性调整始终位于页面最底部。

Fandom 数值同步只在新增卡牌、觉醒/精英上线、平衡性调整或发现数据错误时运行。普通卡牌完成原创模块后，可使用 `ruby tools/validate-clash-data.rb --require-editorials` 做批量补齐检查；常规校验只验证已存在的 editorial 文件结构，不强制所有基础卡一次性完成。

觉醒和精英形态保存在 `data/clashroyale/card-variants/<parent>-<kind>.yaml`。每个形态拥有独立图片、来源、上线时间、顶部事实字段、战斗参数、等级属性、中文玩法内容与版本记录。基础卡牌页和形态子页使用同一组形态导航互相连接；缺少对应形态的卡牌不显示入口。形态页面默认 `noindex: true`，完成数据与原创内容复核后再开放索引。

### 5.3 卡组身份数据

路径：`data/clashroyale/decks.yaml`

```yaml
- id: hog-cycle-classic
  slug: hog-cycle-classic
  name: 经典野猪速转
  status: active
  cards:
    - card: hog-rider
      slot: 1
    - card: musketeer
      slot: 2
  archetype: cycle
  average_elixir: 2.6
  cycle_elixir: 6
  first_seen_at: 2026-07-15T00:00:00Z
  last_seen_at: 2026-07-15T03:00:00Z
```

卡组身份表是内部归一化字典，不是前台人工维护的“经典卡组库”。卡组身份由 8 张卡、觉醒槽、英雄槽和塔楼部队共同决定。生成规范化键时，对普通卡牌 key 排序，再附加特殊槽位信息并计算哈希。展示顺序单独保留，不能用展示顺序判断是否同一套卡组。

`average_elixir` 和 `cycle_elixir` 应由构建或同步脚本计算，YAML 中的值只作为构建结果或人工校验，不应长期手算。

### 5.4 卡组统计快照

路径：`data/clashroyale/deck-rankings/YYYY-MM-DD/<board>.yaml`

```yaml
board:
  id: classic-challenge-7d-rating
  mode: classic-challenge
  mode_label: 经典挑战
  period: 7d
  sort: rating
  result_size: 30
  observed_at: 2026-07-15T03:00:00Z
  battles: 361107
  sample_players: 18420
  methodology_version: v1
entries:
  - rank: 1
    deck_id: deck-hash
    rating: 77
    usage: 11585
    usage_rate: 0.032
    wins: 7314
    draws: 0
    losses: 4271
    win_rate: 0.631
    rank_change: 2
```

榜单快照是前台核心数据，卡组身份只是其引用对象。排名、胜率、使用率和样本量必须绑定周期、模式、分段、排序规则和算法版本，不能写回卡组身份表。

首批固定榜单：

| 榜单 | 默认周期 | 默认排序 | 结果数 |
| --- | --- | --- | --- |
| 天梯 / 排位模式 | 3 天 | 综合评分 | 30 |
| 皇室征程 | 3 天 | 使用率 | 30 |
| 终极挑战 | 7 天 | 综合评分 | 20 |
| 经典挑战 | 7 天 | 综合评分 | 20 |
| 当前特殊活动 | 1-3 天 | 综合评分 | 20 |

用户可切换 `1d`、`3d`、`7d`，以及综合评分、使用率、胜率。胜率排序必须设置最低对战场次，防止小样本卡组因偶然结果占据榜首。

在取得 RoyaleAPI 授权前，`source: royaleapi` 只能用于人工参考链接，不能自动导入和公开展示其数据。

## 6. 数据获取与更新

### 6.1 Fandom 单卡导入工作流

这套流程用于新增或修订基础卡牌、觉醒形态和精英形态。骑士已验证“基础 + 觉醒 + 精英”三形态，弓箭手已验证“基础 + 觉醒”两形态。形态不存在时不生成数据、路由、入口或“尚未推出”占位。

#### 6.1.1 输入与完成定义

每次任务以一张基础卡牌为处理单元，输入至少包含：

- `cards.yaml` 中已经存在的基础卡牌 `key`。
- Fandom 基础页面名称，如 `Knight`、`Archers`。
- 当前处理日期。

一张卡牌处理完成，指基础页及其已经推出的所有形态同时满足：

- 事实、战斗参数、逐级属性和历史记录已核验。
- 图片已本地化，不在页面运行时引用 Fandom。
- 中文特点、使用要点和对局分析已经人工提炼。
- 详情路由、形态切换、桌面端和移动端均通过检查。
- 数据校验、Hugo 构建和 `git diff --check` 全部通过。

#### 6.1.2 来源发现

优先使用 Fandom MediaWiki API，不抓取带 Cloudflare 页面壳的 HTML：

```text
基础页：<CardName>
觉醒页：<CardName>/Evolution
精英页：<CardName>/Hero
```

API 用途：

```text
/api.php?action=parse&page=<Page>&prop=wikitext|text&format=json
/api.php?action=query&prop=images&titles=<Page>&imlimit=500&format=json
/api.php?action=query&prop=imageinfo&titles=File:<Name>&iiprop=url|size&format=json
```

- `wikitext` 用于读取信息框原值、变量、历史段落和内部链接。
- `text` 用于读取模板计算后的等级表，避免重复实现复杂 Wiki 表达式。
- `images` 和 `imageinfo` 用于定位原始卡图及尺寸。
- 推荐同时记录页面修订号；当前文件至少保存 `source_url` 和 `source_retrieved_at`。

发现形态时逐一探测 `/Evolution` 和 `/Hero`：

- 页面存在且形态已经正式上线：进入导入流程。
- 页面不存在、仍为测试内容或尚未上线：不创建形态。
- 后续推出新形态时再新增，不预先创建空 YAML 和空页面。

#### 6.1.3 基础卡牌处理

基础卡牌数据分为三层：

1. `data/clashroyale/cards.yaml`：中文名、类型、稀有度、圣水、解锁位置、卡图、摘要和详情地址。
2. `data/clashroyale/card-details/<key>.yaml`：单位分组、战斗参数、等级属性和基础卡牌历史。
3. `data/clashroyale/card-editorials/<key>.yaml`：SCBase 原创的特点、使用要点和对局分析。

结构化规则：

- 普通部队使用一个 `main` 单位。
- 召唤、分裂或协同单位使用额外 `child` 单位，不把多个单位压进同一张属性表。需要明确关系时，可使用 `section_label` 和 `summary` 说明“召唤单位”“分裂单位”及其生成条件。
- 等级表列名全部中文化，数值保持上游当前口径。
- Fandom 表格由公式生成时，优先读取 API 已渲染结果；必须自行计算时，要和 1、11、16 级以及页面展示结果交叉校验。
- 英文名只保留为内部来源匹配字段，页面标题、参数和说明不展示英文小标签。

基础卡牌历史使用 `card-details` 的自动结果；自动解析遗漏或翻译不可靠时，改用 `card-history-overrides/<key>.yaml` 完整覆盖，不能只补一条导致后续同步再次丢失。

#### 6.1.4 觉醒与精英形态处理

每个已推出形态保存为：

```text
data/clashroyale/card-variants/<parent>-evolution.yaml
data/clashroyale/card-variants/<parent>-hero.yaml
```

形态文件必须包含：

```yaml
key: knight-evolution
parent_key: knight
kind: evolution
order: 2
name: 觉醒骑士
label: 觉醒
url: /clashroyale/cards/knight/evolution/
image: images/clashroyale/cards/variants/knight-evolution.webp
source_url: https://clashroyale.fandom.com/wiki/Knight/Evolution
source_retrieved_at: '2026-07-15'
release_date: '2023-08-07'
summary: 中文摘要
facts: []
overview: []
units: []
usage_tips: []
matchups: []
balance_history: []
```

形态页面分别使用固定路由：

```text
/clashroyale/cards/<parent>/evolution/
/clashroyale/cards/<parent>/hero/
```

形态字段根据机制变化，不强求所有页面拥有相同数值列：

- 觉醒常见字段：循环次数、特殊效果、触发距离、倍率和形态独立属性。
- 精英常见字段：技能名称、技能费用、施放时间、持续时间、冷却、范围和护盾。
- 特殊伤害、护盾或召唤单位应成为独立属性列或单位组，不塞入说明文本代替结构化数据。
- 形态导航由数据自动生成。一个形态时显示“基础 + 该形态”，两个形态时显示三项；不存在的形态完全不显示。

#### 6.1.5 历史记录口径

历史统一按日期倒序排列，类型只使用：

```text
buff, nerf, adjustment, release, visual, evolution, hero
```

基础卡牌应收录：

- 所有影响实际对战的数值、攻击逻辑、部署方式和机制调整。
- 首次上线时间。
- 卡牌图片更换。
- 觉醒形态上线和精英形态上线。

形态子页应收录：

- 该形态首次上线。
- 形态特有数值、机制和技能调整。
- 影响实战的故障修复。

形态上线节点允许同时出现在基础卡牌历史和对应形态历史中：前者用于说明基础卡何时获得新形态，后者是形态自身时间线的起点。形态上线后的专属调整只保存在形态子页，不在基础卡历史中重复维护。

以下内容不收录：

- 等级上限调整，包括 14、15、16 级上线。
- 纯文案、翻译、说明文本和专精任务变化。
- 只有音效或非卡牌图片的美术变化。
- 上线前且没有可靠日期的测试数值。

日期只能使用来源能够支持的精度。来源只写到月份时，数据使用当月第一天并增加 `date_precision: month`，模板显示为“年 + 月”，不得自行猜测具体日号。

#### 6.1.6 图片处理

- 只处理当前页面需要的卡图，不批量镜像图库、预览动画和装饰素材。
- 先通过 `imageinfo` 获取原始地址，再保存到 `assets/images/clashroyale/cards/` 或其 `variants/` 子目录。
- 文件名使用站内稳定 key，不保留第三方站名、查询串或临时编号。
- 转换为透明背景 WebP，并统一放入 `180 × 220` 画布；保持完整卡图，不裁掉边框和形态标记。
- 处理前确认素材可依据 Supercell 粉丝内容政策使用，并在数据中保留来源页面。
- 模板只使用本地 Hugo Resource，不能输出 Fandom 图片 URL。

#### 6.1.7 中文编辑内容

基础卡牌和每个形态都必须经过人工整理，不能把 Fandom Strategy 逐句翻译后发布。固定内容结构：

- `overview`：至少两个自然段，解释定位、核心机制、优势和边界。
- `usage_tips`：至少三条可以实际执行的使用建议。
- `matchups`：固定为“适合应对”“需要提防”“搭配思路”三项。

写作要求：

- 使用正常资讯或百科自然段，不采用一句一段。
- 数值说明与结构化数据一致，避免“高额”“很远”等没有口径的孤立表达。
- 不照搬 Fandom 句式、笑话、角色外貌和冗长卡组枚举。
- 重点解释中文玩家实际需要的站位、距离、费用和对局条件。

#### 6.1.8 文件写入顺序

卡牌页面入口统一收纳在 `content/clashroyale/cards/`，不要再写入 `content/` 根目录：

```text
content/clashroyale/cards/
├── _index.md
├── archers.md
├── archers-evolution.md
├── knight.md
├── knight-evolution.md
└── knight-hero.md
```

- `_index.md` 是卡牌百科栏目入口，只输出 HTML。
- 基础卡牌文件名为 `<key>.md`。
- 觉醒与精英形态文件名为 `<parent>-evolution.md` 和 `<parent>-hero.md`。
- 形态文件在物理目录中保持扁平，避免 Hugo 将每张基础卡牌识别为 section；页面仍通过 front matter 的 `url` 输出为 `/clashroyale/cards/<parent>/evolution/` 或 `/hero/`。
- 卡牌普通页面模板位于 `layouts/clashroyale/`，卡牌百科栏目模板位于 `layouts/section/`。

建议一张卡按以下顺序完成，避免页面先出现但数据不完整：

1. 核对基础卡 `key`、中文名和 Fandom 页面。
2. 探测基础、觉醒和精英页面，建立本次处理清单。
3. 提取信息框、战斗参数、单位组、等级属性和历史原文。
4. 下载并转换基础卡图与已推出形态卡图。
5. 更新基础卡 `cards.yaml`、`card-details` 和必要的历史覆盖。
6. 编写基础卡 `card-editorials`。
7. 为每个已推出形态创建 `card-variants` 数据和内容路由。
8. 完成中文特点、玩法、对局分析和版本记录。
9. 运行数据校验、Hugo 构建和页面检查。
10. 人工确认后再决定是否移除 `noindex`。

现有脚本职责：

```bash
ruby tools/sync-clash-card-sources.rb --write-manifest
ruby tools/discover-clash-card-variants.rb --write
ruby tools/build-clash-card-data.rb --write --images
npm run audit:clash-cards
```

- `sync-clash-card-sources.rb` 维护基础卡牌来源清单。
- `discover-clash-card-variants.rb` 批量探测每张基础卡的 `/Evolution` 和 `/Hero` 页面，记录已上线形态、页面修订号和更新时间。
- `build-clash-card-data.rb` 生成基础卡牌详情、路由和图片；历史覆盖文件优先于自动解析结果。
- `audit-clash-card-workflow.rb` 统计中文编辑内容、完整历史覆盖、页面人工复核和应有形态是否齐全；全量收尾时使用 `--require-complete` 作为硬门槛。
- 当前脚本只负责发现形态，不直接生成 `card-variants`。只新增觉醒或精英形态时，不需要为了形态页面重跑全量基础卡同步。
- 将来增加形态同步脚本时，应先输出候选文件或 diff，不得直接覆盖人工核验内容。

形态内容路由示例：

```yaml
title: 觉醒骑士：属性、玩法与平衡调整
description: 面向读者和搜索引擎的中文说明
url: /clashroyale/cards/knight/evolution/
layout: clashroyale-card-variant
variant_key: knight-evolution
noindex: true
draft: false
```

#### 6.1.9 校验与视觉验收

每张卡完成后执行：

```bash
npm run validate:clash-data
hugo --gc --minify --destination /tmp/hugosc-card-check
git diff --check
```

本地页面至少检查：

- 基础页及所有形态页均返回 `200`。
- 面包屑、形态图片和形态切换链接正确。
- 不存在的形态没有占位入口。
- 桌面端战斗参数和等级属性顶部对齐。
- 长日期不换行；月份精度显示正确。
- 多列属性表不撑宽页面，移动端只在表格内部横向滚动。
- 页面没有英文小标签、文字遮挡和整页横向溢出。
- 历史记录位于页面最底部，并与对应基础卡或形态严格匹配。

完成技术验收不等于可以索引。`noindex` 只有在事实、中文编辑内容、来源和 SEO 描述全部经过人工复核后才能移除。

#### 6.1.10 自动化边界与批次安排

当前基础卡牌的目录、参数和部分历史可由现有同步脚本生成；形态发现、形态历史和中文编辑内容仍采用“API 辅助 + 人工核验”。后续自动化应遵守：

- 可以自动：探测页面、读取信息框和表格、下载图片、生成候选 YAML、检查变化。
- 必须人工：中文名称确认、复合调整翻译、历史取舍、玩法提炼、SEO 描述和开放索引。
- 自动任务不得覆盖 `card-editorials`、`card-history-overrides` 或已经人工核验的 `card-variants`。
- 同步结果应先生成 diff 或候选文件，审核后再写入正式数据。

建议每批处理 5–10 张基础卡牌，优先级依次为：已有自然搜索需求、已有觉醒或精英形态、近期发生平衡调整、常见卡组中的高使用率卡牌。每批必须独立通过构建和视觉抽查，避免一次性导入全部形态后集中返工。

### 6.2 第一阶段：榜单数据管道

```mermaid
flowchart LR
  A["官方排行榜玩家标签"] --> B["玩家采样池"]
  B --> C["定时拉取战斗日志"]
  C --> D["去重与模式归类"]
  D --> E["卡组归一化"]
  E --> F["榜单快照 JSON"]
  F --> G["Hugo / 前端榜单"]
```

- 使用官方排行榜、已知活跃玩家和历史样本建立玩家标签池。
- 每个玩家的近期战斗日志按频率拉取，使用双方标签、时间、模式、结果和卡组生成去重键。
- 根据 battle type 区分排位、皇室征程、终极挑战、经典挑战和特殊活动。
- 每小时增量聚合一次，每日保留一个完整快照。
- Hugo 不直接调用官方 API，只读取同步服务发布的公开快照。

### 6.3 固定 IP 同步服务

闲置服务器承担：

- 保存官方 API 密钥和固定出口 IP。
- 定时同步官方卡牌目录。
- 拉取经过明确抽样规则选择的玩家战斗日志。
- 对 battle ID、玩家、时间和模式去重。
- 识别特殊活动 ID、塔楼部队、英雄和觉醒槽。
- 输出不含密钥的规范化 JSON；榜单快照不提交大量原始战斗记录到 Hugo 仓库。

不建议让 Hugo 构建直接依赖同步服务在线可用。稳定做法是同步服务生成版本化快照，Vercel 只消费最近一次成功结果。

### 6.4 更新频率

| 数据 | 建议频率 | 触发条件 |
| --- | --- | --- |
| 卡牌目录 | 每周一次 | 新卡、觉醒、英雄或官方字段变化 |
| 卡牌数值 | 平衡更新后 | 官方平衡公告实装 |
| 卡牌中文解读 | 按需 | 机制变化或内容修订 |
| 卡组身份 | 每小时 | 采集到新的 8 卡组合 |
| 榜单聚合 | 每小时 | 新增战斗日志 |
| 榜单公开快照 | 每 3-6 小时 | 聚合完成且通过样本检查 |
| 赛季归档 | 每赛季 | 赛季结束 |
| 详情页搜索索引 | 每次构建 | 数据或正文变化 |

## 7. 页面规格

### 7.1 卡牌百科列表

- 标题、更新时间和数据口径说明。
- 名称搜索。
- 类型、稀有度、圣水筛选；移动端使用紧凑下拉框。
- 卡牌项显示图片、中文名、圣水、类型、稀有度和一句定位。
- 桌面端使用紧凑网格，移动端使用左图右信息列表。

### 7.2 单卡详情

- 卡图、中文名、圣水、稀有度、类型、竞技场。
- 战斗参数与等级属性在桌面端左右分布，移动端上下堆叠。
- 多单位卡牌先展示主单位，再分别展示召唤或分裂单位，最后统一展示平衡性调整。
- 定位、优势、弱点和适合卡组。
- 当前关键数值及明确等级口径。
- 平衡性调整时间线。
- 包含该卡牌的精选卡组。
- 来源与最后核验时间。
- 存在觉醒或精英形态时，在基础信息下方显示紧凑形态切换；子形态沿用相同详情结构，但显示各自技能、属性和独立版本记录。

### 7.3 卡组榜单

- 第一层切换模式：天梯、皇室征程、终极挑战、经典挑战、当前特殊活动。
- 第二层切换统计周期：1 天、3 天、7 天；切换排序：综合、使用率、胜率。
- 默认展示 Top 20，天梯和皇室征程可展示 Top 30。
- 每行显示排名、8 张卡、平均圣水、使用率、胜率、对战场次和排名变化。
- 页面顶部显示总样本量、最后更新时间和数据方法入口。
- 卡牌包含/排除、奖杯或联赛分段属于第二阶段筛选，不阻塞首版。
- 提供“复制卡组”和“查看详情”动作；详情页必须显示该卡组在哪些模式和周期中出现。
- 快照超过 12 小时标记“数据延迟”，超过 48 小时停止显示榜单并展示维护状态。

### 7.4 卡组详情

- 8 张卡和变体槽位。
- 核心思路、开局、进攻、防守和加时策略。
- 难打对局、替代卡及替换影响。
- 统计趋势和统计口径。
- 关联攻略、相关卡牌和更新记录。

## 8. SEO 与结构化数据

- 列表页使用稳定 canonical，不为每种筛选组合生成可索引 URL。
- 筛选通过前端状态或 query 参数完成，query 结果使用同一个 canonical。
- 卡牌详情标题格式：`迷你皮卡：属性、机制与卡组推荐 | 超级细胞营地`。
- 卡组详情标题格式：`经典野猪速转卡组：卡牌组成与打法 | 超级细胞营地`。
- 卡组和卡牌页进入 sitemap；空筛选页和搜索结果不产生独立索引。
- 可使用 `ItemList` 和 `BreadcrumbList`；不要把第三方统计包装成官方数据。
- 页面显示 `updated_at`，发生机制或平衡变化时同步更新正文和数据。

## 9. 校验规则

第一阶段至少实现：

- 卡牌 `key`、卡组 `id` 和 `slug` 唯一。
- 卡组必须恰好包含 8 张不同卡牌。
- 每个卡牌引用都必须存在。
- `elixir`、`average_elixir` 和 `cycle_elixir` 范围合法。
- 图片资源存在，来源记录不为空。
- 快照必须包含周期、模式、分段、样本量和方法版本。
- 失效卡组设为 `archived`，不直接删除历史记录。

## 10. 可行性结论

| 能力 | 结论 | 说明 |
| --- | --- | --- |
| 卡牌百科 | 可行 | 仓库数据 + 原创中文内容，后续接官方目录 |
| 固定经典卡组库 | 不作为主产品 | 环境变化快，长期陈列容易误导 |
| 模式 Top 20-30 榜单 | 条件可行 | 必须先获得合法、持续且有规模的战斗数据 |
| 卡组文章关联 | 可行 | 使用 `deck_ids` / `card_keys` Front Matter |
| RoyaleAPI 实时榜单 | 条件可行 | 必须取得授权或数据合作 |
| 自建全局排行 | 条件可行 | 需固定 IP 服务、采样方法、存储和持续成本 |
| 构建时抓第三方页面 | 不采用 | 不稳定，并存在条款、授权和构建可靠性问题 |

总体结论：**卡牌百科通过；卡组榜单有条件通过。** 当前三套静态卡组只能验证 8 卡渲染和归一化，不构成可上线的卡组产品。榜单页面必须等授权数据或自建聚合产生真实样本后再作为正式入口。

## 11. 分阶段实施

### Phase A：静态原型

状态：卡牌百科已完成全量目录与详情页；原卡组库方向已废弃，仅保留底层组件验证结果。

- [x] 创建卡牌和卡组 YAML。
- [x] 创建 `/clashroyale/cards/` 与 126 张卡牌详情页。
- [x] 使用 126 张卡牌、3 套卡组验证动态等级表、8 卡归一化和渲染组件。
- [x] 建立 Fandom 来源清单、官方简中名称回退、全量详情解析与本地图片同步脚本。
- [x] 将 `/clashroyale/decks/` 改为模式榜单框架，不再展示固定经典卡组。
- [ ] 数据源可用后再在皇室战争频道开放正式榜单入口。
- [x] 增加数据一致性校验器。
- [x] 以骑士完成基础、觉醒和精英三种形态的可复用详情页原型。
- [x] 以弓箭手完成“缺少精英时不显示占位”的两形态原型。
- [x] 固化 Fandom 单卡与形态的导入、编辑、校验和视觉验收流程。
- [x] 补齐 126 张基础卡牌当前已上线的全部觉醒与精英形态数据；截至 2026-07-15 共 55 个形态。

### Phase B：榜单采集 MVP

- 部署固定 IP 采集服务并接入官方 API。
- 建立排行榜玩家种子、战斗日志去重和 battle type 映射。
- 先跑通经典挑战与排位两个榜单，验证样本偏差和更新成本。
- 输出 Top 20 JSON，并保留 7 天快照。

### Phase C：榜单产品

- 扩展到皇室征程、终极挑战和特殊活动。
- 上线模式、周期、排序、卡牌包含/排除和分段筛选。
- 增加趋势、替代卡影响、复制卡组和数据方法页。

### Phase D：内容化与搜索

- [x] 补齐卡牌基础目录、战斗参数、等级属性和可可靠解析的平衡记录。
- [x] 为 126 张基础卡牌补充原创中文特点、使用要点、对局分析与人工复核后的完整版本历史。
- 将卡组榜单、卡牌和攻略加入 Fuse 搜索。
- 为高频榜单卡组关联原创打法与环境报告。

## 12. 原型验收标准

- 卡牌列表、126 张卡牌详情和卡组榜单框架均可直接访问。
- 皇室战争频道入口可到达卡牌百科；榜单入口仅在真实数据可用后正式开放。
- 桌面和移动端无横向溢出、文字遮挡或错位。
- 每个榜单条目都包含 8 张有效卡牌及完整统计口径。
- 页面不使用编辑样例代替 Top 榜单真实数据。
- `hugo --minify` 构建通过。
- 原型数据可被未来 API 输出替换，不依赖模板硬编码卡名。
