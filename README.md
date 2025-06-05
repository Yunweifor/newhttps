# NewHTTPS - 独立SSL证书自动化管理系统

## 项目概述

NewHTTPS 是一个**完全独立**的SSL证书自动化管理系统，融合了优秀开源项目的核心思想：
- 借鉴 **Certd-2** 的证书申请和管理理念
- 采用 **httpsok.sh** 的可靠本地部署机制
- 提供完整的独立解决方案，无需依赖外部系统

### 核心特性

1. **独立证书申请**: 内置完整的 ACME 客户端
   - 支持 Let's Encrypt、ZeroSSL、Google Trust Services 等多个 CA 机构
   - 支持 DNS-01、HTTP-01 验证方式
   - 支持通配符域名和多域名证书
   - 无需依赖 Docker 或外部 Certd-2 实例

2. **可靠本地部署**: 基于 httpsok.sh 的部署机制
   - 自动检测 Nginx 配置
   - 智能证书文件替换
   - 自动 Nginx 重载
   - 完整的备份和恢复机制

3. **灵活部署架构**:
   - **独立模式**：完全自包含的证书管理系统
   - **集成模式**：可选择与现有 Certd-2 集成
   - **混合模式**：支持多种部署策略

## 架构设计

### 方案一：完全独立部署（推荐）
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  NewHTTPS Web   │    │  NewHTTPS API   │    │ Local Agent     │
│  证书管理界面    │◄──►│  证书申请+管理   │◄──►│ 本地部署代理     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                                               ┌─────────────────┐
                                               │  Nginx Server   │
                                               │  目标服务器     │
                                               └─────────────────┘
```

### 方案二：与现有 Certd-2 集成
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Certd-2 Web   │    │  NewHTTPS API   │    │ Local Agent     │
│   管理界面       │◄──►│   中间层        │◄──►│ 本地部署代理     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                                               ┌─────────────────┐
                                               │  Nginx Server   │
                                               │  目标服务器     │
                                               └─────────────────┘
```

## 目录结构

```
newhttps/
├── README.md                 # 项目说明
├── api/                      # API 中间层
│   ├── src/
│   │   ├── controllers/      # 控制器
│   │   ├── services/         # 业务逻辑
│   │   └── models/           # 数据模型
│   └── package.json
├── agent/                    # 本地部署代理
│   ├── newhttps-agent.sh     # 主要脚本
│   ├── config/               # 配置文件
│   └── utils/                # 工具函数
├── plugins/                  # Certd-2 插件扩展
│   └── newhttps-deploy/      # 新的部署插件
└── docs/                     # 文档
    ├── install.md            # 安装指南
    ├── config.md             # 配置说明
    └── api.md                # API 文档
```

## 工作流程

1. **证书申请阶段**:
   - 用户在 Certd-2 Web 界面创建证书申请流水线
   - 系统自动申请证书并存储

2. **证书分发阶段**:
   - NewHTTPS API 提供证书下载接口
   - 本地 Agent 定期检查证书更新

3. **证书部署阶段**:
   - Agent 下载新证书
   - 自动检测 Nginx 配置
   - 备份旧证书并替换新证书
   - 测试配置并重载 Nginx

## 快速开始

### 方法一：独立安装（推荐用于生产环境）

适用于 AlimaLinux 9、CentOS、RHEL 等 Linux 系统：

```bash
# 克隆项目
git clone https://github.com/your-repo/newhttps.git
cd newhttps

# 运行安装前检查（推荐）
chmod +x pre-install-check.sh
sudo ./pre-install-check.sh

# 运行独立安装脚本（需要 root 权限）
chmod +x standalone-install.sh
sudo ./standalone-install.sh
```

> 📋 **AlimaLinux 9 用户**: 请参考 [AlimaLinux 安装指南](docs/almalinux-install.md) 获取详细的安装步骤和故障排除方法。

### 方法二：手动安装

#### 1. 安装 Certd-2 (如果还没有)
```bash
# 使用 Docker 安装 Certd-2
docker run -d --name certd \
  -p 7001:7001 \
  -v /data/certd:/app/data \
  registry.cn-shenzhen.aliyuncs.com/handsfree/certd:latest
```

#### 2. 部署 NewHTTPS API
```bash
cd newhttps/api
npm install
npm run build
npm start
```

#### 3. 安装本地 Agent
```bash
cd newhttps/agent
chmod +x newhttps-agent.sh
./newhttps-agent.sh --install
./newhttps-agent.sh --config
```

### 方法三：Docker Compose 部署

#### 快速启动（推荐）
```bash
# 克隆项目
git clone https://github.com/your-repo/newhttps.git
cd newhttps

# 使用快速启动脚本
chmod +x docker-start.sh
./docker-start.sh --standalone
```

#### 手动启动
```bash
# 独立模式（推荐）
docker-compose -f docker-compose.standalone.yml up -d

# 集成模式（与 Certd-2 集成）
docker-compose up -d
```

## 配置说明

详细配置说明请参考 [配置文档](docs/config.md)

## 贡献指南

欢迎提交 Issue 和 Pull Request 来改进项目。

## 许可证

本项目采用 MIT 许可证。
