#!/usr/bin/env bash

# NewHTTPS 快速开始脚本
# 自动安装和配置 NewHTTPS 系统（独立模式）

set -e

# 部署模式选择
DEPLOYMENT_MODE="standalone"  # standalone 或 integrated

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."
    
    # 检查操作系统
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_success "操作系统: Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        log_success "操作系统: macOS"
    else
        log_error "不支持的操作系统: $OSTYPE"
        exit 1
    fi
    
    # 检查 Docker
    if command_exists docker; then
        log_success "Docker 已安装"
    else
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    # 检查 Docker Compose
    if command_exists docker-compose || docker compose version >/dev/null 2>&1; then
        log_success "Docker Compose 已安装"
    else
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    # 检查端口占用
    if [ "$DEPLOYMENT_MODE" = "standalone" ]; then
        ports="3000 8080"
    else
        ports="3000 7001 8080"
    fi

    for port in $ports; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || \
           ss -tuln 2>/dev/null | grep -q ":$port " || \
           lsof -i :$port 2>/dev/null | grep -q LISTEN; then
            log_warn "端口 $port 已被占用，可能会导致冲突"
        fi
    done
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."

    if [ "$DEPLOYMENT_MODE" = "standalone" ]; then
        mkdir -p data/newhttps
        mkdir -p data/acme
        mkdir -p data/certificates
        mkdir -p data/acme-challenges
        mkdir -p logs
        mkdir -p web/dist
    else
        mkdir -p data/certd
        mkdir -p data/newhttps
        mkdir -p logs
        mkdir -p ssl
        mkdir -p nginx/conf.d
    fi

    log_success "目录结构创建完成"
}

# 生成配置文件
generate_config() {
    log_info "生成配置文件..."
    
    # 生成 JWT 密钥
    JWT_SECRET=$(openssl rand -base64 32)
    
    # 创建 API 配置文件
    cat > api/.env << EOF
# NewHTTPS API Configuration
PORT=3000
NODE_ENV=production

# JWT Configuration
JWT_SECRET=$JWT_SECRET

# Certd-2 Integration
CERTD_BASE_URL=http://certd:7001
CERTD_TOKEN=

# Database Configuration
DATABASE_PATH=./data/newhttps.db

# Logging Configuration
LOG_LEVEL=INFO

# Security
BCRYPT_ROUNDS=12

# Agent Configuration
MAX_AGENTS=100
MAX_CERTIFICATES=1000
AGENT_HEARTBEAT_INTERVAL=300
EOF

    # 创建 Nginx 配置
    cat > nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    include /etc/nginx/conf.d/*.conf;
}
EOF

    cat > nginx/conf.d/default.conf << 'EOF'
# NewHTTPS API 代理
upstream newhttps-api {
    server newhttps-api:3000;
}

# Certd-2 代理
upstream certd {
    server certd:7001;
}

server {
    listen 80;
    server_name _;
    
    # NewHTTPS API
    location /api/ {
        proxy_pass http://newhttps-api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Certd-2 Web 界面
    location / {
        proxy_pass http://certd;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
    
    log_success "配置文件生成完成"
}

# 启动服务
start_services() {
    log_info "启动 NewHTTPS 服务..."
    
    # 构建并启动服务
    docker-compose up -d --build
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    if docker-compose ps | grep -q "Up"; then
        log_success "服务启动成功"
    else
        log_error "服务启动失败"
        docker-compose logs
        exit 1
    fi
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    
    # 检查 API 健康状态
    if curl -f http://localhost:3000/health >/dev/null 2>&1; then
        log_success "NewHTTPS API 运行正常"
    else
        log_error "NewHTTPS API 无法访问"
    fi
    
    # 检查 Certd-2
    if curl -f http://localhost:7001 >/dev/null 2>&1; then
        log_success "Certd-2 运行正常"
    else
        log_warn "Certd-2 可能还在启动中，请稍后检查"
    fi
}

# 显示安装结果
show_results() {
    echo
    log_success "NewHTTPS 安装完成！"
    echo
    echo "访问地址："
    echo "  - NewHTTPS Web 界面: http://localhost:8080"
    echo "  - NewHTTPS API: http://localhost:3000"
    echo "  - API 健康检查: http://localhost:3000/health"
    echo
    echo "默认登录信息："
    echo "  - 用户名: admin"
    echo "  - 密码: admin123"
    echo "  - 请登录后立即修改默认密码"
    echo
    echo "下一步："
    echo "  1. 访问 NewHTTPS Web 界面进行初始化设置"
    echo "  2. 配置 CA 机构信息（Let's Encrypt、ZeroSSL 等）"
    echo "  3. 在目标服务器上安装 NewHTTPS Agent："
    echo "     wget https://raw.githubusercontent.com/your-repo/newhttps/main/agent/newhttps-agent.sh"
    echo "     chmod +x newhttps-agent.sh"
    echo "     ./newhttps-agent.sh --install"
    echo "  4. 配置 Agent 连接到 API："
    echo "     ./newhttps-agent.sh --config"
    echo "  5. 创建证书申请和自动部署任务"
    echo
    echo "文档："
    echo "  - 安装指南: docs/install.md"
    echo "  - 使用指南: docs/usage.md"
    echo "  - 配置说明: docs/config.md"
    echo
    echo "管理命令："
    echo "  - 查看服务状态: docker-compose ps"
    echo "  - 查看日志: docker-compose logs -f"
    echo "  - 停止服务: docker-compose down"
    echo "  - 重启服务: docker-compose restart"
}

# 主函数
main() {
    echo
    echo "========================================"
    echo "    NewHTTPS 快速安装脚本"
    echo "========================================"
    echo
    
    check_requirements
    create_directories
    generate_config
    start_services
    verify_installation
    show_results
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
