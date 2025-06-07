#!/bin/bash

# NewHTTPS 生产环境部署脚本
# 适配服务器: 8.134.166.234
# 网络限制: 仅开放80/443端口

set -euo pipefail

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVER_IP="8.134.166.234"

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
NewHTTPS 生产环境部署脚本

用法: $0 [选项] [命令]

命令:
    install     全新安装生产环境
    start       启动生产服务
    stop        停止生产服务
    restart     重启生产服务
    status      查看服务状态
    logs        查看服务日志
    update      更新服务
    backup      备份数据
    ssl         生成SSL证书

选项:
    --ip IP             服务器IP地址 (默认: 8.134.166.234)
    --with-ssl          同时生成SSL证书
    --force             强制重新部署
    --help              显示帮助信息

示例:
    $0 install                      # 安装生产环境
    $0 install --with-ssl           # 安装并生成SSL证书
    $0 start                        # 启动服务
    $0 status                       # 查看状态
    $0 ssl                          # 生成SSL证书

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
    
    # 检查端口占用
    if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
        log_warning "端口80已被占用，请确保没有其他Web服务运行"
    fi
    
    if netstat -tlnp 2>/dev/null | grep -q ":443 "; then
        log_warning "端口443已被占用，请确保没有其他HTTPS服务运行"
    fi
    
    # 检查内存
    local memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $memory_gb -lt 2 ]]; then
        log_warning "内存不足2GB，建议升级服务器配置"
    fi
    
    log_success "系统要求检查完成"
}

# 生成JWT密钥
generate_jwt_secret() {
    log_info "生成JWT密钥..."
    
    if command -v openssl &> /dev/null; then
        JWT_SECRET=$(openssl rand -base64 32)
        log_success "JWT密钥生成完成"
    else
        log_error "OpenSSL未安装，无法生成JWT密钥"
        exit 1
    fi
}

# 设置生产环境配置
setup_production_config() {
    log_info "设置生产环境配置..."
    
    # 复制生产环境配置模板
    cp "$PROJECT_ROOT/.env.production" "$PROJECT_ROOT/.env"
    
    # 替换JWT密钥
    if [[ -n "${JWT_SECRET:-}" ]]; then
        sed -i "s|JWT_SECRET=请使用openssl-rand-base64-32生成新密钥并替换此行|JWT_SECRET=$JWT_SECRET|" "$PROJECT_ROOT/.env"
        log_success "JWT密钥已配置"
    fi
    
    # 生成备份加密密钥
    if command -v openssl &> /dev/null; then
        BACKUP_KEY=$(openssl rand -base64 32)
        sed -i "s|BACKUP_ENCRYPTION_KEY=请使用openssl-rand-base64-32生成备份加密密钥|BACKUP_ENCRYPTION_KEY=$BACKUP_KEY|" "$PROJECT_ROOT/.env"
        log_success "备份加密密钥已配置"
    fi
    
    # 确认服务器IP配置
    sed -i "s|SERVER_IP=8.134.166.234|SERVER_IP=$SERVER_IP|g" "$PROJECT_ROOT/.env"
    sed -i "s|8.134.166.234|$SERVER_IP|g" "$PROJECT_ROOT/.env"
    
    log_success "生产环境配置完成"
}

# 生成SSL证书
generate_ssl_certificate() {
    if [[ "$GENERATE_SSL" == true ]]; then
        log_info "生成SSL证书..."
        
        if [[ -f "$SCRIPT_DIR/generate-ssl-cert.sh" ]]; then
            "$SCRIPT_DIR/generate-ssl-cert.sh" --ip "$SERVER_IP" --force
            log_success "SSL证书生成完成"
        else
            log_error "SSL证书生成脚本不存在"
            exit 1
        fi
    fi
}

# 创建必要目录
create_directories() {
    log_info "创建必要目录..."
    
    mkdir -p "$PROJECT_ROOT"/{data,logs,ssl,backups,config}
    chmod 755 "$PROJECT_ROOT"/{data,logs,ssl,backups,config}
    
    log_success "目录创建完成"
}

# 构建Docker镜像
build_images() {
    log_info "构建Docker镜像..."
    
    cd "$PROJECT_ROOT"
    
    # 构建基础镜像
    docker build -f Dockerfile.base -t newhttps-base:latest .
    
    # 构建应用镜像
    docker-compose -f docker-compose.production.yml build
    
    log_success "Docker镜像构建完成"
}

# 启动生产服务
start_services() {
    log_info "启动生产服务..."
    
    cd "$PROJECT_ROOT"
    
    # 启动服务
    docker-compose -f docker-compose.production.yml up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    check_service_health
    
    log_success "生产服务启动完成"
}

# 停止服务
stop_services() {
    log_info "停止生产服务..."
    
    cd "$PROJECT_ROOT"
    docker-compose -f docker-compose.production.yml down
    
    log_success "服务已停止"
}

