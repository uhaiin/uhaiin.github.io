---
title: "Spring Boot 轻量级 API 网关设计"
tags:
    - gateway
    - java
    - SpringBoot
date: "2026-02-03"
---

# 目标

实现了一个基于 SpringBoot 的轻量级 API 防火墙，通过拦截器机制提供实时防护能力。对所有 API 请求进行“前置检查“，支持配置IP白名单、黑名单，白名单优先级更高。系统采用 Guava Cache 实现高性能内存缓存，支持 QPS 限制。

# 技术选型

**数据库**：postgresql + 通用 mapper tk.mybatis

**缓存**：Guava Cache

**SpringBoot**： 4

**JDK**：21

> 对于分布式场景，后续可以扩展 Redis + Lua 实现统一限流；但在本文场景下，先聚焦 单机轻量化防护。

# 核心表

## 接口访问日志表

```sql
CREATE TABLE demo.firewall_access_log (
	id int8 NOT NULL, -- 主键ID
	ip_address varchar(100) NOT NULL, -- IP地址
	api_path varchar(200) NOT NULL, -- API路径
	user_agent varchar(500) NULL, -- User-Agent
	request_method varchar(10) NULL, -- 请求方法
	status_code int4 NULL, -- 响应状态码
	block_reason varchar(100) NULL, -- 拦截原因
	request_time timestamp DEFAULT CURRENT_TIMESTAMP NULL, -- 请求时间
	response_time int8 NULL, -- 响应时间(毫秒)
	CONSTRAINT firewall_access_log_pkey PRIMARY KEY (id)
);
CREATE INDEX idx_api_time ON demo.firewall_access_log USING btree (api_path, request_time);
CREATE INDEX idx_ip_time ON demo.firewall_access_log USING btree (ip_address, request_time);
COMMENT ON TABLE demo.firewall_access_log IS '接口访问日志表';

-- Column comments

COMMENT ON COLUMN demo.firewall_access_log.id IS '主键ID';
COMMENT ON COLUMN demo.firewall_access_log.ip_address IS 'IP地址';
COMMENT ON COLUMN demo.firewall_access_log.api_path IS 'API路径';
COMMENT ON COLUMN demo.firewall_access_log.user_agent IS 'User-Agent';
COMMENT ON COLUMN demo.firewall_access_log.request_method IS '请求方法';
COMMENT ON COLUMN demo.firewall_access_log.status_code IS '响应状态码';
COMMENT ON COLUMN demo.firewall_access_log.block_reason IS '拦截原因';
COMMENT ON COLUMN demo.firewall_access_log.request_time IS '请求时间';
COMMENT ON COLUMN demo.firewall_access_log.response_time IS '响应时间(毫秒)';
```

## 接口限流规则表

```sql
CREATE TABLE demo.firewall_rule (
	id int8 NOT NULL, -- 主键ID
	rule_name varchar(100) NOT NULL, -- 规则名称
	api_pattern varchar(200) NOT NULL, -- API路径匹配模式
	qps_limit int4 DEFAULT 100 NULL, -- QPS限制
	enabled bool DEFAULT true NULL, -- 是否启用
	description varchar(500) NULL, -- 规则描述
	created_time timestamp DEFAULT CURRENT_TIMESTAMP NULL, -- 创建时间
	updated_time timestamp DEFAULT CURRENT_TIMESTAMP NULL, -- 更新时间
	CONSTRAINT firewall_rule_pkey PRIMARY KEY (id)
);
COMMENT ON TABLE demo.firewall_rule IS '接口限流规则表';

-- Column comments

COMMENT ON COLUMN demo.firewall_rule.id IS '主键ID';
COMMENT ON COLUMN demo.firewall_rule.rule_name IS '规则名称';
COMMENT ON COLUMN demo.firewall_rule.api_pattern IS 'API路径匹配模式';
COMMENT ON COLUMN demo.firewall_rule.qps_limit IS 'QPS限制';
COMMENT ON COLUMN demo.firewall_rule.enabled IS '是否启用';
COMMENT ON COLUMN demo.firewall_rule.description IS '规则描述';
COMMENT ON COLUMN demo.firewall_rule.created_time IS '创建时间';
COMMENT ON COLUMN demo.firewall_rule.updated_time IS '更新时间';

INSERT INTO firewall_rule (id, rule_name, api_pattern, qps_limit, enabled, description, created_time, updated_time) VALUES(1, '用户登录限流', '/api/auth/login', 10, true, '用户登录接口限流，防止暴力破解', '2026-01-26 13:48:18.421', '2026-01-26 13:48:18.421');
INSERT INTO firewall_rule (id, rule_name, api_pattern, qps_limit, enabled, description, created_time, updated_time) VALUES(2, '订单接口限流', '/api/order/**', 50, true, '订单相关接口限流', '2026-01-26 13:48:18.421', '2026-01-26 13:48:18.421');
INSERT INTO firewall_rule (id, rule_name, api_pattern, qps_limit, enabled, description, created_time, updated_time) VALUES(3, '支付接口限流', '/api/payment/**', 20, true, '支付相关接口限流', '2026-01-26 13:48:18.421', '2026-01-26 13:48:18.421');
INSERT INTO firewall_rule (id, rule_name, api_pattern, qps_limit, enabled, description, created_time, updated_time) VALUES(4, '文件上传限流', '/api/upload/**', 30, true, '文件上传接口限流', '2026-01-26 13:48:18.421', '2026-01-26 13:48:18.421');
INSERT INTO firewall_rule (id, rule_name, api_pattern, qps_limit, enabled, description, created_time, updated_time) VALUES(5, '数据导出限流', '/api/export/**', 5, true, '数据导出接口限流，防止大量导出', '2026-01-26 13:48:18.421', '2026-01-26 13:48:18.421');
INSERT INTO firewall_rule (id, rule_name, api_pattern, qps_limit, enabled, description, created_time, updated_time) VALUES(6, '默认API限流', '/api/test/**', 10, true, '默认API接口限流规则', '2026-01-26 13:48:18.421', '2026-01-26 15:43:53.418');
INSERT INTO firewall_rule (id, rule_name, api_pattern, qps_limit, enabled, description, created_time, updated_time) VALUES(7, 'demo 限流', '/demo', 2, true, '默认API接口限流规则', '2026-01-26 13:48:18.421', '2026-01-26 15:43:53.418');
```

## 接口访问统计表

