#!/bin/bash

# NewHTTPS 开发环境启动脚本

echo "🚀 启动 NewHTTPS 开发环境..."

# 检查Node.js版本
if ! command -v node &> /dev/null; then
    echo "❌ Node.js 未安装，请先安装 Node.js"
    exit 1
fi

echo "✅ Node.js 版本: $(node --version)"

# 启动后端API服务
echo "📡 启动后端API服务..."
cd api
if [ ! -d "node_modules" ]; then
    echo "📦 安装后端依赖..."
    npm install
fi

echo "🔨 构建后端..."
npm run build

echo "🌐 启动API服务器 (端口: 3000)..."
npm start &
API_PID=$!

# 等待API服务启动
sleep 3

# 启动前端开发服务器
echo "🎨 启动前端开发服务器..."
cd ../web
if [ ! -d "node_modules" ]; then
    echo "📦 安装前端依赖..."
    npm install
fi

echo "🌐 启动前端服务器 (端口: 5173)..."
npm run dev &
WEB_PID=$!

echo ""
echo "🎉 NewHTTPS 开发环境启动完成！"
echo ""
echo "📍 访问地址:"
echo "   前端: http://localhost:5173"
echo "   API:  http://localhost:3000"
echo ""
echo "📊 健康检查:"
echo "   API健康检查: http://localhost:3000/health"
echo ""
echo "⚡ 功能特性:"
echo "   ✅ 证书管理 - 申请、续期、删除证书"
echo "   ✅ 自动续期调度 - 基于cron表达式的智能调度"
echo "   ✅ Agent管理 - 分布式证书部署"
echo "   ✅ 部署任务 - 自动化证书部署"
echo "   ✅ 监控面板 - 实时统计和状态监控"
echo ""
echo "🛑 停止服务: Ctrl+C"

# 等待用户中断
trap "echo ''; echo '🛑 正在停止服务...'; kill $API_PID $WEB_PID 2>/dev/null; echo '✅ 服务已停止'; exit 0" INT

# 保持脚本运行
wait
