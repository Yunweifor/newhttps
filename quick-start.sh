#!/usr/bin/env bash

# NewHTTPS 快速开始脚本 - Docker 版本
# 自动部署 NewHTTPS 系统

set -e

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

    # 检查 Docker
    if command_exists docker; then
        log_success "Docker 已安装"
    else
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi

    # 检查 Docker Compose (新版本集成在 Docker CLI 中)
    if docker compose version >/dev/null 2>&1; then
        log_success "Docker Compose 已安装 (集成版本)"
        DOCKER_COMPOSE="docker compose"
    elif command_exists docker-compose; then
        log_success "Docker Compose 已安装 (独立版本)"
        DOCKER_COMPOSE="docker-compose"
    else
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi

    # 检查端口占用
    ports="3000 8080 80"
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

    mkdir -p data/newhttps
    mkdir -p logs
    mkdir -p ssl

    log_success "目录结构创建完成"
}

# 设置环境配置
setup_environment() {
    log_info "设置环境配置..."

    # 创建 .env 文件
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            log_info "已创建 .env 文件"
        else
            # 生成基本配置
            JWT_SECRET=$(openssl rand -base64 32)
            cat > .env << EOF
JWT_SECRET=$JWT_SECRET
API_PORT=3000
WEB_PORT=8080
NODE_ENV=production
EOF
            log_info "已创建基本 .env 配置"
        fi
    else
        log_info ".env 文件已存在"
    fi

    log_success "环境配置完成"
}

# 启动服务
start_services() {
    log_info "启动 NewHTTPS 服务..."

    # 停止现有服务
    $DOCKER_COMPOSE down 2>/dev/null || true

    # 构建并启动服务
    $DOCKER_COMPOSE up -d --build

    # 等待服务启动
    log_info "等待服务启动..."
    sleep 30

    log_success "服务启动完成"
}

# 验证安装
verify_installation() {
    log_info "验证安装..."

    # 检查 API 健康状态
    local max_attempts=10
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:3000/health >/dev/null 2>&1; then
            log_success "NewHTTPS API 运行正常"
            return 0
        fi

        log_info "等待 API 启动... ($attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done

    log_error "API 服务验证失败"
    $DOCKER_COMPOSE logs newhttps-api
}

# 显示安装结果
show_results() {
    echo
    log_success "NewHTTPS 部署完成！"
    echo
    echo "访问地址："
    echo "  - NewHTTPS Web 界面: http://localhost:8080"
    echo "  - NewHTTPS API: http://localhost:3000"
    echo "  - API 健康检查: http://localhost:3000/health"
    echo "  - Nginx 代理: http://localhost:80"
    echo
    echo "管理命令："
    echo "  - 查看服务状态: $DOCKER_COMPOSE ps"
    echo "  - 查看日志: $DOCKER_COMPOSE logs -f"
    echo "  - 停止服务: $DOCKER_COMPOSE down"
    echo "  - 重启服务: $DOCKER_COMPOSE restart"
    echo
    echo "数据目录："
    echo "  - 应用数据: ./data/newhttps"
    echo "  - SSL证书: ./ssl"
    echo "  - 日志文件: ./logs"
    echo
}

# 主函数
main() {
    echo
    echo "========================================"
    echo "    NewHTTPS Docker 快速部署"
    echo "========================================"
    echo

    check_requirements
    create_directories
    setup_environment
    start_services
    verify_installation
    show_results
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
