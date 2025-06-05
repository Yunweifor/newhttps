# NewHTTPS - Docker 部署指南

NewHTTPS 是一个现代化的 SSL 证书自动化管理平台，专为简化 HTTPS 证书的申请、部署和续期而设计。

## 🌟 特性

- **自动化证书管理** - 支持 Let's Encrypt、ZeroSSL 等多种 CA
- **智能部署** - 自动部署证书到 Nginx、Apache 等 Web 服务器
- **多服务器支持** - 通过 Agent 管理多台服务器的证书
- **Web 管理界面** - 直观的 Vue.js 前端界面
- **RESTful API** - 完整的 API 接口，支持第三方集成
- **实时监控** - 证书状态监控和到期提醒
- **安全可靠** - JWT 认证、权限控制、数据加密

## 🚀 快速开始

### 系统要求

- Docker 20.10+
- Docker Compose 2.0+
- 2GB+ 内存
- 10GB+ 磁盘空间

### 一键部署

```bash
# 克隆项目
git clone https://github.com/your-username/newhttps.git
cd newhttps

# 完整部署（API + Web界面）
./docker-deploy.sh

# 或仅部署API服务
./docker-deploy.sh --api-only
```

### 手动部署

```bash
# 1. 复制环境配置
cp .env.example .env

# 2. 编辑配置文件
vim .env

# 3. 启动完整服务（API + Web + Nginx）
docker-compose up -d

# 或启动仅API服务
docker-compose -f docker-compose.simple.yml up -d
```

## 📁 项目结构

```
newhttps/
├── api/                    # API 服务
│   ├── src/               # 源代码
│   ├── Dockerfile         # API Docker 配置
│   └── package.json       # 依赖配置
├── web/                   # Web 界面
│   ├── src/               # Vue.js 源代码
│   ├── Dockerfile         # Web Docker 配置
│   └── package.json       # 依赖配置
├── nginx/                 # Nginx 配置
│   └── nginx.conf         # 反向代理配置
├── docker-compose.yml     # 完整服务配置
├── docker-compose.simple.yml  # 仅API配置
├── docker-deploy.sh       # 部署脚本
└── .env.example          # 环境配置模板
```

## 🔧 配置说明

### 环境变量

编辑 `.env` 文件配置系统参数：

```bash
# JWT密钥（必须修改）
JWT_SECRET=your-super-secret-jwt-key

# 端口配置
API_PORT=3000
WEB_PORT=8080

# 数据库配置
DB_PATH=/app/data/newhttps.db

# 日志配置
LOG_LEVEL=info
```

### 服务配置

- **API 服务**: `http://localhost:3000`
- **Web 界面**: `http://localhost:8080`
- **Nginx 代理**: `http://localhost:80`

## 📊 管理命令

```bash
# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 重启服务
docker-compose restart

# 停止服务
docker-compose down

# 更新服务
docker-compose pull
docker-compose up -d
```

## 🔍 故障排除

### 常见问题

1. **端口冲突**
   ```bash
   # 检查端口占用
   netstat -tlnp | grep :3000
   
   # 修改 .env 文件中的端口配置
   ```

2. **权限问题**
   ```bash
   # 检查数据目录权限
   ls -la data/
   
   # 修复权限
   sudo chown -R 1001:1001 data/
   ```

3. **服务启动失败**
   ```bash
   # 查看详细日志
   docker-compose logs newhttps-api
   
   # 重新构建镜像
   docker-compose build --no-cache
   ```

## 📚 API 文档

API 服务启动后，访问以下地址查看文档：

- **健康检查**: `http://localhost:3000/health`
- **API 文档**: `http://localhost:3000/api/docs`

## 🛡️ 安全建议

1. **修改默认密钥**
   ```bash
   # 生成随机JWT密钥
   openssl rand -base64 32
   ```

2. **使用HTTPS**
   - 配置SSL证书
   - 启用HTTPS重定向

3. **网络安全**
   - 配置防火墙
   - 限制访问IP

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件
