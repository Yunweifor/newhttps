# NewHTTPS 独立部署指南

## 概述

NewHTTPS 支持完全独立部署，无需依赖任何外部系统（如 Certd-2 或 Docker）。这种部署方式提供了最大的灵活性和控制权。

## 为什么选择独立部署？

### 1. 避免 Docker 依赖问题
- **版本滞后**：Docker 镜像可能不包含最新功能
- **资源占用**：避免不必要的容器开销
- **部署复杂性**：简化部署流程

### 2. 完全控制
- **源码级控制**：可以查看和修改所有代码
- **配置灵活**：完全自定义配置
- **性能优化**：针对特定环境优化

### 3. 生产环境友好
- **稳定性**：避免外部依赖的不稳定性
- **安全性**：减少攻击面
- **维护性**：更容易维护和升级

## 独立部署架构

```
┌─────────────────────────────────────────────────────────────┐
│                    NewHTTPS 独立系统                         │
├─────────────────┬─────────────────┬─────────────────────────┤
│  NewHTTPS Web   │  NewHTTPS API   │    Certificate Store    │
│   前端界面       │   后端服务       │      证书存储           │
├─────────────────┼─────────────────┼─────────────────────────┤
│  - Vue 3        │  - Node.js      │    - SQLite 数据库      │
│  - Ant Design   │  - TypeScript   │    - 文件系统存储       │
│  - 证书管理界面  │  - ACME 客户端   │    - 自动备份           │
└─────────────────┴─────────────────┴─────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   本地 Agent 网络                            │
├─────────────────┬─────────────────┬─────────────────────────┤
│   Server 1      │   Server 2      │      Server N           │
│  Agent + Nginx  │  Agent + Nginx  │   Agent + Nginx         │
└─────────────────┴─────────────────┴─────────────────────────┘
```

## 快速开始

### 1. 系统要求

**服务端（NewHTTPS 主服务）：**
- Node.js 18.0+
- 操作系统：Linux（推荐 Ubuntu 18.04+、CentOS 7+）
- 内存：至少 1GB RAM
- 磁盘：至少 5GB 可用空间
- 系统工具：curl、openssl、git

**客户端（Agent 服务器）：**
- Linux 系统（推荐 Ubuntu 18.04+、CentOS 7+）
- Nginx 已安装并运行
- 系统工具：curl 或 wget、openssl、jq
- cron 服务
- 网络：能够访问 NewHTTPS API 服务器

### 2. 安装前检查

在开始安装前，请确保系统满足要求：

```bash
# 检查 Node.js 版本
node --version  # 应该 >= 18.0.0

# 检查系统工具
which curl openssl git

# 检查可用磁盘空间
df -h

# 检查内存
free -h

# 检查端口占用
netstat -tlnp | grep -E ':(3000|8080) '
```

### 3. 一键安装

```bash
# 克隆项目
git clone https://github.com/your-repo/newhttps.git
cd newhttps

# 运行独立部署脚本（需要 root 权限）
chmod +x standalone-install.sh
sudo ./standalone-install.sh
```

**注意事项：**
- 安装过程需要 root 权限来创建系统用户和服务
- 确保端口 3000 和 8080 未被占用
- 安装过程中会自动下载和编译依赖，需要网络连接

### 3. 手动安装

#### 步骤 1：安装 NewHTTPS API 服务

```bash
# 进入 API 目录
cd newhttps/api

# 安装依赖
npm install

# 配置环境变量
cp .env.example .env
nano .env  # 编辑配置文件

# 构建项目
npm run build

# 启动服务
npm start
```

#### 步骤 2：安装 NewHTTPS Web 界面

```bash
# 进入 Web 目录
cd newhttps/web

# 安装依赖
npm install

# 配置 API 地址
echo "VUE_APP_API_BASE_URL=http://localhost:3000" > .env.local

# 构建项目
npm run build

# 启动服务（开发模式）
npm run dev

# 或者使用 nginx 部署生产版本
# 将 dist 目录内容复制到 nginx 网站根目录
```

#### 步骤 3：安装 Agent

```bash
# 在目标服务器上下载 Agent
wget https://raw.githubusercontent.com/your-repo/newhttps/main/agent/newhttps-agent.sh
chmod +x newhttps-agent.sh

# 安装 Agent
./newhttps-agent.sh --install

# 配置 Agent
./newhttps-agent.sh --config
# 输入 API 地址：http://your-api-server:3000
# 输入 API Token（可选）
```

## 配置说明

### API 服务配置 (.env)

