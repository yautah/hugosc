---
title: ""
image: "/images/{{ now.Format "2006" }}/"
description: ""
date: '{{ now.Format "2006-01-02T15:04:05-07:00" }}'
slug: "{{ replaceRE `^.*?_(.*)$` `$1` .File.ContentBaseName | replaceRE `_` `-` }}"
categories:
  - 默认分类
tags:
  - 默认tag
keywords:
  -
draft: false
---
