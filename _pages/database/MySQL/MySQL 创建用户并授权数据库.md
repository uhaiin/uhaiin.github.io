---
title: "创建用户并授权数据库"
tags:
    - MySQL
date: "2024-11-04"
bookmark: true
---

## 创建新用户
---

```sql
CREATE USER 'username'@'localhost' IDENTIFIED BY 'password';
```

将 **username** 和 **password** 替换为你想要设置的用户名和密码。

## 授权
---

为了安全，每个新建的用户只能访问特定数据库，不能访问所有数据库

```sql
GRANT ALL PRIVILEGES ON database_name.* TO 'username'@'localhost';
```

将**database_name**替换为你想要授权的数据库的名称。

## 刷新权限
---

```sql
FLUSH PRIVILEGES;
```

这一步是为了确保权限更改立即生效。