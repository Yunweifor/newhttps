#!/bin/bash

# 修复Web服务问题的脚本

# 颜色定义
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

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 用户运行此脚本"
        exit 1
    fi
}

# 修复Web服务问题
fix_web_service() {
    log_info "修复Web服务问题..."
    
    # 停止失败的Web服务
    log_info "停止Web服务..."
    systemctl stop newhttps-web.service 2>/dev/null || true
    
    # 禁用Web服务
    log_info "禁用Web服务..."
    systemctl disable newhttps-web.service 2>/dev/null || true
    
    # 删除Web服务文件
    log_info "删除Web服务文件..."
    rm -f /etc/systemd/system/newhttps-web.service
    
    # 重载systemd
    log_info "重载systemd配置..."
    systemctl daemon-reload
    
    log_success "Web服务问题已修复"
}

# 检查API服务状态
check_api_service() {
    log_info "检查API服务状态..."
    
    if systemctl is-active --quiet newhttps-api.service; then
        log_success "NewHTTPS API 服务运行正常"
        
        # 检查API健康状态
        if curl -f http://localhost:3000/health >/dev/null 2>&1; then
            log_success "NewHTTPS API 健康检查通过"
        else
            log_warn "NewHTTPS API 健康检查失败"
        fi
    else
        log_warn "NewHTTPS API 服务未运行"
        log_info "尝试启动API服务..."
        systemctl start newhttps-api.service
        sleep 5
        
        if systemctl is-active --quiet newhttps-api.service; then
            log_success "NewHTTPS API 服务启动成功"
        else
            log_error "NewHTTPS API 服务启动失败"
            systemctl status newhttps-api.service
        fi
    fi
}

# 显示当前状态
show_status() {
    echo
    log_info "当前系统状态："
    echo
    
    # API服务状态
    if systemctl is-active --quiet newhttps-api.service; then
        echo -e "  ${GREEN}✓${NC} NewHTTPS API 服务: 运行中"
        echo "    - 访问地址: http://localhost:3000"
        echo "    - 健康检查: http://localhost:3000/health"
    else
        echo -e "  ${RED}✗${NC} NewHTTPS API 服务: 未运行"
    fi
    
    # Web服务状态
    if systemctl list-unit-files | grep -q newhttps-web.service; then
        if systemctl is-active --quiet newhttps-web.service; then
            echo -e "  ${GREEN}✓${NC} NewHTTPS Web 服务: 运行中"
        else
            echo -e "  ${RED}✗${NC} NewHTTPS Web 服务: 未运行"
        fi
    else
        echo -e "  ${YELLOW}!${NC} NewHTTPS Web 服务: 未安装"
    fi
    
    echo
    log_info "管理命令："
    echo "  - 查看API状态: systemctl status newhttps-api"
    echo "  - 查看API日志: journalctl -u newhttps-api -f"
    echo "  - 重启API服务: systemctl restart newhttps-api"
    echo
}

# 主函数
main() {
    echo
    echo "========================================"
    echo "    NewHTTPS Web服务修复脚本"
    echo "========================================"
    echo
    
    check_root
    fix_web_service
    check_api_service
    show_status
    
    echo
    log_success "修复完成！"
    echo
    log_info "说明："
    echo "  - Web服务已被移除，因为Web界面未正确安装"
    echo "  - API服务仍然可以正常使用"
    echo "  - 如需Web界面，请确保web目录存在后重新运行安装脚本"
    echo
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
