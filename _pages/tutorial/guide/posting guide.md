---
title: "安装部署指南"
tags:
    - guide
date: "2024-01-01"
thumbnail: "/assets/img/thumbnail/1.jpg"
bookmark: true
---

这篇文章讲如何安装配置并发表博客文章。博客基于`Github Page`，如何搭建再次不过多赘述，着重讲一下配置文件以及文章的发布。

## 配置
---

只需要修改`_config.yml`下的配置为你自己的实际配置即可

## 目录
---

确保所有目录内部都有一个`index.md`文件，文件内容如下：

```markdown
---
---
```

## 元数据
---

元数据是博客文章的重要组成部分，它定义了文章的标题、标签、日期、缩略图等属性。所有博客文章文件都必须以通常用于设置标题或其他元数据的前言开头。举个例子：

```markdown
---
title: "the post title"
tags:
    - tags1
    - tags2
    - tags3
date: "2024-01-01"
thumbnail: "https://i.ibb.co/MRzw6T9/sample.webp"
bookmark: true
---
```

上面元数据定义了文章的标题、标签、日期、缩略图、是否添加书签等属性。

## 正文
---

博客的正文语法为`markdown`语法，正常书写即可，书写完毕推送到`github`仓库即可