# 重启服务
restart_services() {
    log_info "重启生产服务..."
    
    stop_services
    sleep 5
    start_services
}

# 检查服务健康状态
check_service_health() {
    log_info "检查服务健康状态..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f "http://$SERVER_IP/health" >/dev/null 2>&1; then
            log_success "服务健康检查通过"
            break
        else
            log_info "等待服务就绪... (尝试 $attempt/$max_attempts)"
            sleep 10
            ((attempt++))
        fi
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        log_error "服务健康检查失败"
        show_service_logs
        exit 1
    fi
}

# 显示服务状态
show_service_status() {
    log_info "服务状态:"
    
    cd "$PROJECT_ROOT"
    docker-compose -f docker-compose.production.yml ps
    
    echo ""
    log_info "访问地址:"
    echo "  HTTP:  http://$SERVER_IP"
    echo "  HTTPS: https://$SERVER_IP (需要SSL证书)"
    echo "  API:   http://$SERVER_IP/api"
    echo "  健康检查: http://$SERVER_IP/health"
    echo ""
    
    # 检查端口监听
    log_info "端口监听状态:"
    netstat -tlnp | grep -E ":(80|443) " || echo "  无端口监听"
}

# 显示服务日志
show_service_logs() {
    cd "$PROJECT_ROOT"
    docker-compose -f docker-compose.production.yml logs --tail=50
}

# 备份数据
backup_data() {
    log_info "备份生产数据..."
    
    local backup_dir="$PROJECT_ROOT/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份数据卷
    docker run --rm \
        -v newhttps-data-prod:/data \
        -v "$backup_dir":/backup \
        alpine tar czf /backup/data.tar.gz -C /data .
    
    docker run --rm \
        -v newhttps-ssl-prod:/ssl \
        -v "$backup_dir":/backup \
        alpine tar czf /backup/ssl.tar.gz -C /ssl .
    
    # 备份配置
    cp "$PROJECT_ROOT/.env" "$backup_dir/"
    cp -r "$PROJECT_ROOT/ssl" "$backup_dir/" 2>/dev/null || true
    
    log_success "备份完成: $backup_dir"
}

# 更新服务
update_services() {
    log_info "更新生产服务..."
    
    # 备份数据
    backup_data
    
    # 拉取最新代码
    git pull origin main
    
    # 重新构建和启动
    build_images
    restart_services
    
    log_success "服务更新完成"
}

# 安装生产环境
install_production() {
    log_info "开始安装NewHTTPS生产环境..."
    
    check_requirements
    generate_jwt_secret
    setup_production_config
    create_directories
    generate_ssl_certificate
    build_images
    start_services
    
    log_success "NewHTTPS生产环境安装完成！"
    show_access_info
}

# 显示访问信息
show_access_info() {
    echo ""
    echo "🎉 NewHTTPS生产环境部署成功！"
    echo ""
    echo "📋 访问信息:"
    echo "  服务器IP: $SERVER_IP"
    echo "  HTTP访问: http://$SERVER_IP"
    echo "  HTTPS访问: https://$SERVER_IP"
    echo "  API接口: http://$SERVER_IP/api"
    echo "  健康检查: http://$SERVER_IP/health"
    echo ""
    echo "🔐 安全信息:"
    echo "  JWT密钥已自动生成并配置"
    echo "  SSL证书位置: $PROJECT_ROOT/ssl/"
    echo "  配置文件: $PROJECT_ROOT/.env"
    echo ""
    echo "🛠️ 管理命令:"
    echo "  查看状态: $0 status"
    echo "  查看日志: $0 logs"
    echo "  重启服务: $0 restart"
    echo "  备份数据: $0 backup"
    echo ""
    echo "📱 Agent配置:"
    echo "  API_ENDPOINT=http://$SERVER_IP/api"
    echo "  JWT_SECRET=<与服务器相同的密钥>"
    echo ""
    
    if [[ "$GENERATE_SSL" == true ]]; then
        echo "⚠️  SSL证书说明:"
        echo "  已生成自签名证书，浏览器会显示安全警告"
        echo "  点击'高级'→'继续访问'即可正常使用"
        echo ""
    fi
}

# 解析命令行参数
COMMAND=""
SERVER_IP="8.134.166.234"
GENERATE_SSL=false
FORCE_DEPLOY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        install|start|stop|restart|status|logs|update|backup|ssl)
            COMMAND="$1"
            shift
            ;;
        --ip)
            SERVER_IP="$2"
            shift 2
            ;;
        --with-ssl)
            GENERATE_SSL=true
            shift
            ;;
        --force)
            FORCE_DEPLOY=true
            shift
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
            install_production
            ;;
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        status)
            show_service_status
            ;;
        logs)
            show_service_logs
            ;;
        update)
            update_services
            ;;
        backup)
            backup_data
            ;;
        ssl)
            GENERATE_SSL=true
            generate_ssl_certificate
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
