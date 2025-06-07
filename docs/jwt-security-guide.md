# NewHTTPS JWT安全配置指南

## 🔐 JWT_SECRET详细说明

### 什么是JWT_SECRET

JWT_SECRET是JSON Web Token的签名密钥，用于：
- **身份验证** - 验证用户和Agent的身份
- **会话管理** - 控制登录状态和访问权限
- **数据完整性** - 防止令牌被篡改或伪造
- **安全通信** - Agent与API服务器之间的安全认证

### 安全风险

如果使用默认或弱密钥：
- ❌ 攻击者可以伪造有效的JWT令牌
- ❌ 未授权访问API和管理界面
- ❌ 证书管理权限被滥用
- ❌ 数据泄露和系统被攻击

## 🛠️ 生成安全的JWT密钥

### 方法一：使用OpenSSL（推荐）

```bash
# 生成256位随机密钥（推荐）
openssl rand -base64 32

# 生成512位超强密钥（高安全要求）
openssl rand -base64 64

# 示例输出
# K8vQJ2mF9xR7nP3sL6wE1tY4uI0oA5zX2cV8bN7mQ9k=
```

### 方法二：使用Node.js

```bash
# 在项目目录执行
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"

# 或者生成更长的密钥
node -e "console.log(require('crypto').randomBytes(64).toString('base64'))"
```

### 方法三：使用Python

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

### 方法四：在线生成（谨慎使用）

```bash
# 仅在测试环境使用，生产环境请使用本地生成
curl -s "https://www.random.org/cgi-bin/randbyte?nbytes=32&format=b" | base64
```

## ⚙️ 配置JWT_SECRET

### 1. 生成密钥

```bash
# 生成新的JWT密钥
JWT_SECRET=$(openssl rand -base64 32)
echo "生成的JWT密钥: $JWT_SECRET"
```

### 2. 更新环境配置

```bash
# 复制配置模板
cp .env.optimized .env

# 编辑配置文件
vim .env
```

**在.env文件中修改**：

```bash
# 将默认密钥替换为生成的密钥
JWT_SECRET=K8vQJ2mF9xR7nP3sL6wE1tY4uI0oA5zX2cV8bN7mQ9k=

# 可选：调整令牌过期时间
JWT_EXPIRES_IN=24h

# Agent令牌配置
AGENT_TOKEN_EXPIRES_IN=30d
AGENT_REFRESH_TOKEN_EXPIRES_IN=90d
```

### 3. 验证配置

```bash
# 启动服务
make standalone

# 检查JWT配置是否生效
curl -X POST http://localhost/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password"}'
```

## 🔒 安全最佳实践

### 密钥要求

- **长度** - 至少32字节（256位）
- **随机性** - 使用加密安全的随机数生成器
- **复杂性** - 包含大小写字母、数字和特殊字符
- **唯一性** - 每个环境使用不同的密钥

### 密钥管理

```bash
# 1. 生产环境密钥管理
# 使用环境变量而非配置文件
export JWT_SECRET="your-production-secret"

# 2. 定期轮换密钥（建议每6个月）
# 生成新密钥
NEW_JWT_SECRET=$(openssl rand -base64 32)

# 3. 备份旧密钥（用于令牌验证过渡期）
OLD_JWT_SECRET="previous-secret"
```

### 环境隔离

```bash
# 开发环境
JWT_SECRET=dev-secret-$(openssl rand -base64 16)

# 测试环境  
JWT_SECRET=test-secret-$(openssl rand -base64 16)

# 生产环境
JWT_SECRET=$(openssl rand -base64 32)
```

## 🚨 安全检查清单

### 部署前检查

- [ ] JWT_SECRET已更改为强密钥
- [ ] 密钥长度至少32字节
- [ ] 不同环境使用不同密钥
- [ ] 密钥未提交到版本控制
- [ ] 配置了合适的令牌过期时间

### 运行时监控

```bash
# 检查JWT配置
curl -s http://localhost/health | jq '.security.jwt'

# 监控异常登录
tail -f logs/api.log | grep "JWT"

# 检查令牌使用情况
docker exec newhttps-api cat /app/logs/auth.log
```

## 🔧 故障排除

### 常见问题

1. **JWT验证失败**
   ```bash
   # 检查密钥是否正确设置
   docker exec newhttps-api env | grep JWT_SECRET
   
   # 重启服务应用新配置
   make restart
   ```

2. **Agent连接失败**
   ```bash
   # 检查Agent配置中的JWT密钥
   cat agent/config.conf | grep JWT_SECRET
   
   # 确保Agent和API使用相同密钥
   ```

3. **令牌过期问题**
   ```bash
   # 调整令牌过期时间
   JWT_EXPIRES_IN=48h  # 延长到48小时
   ```

### 密钥重置

如果需要重置JWT密钥：

```bash
# 1. 生成新密钥
NEW_SECRET=$(openssl rand -base64 32)

# 2. 更新配置
sed -i "s/JWT_SECRET=.*/JWT_SECRET=$NEW_SECRET/" .env

# 3. 重启服务
make restart

# 4. 重新登录所有用户和Agent
```

## 📋 配置示例

### 完整的安全配置示例

```bash
# JWT安全配置
JWT_SECRET=K8vQJ2mF9xR7nP3sL6wE1tY4uI0oA5zX2cV8bN7mQ9k=
JWT_EXPIRES_IN=24h

# Agent认证配置
AGENT_TOKEN_EXPIRES_IN=30d
AGENT_REFRESH_TOKEN_EXPIRES_IN=90d

# 安全增强
RATE_LIMIT_MAX_REQUESTS=100
RATE_LIMIT_WINDOW_MS=900000
CORS_ORIGIN=http://8.134.166.234

# 审计日志
FEATURE_AUDIT_LOGGING=true
LOG_LEVEL=info
```

这个配置确保了NewHTTPS系统的JWT安全性，为后续的网络配置奠定了安全基础。
