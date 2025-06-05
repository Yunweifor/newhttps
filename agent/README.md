# NewHTTPS Agent

NewHTTPS Agent 是一个智能的SSL证书自动化部署脚本，用于在客户端服务器上自动管理SSL证书的下载、部署和更新。

## 🌟 核心功能

- **🔍 自动发现**: 自动检测Nginx配置文件和SSL证书路径
- **📡 API通信**: 与NewHTTPS服务器通信，检查证书更新
- **📜 证书管理**: 自动下载、验证和部署新证书
- **🔄 安全部署**: 备份旧证书、原子性替换、失败自动回滚
- **⏰ 定时任务**: 支持cron定时执行，避免服务器同时请求
- **📝 完整日志**: 详细的操作日志和错误记录

## 🚀 快速开始

### 安装Agent

```bash
# 下载Agent脚本
wget https://raw.githubusercontent.com/Yunweifor/newhttps/main/agent/newhttps-agent.sh
chmod +x newhttps-agent.sh

# 安装Agent
sudo ./newhttps-agent.sh --install
```

### 配置Agent

```bash
# 配置API连接
sudo ./newhttps-agent.sh --config

# 配置过程中需要输入：
# - NewHTTPS API服务器地址 (如: https://your-server.com:3000)
# - API访问Token (从Web界面获取)
# - 证书检查间隔 (默认: 6小时)
```

### 设置定时任务

```bash
# 设置自动定时任务
sudo ./newhttps-agent.sh --cron

# 手动运行一次检查
sudo ./newhttps-agent.sh --check
```

## 📋 命令参考

```bash
# 安装Agent
./newhttps-agent.sh --install

# 配置Agent
./newhttps-agent.sh --config

# 检查证书更新
./newhttps-agent.sh --check

# 设置定时任务
./newhttps-agent.sh --cron

# 查看状态
./newhttps-agent.sh --status

# 查看日志
./newhttps-agent.sh --logs

# 卸载Agent
./newhttps-agent.sh --uninstall

# 显示帮助
./newhttps-agent.sh --help
```

## 🔧 配置文件

Agent配置文件位于 `/etc/newhttps/agent.conf`：

```bash
# NewHTTPS Agent 配置文件

# API服务器配置
API_BASE_URL="https://your-server.com:3000"
API_TOKEN="your-api-token"

# 检查间隔（秒）
CHECK_INTERVAL=21600  # 6小时

# Nginx配置路径
NGINX_CONFIG_PATH="/etc/nginx"
NGINX_SITES_PATH="/etc/nginx/sites-enabled"

# 证书存储路径
CERT_BACKUP_PATH="/etc/newhttps/backups"

# 日志配置
LOG_LEVEL="INFO"
LOG_FILE="/var/log/newhttps-agent.log"
```

## 📊 工作流程

1. **自动发现阶段**
   - 扫描Nginx配置文件
   - 识别SSL证书路径和域名
   - 检查证书有效期

2. **通信检查阶段**
   - 连接NewHTTPS API服务器
   - 上报本地证书状态
   - 检查是否有证书更新

3. **证书部署阶段**
   - 下载新证书文件
   - 验证证书有效性
   - 备份旧证书
   - 原子性替换证书文件
   - 测试Nginx配置
   - 重载Nginx服务

4. **错误处理阶段**
   - 检测部署失败
   - 自动回滚到备份证书
   - 记录错误日志
   - 发送告警通知

## 🔍 故障排除

### 常见问题

1. **Agent无法连接API服务器**
   ```bash
   # 检查网络连接
   curl -I https://your-server.com:3000/health
   
   # 检查API Token
   ./newhttps-agent.sh --config
   ```

2. **Nginx配置检测失败**
   ```bash
   # 检查Nginx配置语法
   nginx -t
   
   # 检查配置文件权限
   ls -la /etc/nginx/
   ```

3. **证书部署失败**
   ```bash
   # 查看详细日志
   ./newhttps-agent.sh --logs
   
   # 手动回滚证书
   ./newhttps-agent.sh --rollback
   ```

### 日志分析

```bash
# 查看最近的日志
tail -f /var/log/newhttps-agent.log

# 查看错误日志
grep "ERROR" /var/log/newhttps-agent.log

# 查看证书更新记录
grep "CERT_UPDATE" /var/log/newhttps-agent.log
```

## 🛡️ 安全考虑

1. **权限控制**
   - Agent需要root权限操作证书文件
   - 配置文件权限设置为600
   - API Token安全存储

2. **网络安全**
   - 使用HTTPS与API服务器通信
   - 验证服务器SSL证书
   - 支持代理服务器

3. **备份策略**
   - 自动备份旧证书
   - 保留最近5个版本
   - 支持手动回滚

## 📈 监控和告警

Agent支持多种监控和告警方式：

- **日志监控**: 详细的操作日志
- **状态检查**: 定期健康检查
- **邮件告警**: 证书更新成功/失败通知
- **Webhook**: 自定义告警接口

## 🔄 更新Agent

```bash
# 下载最新版本
wget https://raw.githubusercontent.com/Yunweifor/newhttps/main/agent/newhttps-agent.sh -O newhttps-agent-new.sh

# 备份当前版本
cp newhttps-agent.sh newhttps-agent-backup.sh

# 替换新版本
mv newhttps-agent-new.sh newhttps-agent.sh
chmod +x newhttps-agent.sh

# 重新配置（如果需要）
./newhttps-agent.sh --config
```

## 📞 技术支持

如果遇到问题，请：

1. 查看日志文件
2. 检查配置文件
3. 运行诊断命令
4. 提交Issue到GitHub

---

**NewHTTPS Agent - 让SSL证书部署变得自动化！** 🤖✨
