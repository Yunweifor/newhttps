# NewHTTPS 单机部署指南

## 🎯 概述

本指南专为单机或小规模部署环境设计，提供了多种部署模式以适应不同的服务器配置和需求。

## 📋 系统要求

### 最低要求
- **操作系统**: Linux (Ubuntu 18.04+, CentOS 7+, Debian 9+)
- **内存**: 1GB RAM (推荐2GB+)
- **磁盘**: 5GB 可用空间
- **Docker**: 20.10+
- **Docker Compose**: 2.0+

### 推荐配置
- **内存**: 2GB+ RAM
- **CPU**: 2核心+
- **磁盘**: 10GB+ SSD
- **网络**: 稳定的互联网连接

## 🚀 快速开始

### 1. 一键安装

```bash
# 克隆项目
git clone https://github.com/Yunweifor/newhttps.git
cd newhttps

# 标准安装（推荐）
./scripts/standalone-deploy.sh install --standard

# 最小化安装（1GB内存服务器）
./scripts/standalone-deploy.sh install --minimal

# 仅API服务
./scripts/standalone-deploy.sh install --api-only
```

### 2. 自定义安装

```bash
# 自定义端口和域名
./scripts/standalone-deploy.sh install --standard \
  --domain yourdomain.com \
  --email admin@yourdomain.com \
  --port 3001 \
  --web-port 8081

# 包含Nginx反向代理
./scripts/standalone-deploy.sh install --standard --with-proxy
```

## 📦 部署模式详解

### 🏢 标准模式 (推荐)

**适用场景**: 2GB+ 内存服务器，生产环境
**配置文件**: `docker-compose.standalone.yml`

```bash
# 启动标准模式
./scripts/standalone-deploy.sh install --standard
```

**特性**:
- ✅ 完整功能 (API + Web界面)
- ✅ 健康检查和自动重启
- ✅ 数据持久化
- ✅ 日志管理
- ✅ 备份支持

### 💡 最小化模式

**适用场景**: 1GB 内存VPS，测试环境
**配置文件**: `docker-compose.minimal.yml`

```bash
# 启动最小化模式
./scripts/standalone-deploy.sh install --minimal
```

**特性**:
- ✅ 资源限制 (API: 256MB, Web: 64MB)
- ✅ 优化的健康检查频率
- ✅ 减少日志输出
- ✅ 基础功能完整

### 🔧 API专用模式

**适用场景**: 仅需要API服务，集成到现有系统
**配置文件**: `docker-compose.simple.yml`

```bash
# 启动API专用模式
./scripts/standalone-deploy.sh install --api-only
```

**特性**:
- ✅ 仅API服务
- ✅ 最小资源占用
- ✅ 适合微服务架构
- ✅ RESTful API完整功能

## 🛠️ 管理操作

### 服务管理

```bash
# 查看服务状态
./scripts/standalone-deploy.sh status

# 启动服务
./scripts/standalone-deploy.sh start

# 停止服务
./scripts/standalone-deploy.sh stop

# 重启服务
./scripts/standalone-deploy.sh restart

# 查看日志
./scripts/standalone-deploy.sh logs
```

### 数据管理

```bash
# 备份数据
./scripts/standalone-deploy.sh backup

# 使用Make命令（如果可用）
make backup
make status
make logs
```

### 更新服务

```bash
# 拉取最新代码
git pull origin main

# 重新构建并重启
./scripts/standalone-deploy.sh restart
```

## 🔧 配置优化

### 环境变量配置

编辑 `.env` 文件进行自定义配置：

```bash
# 基础配置
NODE_ENV=production
API_PORT=3000
WEB_PORT=8080

# 安全配置
JWT_SECRET=your-super-secret-key
CORS_ORIGIN=https://yourdomain.com

# 性能配置
RATE_LIMIT_MAX_REQUESTS=100
UPLOAD_MAX_SIZE=10485760

# SSL配置
DOMAIN=yourdomain.com
EMAIL=admin@yourdomain.com
```

### 资源限制调整

对于不同规格的服务器，可以调整资源限制：

```yaml
# 在docker-compose文件中调整
deploy:
  resources:
    limits:
      memory: 512M  # 根据服务器内存调整
      cpus: '1.0'   # 根据CPU核心数调整
```

### Nginx配置优化

如果使用反向代理，可以优化Nginx配置：

```nginx
# nginx/nginx.standalone.conf
worker_processes auto;
worker_connections 1024;

# 根据服务器性能调整
client_max_body_size 10M;
keepalive_timeout 65;
```

## 🔒 安全建议

### 1. 修改默认密钥

```bash
# 生成强密钥
openssl rand -base64 32

# 更新.env文件
JWT_SECRET=生成的密钥
```

### 2. 配置防火墙

```bash
# Ubuntu/Debian
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS
sudo ufw allow 3000  # API (如果直接暴露)
sudo ufw enable

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
```

### 3. SSL证书配置

```bash
# 使用Let's Encrypt
sudo apt install certbot
sudo certbot certonly --standalone -d yourdomain.com

# 配置证书路径
SSL_CERT_PATH=/etc/letsencrypt/live/yourdomain.com
```

## 📊 监控和维护

### 资源监控

```bash
# 查看容器资源使用
docker stats

# 查看系统资源
htop
df -h
free -h
```

### 日志管理

```bash
# 查看实时日志
docker-compose -f docker-compose.standalone.yml logs -f

# 查看特定服务日志
docker-compose -f docker-compose.standalone.yml logs newhttps-api

# 清理旧日志
docker system prune -f
```

### 定期维护

```bash
# 创建定期备份脚本
cat > /etc/cron.daily/newhttps-backup << 'EOF'
#!/bin/bash
cd /path/to/newhttps
./scripts/standalone-deploy.sh backup
# 清理30天前的备份
find backups/ -name "*.tar.gz" -mtime +30 -delete
EOF

chmod +x /etc/cron.daily/newhttps-backup
```

## 🚨 故障排除

### 常见问题

1. **服务无法启动**
   ```bash
   # 检查端口占用
   netstat -tlnp | grep :3000
   
   # 检查Docker状态
   sudo systemctl status docker
   
   # 查看详细错误
   docker-compose logs
   ```

2. **内存不足**
   ```bash
   # 切换到最小化模式
   ./scripts/standalone-deploy.sh stop
   ./scripts/standalone-deploy.sh install --minimal
   ```

3. **磁盘空间不足**
   ```bash
   # 清理Docker资源
   docker system prune -a
   
   # 清理日志
   sudo journalctl --vacuum-time=7d
   ```

### 性能优化

1. **数据库优化**
   - 定期清理过期数据
   - 优化SQLite配置
   - 考虑使用SSD存储

2. **网络优化**
   - 配置CDN加速静态资源
   - 启用Gzip压缩
   - 优化Nginx配置

## 📈 扩展建议

### 水平扩展

当单机性能不足时，可以考虑：

1. **负载均衡**: 使用Nginx或HAProxy
2. **数据库分离**: 使用外部数据库
3. **缓存层**: 添加Redis缓存
4. **CDN**: 静态资源CDN加速

### 高可用部署

1. **多实例部署**: 在多台服务器部署
2. **数据同步**: 配置数据库主从复制
3. **健康检查**: 配置外部监控
4. **自动故障转移**: 使用Keepalived等工具

这个单机部署指南为NewHTTPS项目提供了完整的部署解决方案，适用于各种规模的服务器环境。