```bash
# 基本配置
PORT=3000
NODE_ENV=production

# 独立模式配置
STANDALONE_MODE=true
ENABLE_CERT_APPLY=true
ENABLE_WEB_INTERFACE=true

# JWT 认证
JWT_SECRET=your-super-secret-key-change-this

# 数据库配置
DATABASE_PATH=./data/newhttps.db

# ACME 配置
ACME_DATA_DIR=./data/acme
DEFAULT_CA=letsencrypt
DEFAULT_EMAIL=admin@yourdomain.com

# 证书存储
CERT_STORAGE_DIR=./data/certificates
ENABLE_AUTO_BACKUP=true
BACKUP_RETENTION_DAYS=30

# 安全配置
ENABLE_RATE_LIMITING=true
MAX_REQUESTS_PER_HOUR=100
ENABLE_CORS=true
CORS_ORIGIN=http://localhost:8080

# 通知配置
ENABLE_EMAIL_NOTIFICATIONS=false
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=

# 监控配置
ENABLE_METRICS=true
METRICS_PORT=9090
```

### Web 界面配置 (.env.local)

```bash
# API 服务地址
VUE_APP_API_BASE_URL=http://localhost:3000

# 应用模式
VUE_APP_MODE=standalone

# 功能开关
VUE_APP_ENABLE_CERT_APPLY=true
VUE_APP_ENABLE_AGENT_MANAGEMENT=true
VUE_APP_ENABLE_MONITORING=true

# 主题配置
VUE_APP_DEFAULT_THEME=light
VUE_APP_ENABLE_DARK_MODE=true

# 调试配置
VUE_APP_DEBUG=false
VUE_APP_LOG_LEVEL=info
```

### Agent 配置 (~/.newhttps/config)

```bash
# NewHTTPS API 配置
NEWHTTPS_API_URL="http://your-api-server:3000"
NEWHTTPS_AGENT_ID="auto-generated-id"
NEWHTTPS_TOKEN=""

# 检查配置
CHECK_INTERVAL=3600  # 1小时检查一次
RETRY_COUNT=3
RETRY_DELAY=60

# Nginx 配置
NGINX_BIN="nginx"
NGINX_CONFIG="/etc/nginx/nginx.conf"
NGINX_CONFIG_HOME="/etc/nginx"

# 证书配置
CERT_BACKUP_ENABLED=true
CERT_BACKUP_DIR="$HOME/.newhttps/backups"
CERT_TEST_ENABLED=true

# 日志配置
LOG_LEVEL="INFO"
LOG_FILE="$HOME/.newhttps/newhttps-agent.log"
LOG_ROTATION=true
LOG_MAX_SIZE="10M"
```

## 证书申请流程

### 1. 通过 Web 界面申请

1. 访问 NewHTTPS Web 界面
2. 登录系统（默认：admin/admin123）
3. 进入"证书管理"页面
4. 点击"申请新证书"
5. 填写域名信息和验证方式
6. 提交申请并等待完成

### 2. 通过 API 申请

```bash
# 申请证书
curl -X POST http://localhost:3000/api/v1/certificates \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-token" \
  -d '{
    "domains": ["example.com", "www.example.com"],
    "ca": "letsencrypt",
    "email": "admin@example.com",
    "challengeType": "http-01",
    "autoRenew": true
  }'
```

### 3. 自动部署

证书申请成功后，Agent 会自动：
1. 检测到新证书
2. 下载证书文件
3. 备份现有证书
4. 部署新证书
5. 测试 Nginx 配置
6. 重载 Nginx 服务

## 监控和维护

### 1. 系统监控

```bash
# 检查 API 服务状态
curl http://localhost:3000/health

# 检查 Agent 状态
./newhttps-agent.sh --status

# 查看系统日志
tail -f logs/newhttps-api.log
tail -f ~/.newhttps/newhttps-agent.log
```

### 2. 证书监控

```bash
# 检查即将过期的证书
curl http://localhost:3000/api/v1/certificates/expiring

# 手动触发续期检查
curl -X POST http://localhost:3000/api/v1/certificates/check-renewals
```

### 3. 备份和恢复

```bash
# 备份数据
tar -czf newhttps-backup-$(date +%Y%m%d).tar.gz \
  data/ logs/ api/.env web/.env.local

# 恢复数据
tar -xzf newhttps-backup-20240101.tar.gz
```

## 生产环境部署

### 1. 使用 PM2 管理进程

```bash
# 安装 PM2
npm install -g pm2

# 启动 API 服务
cd newhttps/api
pm2 start npm --name "newhttps-api" -- start

# 启动 Web 服务（如果需要）
cd newhttps/web
pm2 start npm --name "newhttps-web" -- run serve

# 保存 PM2 配置
pm2 save
pm2 startup
```

### 2. 使用 Nginx 反向代理

```nginx
# /etc/nginx/sites-available/newhttps
server {
    listen 80;
    server_name your-domain.com;
    
    # ACME 挑战
    location /.well-known/acme-challenge/ {
        root /var/www/acme-challenges;
    }
    
    # API 代理
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Web 界面
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 3. 设置系统服务

```bash
# 创建 systemd 服务文件
sudo tee /etc/systemd/system/newhttps.service > /dev/null <<EOF
[Unit]
Description=NewHTTPS SSL Certificate Management
After=network.target

