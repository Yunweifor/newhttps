# NewHTTPS Docker 部署指南

## 概述

NewHTTPS 提供了完善的 Docker 部署方案，支持两种部署模式：

1. **独立模式**（推荐）：完全自包含的 SSL 证书管理系统
2. **集成模式**：与 Certd-2 集成的完整解决方案

## 系统要求

- Docker 20.10+
- Docker Compose 2.0+ 或 docker-compose 1.29+
- 至少 2GB RAM
- 至少 5GB 磁盘空间

## 快速开始

### 方法一：使用快速启动脚本（推荐）

```bash
# 克隆项目
git clone https://github.com/your-repo/newhttps.git
cd newhttps

# 启动独立模式
chmod +x docker-start.sh
./docker-start.sh --standalone

# 查看状态
./docker-start.sh --status
```

### 方法二：手动启动

```bash
# 独立模式
docker-compose -f docker-compose.standalone.yml up -d

# 集成模式（包含 Certd-2）
docker-compose up -d
```

## 部署模式详解

### 独立模式

独立模式包含以下服务：

```yaml
services:
  - newhttps-api     # API 服务（端口 3000）
  - newhttps-web     # Web 界面
  - nginx            # 反向代理（端口 80/443）
  - redis            # 缓存服务（可选）
```

**访问地址：**
- Web 界面: http://localhost
- API 接口: http://localhost/api
- 健康检查: http://localhost/health

### 集成模式

集成模式额外包含：

```yaml
services:
  - certd           # Certd-2 服务（端口 7001）
```

**访问地址：**
- NewHTTPS Web: http://localhost
- Certd-2 Web: http://localhost:7001
- API 接口: http://localhost/api

## 配置说明

### 环境变量配置

主要配置文件：
- `api/.env` - API 服务配置
- `web/.env.local` - Web 界面配置
- `.env.docker` - Docker 环境模板

#### API 配置示例

```bash
# api/.env
PORT=3000
NODE_ENV=production
STANDALONE_MODE=true
ENABLE_CERT_APPLY=true

# JWT 配置
JWT_SECRET=your-super-secret-key

# 数据库配置
DATABASE_PATH=/app/data/newhttps.db

# ACME 配置
DEFAULT_CA=letsencrypt
DEFAULT_EMAIL=admin@yourdomain.com

# 安全配置
ENABLE_RATE_LIMITING=true
CORS_ORIGIN=*
```

#### Web 配置示例

```bash
# web/.env.local
VUE_APP_API_BASE_URL=/api
VUE_APP_MODE=standalone
VUE_APP_ENABLE_CERT_APPLY=true
```

### 数据持久化

重要的数据目录：

```
data/
├── newhttps/          # 数据库和应用数据
├── acme/              # ACME 账户信息
├── certificates/      # 证书文件
└── acme-challenges/   # HTTP-01 验证文件

logs/                  # 应用日志
ssl/                   # SSL 证书（生产环境）
```

## 管理命令

### 使用快速启动脚本

```bash
# 启动服务
./docker-start.sh --standalone

# 查看状态
./docker-start.sh --status

# 查看日志
./docker-start.sh --logs

# 重启服务
./docker-start.sh --restart

# 停止服务
./docker-start.sh --stop

# 清理数据（危险）
./docker-start.sh --clean
```

### 使用 Docker Compose

```bash
# 启动服务
docker-compose -f docker-compose.standalone.yml up -d

# 查看状态
docker-compose -f docker-compose.standalone.yml ps

# 查看日志
docker-compose -f docker-compose.standalone.yml logs -f

# 停止服务
docker-compose -f docker-compose.standalone.yml down

# 重建服务
docker-compose -f docker-compose.standalone.yml up -d --build
```

## 生产环境部署

### 1. 安全配置

```bash
# 修改默认密钥
sed -i 's/your-super-secret-key/$(openssl rand -base64 32)/' api/.env

# 设置正确的域名
sed -i 's/localhost/yourdomain.com/' api/.env
```

### 2. SSL 证书配置

```bash
# 创建 SSL 证书目录
mkdir -p ssl

# 复制证书文件
cp your-cert.pem ssl/cert.pem
cp your-key.pem ssl/key.pem

# 更新 nginx 配置启用 HTTPS
# 编辑 nginx/nginx.standalone.conf
```

### 3. 反向代理配置

如果使用外部反向代理（如 Cloudflare、AWS ALB），需要：

```yaml
# docker-compose.override.yml
version: '3.8'
services:
  nginx:
    ports:
      - "127.0.0.1:8080:80"  # 仅本地访问
```

### 4. 资源限制

```yaml
# docker-compose.override.yml
version: '3.8'
services:
  newhttps-api:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 256M
          cpus: '0.25'
```

## 监控和维护

### 健康检查

```bash
# API 健康检查
curl http://localhost/health

# 容器健康状态
docker ps --filter "name=newhttps"

# 服务日志
docker logs newhttps-api
```

### 备份和恢复

```bash
# 备份数据
tar -czf newhttps-backup-$(date +%Y%m%d).tar.gz data/ logs/

# 恢复数据
tar -xzf newhttps-backup-20240101.tar.gz
```

### 更新升级

```bash
# 拉取最新代码
git pull

# 重建并启动
./docker-start.sh --restart
```

## 故障排除

### 常见问题

1. **端口冲突**
   ```bash
   # 检查端口占用
   netstat -tlnp | grep :80
   
   # 修改端口映射
   # 编辑 docker-compose.standalone.yml
   ```

2. **容器启动失败**
   ```bash
   # 查看详细日志
   docker logs newhttps-api
   
   # 检查配置文件
   docker exec newhttps-api cat /app/.env
   ```

3. **数据库连接失败**
   ```bash
   # 检查数据目录权限
   ls -la data/
   
   # 重新创建数据库
   docker exec newhttps-api rm -f /app/data/newhttps.db
   docker restart newhttps-api
   ```

4. **证书申请失败**
   ```bash
   # 检查 ACME 挑战文件
   ls -la data/acme-challenges/
   
   # 测试域名解析
   nslookup yourdomain.com
   
   # 检查防火墙
   curl -I http://yourdomain.com/.well-known/acme-challenge/test
   ```

### 调试模式

```bash
# 启用调试日志
echo "LOG_LEVEL=DEBUG" >> api/.env

# 重启服务
docker restart newhttps-api

# 查看详细日志
docker logs -f newhttps-api
```

## 性能优化

### 1. 资源配置

```yaml
# 生产环境推荐配置
services:
  newhttps-api:
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '1.0'
  
  redis:
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.5'
```

### 2. 缓存配置

```bash
# 启用 Redis 缓存
echo "REDIS_URL=redis://redis:6379" >> api/.env
echo "ENABLE_CACHE=true" >> api/.env
```

### 3. 数据库优化

```bash
# 使用外部数据库（生产环境推荐）
echo "DATABASE_URL=postgresql://user:pass@host:5432/newhttps" >> api/.env
```

## 安全最佳实践

1. **定期更新镜像**
2. **使用强密码和密钥**
3. **限制网络访问**
4. **启用 HTTPS**
5. **定期备份数据**
6. **监控系统日志**

## 总结

Docker 部署方式提供了：
- ✅ 快速部署和启动
- ✅ 环境一致性
- ✅ 易于扩展和维护
- ✅ 完整的服务编排
- ✅ 生产环境就绪

通过合理的配置和监控，可以实现稳定可靠的 SSL 证书自动化管理服务。
