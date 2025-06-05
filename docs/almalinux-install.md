# NewHTTPS 在 AlimaLinux 9 上的安装指南

本指南专门针对 AlimaLinux 9 系统，提供详细的安装步骤和故障排除方法。

## 📋 系统要求

### 最低要求
- **操作系统**: AlimaLinux 9.x
- **内存**: 1GB RAM
- **磁盘空间**: 2GB 可用空间
- **网络**: 互联网连接（用于下载依赖）
- **权限**: root 或 sudo 权限

### 推荐配置
- **内存**: 2GB+ RAM
- **磁盘空间**: 5GB+ 可用空间
- **CPU**: 2+ 核心

## 🚀 快速安装

### 1. 下载项目
```bash
# 使用 git 克隆（推荐）
git clone https://github.com/your-repo/newhttps.git
cd newhttps

# 或者下载压缩包
wget https://github.com/your-repo/newhttps/archive/main.zip
unzip main.zip
cd newhttps-main
```

### 2. 运行安装前检查
```bash
chmod +x pre-install-check.sh
sudo ./pre-install-check.sh
```

### 3. 执行安装
```bash
chmod +x standalone-install.sh
sudo ./standalone-install.sh
```

## 📝 详细安装步骤

### 步骤 1: 系统准备

#### 更新系统
```bash
sudo dnf update -y
```

#### 安装基础工具
```bash
sudo dnf install -y curl wget tar unzip openssl git
```

#### 配置防火墙
```bash
# 开放必要端口
sudo firewall-cmd --permanent --add-port=3000/tcp  # API 端口
sudo firewall-cmd --permanent --add-port=8080/tcp  # Web 端口
sudo firewall-cmd --reload

# 验证端口开放
sudo firewall-cmd --list-ports
```

### 步骤 2: 安装 Node.js 18

#### 方法 1: 使用 NodeSource 仓库（推荐）
```bash
# 添加 NodeSource 仓库
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -

# 安装 Node.js
sudo dnf install -y nodejs

# 验证安装
node --version  # 应该显示 v18.x.x
npm --version
```

#### 方法 2: 使用 dnf 模块
```bash
# 查看可用的 Node.js 版本
sudo dnf module list nodejs

# 安装 Node.js 18
sudo dnf module install -y nodejs:18/common

# 验证安装
node --version
npm --version
```

### 步骤 3: 运行安装脚本

#### 下载并运行安装前检查
```bash
chmod +x pre-install-check.sh
sudo ./pre-install-check.sh
```

#### 运行主安装脚本
```bash
chmod +x standalone-install.sh
sudo ./standalone-install.sh
```

### 步骤 4: 验证安装

#### 检查服务状态
```bash
# 检查服务是否运行
sudo systemctl status newhttps-api
sudo systemctl status newhttps-web

# 检查服务日志
sudo journalctl -u newhttps-api -f
sudo journalctl -u newhttps-web -f
```

#### 测试 API 连接
```bash
# 健康检查
curl http://localhost:3000/health

# 预期响应
{"status":"ok","timestamp":"2024-01-01T00:00:00.000Z"}
```

#### 访问 Web 界面
打开浏览器访问: `http://your-server-ip:8080`

## 🔧 配置说明

### 配置文件位置
- **API 配置**: `/opt/newhttps/config/api.env`
- **Web 配置**: `/opt/newhttps/config/web.env`
- **数据目录**: `/opt/newhttps/data/`
- **日志目录**: `/opt/newhttps/logs/`

### 重要配置项

#### API 配置 (`/opt/newhttps/config/api.env`)
```bash
# 端口配置
PORT=3000

# 数据库路径
DATABASE_PATH=/opt/newhttps/data/newhttps.db

# ACME 配置
ACME_DATA_DIR=/opt/newhttps/data/acme
DEFAULT_CA=letsencrypt
DEFAULT_EMAIL=your-email@domain.com

# 证书存储
CERT_STORAGE_DIR=/opt/newhttps/data/certificates
```