```sql
CREATE TABLE demo.firewall_statistics (
	id int8 NOT NULL, -- 主键ID
	stat_date date NOT NULL, -- 统计日期
	api_path varchar(200) NOT NULL, -- API路径
	total_requests int8 DEFAULT 0 NULL, -- 总请求数
	blocked_requests int8 DEFAULT 0 NULL, -- 被拦截请求数
	avg_response_time numeric(10, 2) DEFAULT 0 NULL, -- 平均响应时间
	created_time timestamp DEFAULT CURRENT_TIMESTAMP NULL, -- 创建时间
	updated_time timestamp DEFAULT CURRENT_TIMESTAMP NULL, -- 更新时间
	CONSTRAINT firewall_statistics_pkey PRIMARY KEY (id),
	CONSTRAINT uk_date_api UNIQUE (stat_date, api_path)
);
COMMENT ON TABLE demo.firewall_statistics IS '接口访问统计表';

-- Column comments

COMMENT ON COLUMN demo.firewall_statistics.id IS '主键ID';
COMMENT ON COLUMN demo.firewall_statistics.stat_date IS '统计日期';
COMMENT ON COLUMN demo.firewall_statistics.api_path IS 'API路径';
COMMENT ON COLUMN demo.firewall_statistics.total_requests IS '总请求数';
COMMENT ON COLUMN demo.firewall_statistics.blocked_requests IS '被拦截请求数';
COMMENT ON COLUMN demo.firewall_statistics.avg_response_time IS '平均响应时间';
COMMENT ON COLUMN demo.firewall_statistics.created_time IS '创建时间';
COMMENT ON COLUMN demo.firewall_statistics.updated_time IS '更新时间';
```

## ip 黑名单表

```sql
CREATE TABLE demo.firewall_blacklist (
	id int8 NOT NULL, -- 主键ID
	ip_address varchar(100) NOT NULL, -- IP地址
	reason varchar(200) NULL, -- 封禁原因
	expire_time timestamp NULL, -- 过期时间(NULL表示永久)
	enabled bool DEFAULT true NULL, -- 是否启用
	created_time timestamp DEFAULT CURRENT_TIMESTAMP NULL, -- 创建时间
	updated_time timestamp DEFAULT CURRENT_TIMESTAMP NULL, -- 更新时间
	CONSTRAINT firewall_blacklist_pkey PRIMARY KEY (id),
	CONSTRAINT uk_ip UNIQUE (ip_address)
);
COMMENT ON TABLE demo.firewall_blacklist IS 'ip 黑名单表';

-- Column comments

COMMENT ON COLUMN demo.firewall_blacklist.id IS '主键ID';
COMMENT ON COLUMN demo.firewall_blacklist.ip_address IS 'IP地址';
COMMENT ON COLUMN demo.firewall_blacklist.reason IS '封禁原因';
COMMENT ON COLUMN demo.firewall_blacklist.expire_time IS '过期时间(NULL表示永久)';
COMMENT ON COLUMN demo.firewall_blacklist.enabled IS '是否启用';
COMMENT ON COLUMN demo.firewall_blacklist.created_time IS '创建时间';
COMMENT ON COLUMN demo.firewall_blacklist.updated_time IS '更新时间';

INSERT INTO firewall_blacklist (id, ip_address, reason, expire_time, enabled, created_time, updated_time) VALUES(1, '10.163.193.196/32', '恶意攻击IP', NULL, NULL, '2026-01-26 13:57:46.428', '2026-01-26 15:35:34.028');
```

## ip 白名单表

```sql
CREATE TABLE demo.firewall_whitelist (
	id int8 NOT NULL, -- 主键ID
	ip_address varchar(100) NOT NULL, -- IP地址
	description varchar(200) NULL, -- 描述
	enabled bool DEFAULT true NULL, -- 是否启用
	created_time timestamp DEFAULT CURRENT_TIMESTAMP NULL, -- 创建时间
	updated_time timestamp DEFAULT CURRENT_TIMESTAMP NULL, -- 更新时间
	CONSTRAINT firewall_whitelist_pkey PRIMARY KEY (id),
	CONSTRAINT uk_whitelist_ip UNIQUE (ip_address)
);
COMMENT ON TABLE demo.firewall_whitelist IS 'ip 白名单表';

-- Column comments

COMMENT ON COLUMN demo.firewall_whitelist.id IS '主键ID';
COMMENT ON COLUMN demo.firewall_whitelist.ip_address IS 'IP地址';
COMMENT ON COLUMN demo.firewall_whitelist.description IS '描述';
COMMENT ON COLUMN demo.firewall_whitelist.enabled IS '是否启用';
COMMENT ON COLUMN demo.firewall_whitelist.created_time IS '创建时间';
COMMENT ON COLUMN demo.firewall_whitelist.updated_time IS '更新时间';

INSERT INTO firewall_whitelist (id, ip_address, description, enabled, created_time, updated_time) VALUES(1, '127.0.0.1/32', '本地回环地址', true, '2026-01-26 13:48:35.552', '2026-01-26 13:48:35.552');
INSERT INTO firewall_whitelist (id, ip_address, description, enabled, created_time, updated_time) VALUES(2, '::1/128', 'IPv6本地回环地址', true, '2026-01-26 13:48:35.552', '2026-01-26 13:48:35.552');
INSERT INTO firewall_whitelist (id, ip_address, description, enabled, created_time, updated_time) VALUES(3, '192.168.1.100/32', '管理员IP地址', true, '2026-01-26 13:48:35.552', '2026-01-26 13:48:35.552');
```

# 配置文件

集成 postgresql+mybatis+firewall

```yaml
# 数据库配置（PostgreSQL）
spring:
  jackson:
    # 核心基础配置
    default-property-inclusion: non_null
    date-format: yyyy-MM-dd HH:mm:ss
    time-zone: Asia/Shanghai
  datasource:
    driver-class-name: org.postgresql.Driver
    url: jdbc:postgresql://ip:port/db?currentSchema=public
    username: username
    password: password
    hikari:
      pool-name: uhaiinHikariPool
      minimum-idle: 5
      maximum-pool-size: 20
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000
      connection-test-query: SELECT 1
      auto-commit: true
      leak-detection-threshold: 60000
      data-source-properties:
        cachePrepStmts: true
        useServerPrepStmts: true
        prepStmtCacheSize: 250
        prepStmtCacheSqlLimit: 2048
        rewriteBatchedStatements: true

# MyBatis配置
mybatis:
  mapper-locations:
    - classpath:mapper/firewall/*.xml
    - classpath:mapper/user/*.xml
  type-aliases-package:
    - com.uhaiin.firewall.entity
    - com.uhaiin.user.entity
  configuration:
    map-underscore-to-camel-case: true
    log-impl: org.apache.ibatis.logging.stdout.StdOutImpl # 生产关闭

# TKMyBatis（通用Mapper）配置
mapper:
  mappers: tk.mybatis.mapper.common.Mapper # 指定通用Mapper接口，核心配置
  identity: POSTGRESQL # 主键生成策略适配PostgreSQL（支持自增主键serial/bigserial）
  not-empty: true # 更新时是否忽略空值（true：只更新非空字段，推荐）
  style: camelhump # 字段名风格：驼峰（与mybatis的下划线转驼峰配合）
  enable-method-cache: true # 开启方法缓存（可选）
  
# 管理端点配置
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
  endpoint:
    health:
      show-details: always

# 防火墙配置
firewall:
  enabled: true
  default-qps-limit: 100
  cache-size: 1000
  exclude-paths:
    - /firewall/**
    - /actuator/**
    - /static/**
    - /favicon.ico
```

# 核心代码

## 接口访问日志实体类

