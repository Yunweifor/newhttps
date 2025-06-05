#!/usr/bin/env bash

# NewHTTPS Docker 快速启动脚本

set -e

# 颜色输出
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

# 显示帮助信息
show_help() {
    echo "NewHTTPS Docker 部署脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  --standalone    使用独立模式（推荐）"
    echo "  --integrated    使用集成模式（包含 Certd-2）"
    echo "  --stop          停止所有服务"
    echo "  --restart       重启所有服务"
    echo "  --logs          查看服务日志"
    echo "  --status        查看服务状态"
    echo "  --clean         清理所有数据（危险操作）"
    echo "  --help          显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0 --standalone    # 启动独立模式"
    echo "  $0 --logs          # 查看日志"
    echo "  $0 --stop          # 停止服务"
}

# 检查 Docker 环境
check_docker() {
    log_info "检查 Docker 环境..."
    
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker 服务未运行，请启动 Docker 服务"
        exit 1
    fi
    
    log_success "Docker 环境检查通过"
}

# 创建必要的目录
create_directories() {
    log_info "创建必要的目录..."
    
    mkdir -p data/{newhttps,acme,certificates,acme-challenges}
    mkdir -p logs
    mkdir -p ssl
    
    log_success "目录创建完成"
}

# 生成环境配置
generate_env() {
    log_info "生成环境配置..."
    
    if [ ! -f "api/.env" ]; then
        cp .env.docker api/.env
        log_info "已创建 api/.env 配置文件"
    fi
    
    if [ ! -f "web/.env.local" ]; then
        cat > web/.env.local << EOF
VUE_APP_API_BASE_URL=/api
VUE_APP_MODE=standalone
VUE_APP_ENABLE_CERT_APPLY=true
VUE_APP_ENABLE_AGENT_MANAGEMENT=true
EOF
        log_info "已创建 web/.env.local 配置文件"
    fi
    
    log_success "环境配置生成完成"
}

# 启动独立模式
start_standalone() {
    log_info "启动 NewHTTPS 独立模式..."
    
    check_docker
    create_directories
    generate_env
    
    # 构建并启动服务
    if docker compose version >/dev/null 2>&1; then
        docker compose -f docker-compose.standalone.yml up -d --build
    else
        docker-compose -f docker-compose.standalone.yml up -d --build
    fi
    
    log_success "独立模式启动完成"
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 30
    
    # 显示状态
    show_status
}

# 启动集成模式
start_integrated() {
    log_info "启动 NewHTTPS 集成模式（包含 Certd-2）..."
    
    check_docker
    create_directories
    generate_env
    
    # 构建并启动服务
    if docker compose version >/dev/null 2>&1; then
        docker compose up -d --build
    else
        docker-compose up -d --build
    fi
    
    log_success "集成模式启动完成"
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 30
    
    # 显示状态
    show_status
}

# 停止服务
stop_services() {
    log_info "停止 NewHTTPS 服务..."
    
    if docker compose version >/dev/null 2>&1; then
        docker compose -f docker-compose.standalone.yml down 2>/dev/null || true
        docker compose down 2>/dev/null || true
    else
        docker-compose -f docker-compose.standalone.yml down 2>/dev/null || true
        docker-compose down 2>/dev/null || true
    fi
    
    log_success "服务已停止"
}

# 重启服务
restart_services() {
    log_info "重启 NewHTTPS 服务..."
    
    stop_services
    sleep 5
    start_standalone
}

# 查看日志
show_logs() {
    log_info "显示服务日志..."
    
    if docker compose version >/dev/null 2>&1; then
        docker compose -f docker-compose.standalone.yml logs -f
    else
        docker-compose -f docker-compose.standalone.yml logs -f
    fi
}

# 查看状态
show_status() {
    log_info "检查服务状态..."
    
    echo
    echo "=== Docker 容器状态 ==="
    docker ps --filter "name=newhttps" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo
    echo "=== 服务健康检查 ==="
    
    # 检查 API 健康状态
    if curl -f http://localhost/health >/dev/null 2>&1; then
        log_success "NewHTTPS API: 健康"
    else
        log_warn "NewHTTPS API: 不健康"
    fi
    
    # 检查 Web 界面
    if curl -f http://localhost/ >/dev/null 2>&1; then
        log_success "NewHTTPS Web: 可访问"
    else
        log_warn "NewHTTPS Web: 不可访问"
    fi
    
    echo
    echo "=== 访问地址 ==="
    echo "  - NewHTTPS Web 界面: http://localhost"
    echo "  - NewHTTPS API: http://localhost/api"
    echo "  - API 健康检查: http://localhost/health"
    echo
}

# 清理数据
clean_data() {
    log_warn "这将删除所有 NewHTTPS 数据，包括证书和配置！"
    read -p "确定要继续吗？(y/N): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        log_info "清理数据..."
        
        stop_services
        
        # 删除容器和镜像
        docker system prune -f
        docker volume prune -f
        
        # 删除数据目录
        rm -rf data logs ssl
        
        log_success "数据清理完成"
    else
        log_info "取消清理操作"
    fi
}

# 主函数
main() {
    case "${1:-}" in
        --standalone)
            start_standalone
            ;;
        --integrated)
            start_integrated
            ;;
        --stop)
            stop_services
            ;;
        --restart)
            restart_services
            ;;
        --logs)
            show_logs
            ;;
        --status)
            show_status
            ;;
        --clean)
            clean_data
            ;;
        --help|"")
            show_help
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 脚本入口
main "$@"
