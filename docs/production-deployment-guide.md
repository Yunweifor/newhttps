# NewHTTPS 生产环境部署指南

## 🎯 环境说明

**服务器配置**:
- IP地址: 8.134.166.234
- 网络限制: 仅允许外部访问80和443端口
- 无域名环境: 通过IP地址访问
- 内部端口: 无限制

## 🚀 一键部署

### 快速安装

```bash
# 克隆项目
git clone https://github.com/Yunweifor/newhttps.git
cd newhttps

# 一键安装生产环境（包含SSL证书）
./scripts/production-deploy.sh install --with-ssl

# 或者分步安装
./scripts/production-deploy.sh install    # 安装服务
./scripts/production-deploy.sh ssl        # 生成SSL证书
```

### 访问地址

安装完成后，可通过以下地址访问：

- **HTTP**: http://8.134.166.234
- **HTTPS**: https://8.134.166.234
- **API**: http://8.134.166.234/api
- **健康检查**: http://8.134.166.234/health

## 🔐 JWT_SECRET配置详解

### 1. JWT_SECRET的重要性

JWT_SECRET是系统安全的核心，用于：
- **用户身份验证** - 验证登录用户的身份
- **Agent认证** - Agent与API服务器之间的安全通信
- **会话管理** - 控制访问权限和登录状态
- **数据完整性** - 防止令牌被篡改或伪造

### 2. 生成安全的JWT密钥

```bash
# 方法一：使用OpenSSL（推荐）
openssl rand -base64 32

# 方法二：使用Node.js
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"

# 方法三：使用Python
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# 示例输出
# K8vQJ2mF9xR7nP3sL6wE1tY4uI0oA5zX2cV8bN7mQ9k=
```

### 3. 配置JWT密钥

```bash
# 生成新密钥
JWT_SECRET=$(openssl rand -base64 32)

# 编辑环境配置
vim .env

# 替换默认密钥
JWT_SECRET=K8vQJ2mF9xR7nP3sL6wE1tY4uI0oA5zX2cV8bN7mQ9k=
```

## 🌐 网络配置详解

### 1. 架构说明

```
外部访问 (80/443) → Nginx反向代理 → 内部服务
                                   ├── API服务 (3000)
                                   └── Web服务 (80)
```

### 2. 端口映射

| 外部端口 | 内部服务 | 说明 |
|----------|----------|------|
| 80 | Nginx → API(3000) + Web(80) | HTTP访问 |
| 443 | Nginx → API(3000) + Web(80) | HTTPS访问 |

### 3. 反向代理配置

Nginx配置已优化，包含：
- **API代理**: `/api/` → `newhttps-api:3000`
- **Agent专用**: `/api/agent/` → 更长超时时间
- **Web界面**: `/` → `newhttps-web:80`
- **健康检查**: `/health` → API健康检查
- **限流保护**: API和Web分别限流
- **安全头**: 完整的安全头配置

## 🔒 SSL证书配置

### 1. 自动生成SSL证书

```bash
# 生成自签名证书
./scripts/generate-ssl-cert.sh

# 自定义配置
./scripts/generate-ssl-cert.sh --ip 8.134.166.234 --days 365 --key-size 2048
```

### 2. 证书文件位置

```
ssl/
├── server.crt      # 证书文件
├── server.key      # 私钥文件
├── server.conf     # 证书配置
└── README.md       # 使用说明
```

### 3. 浏览器访问

由于是自签名证书，浏览器会显示安全警告：
1. 点击"高级"或"Advanced"
2. 点击"继续访问"或"Proceed to site"
3. 正常使用HTTPS功能

## 🤖 Agent配置

### 1. Agent配置文件

```bash
# 复制生产环境配置
cp agent/config.production.conf agent/config.conf

# 编辑配置
vim agent/config.conf
```

### 2. 关键配置项