```java
package com.uhaiin.firewall.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import javax.persistence.Column;
import javax.persistence.Id;
import javax.persistence.Table;
import java.time.LocalDateTime;

/**
 * 表名：firewall_access_log
 */
@Table(name = "firewall_access_log")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FirewallAccessLog {
    /**
     * 主键ID
     */
    @Id
    @Column(name = "id")
    private Long id;

    /**
     * IP地址
     */
    @Column(name = "ip_address")
    private String ipAddress;

    /**
     * API路径
     */
    @Column(name = "api_path")
    private String apiPath;

    /**
     * User-Agent
     */
    @Column(name = "user_agent")
    private String userAgent;

    /**
     * 请求方法
     */
    @Column(name = "request_method")
    private String requestMethod;

    /**
     * 响应状态码
     */
    @Column(name = "status_code")
    private Integer statusCode;

    /**
     * 拦截原因
     */
    @Column(name = "block_reason")
    private String blockReason;

    /**
     * 请求时间
     */
    @Column(name = "request_time")
    private LocalDateTime requestTime;

    /**
     * 响应时间(毫秒)
     */
    @Column(name = "response_time")
    private Long responseTime;

    /**
     * 检查是否被拦截
     *
     * @return 是否被拦截
     */
    public boolean isBlocked() {
        return blockReason != null && !blockReason.trim().isEmpty();
    }

    /**
     * 检查是否成功响应
     *
     * @return 是否成功
     */
    public boolean isSuccess() {
        return statusCode != null && statusCode >= 200 && statusCode < 300;
    }

    /**
     * 获取响应时间描述
     *
     * @return 响应时间描述
     */
    public String getResponseTimeDescription() {
        if (responseTime == null) {
            return "未知";
        }

        if (responseTime < 100) {
            return "快速 (" + responseTime + "ms)";
        } else if (responseTime < 500) {
            return "正常 (" + responseTime + "ms)";
        } else if (responseTime < 1000) {
            return "较慢 (" + responseTime + "ms)";
        } else {
            return "缓慢 (" + responseTime + "ms)";
        }
    }

    /**
     * 获取状态描述
     *
     * @return 状态描述
     */
    public String getStatusDescription() {
        if (isBlocked()) {
            return "已拦截: " + blockReason;
        }

        if (statusCode == null) {
            return "未知";
        }

        return switch (statusCode) {
            case 200 -> "成功";
            case 400 -> "请求错误";
            case 401 -> "未授权";
            case 403 -> "禁止访问";
            case 404 -> "未找到";
            case 429 -> "请求过多";
            case 500 -> "服务器错误";
            default -> "状态码: " + statusCode;
        };
    }
}
```

## ip 黑名单实体类

```java
package com.uhaiin.firewall.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import javax.persistence.Column;
import javax.persistence.Id;
import javax.persistence.Table;
import java.time.LocalDateTime;

/**
 * 表名：firewall_blacklist
 */
@Table(name = "firewall_blacklist")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FirewallBlacklist {
    /**
     * 主键ID
     */
    @Id
    @Column(name = "id")
    private Long id;

    /**
     * IP地址
     */
    @Column(name = "ip_address")
    private String ipAddress;

    /**
     * 封禁原因
     */
    private String reason;

    /**
     * 过期时间(NULL表示永久)
     */
    @Column(name = "expire_time")
    private LocalDateTime expireTime;

    /**
     * 是否启用
     */
    private Boolean enabled;

    /**
     * 创建时间
     */
    @Column(name = "created_time")
    private LocalDateTime createdTime;

    /**
     * 更新时间
     */
    @Column(name = "updated_time")
    private LocalDateTime updatedTime;

    /**
     * 检查IP是否已过期
     *
     * @return 是否已过期
     */
    public boolean isExpired() {
        return expireTime != null && LocalDateTime.now().isAfter(expireTime);
    }

    /**
     * 检查IP是否有效（启用且未过期）
     *
     * @return 是否有效
     */
    public boolean isValid() {
        return (enabled == null || enabled) && !isExpired();
    }

    /**
     * 检查IP地址是否匹配
     *
     * @param ip 要检查的IP地址
     * @return 是否匹配
     */
    public boolean matches(String ip) {
        if (ipAddress == null || ip == null) {
            return false;
        }

        // 支持CIDR格式的IP段匹配
        if (ipAddress.contains("/")) {
            return matchesCidr(ip, ipAddress);
        }

        // 支持通配符匹配
        if (ipAddress.contains("*")) {
            String pattern = ipAddress.replace("*", ".*");
            return ip.matches(pattern);
        }

        // 精确匹配
        return ipAddress.equals(ip);
    }

    /**
     * CIDR格式IP段匹配
     *
     * @param ip   IP地址
     * @param cidr CIDR格式的IP段
     * @return 是否匹配
     */
    private boolean matchesCidr(String ip, String cidr) {
        try {
            String[] parts = cidr.split("/");
            if (parts.length != 2) {
                return false;
            }

            String networkIp = parts[0];
            int prefixLength = Integer.parseInt(parts[1]);

            // 简单的IPv4 CIDR匹配实现
            long ipLong = ipToLong(ip);
            long networkLong = ipToLong(networkIp);
            long mask = (0xFFFFFFFFL << (32 - prefixLength)) & 0xFFFFFFFFL;

            return (ipLong & mask) == (networkLong & mask);
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * IP地址转换为长整型
     *
     * @param ip IP地址
     * @return 长整型值
     */
    private long ipToLong(String ip) {
        String[] parts = ip.split("\\.");
        if (parts.length != 4) {
            throw new IllegalArgumentException("Invalid IP address: " + ip);
        }

        long result = 0;
        for (int i = 0; i < 4; i++) {
            result = (result << 8) + Integer.parseInt(parts[i]);
        }
        return result;
    }
}
```

## 规则实体类

```java
package com.uhaiin.firewall.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import javax.persistence.Column;
import javax.persistence.Id;
import javax.persistence.Table;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 表名：firewall_rule
 */
@Table(name = "firewall_rule")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FirewallRule {
    /**
     * 主键ID
     */
    @Id
    @Column(name = "id")
    private Long id;

    /**
     * 规则名称
     */
    @Column(name = "rule_name")
    private String ruleName;

    /**
     * API路径匹配模式
     */
    @Column(name = "api_pattern")
    private String apiPattern;

    /**
     * QPS限制
     */
    @Column(name = "qps_limit")
    private Integer qpsLimit;

    /**
     * 是否启用
     */
    private Boolean enabled;

    /**
     * 规则描述
     */
    private String description;

    /**
     * 创建时间
     */
    @Column(name = "created_time")
    private LocalDateTime createdTime;

    /**
     * 更新时间
     */
    @Column(name = "updated_time")
    private LocalDateTime updatedTime;

    /**
     * 黑名单IP列表（运行时使用，不存储在数据库）
     */
    private List<String> blackIps;

    /**
     * 白名单IP列表（运行时使用，不存储在数据库）
     */
    private List<String> whiteIps;

    /**
     * 检查API路径是否匹配此规则
     *
     * @param apiPath API路径
     * @return 是否匹配
     */
    public boolean matches(String apiPath) {
        if (apiPattern == null || apiPath == null) {
            return false;
        }

        // 支持通配符匹配
        String pattern = apiPattern.replace("**", ".*").replace("*", "[^/]*");
        return apiPath.matches(pattern);
    }

    /**
     * 获取有效的QPS限制
     *
     * @return QPS限制，默认100
     */
    public int getEffectiveQpsLimit() {
        return qpsLimit != null && qpsLimit > 0 ? qpsLimit : 100;
    }

    /**
     * 检查规则是否启用
     *
     * @return 是否启用，默认true
     */
    public boolean isEffectiveEnabled() {
        return enabled == null || enabled;
    }
}
```

