#!/usr/bin/env bash

# NewHTTPS 安装前检查脚本
# 适用于 AlimaLinux 9 和其他 RHEL 系列系统

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

# 检查操作系统
check_os() {
    log_info "检查操作系统..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
        log_success "操作系统: $OS_NAME $OS_VERSION"
        
        # 检查是否为支持的系统
        case "$ID" in
            "almalinux"|"centos"|"rhel"|"rocky"|"fedora")
                log_success "支持的 RHEL 系列系统"
                ;;
            "ubuntu"|"debian")
                log_success "支持的 Debian 系列系统"
                ;;
            *)
                log_warn "未测试的系统，可能需要手动调整"
                ;;
        esac
    else
        log_error "无法识别操作系统"
        return 1
    fi
}

# 检查 root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "需要 root 权限运行此脚本"
        log_info "请使用: sudo $0"
        return 1
    fi
    log_success "Root 权限检查通过"
}

# 检查网络连接
check_network() {
    log_info "检查网络连接..."
    
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_success "网络连接正常"
    else
        log_error "网络连接失败，请检查网络设置"
        return 1
    fi
    
    # 检查 DNS 解析
    if nslookup nodejs.org >/dev/null 2>&1; then
        log_success "DNS 解析正常"
    else
        log_warn "DNS 解析可能有问题"
    fi
}

# 检查必需的系统工具
check_system_tools() {
    log_info "检查系统工具..."
    
    local tools=("curl" "wget" "tar" "unzip" "openssl" "systemctl")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "$tool 已安装"
        else
            missing_tools+=("$tool")
            log_warn "$tool 未安装"
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_info "安装缺失的工具..."
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y "${missing_tools[@]}"
        elif command -v yum >/dev/null 2>&1; then
            yum install -y "${missing_tools[@]}"
        elif command -v apt >/dev/null 2>&1; then
            apt update && apt install -y "${missing_tools[@]}"
        else
            log_error "无法自动安装工具，请手动安装: ${missing_tools[*]}"
            return 1
        fi
    fi
}

# 检查 Node.js
check_nodejs() {
    log_info "检查 Node.js..."
    
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node --version | cut -d'v' -f2)
        MAJOR_VERSION=$(echo $NODE_VERSION | cut -d'.' -f1)
        
        if [ "$MAJOR_VERSION" -ge 18 ]; then
            log_success "Node.js 版本: v$NODE_VERSION (满足要求)"
        else
            log_error "Node.js 版本过低: v$NODE_VERSION，需要 18.0+"
            log_info "正在安装 Node.js 18..."
            install_nodejs
        fi
    else
        log_warn "Node.js 未安装"
        log_info "正在安装 Node.js 18..."
        install_nodejs
    fi
    
    # 检查 npm
    if command -v npm >/dev/null 2>&1; then
        NPM_VERSION=$(npm --version)
        log_success "npm 版本: $NPM_VERSION"
    else
        log_error "npm 未安装"
        return 1
    fi
}

# 安装 Node.js
install_nodejs() {
    log_info "安装 Node.js 18..."
    
    # 使用 NodeSource 仓库安装 Node.js 18
    if command -v dnf >/dev/null 2>&1; then
        # RHEL/CentOS/AlmaLinux
        curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
        dnf install -y nodejs
    elif command -v yum >/dev/null 2>&1; then
        # 旧版本 RHEL/CentOS
        curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
        yum install -y nodejs
    elif command -v apt >/dev/null 2>&1; then
        # Ubuntu/Debian
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt install -y nodejs
    else
        log_error "无法自动安装 Node.js，请手动安装"
        log_info "访问 https://nodejs.org/ 下载安装包"
        return 1
    fi
    
    # 验证安装
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node --version)
        log_success "Node.js 安装成功: $NODE_VERSION"
    else
        log_error "Node.js 安装失败"
        return 1
    fi
}

# 检查端口占用
check_ports() {
    log_info "检查端口占用..."
    
    local ports=(3000 8080)
    local occupied_ports=()
    
    for port in "${ports[@]}"; do
        if ss -tuln 2>/dev/null | grep -q ":$port " || \
           netstat -tuln 2>/dev/null | grep -q ":$port " || \
           lsof -i :$port 2>/dev/null | grep -q LISTEN; then
            occupied_ports+=("$port")
            log_warn "端口 $port 已被占用"
        else
            log_success "端口 $port 可用"
        fi
    done
    
    if [ ${#occupied_ports[@]} -gt 0 ]; then
        log_warn "以下端口被占用: ${occupied_ports[*]}"
        log_info "安装时可能需要修改端口配置"
    fi
}

# 检查磁盘空间
check_disk_space() {
    log_info "检查磁盘空间..."
    
    local required_space=1048576  # 1GB in KB
    local available_space=$(df /opt 2>/dev/null | awk 'NR==2 {print $4}' || df / | awk 'NR==2 {print $4}')
    
    if [ "$available_space" -gt "$required_space" ]; then
        log_success "磁盘空间充足: $(($available_space / 1024))MB 可用"
    else
        log_error "磁盘空间不足，需要至少 1GB 空间"
        return 1
    fi
}

# 检查防火墙
check_firewall() {
    log_info "检查防火墙设置..."
    
    if systemctl is-active --quiet firewalld; then
        log_info "firewalld 正在运行"
        log_warn "请确保开放端口 3000 和 8080"
        log_info "可以运行以下命令开放端口："
        echo "  firewall-cmd --permanent --add-port=3000/tcp"
        echo "  firewall-cmd --permanent --add-port=8080/tcp"
        echo "  firewall-cmd --reload"
    elif systemctl is-active --quiet ufw; then
        log_info "ufw 正在运行"
        log_warn "请确保开放端口 3000 和 8080"
        log_info "可以运行以下命令开放端口："
        echo "  ufw allow 3000"
        echo "  ufw allow 8080"
    else
        log_success "未检测到活跃的防火墙服务"
    fi
}

# 主函数
main() {
    echo
    echo "========================================"
    echo "    NewHTTPS 安装前检查"
    echo "========================================"
    echo
    
    local checks=(
        "check_root"
        "check_os"
        "check_network"
        "check_system_tools"
        "check_nodejs"
        "check_ports"
        "check_disk_space"
        "check_firewall"
    )
    
    local failed_checks=()
    
    for check in "${checks[@]}"; do
        if ! $check; then
            failed_checks+=("$check")
        fi
        echo
    done
    
    echo "========================================"
    if [ ${#failed_checks[@]} -eq 0 ]; then
        log_success "所有检查通过！系统已准备好安装 NewHTTPS"
        echo
        log_info "现在可以运行安装脚本："
        echo "  ./standalone-install.sh"
    else
        log_error "以下检查失败: ${failed_checks[*]}"
        log_info "请解决上述问题后重新运行检查"
        exit 1
    fi
    echo "========================================"
}

# 运行主函数
main "$@"
