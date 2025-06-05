# NewHTTPS 安装指南

## 系统要求

### 服务端要求
- Node.js 18.0 或更高版本
- 操作系统：Linux、macOS 或 Windows
- 内存：至少 512MB RAM
- 磁盘空间：至少 1GB 可用空间

### 客户端要求（Agent）
- Linux 系统（推荐 Ubuntu 18.04+、CentOS 7+）
- Nginx 已安装并正在运行
- curl 或 wget 工具
- cron 服务（用于定时任务）
- 基本的 shell 工具（awk、sed、grep 等）

## 安装步骤

### 1. 安装 Certd-2（如果还没有）

使用 Docker 快速安装：

```bash
# 创建数据目录
mkdir -p /data/certd

# 启动 Certd-2
docker run -d --name certd \
  --restart unless-stopped \
  -p 7001:7001 \
  -v /data/certd:/app/data \
  registry.cn-shenzhen.aliyuncs.com/handsfree/certd:latest
```

或者使用 npm 安装：

```bash
npm install -g @certd/cli
certd start
```

### 2. 部署 NewHTTPS API 服务

#### 方法一：使用 Docker（推荐）

```bash
# 克隆项目
git clone https://github.com/your-repo/newhttps.git
cd newhttps

# 构建 Docker 镜像
docker build -t newhttps-api ./api

# 创建配置文件
cp api/.env.example api/.env
# 编辑 api/.env 文件，配置必要的参数

# 启动服务
docker run -d --name newhttps-api \
  --restart unless-stopped \
  -p 3000:3000 \
  -v $(pwd)/api/.env:/app/.env \
  -v $(pwd)/data:/app/data \
  newhttps-api
```

#### 方法二：直接安装

```bash
# 克隆项目
git clone https://github.com/your-repo/newhttps.git
cd newhttps/api

# 安装依赖
npm install

# 配置环境变量
cp .env.example .env
# 编辑 .env 文件

# 构建项目
npm run build

# 启动服务
npm start
```

### 3. 配置 NewHTTPS API

编辑 `.env` 文件：

```bash
# 基本配置
PORT=3000
NODE_ENV=production

# JWT 密钥（请更改为随机字符串）
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production

# Certd-2 集成配置
CERTD_BASE_URL=http://localhost:7001
CERTD_TOKEN=your-certd-api-token

# 数据库配置
DATABASE_PATH=./data/newhttps.db

# 日志级别
LOG_LEVEL=INFO
```

### 4. 安装 NewHTTPS Agent

在需要部署证书的服务器上执行：

```bash
# 下载 Agent 脚本
wget https://raw.githubusercontent.com/your-repo/newhttps/main/agent/newhttps-agent.sh
chmod +x newhttps-agent.sh

# 安装 Agent
./newhttps-agent.sh --install

# 配置 Agent
./newhttps-agent.sh --config
```

配置过程中需要输入：
- NewHTTPS API URL（如：http://your-api-server:3000）
- API Token（可选，用于认证）
- 检查间隔（默认 3600 秒）

### 5. 验证安装

#### 检查 API 服务状态

```bash
curl http://localhost:3000/health
```

应该返回：
```json
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "version": "1.0.0"
}
```

#### 检查 Agent 状态

```bash
./newhttps-agent.sh --status
```

应该显示 Agent 的详细状态信息。

#### 测试 Agent 连接

```bash
./newhttps-agent.sh --run
```

检查日志输出，确保 Agent 能够成功连接到 API 服务器。

### 6. 安装 Certd-2 插件（可选）

如果要在 Certd-2 中直接使用 NewHTTPS 部署功能：

```bash
cd newhttps/plugins/newhttps-deploy
npm install
npm run build

# 将插件复制到 Certd-2 插件目录
cp -r dist /path/to/certd/plugins/newhttps-deploy
```

## 配置 Nginx

确保 Nginx 配置文件中包含 SSL 证书配置：

```nginx
server {
    listen 443 ssl;
    server_name example.com;
    
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    # 其他 SSL 配置...
}
```

## 防火墙配置

确保以下端口可以访问：

- **3000**：NewHTTPS API 端口
- **7001**：Certd-2 Web 界面端口（如果使用）
- **443**：HTTPS 端口
- **80**：HTTP 端口（用于证书验证）

## 安全建议

1. **更改默认密钥**：
   - 修改 `JWT_SECRET` 为强随机字符串
   - 如果使用数据库，设置强密码

2. **使用 HTTPS**：
   - 为 NewHTTPS API 配置 SSL 证书
   - 使用反向代理（如 Nginx）

3. **限制访问**：
   - 使用防火墙限制 API 访问
   - 配置适当的 CORS 策略

4. **定期备份**：
   - 备份数据库文件
   - 备份配置文件

## 故障排除

### 常见问题

1. **Agent 无法连接到 API**
   - 检查网络连接
   - 验证 API URL 和端口
   - 检查防火墙设置

2. **Nginx 配置测试失败**
   - 检查 Nginx 配置语法
   - 验证证书文件路径
   - 确保 Nginx 有读取证书文件的权限

3. **证书部署失败**
   - 检查文件权限
   - 验证证书格式
   - 查看详细错误日志

### 日志位置

- **API 日志**：`./logs/newhttps-api.log`
- **Agent 日志**：`~/.newhttps/newhttps-agent.log`
- **Nginx 日志**：`/var/log/nginx/error.log`

### 获取帮助

如果遇到问题，请：

1. 查看相关日志文件
2. 检查 [故障排除文档](troubleshooting.md)
3. 在 GitHub 上提交 Issue
4. 联系技术支持

## 下一步

安装完成后，请参考：

- [配置指南](config.md) - 详细配置说明
- [使用指南](usage.md) - 如何使用系统
- [API 文档](api.md) - API 接口说明
