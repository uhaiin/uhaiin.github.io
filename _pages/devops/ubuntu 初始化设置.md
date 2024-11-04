---
title: "ubuntu 初始化设置"
tags:
    - linux
    - ubuntu
date: "2024-11-04"
bookmark: true
---
# ubuntu 免密登陆

## 上传密钥
---

将 `windows/mac/linux` 密钥上传到 ubuntu ，可以使用 ftp 、 scp 或者其他工具，下面我以 scp 命令为例，`192.168.220.128`为我的 ubuntu 远程机器地址，在本地进行上传文件到 ubuntu 服务器的 `~/.ssh` 目录下：

```sh
scp id_rsa.pub uhaiin@192.168.220.128:~/.ssh  
```
## 授权密钥
---

上传完成后，在`ubuntu`进行授权密钥操作

```sh
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

sudo chmod 600 authorized_keys
sudo chmod 700 ~/.ssh
```

## 修改 ssh 配置
---
```sh
sudo vim /etc/ssh/sshd_config

# 修改或添加
RSAAuthentication yes
PubkeyAuthentication yes
PasswordAuthentication no
```

## 重启 ssh
---

```sh
sudo service sshd restart
```

# ubuntu 分配未分配空间

## 查看磁盘
---

```sh
df -h
```

## 分配空间
---

将所有未分配的空间添加到你的逻辑卷 `dev/mapper/ubuntu--vg-ubuntu--lv`中

```sh
sudo lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
```
## 调整逻辑卷
---

```sh
sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
```