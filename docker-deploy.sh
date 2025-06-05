#!/bin/bash

# NewHTTPS Docker 部署脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 检查Docker和Docker Compose
check_requirements() {
    log_info "检查系统要求..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    log_success "系统要求检查通过"
}

# 创建环境配置
setup_environment() {
    log_info "设置环境配置..."
    
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            log_info "已创建 .env 文件，请根据需要修改配置"
        else
            log_warn ".env.example 文件不存在，创建基本配置"
            cat > .env << EOF
JWT_SECRET=$(openssl rand -base64 32)
API_PORT=3000
WEB_PORT=8080
NODE_ENV=production
EOF
        fi
    else
        log_info ".env 文件已存在"
    fi
}

# 创建必要的目录
create_directories() {
    log_info "创建数据目录..."
    
    mkdir -p data/newhttps
    mkdir -p data/ssl
    mkdir -p data/backups
    mkdir -p logs
    
    log_success "目录创建完成"
}

# 构建和启动服务
deploy_services() {
    local compose_file="docker-compose.yml"
    
    # 检查是否只部署API
    if [ "$1" = "--api-only" ]; then
        compose_file="docker-compose.simple.yml"
        log_info "使用API-only模式部署..."
    else
        log_info "使用完整模式部署（API + Web）..."
    fi
    
    # 检查compose文件是否存在
    if [ ! -f "$compose_file" ]; then
        log_error "Docker Compose 文件 $compose_file 不存在"
        exit 1
    fi
    
    log_info "停止现有服务..."
    docker-compose -f "$compose_file" down 2>/dev/null || true
    
    log_info "构建镜像..."
    docker-compose -f "$compose_file" build --no-cache
    
    log_info "启动服务..."
    docker-compose -f "$compose_file" up -d
    
    log_success "服务部署完成"
}

# 等待服务启动
wait_for_services() {
    log_info "等待服务启动..."
    
    # 等待API服务
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:3000/health >/dev/null 2>&1; then
            log_success "API 服务启动成功"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "API 服务启动超时"
            docker-compose logs newhttps-api
            exit 1
        fi
        
        log_info "等待 API 服务启动... ($attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
}

# 显示部署结果
show_results() {
    echo
    log_success "NewHTTPS 部署完成！"
    echo
    echo "访问地址："
    echo "  - API 服务: http://localhost:3000"
    echo "  - API 健康检查: http://localhost:3000/health"
    
    if docker-compose ps | grep -q newhttps-web; then
        echo "  - Web 界面: http://localhost:8080"
    fi
    
    echo
    echo "管理命令："
    echo "  - 查看状态: docker-compose ps"
    echo "  - 查看日志: docker-compose logs -f"
    echo "  - 停止服务: docker-compose down"
    echo "  - 重启服务: docker-compose restart"
    echo
    echo "数据目录："
    echo "  - 应用数据: ./data/newhttps"
    echo "  - SSL证书: ./data/ssl"
    echo "  - 日志文件: ./logs"
    echo
}

# 显示帮助信息
show_help() {
    echo "NewHTTPS Docker 部署脚本"
    echo
    echo "用法:"
    echo "  $0 [选项]"
    echo
    echo "选项:"
    echo "  --api-only    仅部署API服务"
    echo "  --help        显示帮助信息"
    echo
    echo "示例:"
    echo "  $0                # 部署完整服务（API + Web）"
    echo "  $0 --api-only     # 仅部署API服务"
    echo
}

# 主函数
main() {
    echo
    echo "========================================"
    echo "    NewHTTPS Docker 部署脚本"
    echo "========================================"
    echo
    
    # 处理参数
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --api-only)
            API_ONLY=true
            ;;
        "")
            API_ONLY=false
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
    
    check_requirements
    setup_environment
    create_directories
    
    if [ "$API_ONLY" = "true" ]; then
        deploy_services --api-only
    else
        deploy_services
    fi
    
    wait_for_services
    show_results
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
