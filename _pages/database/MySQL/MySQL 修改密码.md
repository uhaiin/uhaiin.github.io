---
title: "MySQL 修改密码"
tags:
    - MySQL
date: "2024-11-04"
bookmark: true
---

## 修改用户密码
---

```sql
ALTER USER 'root'@'localhost' IDENTIFIED BY 'newPassword'
```

## 刷新
---

```sql
FLUSH PRIVILEGES
```

##
---

执行完以后操作后需要进行重启 MySQL 服务生效