## 接口访问统计实体类

```java
package com.uhaiin.firewall.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import javax.persistence.Column;
import javax.persistence.Id;
import javax.persistence.Table;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 表名：firewall_statistics
 */
@Table(name = "firewall_statistics")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FirewallStatistics {
    /**
     * 主键ID
     */
    @Id
    @Column(name = "id")
    private Long id;

    /**
     * 统计日期
     */
    @Column(name = "stat_date")
    private LocalDate statDate;

    /**
     * API路径
     */
    @Column(name = "api_path")
    private String apiPath;

    /**
     * 总请求数
     */
    @Column(name = "total_requests")
    private Long totalRequests;

    /**
     * 被拦截请求数
     */
    @Column(name = "blocked_requests")
    private Long blockedRequests;

    /**
     * 平均响应时间
     */
    @Column(name = "avg_response_time")
    private BigDecimal avgResponseTime;

    /**
     * 创建时间
     */
    @Column(name = "created_time")
    private LocalDateTime createdTime;

    /**
     * 更新时间
     */
    @Column(name = "updated_time")
    private LocalDateTime updatedTime;

    /**
     * 计算拦截率
     *
     * @return 拦截率（百分比）
     */
    public double getBlockRate() {
        if (totalRequests == null || totalRequests == 0) {
            return 0.0;
        }

        long blocked = blockedRequests != null ? blockedRequests : 0;
        return (double) blocked / totalRequests * 100;
    }

    /**
     * 计算成功率
     *
     * @return 成功率（百分比）
     */
    public double getSuccessRate() {
        return 100.0 - getBlockRate();
    }

    /**
     * 获取拦截率描述
     *
     * @return 拦截率描述
     */
    public String getBlockRateDescription() {
        double rate = getBlockRate();

        if (rate == 0) {
            return "无拦截";
        } else if (rate < 1) {
            return "极低 (" + String.format("%.2f", rate) + "%)";
        } else if (rate < 5) {
            return "较低 (" + String.format("%.2f", rate) + "%)";
        } else if (rate < 20) {
            return "中等 (" + String.format("%.2f", rate) + "%)";
        } else {
            return "较高 (" + String.format("%.2f", rate) + "%)";
        }
    }

    /**
     * 获取响应时间描述
     *
     * @return 响应时间描述
     */
    public String getResponseTimeDescription() {
        if (avgResponseTime == null) {
            return "未知";
        }

        double time = avgResponseTime.doubleValue();

        if (time < 100) {
            return "快速 (" + String.format("%.1f", time) + "ms)";
        } else if (time < 500) {
            return "正常 (" + String.format("%.1f", time) + "ms)";
        } else if (time < 1000) {
            return "较慢 (" + String.format("%.1f", time) + "ms)";
        } else {
            return "缓慢 (" + String.format("%.1f", time) + "ms)";
        }
    }

    /**
     * 增加请求统计
     *
     * @param isBlocked    是否被拦截
     * @param responseTime 响应时间
     */
    public void addRequest(boolean isBlocked, long responseTime) {
        // 增加总请求数
        this.totalRequests = (this.totalRequests != null ? this.totalRequests : 0) + 1;

        // 增加拦截数
        if (isBlocked) {
            this.blockedRequests = (this.blockedRequests != null ? this.blockedRequests : 0) + 1;
        }

        // 更新平均响应时间
        if (this.avgResponseTime == null) {
            this.avgResponseTime = BigDecimal.valueOf(responseTime);
        } else {
            // 计算新的平均值
            BigDecimal currentTotal = this.avgResponseTime.multiply(BigDecimal.valueOf(this.totalRequests - 1));
            BigDecimal newTotal = currentTotal.add(BigDecimal.valueOf(responseTime));
            this.avgResponseTime = newTotal.divide(BigDecimal.valueOf(this.totalRequests), 2, BigDecimal.ROUND_HALF_UP);
        }

        // 更新时间
        this.updatedTime = LocalDateTime.now();
    }
}
```

## ip 白名单实体类

```java
package com.uhaiin.firewall.entity;

import java.time.LocalDateTime;

import javax.persistence.Column;
import javax.persistence.Id;
import javax.persistence.Table;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 表名：firewall_whitelist
 */
@Table(name = "firewall_whitelist")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FirewallWhitelist {
	/**
	 * 主键ID
	 */
	@Id
	@Column(name = "id")
	private Long id;

	/**
	 * IP地址
	 */
	@Column(name = "ip_address")
	private String ipAddress;

	/**
	 * 描述
	 */
	private String description;

	/**
	 * 是否启用
	 */
	private Boolean enabled;

	/**
	 * 创建时间
	 */
	@Column(name = "created_time")
	private LocalDateTime createdTime;

	/**
	 * 更新时间
	 */
	@Column(name = "updated_time")
	private LocalDateTime updatedTime;

	/**
	 * 检查IP是否有效（启用）
	 *
	 * @return 是否有效
	 */
	public boolean isValid() {
		return enabled == null || enabled;
	}

	/**
	 * 检查IP地址是否匹配
	 *
	 * @param ip 要检查的IP地址
	 * @return 是否匹配
	 */
	public boolean matches(String ip) {
		if (ipAddress == null || ip == null) {
			return false;
		}

		// 支持CIDR格式的IP段匹配
		if (ipAddress.contains("/")) {
			return matchesCidr(ip, ipAddress);
		}

		// 支持通配符匹配
		if (ipAddress.contains("*")) {
			String pattern = ipAddress.replace("*", ".*");
			return ip.matches(pattern);
		}

		// 精确匹配
		return ipAddress.equals(ip);
	}

	/**
	 * CIDR格式IP段匹配
	 *
	 * @param ip   IP地址
	 * @param cidr CIDR格式的IP段
	 * @return 是否匹配
	 */
	private boolean matchesCidr(String ip, String cidr) {
		try {
			String[] parts = cidr.split("/");
			if (parts.length != 2) {
				return false;
			}

			String networkIp = parts[0];
			int prefixLength = Integer.parseInt(parts[1]);

			// 简单的IPv4 CIDR匹配实现
			long ipLong = ipToLong(ip);
			long networkLong = ipToLong(networkIp);
			long mask = (0xFFFFFFFFL << (32 - prefixLength)) & 0xFFFFFFFFL;

			return (ipLong & mask) == (networkLong & mask);
		} catch (Exception e) {
			return false;
		}
	}

	/**
	 * IP地址转换为长整型
	 *
	 * @param ip IP地址
	 * @return 长整型值
	 */
	private long ipToLong(String ip) {
		String[] parts = ip.split("\\.");
		if (parts.length != 4) {
			throw new IllegalArgumentException("Invalid IP address: " + ip);
		}

		long result = 0;
		for (int i = 0; i < 4; i++) {
			result = (result << 8) + Integer.parseInt(parts[i]);
		}
		return result;
	}
}
```

