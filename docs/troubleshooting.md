# NewHTTPS 故障排除指南

本文档提供常见问题的解决方案和调试方法。

## 🔍 诊断工具

### 快速诊断脚本
```bash
# 检查服务状态
sudo systemctl status newhttps-api newhttps-web

# 检查端口监听
sudo ss -tuln | grep -E ':(3000|8080)'

# 检查进程
ps aux | grep -E '(node|newhttps)'

# 检查日志
sudo journalctl -u newhttps-api -n 20
sudo journalctl -u newhttps-web -n 20
```

### 健康检查
```bash
# API 健康检查
curl -v http://localhost:3000/health

# 预期响应
HTTP/1.1 200 OK
{"status":"ok","timestamp":"2024-01-01T00:00:00.000Z"}
```

## 🚨 常见问题

### 1. 安装问题

#### 问题：Node.js 版本不兼容
```
[ERROR] 需要 Node.js 18.0 或更高版本，当前版本: v16.x.x
```

**解决方案**：
```bash
# AlimaLinux/CentOS/RHEL
sudo dnf module reset nodejs
sudo dnf module install nodejs:18/common

# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -
sudo apt install -y nodejs

# 验证版本
node --version
```

#### 问题：npm install 失败
```
npm ERR! network request failed
```

**解决方案**：
```bash
# 检查网络连接
ping npmjs.org

# 配置 npm 镜像（中国用户）
npm config set registry https://registry.npmmirror.com

# 清理缓存重试
npm cache clean --force
npm install
```

#### 问题：权限错误
```
EACCES: permission denied
```

**解决方案**：
```bash
# 检查文件权限
sudo ls -la /opt/newhttps/

# 修复权限
sudo chown -R newhttps:newhttps /opt/newhttps/
sudo chmod -R 755 /opt/newhttps/

# 重新安装
sudo ./standalone-install.sh
```

### 2. 服务启动问题

#### 问题：API 服务无法启动
```bash
# 查看详细错误
sudo journalctl -u newhttps-api -n 50

# 常见错误和解决方案
```

**错误 1：端口被占用**
```
Error: listen EADDRINUSE :::3000
```
解决方案：
```bash
# 查找占用进程
sudo lsof -i :3000
sudo kill -9 <PID>

# 或修改端口
sudo nano /opt/newhttps/config/api.env
# 修改 PORT=3001
sudo systemctl restart newhttps-api
```

**错误 2：数据库权限问题**
```
SQLITE_CANTOPEN: unable to open database file
```
解决方案：
```bash
# 检查数据库目录权限
sudo ls -la /opt/newhttps/data/
sudo chown -R newhttps:newhttps /opt/newhttps/data/
sudo chmod 755 /opt/newhttps/data/
sudo systemctl restart newhttps-api
```

**错误 3：环境变量问题**
```
JWT_SECRET is not defined
```
解决方案：
```bash
# 检查配置文件
sudo cat /opt/newhttps/config/api.env

# 重新生成配置
sudo openssl rand -base64 32 > /tmp/jwt_secret
sudo sed -i "s/JWT_SECRET=.*/JWT_SECRET=$(cat /tmp/jwt_secret)/" /opt/newhttps/config/api.env
sudo systemctl restart newhttps-api
```

#### 问题：Web 服务无法启动
```bash
# 查看 Web 服务日志
sudo journalctl -u newhttps-web -n 50
```

**错误 1：serve 命令未找到**
```
newhttps-web.service: Failed to execute command: No such file or directory
```
解决方案：
```bash
# 全局安装 serve
sudo npm install -g serve

# 或修改服务文件使用本地安装
sudo systemctl edit newhttps-web
# 添加：
[Service]
ExecStart=/bin/bash -lc 'npx serve -s dist -l 8080'
```

### 3. 网络连接问题

