# NewHTTPS

NewHTTPS 是一个现代化的 SSL 证书自动化管理平台，专为简化 HTTPS 证书的申请、部署和续期而设计。采用纯 Docker 容器化架构，支持分布式多服务器证书管理。

## 🌟 核心特性

- **🔄 自动化证书管理** - 支持 Let's Encrypt、ZeroSSL 等多种 CA
- **🚀 智能部署** - 自动部署证书到 Nginx、Apache 等 Web 服务器
- **🌐 多服务器支持** - 通过 Agent 管理多台服务器的证书
- **💻 Web 管理界面** - 直观的 Vue.js + TypeScript 前端界面
- **🔌 RESTful API** - 完整的 API 接口，支持第三方集成
- **📊 实时监控** - 证书状态监控和到期提醒
- **🔒 安全可靠** - JWT 认证、权限控制、数据加密
- **📦 容器化部署** - 纯 Docker 架构，一键部署
- **🔍 自动发现** - Agent 自动检测 SSL 证书配置
- **⚡ 零停机更新** - 热重载 Web 服务器，不影响业务

## 🏗️ 系统架构

```
┌─────────────────────────────────┐    ┌──────────────────────────────┐
│        服务端 (Docker)           │    │        客户端服务器           │
│                                │    │                             │
│  ┌─────────────────────────────┐ │    │  ┌─────────────────────────┐  │
│  │ NewHTTPS API (Port 3000)   │ │◄───┤  │ newhttps-agent.sh       │  │
│  │ - 证书管理API               │ │    │  │ - 自动检测Nginx配置      │  │
│  │ - Agent通信接口             │ │    │  │ - 检测SSL证书路径        │  │
│  │ - 健康检查 /health          │ │    │  │ - 与API通信检查更新      │  │
│  └─────────────────────────────┘ │    │  │ - 自动下载部署新证书     │  │
│                                │    │  └─────────────────────────┘  │
│  ┌─────────────────────────────┐ │    │                             │
│  │ Web UI (Port 8080)         │ │    │  ┌─────────────────────────┐  │
│  │ - Vue.js管理界面            │ │    │  │ Nginx + SSL证书         │  │
│  │ - 证书可视化管理            │ │    │  │ - 自动续期               │  │
│  └─────────────────────────────┘ │    │  │ - 零停机更新             │  │
│                                │    │  └─────────────────────────┘  │
│  ┌─────────────────────────────┐ │    └──────────────────────────────┘
│  │ Nginx Proxy (Port 80)      │ │
│  │ - 反向代理                  │ │    ┌──────────────────────────────┐
│  │ - 负载均衡                  │ │    │        更多客户端服务器       │
│  └─────────────────────────────┘ │    │                             │
└─────────────────────────────────┘    │  Agent + Apache/Nginx...    │
                                      └──────────────────────────────┘
```

## 🚀 快速开始

### 系统要求

- **Docker** 20.10+
- **Docker Compose** 2.0+
- **内存** 2GB+
- **磁盘** 10GB+

### 一键部署

```bash
# 克隆项目
git clone https://github.com/Yunweifor/newhttps.git
cd newhttps

# 完整部署（API + Web界面 + Nginx）
./docker-deploy.sh

# 或仅部署API服务
./docker-deploy.sh --api-only

# 快速开始
./quick-start.sh
```

### 手动部署

```bash
# 1. 复制环境配置
cp .env.example .env

# 2. 编辑配置文件（可选）
vim .env

# 3. 启动完整服务
docker-compose up -d

# 或启动仅API服务
docker-compose -f docker-compose.simple.yml up -d
```

## 📁 项目结构

```
newhttps/
├── api/                    # API 服务 (Node.js + TypeScript)
│   ├── src/               # 源代码
│   ├── Dockerfile         # API Docker 配置
│   └── package.json       # 依赖配置
├── web/                   # Web 界面 (Vue.js + TypeScript)
│   ├── src/               # Vue.js 源代码
│   ├── Dockerfile         # Web Docker 配置
│   └── package.json       # 依赖配置
├── agent/                 # 客户端 Agent 脚本
│   └── newhttps-agent.sh  # 自动化部署脚本
├── nginx/                 # Nginx 配置
│   └── nginx.conf         # 反向代理配置
├── docker-compose.yml     # 完整服务配置
├── docker-compose.simple.yml  # 仅API配置
├── docker-deploy.sh       # 专业部署脚本
├── quick-start.sh         # 快速开始脚本
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
- **健康检查**: `http://localhost:3000/health`

## 🤖 Agent 部署

在需要管理SSL证书的服务器上安装Agent：

```bash
# 下载Agent脚本
wget https://raw.githubusercontent.com/Yunweifor/newhttps/main/agent/newhttps-agent.sh
chmod +x newhttps-agent.sh

# 安装Agent
./newhttps-agent.sh --install

# 配置API连接
./newhttps-agent.sh --config

# 设置定时任务
./newhttps-agent.sh --cron
```

### Agent 功能

- **🔍 自动发现**: 自动检测Nginx配置和SSL证书路径
- **📡 API通信**: 与NewHTTPS API通信检查证书更新
- **📜 证书管理**: 自动下载、验证和部署新证书
- **🔄 安全部署**: 备份旧证书、原子性替换、自动回滚
- **⏰ 定时任务**: 支持cron定时执行，随机化避免并发

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
git pull
docker-compose build --no-cache
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

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request 来改进项目！

1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 创建 Pull Request

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🔗 相关链接

- [Docker 部署指南](README.docker.md)
- [Agent 使用说明](agent/README.md)
- [API 接口文档](docs/api.md)
- [故障排除指南](docs/troubleshooting.md)

---

**NewHTTPS - 让SSL证书管理变得简单！** 🚀✨