## mapper

> 采用通用mapper：tk.mybatis
>
> import tk.mybatis.mapper.common.Mapper;

```java
public interface FirewallAccessLogMapper extends Mapper<FirewallAccessLog> {}
public interface FirewallBlacklistMapper extends Mapper<FirewallBlacklist> {}
public interface FirewallRuleMapper extends Mapper<FirewallRule> {}
public interface FirewallStatisticsMapper extends Mapper<FirewallStatistics> {}
public interface FirewallWhitelistMapper extends Mapper<FirewallWhitelist> {}
```

## WebConfig

```java
import com.uhaiin.common.interceptor.FirewallInterceptor;
import jakarta.annotation.Resource;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.Arrays;
import java.util.List;

/**
 * Web配置类
 *
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Resource
    private FirewallInterceptor firewallInterceptor;

    @Value("${firewall.exclude-paths:/actuator/**,/static/**,/css/**,/js/**,/images/**,/favicon.ico}")
    private String excludePathsStr;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        // 解析排除路径
        List<String> excludePaths = Arrays.asList(excludePathsStr.split(","));

        registry.addInterceptor(firewallInterceptor)
                // 拦截所有请求
                .addPathPatterns("/**")
                // 排除指定路径
                .excludePathPatterns(excludePaths);
    }
}
```

## Interceptor

```java
package com.uhaiin.common.interceptor;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.common.cache.Cache;
import com.google.common.cache.CacheBuilder;
import com.uhaiin.common.utils.SnowflakeIdGenerator;
import com.uhaiin.firewall.entity.FirewallAccessLog;
import com.uhaiin.firewall.entity.FirewallRule;
import com.uhaiin.firewall.service.FirewallService;
import com.uhaiin.firewall.service.RuleManagerService;
import jakarta.annotation.Resource;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * 防火墙拦截器
 *
 */
@Slf4j
@Component
public class FirewallInterceptor implements HandlerInterceptor {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Resource
    private RuleManagerService ruleManagerService;

    @Resource
    private FirewallService firewallService;

    @Value("${firewall.enabled:false}")
    private boolean firewallEnable;

    @Value("${firewall.default.qps-limit:100}")
    private int defaultQpsLimit;

    @Value("${firewall.cache-size:10000}")
    private long maximumSize;

    /**
     * QPS限制缓存 - 存储每个IP+API的访问计数
     */
    private final Cache<String, AtomicInteger> qpsCache = CacheBuilder.newBuilder().maximumSize(maximumSize)
            .expireAfterWrite(1, TimeUnit.MINUTES).build();

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        // 设置字符集为UTF-8
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        long startTime = System.currentTimeMillis();
        String ipAddress = getClientIpAddress(request);
        String apiPath = request.getRequestURI();
        String userAgent = request.getHeader("User-Agent");
        String method = request.getMethod();

        if (!firewallEnable) {
            // 没有启用防火墙则直接返回true不拦截
            return true;
        }

        log.info("防火墙拦截检查: IP={}, API={}, Method={}", ipAddress, apiPath, method);

        try {
            // 1. 检查白名单
            if (ruleManagerService.isWhitelisted(ipAddress)) {
                log.info("IP {} 在白名单中，允许访问", ipAddress);
                logAccess(ipAddress, apiPath, userAgent, method, 200, null, startTime);
                return true;
            }

            // 2. 检查黑名单
            if (ruleManagerService.isBlacklisted(ipAddress)) {
                log.warn("IP {} 在黑名单中，拒绝访问", ipAddress);
                blockRequest(response, "IP地址被列入黑名单", 403);
                logAccess(ipAddress, apiPath, userAgent, method, 403, "IP黑名单拦截", startTime);
                return false;
            }

            // 3. 获取匹配的防火墙规则
            FirewallRule rule = ruleManagerService.getMatchingRule(apiPath);
            if (rule == null) {
                // 使用默认规则
                rule = createDefaultRule(apiPath);
            }

            // 4. QPS限制检查
            if (!checkQpsLimit(ipAddress, apiPath, rule)) {
                log.warn("IP {} 访问 {} 超过QPS限制 {}", ipAddress, apiPath, rule.getEffectiveQpsLimit());
                blockRequest(response, "访问频率过高，请稍后再试", 429);
                logAccess(ipAddress, apiPath, userAgent, method, 429, "QPS限制拦截", startTime);
                return false;
            }

            // 5. 记录正常访问
            logAccess(ipAddress, apiPath, userAgent, method, 200, null, startTime);
            log.info("IP {} 访问 {} 通过防火墙检查", ipAddress, apiPath);
            return true;

        } catch (Exception e) {
            log.error("防火墙拦截器处理异常: IP={}, API={}", ipAddress, apiPath, e);
            logAccess(ipAddress, apiPath, userAgent, method, 500, "系统异常", startTime);
            // 异常情况下允许通过，避免影响正常业务
            return true;
        }
    }

    /**
     * 检查QPS限制
     *
     * @param ipAddress IP地址
     * @param apiPath   API路径
     * @param rule      防火墙规则
     * @return 是否通过检查
     */
    private boolean checkQpsLimit(String ipAddress, String apiPath, FirewallRule rule) {
        String key = ipAddress + ":" + apiPath;
        int qpsLimit = rule.getEffectiveQpsLimit();

        if (qpsLimit <= 0) {
            // 无限制
            return true;
        }

        AtomicInteger counter = qpsCache.getIfPresent(key);
        if (counter == null) {
            counter = new AtomicInteger(0);
            qpsCache.put(key, counter);
        }

        int currentCount = counter.incrementAndGet();
        return currentCount <= qpsLimit;
    }

    /**
     * 创建默认规则
     *
     * @param apiPath API路径
     * @return 默认规则
     */
    private FirewallRule createDefaultRule(String apiPath) {
        FirewallRule rule = new FirewallRule();
        rule.setRuleName("默认规则");
        rule.setApiPattern(apiPath);
        rule.setQpsLimit(defaultQpsLimit);
        rule.setEnabled(true);
        return rule;
    }

    /**
     * 阻止请求并返回错误响应
     *
     * @param response   HTTP响应
     * @param message    错误消息
     * @param statusCode 状态码
     * @throws IOException IO异常
     */
    private void blockRequest(HttpServletResponse response, String message, int statusCode) throws IOException {
        response.setStatus(statusCode);
        response.setContentType("application/json;charset=UTF-8");

        Map<String, Object> result = new HashMap<>();
        result.put("success", false);
        result.put("code", statusCode);
        result.put("message", message);
        result.put("timestamp", System.currentTimeMillis());

        String jsonResponse = objectMapper.writeValueAsString(result);
        response.getWriter().write(jsonResponse);
        response.getWriter().flush();
    }

    /**
     * 记录访问日志
     *
     * @param ipAddress   IP地址
     * @param apiPath     API路径
     * @param userAgent   User-Agent
     * @param method      请求方法
     * @param statusCode  状态码
     * @param blockReason 拦截原因
     * @param startTime   开始时间
     */
    private void logAccess(String ipAddress, String apiPath, String userAgent, String method, int statusCode,
                           String blockReason, long startTime) {
        try {
            FirewallAccessLog accessLog = new FirewallAccessLog();
            accessLog.setId(SnowflakeIdGenerator.next());
            accessLog.setIpAddress(ipAddress);
            accessLog.setApiPath(apiPath);
            accessLog.setUserAgent(userAgent);
            accessLog.setRequestMethod(method);
            accessLog.setStatusCode(statusCode);
            accessLog.setBlockReason(blockReason);
            accessLog.setRequestTime(LocalDateTime.now());
            accessLog.setResponseTime(System.currentTimeMillis() - startTime);

            // 异步记录日志，避免影响性能
            firewallService.logAccessAsync(accessLog);

        } catch (Exception e) {
            log.error("记录访问日志失败: IP={}, API={}", ipAddress, apiPath, e);
        }
    }

    /**
     * 获取客户端真实IP地址
     *
     * @param request HTTP请求
     * @return IP地址
     */
    private String getClientIpAddress(HttpServletRequest request) {
        String[] headers = {"X-Forwarded-For", "X-Real-IP", "Proxy-Client-IP", "WL-Proxy-Client-IP",
                "HTTP_X_FORWARDED_FOR", "HTTP_X_FORWARDED", "HTTP_X_CLUSTER_CLIENT_IP", "HTTP_CLIENT_IP",
                "HTTP_FORWARDED_FOR", "HTTP_FORWARDED", "HTTP_VIA", "REMOTE_ADDR"};

        for (String header : headers) {
            String ip = request.getHeader(header);
            if (ip != null && !ip.isEmpty() && !"unknown".equalsIgnoreCase(ip)) {
                // 多个IP时取第一个
                if (ip.contains(",")) {
                    ip = ip.split(",")[0].trim();
                }
                return ip;
            }
        }

        return request.getRemoteAddr();
    }
}
```