#### 问题：无法访问 Web 界面
**检查步骤**：
```bash
# 1. 检查服务状态
sudo systemctl status newhttps-web

# 2. 检查端口监听
sudo ss -tuln | grep :8080

# 3. 检查防火墙
sudo firewall-cmd --list-ports
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload

# 4. 检查 SELinux
getenforce
sudo setsebool -P httpd_can_network_connect 1
```

#### 问题：API 连接超时
```bash
# 检查 API 服务
curl -v http://localhost:3000/health

# 检查网络配置
sudo netstat -tuln | grep :3000

# 检查防火墙规则
sudo iptables -L | grep 3000
```

### 4. 证书相关问题

#### 问题：ACME 挑战失败
```bash
# 检查 ACME 目录权限
sudo ls -la /opt/newhttps/data/acme/
sudo chown -R newhttps:newhttps /opt/newhttps/data/acme/

# 检查域名解析
nslookup your-domain.com

# 检查 HTTP 挑战路径
curl http://your-domain.com/.well-known/acme-challenge/test
```

#### 问题：证书下载失败
```bash
# 检查证书存储目录
sudo ls -la /opt/newhttps/data/certificates/

# 检查 API 日志
sudo journalctl -u newhttps-api | grep -i certificate

# 手动测试证书下载
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:3000/api/v1/cert/CERT_ID/download?agent_id=AGENT_ID
```

### 5. 性能问题

#### 问题：服务响应慢
```bash
# 检查系统资源
top
free -h
df -h

# 检查进程状态
ps aux | grep node

# 优化建议
sudo systemctl edit newhttps-api
# 添加：
[Service]
Environment=UV_THREADPOOL_SIZE=16
Environment=NODE_ENV=production
LimitNOFILE=65536
```

#### 问题：内存使用过高
```bash
# 监控内存使用
sudo systemctl status newhttps-api
ps -o pid,ppid,cmd,%mem,%cpu -p $(pgrep node)

# 重启服务释放内存
sudo systemctl restart newhttps-api newhttps-web
```

## 🔧 调试模式

### 启用详细日志
```bash
# 修改 API 配置
sudo nano /opt/newhttps/config/api.env
# 设置 LOG_LEVEL=DEBUG

# 重启服务
sudo systemctl restart newhttps-api

# 查看详细日志
sudo journalctl -u newhttps-api -f
```

### 手动启动服务（调试用）
```bash
# 停止系统服务
sudo systemctl stop newhttps-api

# 手动启动（前台运行）
cd /opt/newhttps/api
sudo -u newhttps bash -lc 'node dist/index.js'
```

## 📞 获取帮助

### 收集诊断信息
```bash
# 创建诊断报告
cat > /tmp/newhttps-diag.txt << EOF
=== 系统信息 ===
$(uname -a)
$(cat /etc/os-release)

=== 服务状态 ===
$(sudo systemctl status newhttps-api newhttps-web)

=== 端口监听 ===
$(sudo ss -tuln | grep -E ':(3000|8080)')

=== 最近日志 ===
$(sudo journalctl -u newhttps-api -n 20)
$(sudo journalctl -u newhttps-web -n 20)

=== 配置文件 ===
$(sudo cat /opt/newhttps/config/api.env)
EOF

echo "诊断信息已保存到 /tmp/newhttps-diag.txt"
```

### 联系支持
- 查看项目文档：[docs/](../docs/)
- 提交 Issue：GitHub Issues
- 社区讨论：项目讨论区

### 有用的命令
```bash
# 完全重置服务
sudo systemctl stop newhttps-api newhttps-web
sudo systemctl reset-failed newhttps-api newhttps-web
sudo systemctl daemon-reload
sudo systemctl start newhttps-api newhttps-web

# 检查配置文件语法
sudo nginx -t  # 如果使用 Nginx
node -c /opt/newhttps/api/dist/index.js  # 检查 Node.js 语法

# 网络诊断
sudo tcpdump -i any port 3000  # 监控 API 流量
sudo tcpdump -i any port 8080  # 监控 Web 流量
```
