# 域名验证 API 文档

## 🎯 概述

为了提高证书申请的成功率和安全性，我们新增了完善的域名验证功能，参考了 httpsok 等成熟平台的验证机制。

## 🔧 新增功能

### 1. 域名验证 API

#### 单个域名验证
```http
POST /api/v1/domain/validate
Authorization: Bearer <token>
Content-Type: application/json

{
  "domain": "example.com"
}
```

**响应示例**：
```json
{
  "success": true,
  "domain": "example.com",
  "validation": {
    "dns": {
      "valid": true,
      "records": {
        "a": ["192.168.1.1"],
        "aaaa": ["2001:db8::1"],
        "cname": []
      }
    },
    "http": {
      "valid": true,
      "status": 200,
      "responseTime": 150
    },
    "format": {
      "valid": true
    }
  },
  "message": "Domain validation successful"
}
```

#### 批量域名验证
```http
POST /api/v1/domain/validate-batch
Authorization: Bearer <token>
Content-Type: application/json

{
  "domains": ["example.com", "www.example.com", "api.example.com"]
}
```

**响应示例**：
```json
{
  "success": true,
  "summary": {
    "total": 3,
    "valid": 2,
    "invalid": 1
  },
  "results": [
    {
      "domain": "example.com",
      "valid": true,
      "details": { ... }
    },
    {
      "domain": "www.example.com",
      "valid": true,
      "details": { ... }
    },
    {
      "domain": "api.example.com",
      "valid": false,
      "error": "DNS resolution failed"
    }
  ]
}
```

### 2. DNS 记录查询

```http
GET /api/v1/domain/dns/example.com
Authorization: Bearer <token>
```

**响应示例**：
```json
{
  "success": true,
  "domain": "example.com",
  "records": {
    "a": ["192.168.1.1", "192.168.1.2"],
    "aaaa": ["2001:db8::1"],
    "cname": [],
    "mx": [{"exchange": "mail.example.com", "priority": 10}],
    "txt": [["v=spf1 include:_spf.google.com ~all"]]
  },
  "hasRecords": true
}
```

### 3. 连接性测试

```http
GET /api/v1/domain/connectivity/example.com?port=443&secure=true
Authorization: Bearer <token>
```

**响应示例**：
```json
{
  "success": true,
  "domain": "example.com",
  "port": 443,
  "secure": true,
  "accessible": true,
  "status": 200,
  "responseTime": 120
}
```

## 🛡️ 验证机制

### DNS 验证
- **A 记录**：IPv4 地址解析
- **AAAA 记录**：IPv6 地址解析
- **CNAME 记录**：别名记录
- **MX 记录**：邮件交换记录
- **TXT 记录**：文本记录

### HTTP 连接验证
- **HTTPS 优先**：先尝试 443 端口
- **HTTP 备用**：HTTPS 失败时尝试 80 端口
- **超时控制**：5秒连接超时
- **状态码检查**：验证 HTTP 响应状态

### 域名格式验证
- **RFC 合规性**：符合域名标准格式
- **长度限制**：域名总长度 ≤ 253 字符
- **标签长度**：每个标签 ≤ 63 字符
- **禁止域名**：localhost、127.0.0.1 等

## 🔄 证书申请集成

### 自动验证模式（默认）
```http
POST /api/v1/cert/create
Authorization: Bearer <token>
Content-Type: application/json

{
  "domains": ["example.com", "www.example.com"],
  "ca": "letsencrypt",
  "email": "admin@example.com",
  "challengeType": "http-01",
  "autoRenew": true,
  "renewDays": 30
}
```

### 跳过验证模式
```http
POST /api/v1/cert/create
Authorization: Bearer <token>
Content-Type: application/json

{
  "domains": ["example.com"],
  "ca": "letsencrypt", 
  "email": "admin@example.com",
  "skipValidation": true
}
```

## 📊 验证结果处理

### 成功响应
```json
{
  "success": true,
  "data": {
    "id": "cert_1234567890",
    "domains": ["example.com"],
    "status": "active",
    "issuedAt": "2024-01-01T00:00:00.000Z",
    "expiresAt": "2024-04-01T00:00:00.000Z"
  },
  "message": "Certificate created successfully (domains validated)"
}
```

### 验证失败响应
```json
{
  "success": false,
  "error": "Domain validation failed",
  "validationResults": [
    {
      "domain": "example.com",
      "valid": false,
      "error": "DNS resolution failed",
      "details": {
        "dns": {
          "valid": false,
          "error": "No DNS records found"
        }
      }
    }
  ]
}
```

## 🚀 使用建议

### 1. 证书申请前验证
```javascript
// 1. 先验证域名
const validation = await fetch('/api/v1/domain/validate', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ domain: 'example.com' })
});

// 2. 验证成功后申请证书
if (validation.success) {
  const cert = await fetch('/api/v1/cert/create', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      domains: ['example.com'],
      ca: 'letsencrypt',
      email: 'admin@example.com'
    })
  });
}
```

### 2. 批量域名处理
```javascript
// 批量验证多个域名
const domains = ['example.com', 'www.example.com', 'api.example.com'];
const batchValidation = await fetch('/api/v1/domain/validate-batch', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ domains })
});

// 只为验证成功的域名申请证书
const validDomains = batchValidation.results
  .filter(r => r.valid)
  .map(r => r.domain);

if (validDomains.length > 0) {
  // 申请证书...
}
```

## 🔧 配置选项

### 环境变量
```bash
# 验证超时设置
DOMAIN_VALIDATION_TIMEOUT=5000

# DNS 服务器设置
DNS_SERVERS=8.8.8.8,1.1.1.1

# 开发模式（跳过验证）
NODE_ENV=development
```

### 验证策略
- **生产环境**：强制验证所有域名
- **开发环境**：默认跳过验证
- **手动跳过**：使用 `skipValidation: true`

## 🐛 错误处理

### 常见错误码
- `400`：请求参数错误
- `401`：认证失败
- `404`：资源不存在
- `500`：服务器内部错误

### 验证失败原因
1. **DNS 解析失败**：域名无法解析
2. **连接超时**：网络连接问题
3. **格式错误**：域名格式不符合规范
4. **禁止域名**：使用了禁止的域名

## 📈 监控和日志

### 验证日志
```
[INFO] Validating domain ownership: example.com
[INFO] Domain validation successful: example.com
[WARN] Domain validation failed: invalid.com - DNS resolution failed
```

### 性能监控
- 验证响应时间
- 成功率统计
- 失败原因分析

## 🔄 与 httpsok 对比

| 功能 | NewHTTPS | httpsok |
|------|----------|---------|
| DNS 验证 | ✅ | ✅ |
| HTTP 连接测试 | ✅ | ✅ |
| 批量验证 | ✅ | ✅ |
| 多 CA 支持 | ✅ | ✅ |
| 自动续期 | ✅ | ✅ |
| 域名格式检查 | ✅ | ✅ |
| 验证结果详情 | ✅ | ✅ |

通过这些改进，NewHTTPS 现在具备了与 httpsok 相当的域名验证能力，大大提高了证书申请的成功率和用户体验。
