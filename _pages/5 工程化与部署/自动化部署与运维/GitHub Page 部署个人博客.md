---
title: "GitHub Page 部署个人博客"
tags:
    - GitHub Page
    - GitHub
    - blog
date: "2025-10-06"
---

## 快速入门

参考官方文档 [GitHub Pages 快速入门](https://docs.github.com/zh/pages/quickstart)  

## 域名解析

下面用阿里云域名解析为例，分别解析 ipv4 和 ipv6 参考如下：

![alt text](/assets/img/blog/20251006/1.png)

## 多博客部署

一个 GitHub 账号怎么实现多个静态网站？上面是基础操作实现个人网站的搭建，但是我现在只有一个 GitHub 账号, 我还想实现多个网站。在 username.github.io 仓库存在的前提下，我们再创建一个仓库，现在的名字可以随便取。

- 往仓库里面放入 index.html 文件
- 设置里面开启 GitHub Page
- 此时就可以通过 `username.github.io/仓库名` 访问了(部署需要时间, 需要稍等片刻哦)