[Service]
Type=simple
User=newhttps
WorkingDirectory=/opt/newhttps/api
ExecStart=/bin/bash -lc '/usr/bin/node dist/index.js'
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
sudo systemctl enable newhttps
sudo systemctl start newhttps
```

## 故障排除

### 安装问题

1. **安装脚本失败**
   ```bash
   # 检查系统要求
   ./diagnose.sh

   # 查看详细错误
   sudo ./standalone-install.sh 2>&1 | tee install.log

   # 手动修复安装
   sudo ./fix-install.sh
   ```

2. **依赖安装失败**
   ```bash
   # 检查 Node.js 版本
   node --version

   # 清理 npm 缓存
   npm cache clean --force

   # 手动安装依赖
   cd /opt/newhttps/api
   sudo -u newhttps bash -lc 'npm install'
   ```

3. **权限问题**
   ```bash
   # 修复文件权限
   sudo chown -R newhttps:newhttps /opt/newhttps
   sudo chmod -R 755 /opt/newhttps
   ```

### 运行时问题

1. **API 服务无法启动**
   ```bash
   # 检查服务状态
   systemctl status newhttps-api

   # 查看详细日志
   journalctl -u newhttps-api -f

   # 检查端口占用
   netstat -tlnp | grep :3000

   # 检查配置文件
   cat /opt/newhttps/config/api.env
   ```

2. **证书申请失败**
   ```bash
   # 检查域名解析
   nslookup yourdomain.com

   # 检查防火墙
   ufw status
   iptables -L

   # 测试 ACME 挑战
   curl -I http://yourdomain.com/.well-known/acme-challenge/test

   # 查看 ACME 日志
   tail -f /opt/newhttps/logs/api.log | grep -i acme
   ```

3. **Agent 连接失败**
   ```bash
   # 检查 Agent 状态
   ./newhttps-agent.sh --status

   # 测试网络连接
   curl -I http://your-api-server:3000/health

   # 检查 Agent 配置
   cat ~/.newhttps/config

   # 查看 Agent 日志
   tail -f ~/.newhttps/newhttps-agent.log
   ```

4. **Web 界面无法访问**
   ```bash
   # 检查 Web 服务
   systemctl status newhttps-web

   # 检查端口
   netstat -tlnp | grep :8080

   # 测试本地访问
   curl -I http://localhost:8080
   ```

### 性能问题

1. **内存不足**
   ```bash
   # 检查内存使用
   free -h
   ps aux | grep node

   # 优化 Node.js 内存
   export NODE_OPTIONS="--max-old-space-size=512"
   systemctl restart newhttps-api
   ```

2. **磁盘空间不足**
   ```bash
   # 检查磁盘使用
   df -h
   du -sh /opt/newhttps/*

   # 清理日志
   sudo journalctl --vacuum-time=7d
   find /opt/newhttps/logs -name "*.log" -mtime +7 -delete
   ```

### 数据恢复

1. **数据库损坏**
   ```bash
   # 备份当前数据库
   cp /opt/newhttps/data/newhttps.db /opt/newhttps/data/newhttps.db.backup

   # 检查数据库完整性
   sqlite3 /opt/newhttps/data/newhttps.db "PRAGMA integrity_check;"

   # 重建数据库（如果必要）
   rm /opt/newhttps/data/newhttps.db
   systemctl restart newhttps-api
   ```

2. **配置文件丢失**
   ```bash
   # 重新生成配置
   sudo ./fix-install.sh

   # 或手动创建配置
   sudo mkdir -p /opt/newhttps/config
   sudo cp api/.env.example /opt/newhttps/config/api.env
   sudo chown newhttps:newhttps /opt/newhttps/config/api.env
   ```

### 获取帮助

1. **收集诊断信息**
   ```bash
   # 运行诊断脚本
   ./diagnose.sh > diagnostic-report.txt

   # 收集日志
   sudo journalctl -u newhttps-api --since "1 hour ago" > api-logs.txt
   sudo journalctl -u newhttps-web --since "1 hour ago" > web-logs.txt
   ```

2. **联系支持**
   - 查看日志文件获取详细错误信息
   - 访问项目 GitHub 页面提交 Issue
   - 参考完整文档：[docs/](../docs/)
   - 提供诊断报告和相关日志

## 总结

独立部署模式为 NewHTTPS 提供了最大的灵活性和控制权，特别适合：

- 不想依赖 Docker 的环境
- 需要完全控制系统的场景
- 生产环境部署
- 需要自定义功能的情况

通过独立部署，你可以获得一个完整、可靠、易维护的SSL证书自动化管理系统。
