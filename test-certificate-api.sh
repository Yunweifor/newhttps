#!/bin/bash

# 测试证书申请API的脚本

echo "🧪 测试证书申请API..."

# 检查API服务是否运行
echo "📡 检查API服务状态..."
if ! curl -s http://localhost:3000/health > /dev/null; then
    echo "❌ API服务未运行，请先启动API服务"
    echo "   运行: cd api && npm start"
    exit 1
fi

echo "✅ API服务正在运行"

# 测试证书申请
echo ""
echo "📋 测试证书申请..."
echo "请求数据:"
cat << EOF
{
  "domains": ["test.example.com"],
  "ca": "letsencrypt",
  "email": "test@example.com",
  "challengeType": "http-01",
  "autoRenew": true,
  "renewDays": 30
}
EOF

echo ""
echo "发送请求..."

response=$(curl -s -X POST http://localhost:3000/api/v1/cert/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test-token" \
  -d '{
    "domains": ["test.example.com"],
    "ca": "letsencrypt", 
    "email": "test@example.com",
    "challengeType": "http-01",
    "autoRenew": true,
    "renewDays": 30
  }')

echo "响应结果:"
echo "$response" | jq . 2>/dev/null || echo "$response"

# 检查响应是否成功
if echo "$response" | grep -q '"success":true'; then
    echo ""
    echo "✅ 证书申请测试成功！"
    
    # 测试证书列表
    echo ""
    echo "📋 测试证书列表..."
    list_response=$(curl -s -H "Authorization: Bearer test-token" http://localhost:3000/api/v1/cert/list)
    echo "证书列表:"
    echo "$list_response" | jq . 2>/dev/null || echo "$list_response"
    
else
    echo ""
    echo "❌ 证书申请测试失败"
    exit 1
fi

echo ""
echo "🎉 所有测试通过！"
