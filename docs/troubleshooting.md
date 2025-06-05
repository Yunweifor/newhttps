# NewHTTPS 故障排除指南

本指南帮助您解决NewHTTPS部署和使用过程中可能遇到的常见问题。

## 🚀 部署问题

### Docker相关问题

#### 1. Docker Compose版本不兼容
```bash
# 错误信息
ERROR: Version in "./docker-compose.yml" is unsupported

# 解决方案
# 安装最新版本的Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

#### 2. 端口冲突
```bash
# 错误信息
Error starting userland proxy: listen tcp 0.0.0.0:3000: bind: address already in use

# 检查端口占用
netstat -tlnp | grep :3000
lsof -i :3000

# 解决方案1: 停止占用端口的服务
sudo systemctl stop service-name

# 解决方案2: 修改端口配置
vim .env
# 修改 API_PORT=3001
```

#### 3. 权限问题
```bash
# 错误信息
Permission denied

# 解决方案
sudo chown -R 1001:1001 data/
sudo chmod -R 755 data/
```

### 构建问题

#### 1. TypeScript编译错误
```bash
# 错误信息
TypeScript compilation failed

# 解决方案
cd api
npm install
npm run build

# 或者
cd web
npm install
npm run build
```

#### 2. 依赖安装失败
```bash
# 错误信息
npm ERR! network timeout

# 解决方案
# 使用国内镜像
npm config set registry https://registry.npmmirror.com
npm install
```

## 🔧 服务运行问题

### API服务问题

#### 1. API服务无法启动
```bash
# 检查日志
docker-compose logs newhttps-api

# 常见原因和解决方案
# 1. 数据库连接失败
mkdir -p data/newhttps
sudo chown -R 1001:1001 data/

# 2. 环境变量配置错误
cp .env.example .env
vim .env  # 检查配置
```

#### 2. 健康检查失败
```bash
# 检查API健康状态
curl http://localhost:3000/health

# 如果无响应，检查服务状态
docker-compose ps
docker-compose logs newhttps-api
```

### Web界面问题

#### 1. Web界面无法访问
```bash
# 检查Web服务状态
curl -I http://localhost:8080

# 检查Nginx配置
docker-compose logs newhttps-web
```

#### 2. 页面加载错误
```bash
# 检查浏览器控制台错误
# 常见问题：API地址配置错误

# 检查代理配置
docker-compose logs newhttps-nginx
```

## 🤖 Agent问题

### Agent安装问题

#### 1. 下载失败
```bash
# 错误信息
wget: unable to resolve host address

# 解决方案
# 检查网络连接
ping github.com

# 使用代理下载
wget --proxy=http://proxy:port https://raw.githubusercontent.com/Yunweifor/newhttps/main/agent/newhttps-agent.sh
```

#### 2. 权限不足
```bash
# 错误信息
Permission denied

# 解决方案
sudo chmod +x newhttps-agent.sh
sudo ./newhttps-agent.sh --install
```

### Agent运行问题

#### 1. 无法连接API服务器
```bash
# 检查网络连接
curl -I https://your-server.com:3000/health

# 检查防火墙
sudo ufw status
sudo firewall-cmd --list-all

# 检查API Token
./newhttps-agent.sh --config
```

#### 2. Nginx配置检测失败
```bash
# 检查Nginx状态
systemctl status nginx

# 检查配置语法
nginx -t

# 检查配置文件权限
ls -la /etc/nginx/
```

#### 3. 证书部署失败
```bash
# 查看Agent日志
./newhttps-agent.sh --logs
tail -f /var/log/newhttps-agent.log

# 手动回滚
./newhttps-agent.sh --rollback

# 重新配置
./newhttps-agent.sh --config
```

## 🔍 诊断工具

### 系统诊断脚本

创建诊断脚本 `diagnose.sh`：

```bash
#!/bin/bash
echo "=== NewHTTPS 系统诊断 ==="

echo "1. Docker状态:"
docker --version
docker-compose --version

echo "2. 服务状态:"
docker-compose ps

echo "3. 端口检查:"
netstat -tlnp | grep -E ":(3000|8080|80|443)"

echo "4. 磁盘空间:"
df -h

echo "5. 内存使用:"
free -h

echo "6. API健康检查:"
curl -s http://localhost:3000/health || echo "API不可访问"

echo "7. Web界面检查:"
curl -s -I http://localhost:8080 | head -1 || echo "Web界面不可访问"
```

### 日志收集

```bash
# 收集所有日志
mkdir -p /tmp/newhttps-logs
docker-compose logs > /tmp/newhttps-logs/docker-compose.log
cp .env /tmp/newhttps-logs/env.log
cp -r data/ /tmp/newhttps-logs/data-backup/
tar -czf newhttps-logs.tar.gz /tmp/newhttps-logs/
```

## 🛠️ 性能优化

### 1. 内存优化
```bash
# 限制容器内存使用
# 在docker-compose.yml中添加：
services:
  newhttps-api:
    mem_limit: 512m
  newhttps-web:
    mem_limit: 256m
```

### 2. 磁盘优化
```bash
# 清理Docker镜像
docker system prune -a

# 清理日志文件
sudo truncate -s 0 /var/log/newhttps-agent.log
```

### 3. 网络优化
```bash
# 使用本地DNS缓存
echo "nameserver 127.0.0.1" > /etc/resolv.conf
```

## 📞 获取帮助

### 1. 查看日志
```bash
# Docker服务日志
docker-compose logs -f

# Agent日志
tail -f /var/log/newhttps-agent.log

# 系统日志
journalctl -u docker
```

### 2. 社区支持
- GitHub Issues: https://github.com/Yunweifor/newhttps/issues
- 讨论区: https://github.com/Yunweifor/newhttps/discussions

### 3. 提交Bug报告

提交Bug时请包含：
1. 错误信息和日志
2. 系统环境信息
3. 复现步骤
4. 配置文件（去除敏感信息）

---

**如果本指南没有解决您的问题，请在GitHub上提交Issue，我们会尽快帮助您解决！** 🚀