## 实现类

> 防火墙实现类

```java
package com.uhaiin.firewall.service.impl;

import com.uhaiin.common.utils.SnowflakeIdGenerator;
import com.uhaiin.firewall.entity.FirewallAccessLog;
import com.uhaiin.firewall.entity.FirewallStatistics;
import com.uhaiin.firewall.mapper.FirewallAccessLogMapper;
import com.uhaiin.firewall.mapper.FirewallStatisticsMapper;
import com.uhaiin.firewall.service.FirewallService;
import jakarta.annotation.Resource;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tk.mybatis.mapper.entity.Example;
import tk.mybatis.mapper.entity.Example.Criteria;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Slf4j
@Service
public class FirewallServiceImpl implements FirewallService {

	@Resource
	private FirewallAccessLogMapper accessLogMapper;

	@Resource
	private FirewallStatisticsMapper statisticsMapper;

	/**
	 * 异步记录访问日志
	 *
	 * @param accessLog 访问日志
	 */
	@Override
	@Async
	@Transactional
	public void logAccessAsync(FirewallAccessLog accessLog) {
		try {
			accessLogMapper.insert(accessLog);

			// 更新统计数据
			updateStatistics(accessLog);

		} catch (Exception e) {
			log.error("异步记录访问日志失败: {}", accessLog, e);
		}
	}

	/**
	 * 更新统计数据
	 *
	 * @param accessLog 访问日志
	 */
	private void updateStatistics(FirewallAccessLog accessLog) {
		try {
			LocalDate today = LocalDate.now();
			String apiPath = accessLog.getApiPath();

			// 查询今日统计
			Example example = new Example(FirewallStatistics.class);
			Criteria criteria = example.createCriteria();
			criteria.andEqualTo("statDate", today).andEqualTo("apiPath", apiPath);
			FirewallStatistics stats = statisticsMapper.selectOneByExample(example);

			if (stats == null) {
				// 创建新的统计记录
				stats = new FirewallStatistics();
                stats.setId(SnowflakeIdGenerator.next());
				stats.setStatDate(today);
				stats.setApiPath(apiPath);
				stats.setTotalRequests(1L);
				stats.setBlockedRequests(accessLog.isBlocked() ? 1L : 0L);
				stats.setAvgResponseTime(BigDecimal.valueOf(accessLog.getResponseTime()));
				stats.setCreatedTime(LocalDateTime.now());
				stats.setUpdatedTime(LocalDateTime.now());

				statisticsMapper.insert(stats);
			} else {
				// 更新现有统计记录
				stats.addRequest(accessLog.isBlocked(), accessLog.getResponseTime());
				stats.setUpdatedTime(LocalDateTime.now());
				statisticsMapper.updateByPrimaryKeySelective(stats);
			}

		} catch (Exception e) {
			log.error("更新统计数据失败: {}", accessLog, e);
		}
	}
}
```

> 规则实现类

