#!/bin/bash

# NewHTTPS 单机部署脚本
# 专为单机或小规模部署环境设计

set -euo pipefail

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 显示帮助
show_help() {
    cat << EOF
NewHTTPS 单机部署脚本

用法: $0 [选项] [命令]

命令:
    install     全新安装
    start       启动服务
    stop        停止服务
    restart     重启服务
    status      查看状态
    logs        查看日志
    update      更新服务
    backup      备份数据
    restore     恢复数据
    clean       清理数据

部署模式:
    --standard      标准部署（默认，2GB+ 内存）
    --minimal       最小化部署（1GB 内存）
    --api-only      仅API服务
    --with-proxy    包含Nginx代理

选项:
    --domain DOMAIN     设置域名
    --email EMAIL       设置邮箱（用于SSL证书）
    --port PORT         设置API端口（默认3000）
    --web-port PORT     设置Web端口（默认8080）
    --help              显示帮助

示例:
    $0 install --standard                    # 标准安装
    $0 install --minimal                     # 最小化安装
    $0 install --api-only --port 3001       # 仅API，自定义端口
    $0 start --with-proxy                    # 启动包含代理
    $0 backup                                # 备份数据

EOF
}

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose未安装，请先安装Docker Compose"
        exit 1
    fi
    
    # 检查内存
    local memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $memory_gb -lt 1 ]]; then
        log_warning "内存不足1GB，建议使用 --minimal 模式"
    fi
    
    # 检查磁盘空间
    local disk_gb=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $disk_gb -lt 5 ]]; then
        log_warning "磁盘空间不足5GB，可能影响运行"
    fi
    
    log_success "系统要求检查完成"
}

# 设置环境配置
setup_environment() {
    log_info "设置环境配置..."
    
    # 创建.env文件
    if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
        cat > "$PROJECT_ROOT/.env" << EOF
# NewHTTPS 单机部署配置
NODE_ENV=production
VERSION=latest
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

# 安全配置
JWT_SECRET=$(openssl rand -base64 32)

# 服务端口
API_PORT=${API_PORT:-3000}
WEB_PORT=${WEB_PORT:-8080}

# 域名配置
DOMAIN=${DOMAIN:-localhost}
EMAIL=${EMAIL:-admin@localhost}

# 日志配置
LOG_LEVEL=info
LOG_PATH=/app/logs

# SSL配置
SSL_CERT_PATH=/app/ssl
CORS_ORIGIN=*

# 性能配置
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
UPLOAD_MAX_SIZE=10485760
EOF
        log_success "环境配置文件已创建"
    else
        log_info "环境配置文件已存在"
    fi
    
    # 创建必要目录
    mkdir -p "$PROJECT_ROOT"/{data,logs,ssl,backups,config}
    log_success "目录结构创建完成"
}

# 选择部署配置
select_compose_file() {
    case $DEPLOY_MODE in
        standard)
            COMPOSE_FILE="docker-compose.standalone.yml"
            ;;
        minimal)
            COMPOSE_FILE="docker-compose.minimal.yml"
            ;;
        api-only)
            COMPOSE_FILE="docker-compose.simple.yml"
            ;;
        *)
            COMPOSE_FILE="docker-compose.standalone.yml"
            ;;
    esac
    
    log_info "使用配置文件: $COMPOSE_FILE"
}

# 安装服务
install_service() {
    log_info "开始安装NewHTTPS..."
    
    check_requirements
    setup_environment
    select_compose_file
    
    # 构建并启动服务
    log_info "构建Docker镜像..."
    if [[ "$WITH_PROXY" == true ]]; then
        docker-compose -f "$COMPOSE_FILE" --profile with-proxy build
    else
        docker-compose -f "$COMPOSE_FILE" build
    fi
    
    log_info "启动服务..."
    start_service
    
    log_success "NewHTTPS安装完成！"
    show_access_info
}

