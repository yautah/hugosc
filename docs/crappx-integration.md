# crappx 集成说明

SCBase 的卡组、小程序共用接口和数据同步说明，以 crappx 项目文档为准：

```text
/Users/yang/workspaces/crappx/docs/scbase-integration.md
```

本文件只记录 Hugo 侧接入点，避免两边重复维护接口细节。

## SCBase 侧职责

- 提供卡组榜单的静态入口页。
- 使用浏览器端 Vue 组件请求 crappx 公开 API。
- 保留 SEO 标题、描述、canonical、基础说明和接口失败降级文案。
- 不保存 RoyaleAPI Token、微信 Secret 或任何后端密钥。
- 不按天生成大量卡组快照页面。

## 计划页面

第一阶段：

```text
/clashroyale/decks/
```

后续视数据和页面价值拆分：

```text
/clashroyale/decks/ladder/
/clashroyale/decks/grand-challenge/
/clashroyale/decks/cores/hog-rider/
```

## 接口事实源

需要接口字段、同步链路、CORS、安全边界或小程序共用规则时，先读：

```text
/Users/yang/workspaces/crappx/docs/scbase-integration.md
/Users/yang/workspaces/crappx/docs/api-reference.md
```
