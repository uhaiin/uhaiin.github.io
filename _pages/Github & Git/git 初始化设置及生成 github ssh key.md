---
title: "git 初始化设置及生成 github ssh key"
tags:
    - git
date: "2025-09-27"
---

# git 初始化设置
---

**配置Git 用户名和邮箱，无论你使用 Windows 的命令提示符、Git Bash，还是 macOS/Linux 的终端，都需要先打开一个命令窗口**

**设置用户名**：在终端中输入以下命令，然后替换 "你的用户名" 为你想要设置的用户名
```sh
git config --global user.name "你的用户名"
```

**设置邮箱** 接着输入以下命令，将 "你的邮箱地址" 替换成你的邮箱。

```sh
git config --global user.email "你的邮箱地址"
```

**验证配置** 你可以使用查看所有全局配置命令检查是否配置成功

```sh
git config --global --list
```

# 生成 SSH 密钥
---



在终端中，运行以下命令来生成一个新的SSH密钥对。这里，你需要将your_email@example.com替换成你的GitHub邮箱地址，并将id_ed25519替换成你想要的密钥文件名（如果你想要使用RSA算法，可以将-t ed25519改为-t rsa -b 4096）

```sh
ssh-keygen -t ed25519 -C "your_email@example.com"
```

**设置密码**(可选)

在执行上述命令后，系统会询问是否需要为你的密钥设置密码。如果你想要每次使用密钥时都输入密码，可以设置一个密码。如果你不想每次都输入密码，可以直接按回车跳过这一步。

**看你的公钥**

生成的公钥位于~/.ssh/id_ed25519.pub（如果你使用的是默认的文件名和算法）。

**添加 SSH 密钥到 GitHub**

复制你的公钥内容（通过cat ~/.ssh/id_ed25519.pub命令得到），然后登录到你的GitHub账户，在“Settings”->“SSH and GPG keys”->“New SSH key”页面中，将公钥粘贴到“Key”框中，并添加一个描述性的标题（例如“My MacBook Pro”），最后点击“Add SSH key”。

**测试连接**

```sh
ssh -T git@github.com
```

系统会要求你确认是否继续连接，输入yes即可。如果一切设置正确，你将看到类似“Hi username! You've successfully authenticated, but GitHub does not provide shell access.”的欢迎信息。

这样，你就成功地在Mac上生成了GitHub的SSH密钥，并配置好了与GitHub的SSH连接。