```bash
# API服务器地址
API_ENDPOINT="http://8.134.166.234/api"

# JWT密钥（与服务器保持一致）
JWT_SECRET="K8vQJ2mF9xR7nP3sL6wE1tY4uI0oA5zX2cV8bN7mQ9k="

# Agent信息
AGENT_NAME="$(hostname)-agent"
```

### 3. Agent部署

```bash
# 在目标服务器上部署Agent
./agent/newhttps-agent.sh install

# 启动Agent
./agent/newhttps-agent.sh start

# 检查状态
./agent/newhttps-agent.sh status
```

## 🛠️ 管理操作

### 服务管理

```bash
# 查看服务状态
./scripts/production-deploy.sh status

# 启动服务
./scripts/production-deploy.sh start

# 停止服务
./scripts/production-deploy.sh stop

# 重启服务
./scripts/production-deploy.sh restart

# 查看日志
./scripts/production-deploy.sh logs
```

### 数据管理

```bash
# 备份数据
./scripts/production-deploy.sh backup

# 更新服务
./scripts/production-deploy.sh update
```

### 监控检查

```bash
# 健康检查
curl http://8.134.166.234/health

# API测试
curl http://8.134.166.234/api/health

# 服务状态
docker-compose -f docker-compose.production.yml ps

# 资源使用
docker stats
```

## 🔧 故障排除

### 常见问题

1. **服务无法启动**
   ```bash
   # 检查端口占用
   netstat -tlnp | grep -E ":(80|443)"
   
   # 检查Docker状态
   systemctl status docker
   
   # 查看详细日志
   ./scripts/production-deploy.sh logs
   ```

2. **Agent连接失败**
   ```bash
   # 检查网络连通性
   curl http://8.134.166.234/health
   
   # 检查JWT密钥是否一致
   grep JWT_SECRET .env
   grep JWT_SECRET agent/config.conf
   
   # 检查Agent日志
   tail -f /var/log/newhttps-agent.log
   ```

3. **SSL证书问题**
   ```bash
   # 重新生成证书
   ./scripts/generate-ssl-cert.sh --force
   
   # 检查证书有效性
   openssl x509 -in ssl/server.crt -text -noout
   
   # 重启Nginx
   docker-compose -f docker-compose.production.yml restart nginx-proxy
   ```

### 性能优化

1. **资源监控**
   ```bash
   # 容器资源使用
   docker stats
   
   # 系统资源
   htop
   free -h
   df -h
   ```

2. **日志管理**
   ```bash
   # 清理旧日志
   docker system prune -f
   
   # 配置日志轮转
   vim /etc/logrotate.d/newhttps
   ```

## 📋 部署检查清单

### 部署前检查

- [ ] 服务器满足最低要求（2GB内存，10GB磁盘）
- [ ] Docker和Docker Compose已安装
- [ ] 端口80和443未被占用
- [ ] 网络连接正常

### 部署后验证

- [ ] 服务正常启动：`./scripts/production-deploy.sh status`
- [ ] HTTP访问正常：`curl http://8.134.166.234`
- [ ] API接口正常：`curl http://8.134.166.234/api/health`
- [ ] HTTPS访问正常：`curl -k https://8.134.166.234`
- [ ] JWT密钥已配置且安全
- [ ] SSL证书已生成
- [ ] 数据目录权限正确

### 安全检查

- [ ] JWT_SECRET已更改为强密钥
- [ ] 备份加密密钥已配置
- [ ] SSL证书已生成
- [ ] 防火墙规则已配置
- [ ] 日志记录正常

## 🎉 部署完成

完成部署后，您的NewHTTPS系统将：

1. **通过HTTP/HTTPS访问**: http://8.134.166.234 和 https://8.134.166.234
2. **支持Agent连接**: Agent通过反向代理访问API
3. **数据持久化**: 所有数据保存在Docker卷中
4. **自动备份**: 支持数据备份和恢复
5. **监控就绪**: 健康检查和日志记录

现在您可以开始使用NewHTTPS管理SSL证书了！🚀
