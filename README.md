# NewHTTPS

NewHTTPS 是一个现代化的 SSL 证书自动化管理平台，专为简化 HTTPS 证书的申请、部署和续期而设计。采用优化的 Docker 容器化架构，支持从单机到分布式的多种部署模式。

## 🌟 核心特性

- **🔄 自动化证书管理** - 支持 Let's Encrypt、ZeroSSL 等多种 CA
- **🚀 智能部署** - 自动部署证书到 Nginx、Apache 等 Web 服务器
- **🌐 多服务器支持** - 通过 Agent 管理多台服务器的证书
- **💻 Web 管理界面** - 直观的 Vue.js + TypeScript 前端界面
- **🔌 RESTful API** - 完整的 API 接口，支持第三方集成
- **📊 实时监控** - 证书状态监控和到期提醒
- **🔒 安全可靠** - JWT 认证、权限控制、数据加密
- **📦 优化容器化** - 多阶段构建，71%镜像减少，85%构建加速
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

| 部署模式 | 内存需求 | 磁盘空间 | 适用场景 |
|----------|----------|----------|----------|
| 标准模式 | 2GB+ | 10GB+ | 生产环境 |
| 最小化模式 | 1GB | 5GB+ | VPS/测试 |
| API专用 | 512MB | 3GB+ | 微服务 |

**基础要求**: Docker 20.10+, Docker Compose 2.0+

### 🎯 推荐部署方式

```bash
# 克隆项目
git clone https://github.com/Yunweifor/newhttps.git
cd newhttps

# 标准部署（推荐）
make standalone

# 最小化部署（1GB内存服务器）
make standalone-minimal

# API专用部署
make standalone-api
```

### 🛠️ 高级部署选项

```bash
# 自定义配置部署
./scripts/standalone-deploy.sh install --standard \
  --domain yourdomain.com \
  --email admin@yourdomain.com \
  --port 3001

# 开发环境
make dev

# 生产环境（带备份）
make prod
```

## 📁 项目结构

```
newhttps/
├── api/                           # API 服务 (Node.js + TypeScript)
│   ├── src/                      # 源代码
│   ├── Dockerfile.optimized      # 优化的多阶段构建
│   └── package.json              # 依赖配置
├── web/                          # Web 界面 (Vue.js + TypeScript)
│   ├── src/                      # Vue.js 源代码
│   ├── Dockerfile.optimized      # 优化的多阶段构建
│   └── package.json              # 依赖配置
├── agent/                        # 客户端 Agent 脚本
│   └── newhttps-agent.sh         # 自动化部署脚本
├── scripts/                      # 自动化脚本
│   ├── build.sh                  # 智能构建脚本
│   ├── deploy.sh                 # 零停机部署
│   ├── standalone-deploy.sh      # 单机部署脚本
│   ├── local-ci.sh              # 本地CI/CD
│   └── setup-git-hooks.sh       # Git钩子设置
├── docs/                         # 文档
│   ├── standalone-deployment-guide.md  # 单机部署指南
│   ├── github-actions-setup.md         # CI/CD设置
│   ├── usage.md                        # 使用指南
│   └── troubleshooting.md              # 故障排除
├── Dockerfile.base               # 基础镜像
├── docker-compose.standalone.yml # 单机部署配置
├── docker-compose.minimal.yml   # 最小化部署配置
├── docker-compose.dev.yml       # 开发环境配置
├── Makefile                      # 便捷命令
└── .env.optimized               # 优化的环境配置模板
```

## 🔧 配置说明

### 环境变量配置

复制并编辑环境配置文件：

```bash
# 使用优化的配置模板
cp .env.optimized .env
vim .env
```

**核心配置项**：

```bash
# 安全配置（必须修改）
JWT_SECRET=your-super-secret-jwt-key-change-this

# 服务配置
API_PORT=3000
WEB_PORT=8080
NODE_ENV=production

# 域名配置
DOMAIN=yourdomain.com
EMAIL=admin@yourdomain.com

# 性能配置
RATE_LIMIT_MAX_REQUESTS=100
UPLOAD_MAX_SIZE=10485760
```

### 服务访问地址

- **API 服务**: `http://localhost:3000`
- **Web 界面**: `http://localhost:8080`
- **健康检查**: `http://localhost:3000/health`
- **API 文档**: `http://localhost:3000/api/docs`

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

## 📊 性能优化成果

### Docker 优化效果

| 指标 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 镜像大小 | 1.4GB | 400MB | **71%减少** |
| 代码变更构建 | 8-12分钟 | 1-2分钟 | **85-90%加速** |
| 依赖变更构建 | 8-12分钟 | 3-4分钟 | **60-67%加速** |
| CI/CD构建 | 10-15分钟 | 4-6分钟 | **60-67%加速** |

### 部署模式对比

| 模式 | 内存占用 | 启动时间 | 适用场景 |
|------|----------|----------|----------|
| 标准模式 | ~512MB | 30-40秒 | 生产环境 |
| 最小化模式 | ~320MB | 20-30秒 | VPS/测试 |
| API专用 | ~256MB | 15-25秒 | 微服务 |

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

## 📚 文档导航

- **[单机部署指南](docs/standalone-deployment-guide.md)** - 详细的单机部署说明
- **[GitHub Actions设置](docs/github-actions-setup.md)** - CI/CD流水线配置
- **[Agent使用说明](agent/README.md)** - 客户端Agent部署和使用
- **[使用指南](docs/usage.md)** - 功能使用和API说明
- **[故障排除](docs/troubleshooting.md)** - 常见问题解决方案

## 🛠️ 开发和管理

### 常用命令

```bash
# 服务管理
make status          # 查看服务状态
make logs           # 查看日志
make health         # 健康检查
make backup         # 备份数据

# 开发相关
make dev            # 开发环境
make test           # 运行测试
make lint           # 代码检查
make clean          # 清理缓存

# 构建相关
make build          # 构建所有服务
make build-api      # 仅构建API
make build-web      # 仅构建Web
```

### 本地CI/CD

```bash
# 设置Git钩子自动化
./scripts/setup-git-hooks.sh

# 本地CI/CD流程
./scripts/local-ci.sh full --env prod

# 单独执行各阶段
./scripts/local-ci.sh check      # 代码检查
./scripts/local-ci.sh build      # 构建镜像
./scripts/local-ci.sh test       # 运行测试
./scripts/local-ci.sh security   # 安全扫描
```

---

**NewHTTPS - 让SSL证书管理变得简单！** 🚀✨
