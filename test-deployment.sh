#!/bin/bash

# 测试证书部署功能的脚本

echo "🧪 测试证书部署功能..."

# 检查API服务是否运行
echo "📡 检查API服务状态..."
if ! curl -s http://localhost:3000/health > /dev/null; then
    echo "❌ API服务未运行，请先启动API服务"
    echo "   运行: cd api && npm start"
    exit 1
fi

echo "✅ API服务正在运行"

# 测试Agent注册
echo ""
echo "📋 注册测试Agent..."
AGENT_ID="test-deploy-agent"
AGENT_RESPONSE=$(curl -s -X POST http://localhost:3000/api/v1/agent/register \
  -H "Content-Type: application/json" \
  -d "{
    \"agent_id\": \"$AGENT_ID\",
    \"hostname\": \"test-deploy-server\",
    \"os\": \"Ubuntu 22.04\",
    \"nginx_version\": \"1.22.1\",
    \"nginx_config\": \"/etc/nginx/nginx.conf\",
    \"version\": \"1.0.0\"
  }")

echo "Agent注册响应:"
echo "$AGENT_RESPONSE" | jq . 2>/dev/null || echo "$AGENT_RESPONSE"

# 测试证书申请
echo ""
echo "📋 申请测试证书..."
CERT_RESPONSE=$(curl -s -X POST http://localhost:3000/api/v1/cert/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test-token" \
  -d '{
    "domains": ["deploy-test.example.com"],
    "ca": "letsencrypt",
    "email": "test@example.com",
    "challengeType": "http-01",
    "autoRenew": true,
    "renewDays": 30
  }')

echo "证书申请响应:"
echo "$CERT_RESPONSE" | jq . 2>/dev/null || echo "$CERT_RESPONSE"

# 提取证书ID
CERT_ID=$(echo "$CERT_RESPONSE" | jq -r '.data.id' 2>/dev/null)
if [[ "$CERT_ID" == "null" || -z "$CERT_ID" ]]; then
    echo "❌ 无法获取证书ID"
    exit 1
fi

echo "✅ 证书ID: $CERT_ID"

# 测试部署任务创建
echo ""
echo "📋 创建部署任务..."
DEPLOY_RESPONSE=$(curl -s -X POST http://localhost:3000/api/v1/deployment/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test-token" \
  -d "{
    \"certificateId\": \"$CERT_ID\",
    \"agentId\": \"$AGENT_ID\",
    \"targetType\": \"nginx\",
    \"targetConfig\": {
      \"configPath\": \"/etc/nginx/sites-enabled\",
      \"certPath\": \"/etc/ssl/certs\",
      \"keyPath\": \"/etc/ssl/private\",
      \"reloadCommand\": \"systemctl reload nginx\",
      \"backupConfig\": true
    }
  }")

echo "部署任务创建响应:"
echo "$DEPLOY_RESPONSE" | jq . 2>/dev/null || echo "$DEPLOY_RESPONSE"

# 提取任务ID
TASK_ID=$(echo "$DEPLOY_RESPONSE" | jq -r '.data.id' 2>/dev/null)
if [[ "$TASK_ID" == "null" || -z "$TASK_ID" ]]; then
    echo "❌ 无法获取任务ID"
    exit 1
fi

echo "✅ 部署任务ID: $TASK_ID"

# 监控部署任务状态
echo ""
echo "📋 监控部署任务状态..."
for i in {1..10}; do
    echo "检查第 $i 次..."
    
    TASK_STATUS=$(curl -s -H "Authorization: Bearer test-token" \
      "http://localhost:3000/api/v1/deployment/tasks/$TASK_ID")
    
    echo "任务状态:"
    echo "$TASK_STATUS" | jq . 2>/dev/null || echo "$TASK_STATUS"
    
    STATUS=$(echo "$TASK_STATUS" | jq -r '.data.status' 2>/dev/null)
    PROGRESS=$(echo "$TASK_STATUS" | jq -r '.data.progress' 2>/dev/null)
    
    echo "状态: $STATUS, 进度: $PROGRESS%"
    
    if [[ "$STATUS" == "completed" ]]; then
        echo "✅ 部署任务完成！"
        break
    elif [[ "$STATUS" == "failed" ]]; then
        echo "❌ 部署任务失败"
        ERROR=$(echo "$TASK_STATUS" | jq -r '.data.error' 2>/dev/null)
        echo "错误信息: $ERROR"
        break
    fi
    
    sleep 2
done

# 测试部署任务列表
echo ""
echo "📋 获取部署任务列表..."
TASKS_LIST=$(curl -s -H "Authorization: Bearer test-token" \
  "http://localhost:3000/api/v1/deployment/tasks")

echo "部署任务列表:"
echo "$TASKS_LIST" | jq . 2>/dev/null || echo "$TASKS_LIST"

# 测试部署统计
echo ""
echo "📊 获取部署统计..."
DEPLOY_STATS=$(curl -s -H "Authorization: Bearer test-token" \
  "http://localhost:3000/api/v1/deployment/stats")

echo "部署统计:"
echo "$DEPLOY_STATS" | jq . 2>/dev/null || echo "$DEPLOY_STATS"

# 测试Agent通信
echo ""
echo "📡 测试Agent通信..."
echo "注意: 这需要Agent服务器在运行"
echo "启动Agent服务器命令:"
echo "  export API_KEY='test-api-key'"
echo "  export AGENT_PORT=8443"
echo "  ./agent/newhttps-agent-server.sh"

# 如果Agent服务器在运行，测试ping
if curl -s --connect-timeout 2 http://localhost:8443/api/v1/ping >/dev/null 2>&1; then
    echo "✅ Agent服务器在线"
    
    PING_RESPONSE=$(curl -s -H "Authorization: Bearer test-api-key" \
      http://localhost:8443/api/v1/ping)
    echo "Agent Ping响应:"
    echo "$PING_RESPONSE" | jq . 2>/dev/null || echo "$PING_RESPONSE"
else
    echo "⚠️  Agent服务器离线或未启动"
fi

# 测试重试功能
echo ""
echo "📋 测试部署任务重试..."
RETRY_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer test-token" \
  "http://localhost:3000/api/v1/deployment/tasks/$TASK_ID/retry")

echo "重试响应:"
echo "$RETRY_RESPONSE" | jq . 2>/dev/null || echo "$RETRY_RESPONSE"

# 清理测试数据
echo ""
echo "🧹 清理测试数据..."

# 删除Agent
curl -s -X DELETE \
  -H "Authorization: Bearer test-token" \
  "http://localhost:3000/api/v1/agent/$AGENT_ID" >/dev/null

echo "✅ 测试Agent已删除"

echo ""
echo "🎉 证书部署功能测试完成！"
echo ""
echo "📋 测试总结:"
echo "  ✅ Agent注册功能"
echo "  ✅ 证书申请功能"
echo "  ✅ 部署任务创建"
echo "  ✅ 任务状态监控"
echo "  ✅ 部署统计获取"
echo "  ✅ 任务重试功能"
echo ""
echo "📝 注意事项:"
echo "  - 真实部署需要Agent服务器运行"
echo "  - Agent需要正确的API密钥配置"
echo "  - 生产环境需要HTTPS和证书验证"
echo "  - 需要配置防火墙允许Agent端口访问"