# 启动服务
start_service() {
    select_compose_file
    
    log_info "启动NewHTTPS服务..."
    
    if [[ "$WITH_PROXY" == true ]]; then
        docker-compose -f "$COMPOSE_FILE" --profile with-proxy up -d
    else
        docker-compose -f "$COMPOSE_FILE" up -d
    fi
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    check_service_status
    
    log_success "服务启动完成"
}

# 停止服务
stop_service() {
    select_compose_file
    
    log_info "停止NewHTTPS服务..."
    docker-compose -f "$COMPOSE_FILE" down
    log_success "服务已停止"
}

# 重启服务
restart_service() {
    log_info "重启NewHTTPS服务..."
    stop_service
    sleep 5
    start_service
}

# 检查服务状态
check_service_status() {
    select_compose_file
    
    log_info "检查服务状态..."
    docker-compose -f "$COMPOSE_FILE" ps
    
    # 检查API健康状态
    if curl -f http://localhost:${API_PORT:-3000}/health >/dev/null 2>&1; then
        log_success "API服务运行正常"
    else
        log_warning "API服务可能未就绪"
    fi
    
    # 检查Web服务（如果不是API-only模式）
    if [[ "$DEPLOY_MODE" != "api-only" ]]; then
        if curl -f http://localhost:${WEB_PORT:-8080}/ >/dev/null 2>&1; then
            log_success "Web服务运行正常"
        else
            log_warning "Web服务可能未就绪"
        fi
    fi
}

# 显示访问信息
show_access_info() {
    echo ""
    echo "🎉 NewHTTPS部署成功！"
    echo ""
    echo "访问地址："
    echo "  API服务: http://localhost:${API_PORT:-3000}"
    if [[ "$DEPLOY_MODE" != "api-only" ]]; then
        echo "  Web界面: http://localhost:${WEB_PORT:-8080}"
    fi
    echo "  健康检查: http://localhost:${API_PORT:-3000}/health"
    echo ""
    echo "管理命令："
    echo "  查看状态: $0 status"
    echo "  查看日志: $0 logs"
    echo "  重启服务: $0 restart"
    echo "  停止服务: $0 stop"
    echo ""
}

# 查看日志
show_logs() {
    select_compose_file
    docker-compose -f "$COMPOSE_FILE" logs -f
}

# 备份数据
backup_data() {
    log_info "备份NewHTTPS数据..."
    
    local backup_dir="$PROJECT_ROOT/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份数据卷
    docker run --rm -v newhttps-data:/data -v "$backup_dir":/backup alpine tar czf /backup/data.tar.gz -C /data .
    docker run --rm -v newhttps-ssl:/ssl -v "$backup_dir":/backup alpine tar czf /backup/ssl.tar.gz -C /ssl .
    
    # 备份配置
    cp "$PROJECT_ROOT/.env" "$backup_dir/"
    
    log_success "备份完成: $backup_dir"
}

# 解析命令行参数
COMMAND=""
DEPLOY_MODE="standard"
WITH_PROXY=false
API_PORT=3000
WEB_PORT=8080
DOMAIN="localhost"
EMAIL="admin@localhost"

while [[ $# -gt 0 ]]; do
    case $1 in
        install|start|stop|restart|status|logs|update|backup|restore|clean)
            COMMAND="$1"
            shift
            ;;
        --standard)
            DEPLOY_MODE="standard"
            shift
            ;;
        --minimal)
            DEPLOY_MODE="minimal"
            shift
            ;;
        --api-only)
            DEPLOY_MODE="api-only"
            shift
            ;;
        --with-proxy)
            WITH_PROXY=true
            shift
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --port)
            API_PORT="$2"
            shift 2
            ;;
        --web-port)
            WEB_PORT="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 主执行函数
main() {
    cd "$PROJECT_ROOT"
    
    case $COMMAND in
        install)
            install_service
            ;;
        start)
            start_service
            ;;
        stop)
            stop_service
            ;;
        restart)
            restart_service
            ;;
        status)
            check_service_status
            ;;
        logs)
            show_logs
            ;;
        backup)
            backup_data
            ;;
        "")
            log_error "请指定命令"
            show_help
            exit 1
            ;;
        *)
            log_error "未知命令: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