#### Web 配置 (`/opt/newhttps/config/web.env`)
```bash
# API 地址
VUE_APP_API_BASE_URL=http://localhost:3000

# 功能开关
VUE_APP_ENABLE_CERT_APPLY=true
VUE_APP_ENABLE_AGENT_MANAGEMENT=true
```

## 🛠️ 常见问题排除

### 问题 1: Node.js 版本过低
```bash
# 错误信息
[ERROR] 需要 Node.js 18.0 或更高版本，当前版本: v16.x.x

# 解决方案
sudo dnf module reset nodejs
sudo dnf module install nodejs:18/common
```

### 问题 2: 端口被占用
```bash
# 检查端口占用
sudo ss -tuln | grep :3000
sudo ss -tuln | grep :8080

# 查找占用进程
sudo lsof -i :3000
sudo lsof -i :8080

# 修改端口（编辑配置文件）
sudo nano /opt/newhttps/config/api.env
# 修改 PORT=3001

sudo nano /opt/newhttps/config/web.env
# 修改 VUE_APP_API_BASE_URL=http://localhost:3001
```

### 问题 3: 服务启动失败
```bash
# 查看详细错误日志
sudo journalctl -u newhttps-api -n 50
sudo journalctl -u newhttps-web -n 50

# 检查文件权限
sudo ls -la /opt/newhttps/
sudo chown -R newhttps:newhttps /opt/newhttps/

# 重启服务
sudo systemctl restart newhttps-api
sudo systemctl restart newhttps-web
```

### 问题 4: 防火墙阻止访问
```bash
# 检查防火墙状态
sudo firewall-cmd --state

# 检查开放的端口
sudo firewall-cmd --list-ports

# 重新开放端口
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

### 问题 5: SELinux 问题
```bash
# 检查 SELinux 状态
getenforce

# 临时禁用 SELinux（仅用于测试）
sudo setenforce 0

# 永久配置 SELinux（推荐）
sudo setsebool -P httpd_can_network_connect 1
sudo setsebool -P httpd_can_network_relay 1
```

## 📊 性能优化

### 系统优化
```bash
# 增加文件描述符限制
echo "newhttps soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "newhttps hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# 优化内核参数
echo "net.core.somaxconn = 65535" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 65535" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 服务优化
```bash
# 编辑 systemd 服务文件
sudo systemctl edit newhttps-api

# 添加以下内容
[Service]
LimitNOFILE=65536
Environment=NODE_ENV=production
Environment=UV_THREADPOOL_SIZE=16
```

## 🔄 管理命令

### 服务管理
```bash
# 启动服务
sudo systemctl start newhttps-api newhttps-web

# 停止服务
sudo systemctl stop newhttps-api newhttps-web

# 重启服务
sudo systemctl restart newhttps-api newhttps-web

# 查看状态
sudo systemctl status newhttps-api newhttps-web

# 开机自启
sudo systemctl enable newhttps-api newhttps-web
```

### 日志管理
```bash
# 实时查看日志
sudo journalctl -u newhttps-api -f
sudo journalctl -u newhttps-web -f

# 查看最近日志
sudo journalctl -u newhttps-api -n 100
sudo journalctl -u newhttps-web -n 100

# 清理旧日志
sudo journalctl --vacuum-time=7d
```

### 备份和恢复
```bash
# 备份数据
sudo tar -czf newhttps-backup-$(date +%Y%m%d).tar.gz /opt/newhttps/data/

# 恢复数据
sudo systemctl stop newhttps-api newhttps-web
sudo tar -xzf newhttps-backup-20240101.tar.gz -C /
sudo chown -R newhttps:newhttps /opt/newhttps/data/
sudo systemctl start newhttps-api newhttps-web
```

## 📞 获取帮助

如果遇到问题，请：

1. 查看日志文件: `sudo journalctl -u newhttps-api -n 100`
2. 检查配置文件: `/opt/newhttps/config/`
3. 验证网络连接: `curl http://localhost:3000/health`
4. 查看系统资源: `top`, `df -h`, `free -h`

更多帮助请参考：
- [安装指南](install.md)
- [使用指南](usage.md)
- [故障排除](troubleshooting.md)