```java
package com.uhaiin.firewall.service.impl;

import com.uhaiin.firewall.entity.FirewallBlacklist;
import com.uhaiin.firewall.entity.FirewallRule;
import com.uhaiin.firewall.entity.FirewallWhitelist;
import com.uhaiin.firewall.mapper.FirewallBlacklistMapper;
import com.uhaiin.firewall.mapper.FirewallRuleMapper;
import com.uhaiin.firewall.mapper.FirewallWhitelistMapper;
import com.uhaiin.firewall.service.RuleManagerService;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.Resource;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import tk.mybatis.mapper.entity.Example;
import tk.mybatis.mapper.entity.Example.Criteria;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@Slf4j
@Service
public class RuleManagerServiceImpl implements RuleManagerService {
    /**
     * 规则缓存
     */
    private final Map<String, FirewallRule> ruleCache = new ConcurrentHashMap<>();
    /**
     * 黑名单缓存
     */
    private final Map<String, FirewallBlacklist> blacklistCache = new ConcurrentHashMap<>();
    /**
     * 白名单缓存
     */
    private final Map<String, FirewallWhitelist> whitelistCache = new ConcurrentHashMap<>();

    @Resource
    private FirewallRuleMapper ruleMapper;

    @Resource
    private FirewallBlacklistMapper blacklistMapper;

    @Resource
    private FirewallWhitelistMapper whitelistMapper;

    /**
     * 初始化加载规则
     */
    @PostConstruct
    public void init() {
        log.info("初始化防火墙规则管理器...");
        refreshRules();
        refreshBlacklist();
        refreshWhitelist();
        log.info("防火墙规则管理器初始化完成，加载规则: {}, 黑名单: {}, 白名单: {}", ruleCache.size(), blacklistCache.size(),
                whitelistCache.size());
    }

    /**
     * 获取匹配指定API路径的规则
     *
     * @param apiPath API路径
     * @return 匹配的规则，如果没有匹配则返回null
     */
    @Override
    public FirewallRule getMatchingRule(String apiPath) {
        if (apiPath == null) {
            return null;
        }

        // 优先精确匹配
        FirewallRule exactMatch = ruleCache.get(apiPath);
        if (exactMatch != null && exactMatch.isEffectiveEnabled()) {
            return exactMatch;
        }

        // 模式匹配
        for (FirewallRule rule : ruleCache.values()) {
            if (rule.isEffectiveEnabled() && rule.matches(apiPath)) {
                return rule;
            }
        }

        return null;
    }

    /**
     * 检查IP是否在黑名单中
     *
     * @param ipAddress IP地址
     * @return 是否在黑名单中
     */
    @Override
    public boolean isBlacklisted(String ipAddress) {
        if (ipAddress == null) {
            return false;
        }

        // 精确匹配
        FirewallBlacklist exactMatch = blacklistCache.get(ipAddress);
        if (exactMatch != null && exactMatch.isValid()) {
            return true;
        }

        // 模式匹配
        for (FirewallBlacklist blacklist : blacklistCache.values()) {
            if (blacklist.isValid() && blacklist.matches(ipAddress)) {
                return true;
            }
        }

        return false;
    }

    /**
     * 检查IP是否在白名单中
     *
     * @param ipAddress IP地址
     * @return 是否在白名单中
     */
    @Override
    public boolean isWhitelisted(String ipAddress) {
        if (ipAddress == null) {
            return false;
        }

        // 精确匹配
        FirewallWhitelist exactMatch = whitelistCache.get(ipAddress);
        if (exactMatch != null && exactMatch.isValid()) {
            return true;
        }

        // 模式匹配
        for (FirewallWhitelist whitelist : whitelistCache.values()) {
            if (whitelist.isValid() && whitelist.matches(ipAddress)) {
                return true;
            }
        }

        return false;
    }

    /**
     * 获取所有规则
     *
     * @return 规则列表
     */
    @Override
    public List<FirewallRule> getAllRules() {
        Example example = new Example(FirewallRule.class);
        example.orderBy("id").asc();
        return ruleMapper.selectByExample(example);
    }

    /**
     * 获取所有黑名单
     *
     * @return 黑名单列表
     */
    @Override
    public List<FirewallBlacklist> getAllBlacklist() {
        Example example = new Example(FirewallBlacklist.class);
        example.orderBy("id").asc();
        return blacklistMapper.selectByExample(example);
    }

    /**
     * 获取所有白名单
     *
     * @return 白名单列表
     */
    @Override
    public List<FirewallWhitelist> getAllWhitelist() {
        Example example = new Example(FirewallWhitelist.class);
        example.orderBy("id").asc();
        return whitelistMapper.selectByExample(example);
    }

    /**
     * 添加或更新规则
     *
     * @param rule 规则
     * @return 是否成功
     */
    @Override
    public boolean saveRule(FirewallRule rule) {
        try {
            if (rule.getId() == null) {
                ruleMapper.insert(rule);
            } else {
                ruleMapper.updateByPrimaryKeySelective(rule);
            }
            refreshRules();
            log.info("规则保存成功: {}", rule.getRuleName());
            return true;
        } catch (Exception e) {
            log.error("规则保存失败: {}", rule.getRuleName(), e);
            return false;
        }
    }

    /**
     * 删除规则
     *
     * @param id 规则ID
     * @return 是否成功
     */
    @Override
    public boolean deleteRule(Long id) {
        try {
            ruleMapper.deleteByPrimaryKey(id);
            refreshRules();
            log.info("规则删除成功: {}", id);
            return true;
        } catch (Exception e) {
            log.error("规则删除失败: {}", id, e);
            return false;
        }
    }

    /**
     * 添加黑名单
     *
     * @param blacklist 黑名单
     * @return 是否成功
     */
    @Override
    public boolean addBlacklist(FirewallBlacklist blacklist) {
        try {
            blacklistMapper.insert(blacklist);
            refreshBlacklist();
            log.info("黑名单添加成功: {}", blacklist.getIpAddress());
            return true;
        } catch (Exception e) {
            log.error("黑名单添加失败: {}", blacklist.getIpAddress(), e);
            return false;
        }
    }

    /**
     * 删除黑名单
     *
     * @param id 黑名单ID
     * @return 是否成功
     */
    @Override
    public boolean deleteBlacklist(Long id) {
        try {
            blacklistMapper.deleteByPrimaryKey(id);
            refreshBlacklist();
            log.info("黑名单删除成功: {}", id);
            return true;
        } catch (Exception e) {
            log.error("黑名单删除失败: {}", id, e);
            return false;
        }
    }

    /**
     * 添加白名单
     *
     * @param whitelist 白名单
     * @return 是否成功
     */
    @Override
    public boolean addWhitelist(FirewallWhitelist whitelist) {
        try {
            whitelistMapper.insert(whitelist);
            refreshWhitelist();
            log.info("白名单添加成功: {}", whitelist.getIpAddress());
            return true;
        } catch (Exception e) {
            log.error("白名单添加失败: {}", whitelist.getIpAddress(), e);
            return false;
        }
    }

    /**
     * 删除白名单
     *
     * @param id 白名单ID
     * @return 是否成功
     */
    @Override
    public boolean deleteWhitelist(Long id) {
        try {
            whitelistMapper.deleteByPrimaryKey(id);
            refreshWhitelist();
            log.info("白名单删除成功: {}", id);
            return true;
        } catch (Exception e) {
            log.error("白名单删除失败: {}", id, e);
            return false;
        }
    }

    /**
     * 更新黑名单
     *
     * @param blacklist 黑名单
     * @return 是否成功
     */
    @Override
    public boolean updateBlacklist(FirewallBlacklist blacklist) {
        try {
            blacklistMapper.updateByPrimaryKeySelective(blacklist);
            refreshBlacklist();
            log.info("黑名单更新成功: {}", blacklist.getIpAddress());
            return true;
        } catch (Exception e) {
            log.error("黑名单更新失败: {}", blacklist.getIpAddress(), e);
            return false;
        }
    }

    /**
     * 更新白名单
     *
     * @param whitelist 白名单
     * @return 是否成功
     */
    @Override
    public boolean updateWhitelist(FirewallWhitelist whitelist) {
        try {
            whitelistMapper.updateByPrimaryKeySelective(whitelist);
            refreshWhitelist();
            log.info("白名单更新成功: {}", whitelist.getIpAddress());
            return true;
        } catch (Exception e) {
            log.error("白名单更新失败: {}", whitelist.getIpAddress(), e);
            return false;
        }
    }

    /**
     * 刷新规则缓存
     */
    @Override
    public void refreshRules() {
        try {
            Example example = new Example(FirewallRule.class);
            Criteria criteria = example.createCriteria();
            criteria.andEqualTo("enabled", true);

            // 添加排序
            example.orderBy("id").asc();
            List<FirewallRule> rules = ruleMapper.selectByExample(example);
            ruleCache.clear();
            ruleCache.putAll(rules.stream().collect(Collectors.toMap(FirewallRule::getApiPattern, rule -> rule,
                    (oldBlackList, newBlackList) -> newBlackList)));
            log.debug("规则缓存刷新完成，共加载 {} 条规则", ruleCache.size());
        } catch (Exception e) {
            log.error("刷新规则缓存失败", e);
        }
    }

    /**
     * 刷新黑名单缓存
     */
    @Override
    public void refreshBlacklist() {
        try {
            Example example = new Example(FirewallBlacklist.class);
            Criteria criteria = example.createCriteria();

            criteria.andEqualTo("enabled", true).andCondition("expire_time IS NULL OR expire_time > ",
                    LocalDateTime.now());

            example.orderBy("id").asc();
            List<FirewallBlacklist> blacklists = blacklistMapper.selectByExample(example);
            blacklistCache.clear();
            blacklistCache.putAll(blacklists.stream().collect(Collectors.toMap(FirewallBlacklist::getIpAddress,
                    blacklist -> blacklist, (oldBlackList, newBlackList) -> newBlackList)));
            log.debug("黑名单缓存刷新完成，共加载 {} 条记录", blacklistCache.size());
        } catch (Exception e) {
            log.error("刷新黑名单缓存失败", e);
        }
    }

    /**
     * 刷新白名单缓存
     */
    @Override
    public void refreshWhitelist() {
        try {
            Example example = new Example(FirewallWhitelist.class);
            Criteria criteria = example.createCriteria();

            criteria.andEqualTo("enabled", true);

            example.orderBy("id").asc();
            List<FirewallWhitelist> whitelists = whitelistMapper.selectByExample(example);
            whitelistCache.clear();
            whitelistCache.putAll(whitelists.stream().collect(Collectors.toMap(FirewallWhitelist::getIpAddress,
                    whitelist -> whitelist, (oldBlackList, newBlackList) -> newBlackList)));
            log.debug("白名单缓存刷新完成，共加载 {} 条记录", whitelistCache.size());
        } catch (Exception e) {
            log.error("刷新白名单缓存失败", e);
        }
    }

}
```

