# NewHTTPS 部署指南

## 🚀 快速部署

### 一键部署

```bash
# 克隆项目
git clone https://github.com/Yunweifor/newhttps.git
cd newhttps

# 选择部署模式
make standalone          # 标准部署（推荐）
make standalone-minimal  # 最小化部署（1GB内存）
make standalone-api      # API专用部署
```

### 自定义部署

```bash
# 自定义配置
./scripts/standalone-deploy.sh install --standard \
  --domain yourdomain.com \
  --email admin@yourdomain.com \
  --port 3001 \
  --web-port 8081

# 包含Nginx代理
./scripts/standalone-deploy.sh install --standard --with-proxy
```

## 📋 部署模式

| 模式 | 内存需求 | 适用场景 | 命令 |
|------|----------|----------|------|
| 标准模式 | 2GB+ | 生产环境 | `make standalone` |
| 最小化模式 | 1GB | VPS/测试 | `make standalone-minimal` |
| API专用 | 512MB | 微服务 | `make standalone-api` |
| 开发模式 | 2GB+ | 开发调试 | `make dev` |

## 🔧 管理命令

### 服务管理

```bash
# 查看状态
./scripts/standalone-deploy.sh status
make status

# 启动/停止/重启
./scripts/standalone-deploy.sh start
./scripts/standalone-deploy.sh stop
./scripts/standalone-deploy.sh restart

# 查看日志
./scripts/standalone-deploy.sh logs
make logs
```

### 数据管理

```bash
# 备份数据
./scripts/standalone-deploy.sh backup
make backup

# 更新服务
git pull origin main
./scripts/standalone-deploy.sh restart
```

## ⚙️ 配置

### 环境配置

```bash
# 复制配置模板
cp .env.optimized .env

# 编辑配置
vim .env
```

**必须修改的配置**：

```bash
# 安全密钥（必须修改）
JWT_SECRET=your-super-secret-jwt-key

# 域名配置
DOMAIN=yourdomain.com
EMAIL=admin@yourdomain.com

# 端口配置（如有冲突）
API_PORT=3000
WEB_PORT=8080
```

### 资源限制

根据服务器配置调整资源限制：

```yaml
# 在docker-compose文件中
deploy:
  resources:
    limits:
      memory: 512M    # 根据服务器内存调整
      cpus: '1.0'     # 根据CPU核心数调整
```

## 🔒 安全配置

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
sudo ufw allow 22     # SSH
sudo ufw allow 80     # HTTP
sudo ufw allow 443    # HTTPS
sudo ufw allow 3000   # API（如果直接暴露）
sudo ufw enable
```

### 3. SSL证书

```bash
# 使用Let's Encrypt
sudo apt install certbot
sudo certbot certonly --standalone -d yourdomain.com
```

## 📊 监控

### 资源监控

```bash
# 查看容器资源使用
docker stats

# 查看服务状态
make status

# 健康检查
make health
```

### 日志管理

```bash
# 实时日志
make logs

# 特定服务日志
docker-compose logs newhttps-api
docker-compose logs newhttps-web
```

## 🚨 故障排除

### 常见问题

1. **端口冲突**
   ```bash
   # 检查端口占用
   netstat -tlnp | grep :3000
   
   # 修改端口配置
   vim .env  # 修改API_PORT和WEB_PORT
   ```

2. **内存不足**
   ```bash
   # 切换到最小化模式
   make standalone-minimal
   ```

3. **服务无法启动**
   ```bash
   # 查看详细日志
   make logs
   
   # 检查Docker状态
   sudo systemctl status docker
   ```

### 性能优化

1. **清理资源**
   ```bash
   # 清理Docker资源
   make clean
   
   # 清理系统日志
   sudo journalctl --vacuum-time=7d
   ```

2. **数据库优化**
   - 定期清理过期数据
   - 使用SSD存储
   - 优化SQLite配置

## 📈 扩展

### 水平扩展

当单机性能不足时：

1. **负载均衡** - 使用Nginx或HAProxy
2. **数据库分离** - 使用外部数据库
3. **缓存层** - 添加Redis缓存
4. **CDN加速** - 静态资源CDN

### 高可用

1. **多实例部署** - 多台服务器部署
2. **数据同步** - 数据库主从复制
3. **健康检查** - 外部监控
4. **自动故障转移** - Keepalived等工具

## 🔗 相关文档

- [详细部署指南](docs/standalone-deployment-guide.md)
- [GitHub Actions设置](docs/github-actions-setup.md)
- [使用指南](docs/usage.md)
- [故障排除](docs/troubleshooting.md)

---

**快速开始**: `git clone && cd newhttps && make standalone` 🚀
