---
title: ""
image: "/images/{{ now.Format "2006" }}/"
description: ""
date: '{{ .Date }}'
slug: "{{ replaceRE `^.*?_(.*)$` `$1` .File.ContentBaseName | replaceRE `_` `-` }}"
categories:
  - 默认分类
tags:
  - 默认tag
keywords:
  -
draft: false
---
