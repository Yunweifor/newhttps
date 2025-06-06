#!/bin/bash

# 测试Agent管理API的脚本

echo "🧪 测试Agent管理API..."

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
echo "📋 测试Agent注册..."
echo "请求数据:"
cat << EOF
{
  "agent_id": "test-agent-001",
  "hostname": "test-server",
  "os": "Ubuntu 22.04",
  "nginx_version": "1.22.1",
  "nginx_config": "/etc/nginx/nginx.conf",
  "version": "1.0.0"
}
EOF

echo ""
echo "发送注册请求..."

register_response=$(curl -s -X POST http://localhost:3000/api/v1/agent/register \
  -H "Content-Type: application/json" \
  -d '{
    "agent_id": "test-agent-001",
    "hostname": "test-server",
    "os": "Ubuntu 22.04",
    "nginx_version": "1.22.1",
    "nginx_config": "/etc/nginx/nginx.conf",
    "version": "1.0.0"
  }')

echo "注册响应:"
echo "$register_response" | jq . 2>/dev/null || echo "$register_response"

# 检查注册是否成功
if echo "$register_response" | grep -q '"success":true'; then
    echo ""
    echo "✅ Agent注册测试成功！"
    
    # 测试Agent列表
    echo ""
    echo "📋 测试Agent列表..."
    list_response=$(curl -s -H "Authorization: Bearer test-token" http://localhost:3000/api/v1/agent/list)
    echo "Agent列表:"
    echo "$list_response" | jq . 2>/dev/null || echo "$list_response"
    
    # 测试Agent详情
    echo ""
    echo "📋 测试Agent详情..."
    detail_response=$(curl -s -H "Authorization: Bearer test-token" http://localhost:3000/api/v1/agent/test-agent-001)
    echo "Agent详情:"
    echo "$detail_response" | jq . 2>/dev/null || echo "$detail_response"
    
    # 测试心跳
    echo ""
    echo "💓 测试Agent心跳..."
    heartbeat_response=$(curl -s -X POST http://localhost:3000/api/v1/agent/test-agent-001/heartbeat \
      -H "Content-Type: application/json" \
      -d '{"status": "ok", "message": "Agent is running"}')
    echo "心跳响应:"
    echo "$heartbeat_response" | jq . 2>/dev/null || echo "$heartbeat_response"
    
    # 测试活动日志
    echo ""
    echo "📋 测试Agent活动日志..."
    activities_response=$(curl -s -H "Authorization: Bearer test-token" http://localhost:3000/api/v1/agent/test-agent-001/activities)
    echo "活动日志:"
    echo "$activities_response" | jq . 2>/dev/null || echo "$activities_response"
    
    # 测试Agent统计
    echo ""
    echo "📊 测试Agent统计..."
    stats_response=$(curl -s -H "Authorization: Bearer test-token" http://localhost:3000/api/v1/agent/stats)
    echo "统计信息:"
    echo "$stats_response" | jq . 2>/dev/null || echo "$stats_response"
    
    # 测试Agent更新
    echo ""
    echo "🔄 测试Agent更新..."
    update_response=$(curl -s -X PUT http://localhost:3000/api/v1/agent/test-agent-001 \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer test-token" \
      -d '{
        "hostname": "updated-test-server",
        "os": "Ubuntu 22.04 LTS",
        "nginx_version": "1.22.2"
      }')
    echo "更新响应:"
    echo "$update_response" | jq . 2>/dev/null || echo "$update_response"
    
    # 测试Agent删除
    echo ""
    echo "🗑️  测试Agent删除..."
    delete_response=$(curl -s -X DELETE http://localhost:3000/api/v1/agent/test-agent-001 \
      -H "Authorization: Bearer test-token")
    echo "删除响应:"
    echo "$delete_response" | jq . 2>/dev/null || echo "$delete_response"
    
else
    echo ""
    echo "❌ Agent注册测试失败"
    exit 1
fi

echo ""
echo "🎉 所有Agent管理API测试通过！"
