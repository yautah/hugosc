{{- $slugSource := .File.ContentBaseName -}}
{{- if eq $slugSource "index" -}}
  {{- $slugSource = path.Base (replaceRE "/$" "" .File.Dir) -}}
{{- end -}}
{{- $game := "clashroyale" -}}
{{- $category := "皇室战争" -}}
{{- if in .File.Dir "brawlstars" -}}
  {{- $game = "brawlstars" -}}
  {{- $category = "荒野乱斗" -}}
{{- else if in .File.Dir "clashofclans" -}}
  {{- $game = "clashofclans" -}}
  {{- $category = "部落冲突" -}}
{{- else if in .File.Dir "moco" -}}
  {{- $game = "moco" -}}
  {{- $category = "Mo.Co" -}}
{{- else if in .File.Dir "squadbusters" -}}
  {{- $game = "squadbusters" -}}
  {{- $category = "爆裂小队" -}}
{{- end -}}
---
title: ""
image: "/images/{{ now.Format "2006" }}/"
description: ""
date: "{{ .Date }}"
updated: "{{ .Date }}"
slug: "{{ $slugSource | urlize }}"
game: "{{ $game }}"
content_type: "guide"
difficulty: "beginner"
evergreen: false
featured: false
categories:
  - {{ $category }}
tags:
  - {{ $category }}
keywords:
  -
related:
  -
wechat:
  template: redream-obsidian-blue
draft: false
---

用 2-3 句话说明这篇文章解决什么问题、适合谁阅读，以及读完能获得什么。

## 适合谁

-
-
-

## 关键结论

-
-
-

## 正文

### 小节标题

正文内容。

## 常见问题

### 问题一？

回答。

### 问题二？

回答。

## 相关攻略

-

## 资料说明

本文根据游戏内实际内容、公开资料和玩家经验整理。游戏版本、活动规则和平衡性可能随时间变化，请以游戏内最新信息为准。