## 定时任务

> 定期清理过期规则

```java
package com.uhaiin.firewall.scheduled;

import com.uhaiin.firewall.entity.FirewallAccessLog;
import com.uhaiin.firewall.entity.FirewallBlacklist;
import com.uhaiin.firewall.mapper.FirewallAccessLogMapper;
import com.uhaiin.firewall.mapper.FirewallBlacklistMapper;
import com.uhaiin.firewall.service.RuleManagerService;
import jakarta.annotation.Resource;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import tk.mybatis.mapper.entity.Example;
import tk.mybatis.mapper.entity.Example.Criteria;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Component
@Configuration
@EnableScheduling
@Slf4j
public class FirewallTask {
    @Resource
    private FirewallAccessLogMapper accessLogMapper;

    @Resource
    private RuleManagerService ruleManagerService;

    @Resource
    private FirewallBlacklistMapper firewallBlacklistMapper;

    /**
     * 定时清理旧的访问日志（每天凌晨2点执行）
     */
    @Transactional
    @Scheduled(cron = "0 0 2 * * ?")
    void cleanOldAccessLogs() {
        try {
            // 保留30天
            LocalDateTime cutoffTime = LocalDateTime.now().minusDays(30);
            Example example = new Example(FirewallAccessLog.class);
            Criteria criteria = example.createCriteria();
            criteria.andLessThan("requestTime", cutoffTime);
            int deleted = accessLogMapper.deleteByExample(example);
            log.info("清理30天前的访问日志，删除 {} 条记录", deleted);
        } catch (Exception e) {
            log.error("清理旧访问日志失败", e);
        }
    }

    /**
     * 定时清理旧的统计数据（每天凌晨3点执行）
     */
    @Transactional
    @Scheduled(cron = "0 0 3 * * ?")
    void cleanOldStatistics() {
        try {
            // 保留90天
            LocalDate cutoffDate = LocalDate.now().minusDays(90);
            Example example = new Example(FirewallAccessLog.class);
            Criteria criteria = example.createCriteria();
            criteria.andLessThan("requestTime", cutoffDate);
            int deleted = accessLogMapper.deleteByExample(example);
            log.info("清理90天前的统计数据，删除 {} 条记录", deleted);
        } catch (Exception e) {
            log.error("清理旧统计数据失败", e);
        }
    }

    /**
     * 定时刷新缓存（每5分钟）
     */
    @Scheduled(fixedRate = 5 * 60 * 1000)
    @Transactional
    public void scheduledRefresh() {
        ruleManagerService.refreshRules();
        ruleManagerService.refreshBlacklist();
        ruleManagerService.refreshWhitelist();

        // 清理过期的黑名单
        try {
            LocalDateTime now = LocalDateTime.now();
            Example example = new Example(FirewallBlacklist.class);
            Example.Criteria criteria = example.createCriteria();
            criteria.andLessThanOrEqualTo("expireTime", now);
            int cleaned = firewallBlacklistMapper.deleteByExample(example);
            if (cleaned > 0) {
                log.info("清理过期黑名单 {} 条", cleaned);
                ruleManagerService.refreshBlacklist();
            }
        } catch (Exception e) {
            log.error("清理过期黑名单失败", e);
        }
    }
}
```

## POM

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>4.0.0</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>
    <groupId>com.uhaiin</groupId>
    <artifactId>demo</artifactId>
    <version>0.0.1</version>
    <name>demo</name>
    <description>A bug in the code is worth two in the documentation</description>

    <properties>
        <java.version>21</java.version>
    </properties>
    <dependencies>
        <!--启动器-->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter</artifactId>
        </dependency>
        <!--web-->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <!-- Spring Boot Starter Actuator -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        <!--测试套件-->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <!--自动配置类-->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-autoconfigure</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-configuration-processor</artifactId>
            <optional>true</optional>
        </dependency>
        <!--预编译工具-->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
        <!--热部署工具-->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-devtools</artifactId>
            <scope>runtime</scope>
            <optional>true</optional>
        </dependency>
        <!-- PostgreSQL 驱动 -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <scope>runtime</scope>
        </dependency>
        <!--通用Mapper4之tk.mybatis-->
        <dependency>
            <groupId>tk.mybatis</groupId>
            <artifactId>mapper</artifactId>
            <version>4.3.0</version>
        </dependency>
        <!-- MyBatis Spring Boot Starter -->
        <dependency>
            <groupId>org.mybatis.spring.boot</groupId>
            <artifactId>mybatis-spring-boot-starter</artifactId>
            <version>4.0.1</version>
        </dependency>
        <!-- fastjson2 -->
        <dependency>
            <groupId>com.alibaba.fastjson2</groupId>
            <artifactId>fastjson2</artifactId>
            <version>2.0.60</version>
        </dependency>
        <!-- Jackson (JSON处理) -->
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-databind</artifactId>
        </dependency>
        <!-- Guava (限流器) -->
        <dependency>
            <groupId>com.google.guava</groupId>
            <artifactId>guava</artifactId>
            <version>33.5.0-jre</version>
            <exclusions>
                <exclusion>
                    <artifactId>checker-qual</artifactId>
                    <groupId>org.checkerframework</groupId>
                </exclusion>
            </exclusions>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <excludeDevtools>true</excludeDevtools>
                    <excludes>
                        <exclude>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                        </exclude>
                    </excludes>
                </configuration>
            </plugin>
        </plugins>
    </build>

</project>
```