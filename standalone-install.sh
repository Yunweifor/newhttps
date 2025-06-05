#!/usr/bin/env bash

# NewHTTPS 独立安装脚本
# 无需 Docker，直接安装到系统

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
INSTALL_DIR="/opt/newhttps"
SERVICE_USER="newhttps"
API_PORT=3000
WEB_PORT=8080

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

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 权限运行此脚本"
        exit 1
    fi
}

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."
    
    # 检查操作系统
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_success "操作系统: Linux"
    else
        log_error "仅支持 Linux 系统"
        exit 1
    fi
    
    # 检查 Node.js
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node --version | cut -d'v' -f2)
        MAJOR_VERSION=$(echo $NODE_VERSION | cut -d'.' -f1)
        if [ "$MAJOR_VERSION" -ge 18 ]; then
            log_success "Node.js 版本: v$NODE_VERSION"
        else
            log_error "需要 Node.js 18.0 或更高版本，当前版本: v$NODE_VERSION"
            exit 1
        fi
    else
        log_error "Node.js 未安装，请先安装 Node.js 18.0+"
        exit 1
    fi
    
    # 检查 npm
    if command -v npm >/dev/null 2>&1; then
        log_success "npm 已安装"
    else
        log_error "npm 未安装"
        exit 1
    fi
    
    # 检查端口占用
    for port in $API_PORT $WEB_PORT; do
        if ss -tuln 2>/dev/null | grep -q ":$port " || \
           netstat -tuln 2>/dev/null | grep -q ":$port " || \
           lsof -i :$port 2>/dev/null | grep -q LISTEN; then
            log_warn "端口 $port 已被占用，可能会导致冲突"
        fi
    done
}

# 创建系统用户
create_user() {
    log_info "创建系统用户..."
    
    if id "$SERVICE_USER" &>/dev/null; then
        log_info "用户 $SERVICE_USER 已存在"
    else
        useradd --system  --shell /bin/bash "$SERVICE_USER"
        log_success "创建用户: $SERVICE_USER"
    fi
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    
    mkdir -p "$INSTALL_DIR"/{api,web,data,logs,config}
    mkdir -p "$INSTALL_DIR/data"/{newhttps,acme,certificates,acme-challenges}
    
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
    
    log_success "目录结构创建完成"
}

# 安装 API 服务
install_api() {
    log_info "安装 NewHTTPS API 服务..."

    # 获取当前脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # 检查是否在项目目录内运行
    if [ "$SCRIPT_DIR" = "$(pwd)" ]; then
        log_info "检测到在项目目录内运行，使用 rsync 复制文件..."

        # 使用 rsync 避免复制到自己
        if command -v rsync >/dev/null 2>&1; then
            rsync -av --exclude=node_modules --exclude=dist "$SCRIPT_DIR/api/" "$INSTALL_DIR/api/"
        else
            # 如果没有 rsync，手动复制关键文件
            cp "$SCRIPT_DIR/api/package.json" "$INSTALL_DIR/api/"
            cp "$SCRIPT_DIR/api/package-lock.json" "$INSTALL_DIR/api/" 2>/dev/null || true
            cp "$SCRIPT_DIR/api/tsconfig.json" "$INSTALL_DIR/api/"
            cp -r "$SCRIPT_DIR/api/src" "$INSTALL_DIR/api/"
            cp "$SCRIPT_DIR/api/.env.example" "$INSTALL_DIR/api/" 2>/dev/null || true
        fi
    else
        # 正常复制
        cp -r "$SCRIPT_DIR/api"/* "$INSTALL_DIR/api/"
    fi

    # 设置权限
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/api"

    # 安装依赖（包括开发依赖，用于构建）
    cd "$INSTALL_DIR/api"
    log_info "安装 Node.js 依赖..."

    if ! sudo -u "$SERVICE_USER" bash -lc 'npm install'; then
        log_error "npm install 失败"
        return 1
    fi

    # 构建项目
    log_info "构建 TypeScript 项目..."

    if ! sudo -u "$SERVICE_USER" bash -lc 'npm run build'; then
        log_error "TypeScript 构建失败"
        return 1
    fi

    # 重新安装仅生产依赖
    log_info "清理开发依赖..."
    if ! sudo -u "$SERVICE_USER" bash -lc 'npm prune --production'; then
        log_warn "清理开发依赖失败，但继续安装"
    fi

    log_success "API 服务安装完成"
}

# 安装 Web 界面
install_web() {
    log_info "安装 NewHTTPS Web 界面..."

    # 获取当前脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # 检查 web 目录是否存在
    if [ ! -d "$SCRIPT_DIR/web" ]; then
        log_warn "Web 目录不存在，跳过 Web 界面安装"
        log_info "您可以稍后手动安装 Web 界面或使用 API 直接管理"
        # 设置标志表示Web未安装
        WEB_INSTALLED=false
        return 0
    fi

    # 复制 Web 代码
    if [ "$SCRIPT_DIR" = "$(pwd)" ]; then
        if command -v rsync >/dev/null 2>&1; then
            rsync -av --exclude=node_modules --exclude=dist "$SCRIPT_DIR/web/" "$INSTALL_DIR/web/"
        else
            cp "$SCRIPT_DIR/web/package.json" "$INSTALL_DIR/web/"
            cp "$SCRIPT_DIR/web/package-lock.json" "$INSTALL_DIR/web/" 2>/dev/null || true
            cp -r "$SCRIPT_DIR/web/src" "$INSTALL_DIR/web/" 2>/dev/null || true
            cp "$SCRIPT_DIR/web/public" "$INSTALL_DIR/web/" 2>/dev/null || true
            cp "$SCRIPT_DIR/web/index.html" "$INSTALL_DIR/web/" 2>/dev/null || true
            cp "$SCRIPT_DIR/web/vite.config.ts" "$INSTALL_DIR/web/" 2>/dev/null || true
        fi
    else
        cp -r "$SCRIPT_DIR/web"/* "$INSTALL_DIR/web/"
    fi

    # 设置权限
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/web"

    # 检查是否有 package.json
    if [ ! -f "$INSTALL_DIR/web/package.json" ]; then
        log_warn "Web package.json 不存在，创建简单的静态服务"

        # 创建简单的静态文件服务
        mkdir -p "$INSTALL_DIR/web/public"
        cat > "$INSTALL_DIR/web/public/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>NewHTTPS</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>NewHTTPS API Server</h1>
    <p>API 服务正在运行</p>
    <p>访问 <a href="/api/health">/api/health</a> 检查 API 状态</p>
</body>
</html>
EOF
        return 0
    fi

    # 安装依赖
    cd "$INSTALL_DIR/web"
    log_info "安装 Web 依赖..."
    sudo -u "$SERVICE_USER" bash -lc 'npm install'

    # 构建项目
    log_info "构建 Web 项目..."
    sudo -u "$SERVICE_USER" bash -lc 'npm run build'

    # 设置标志表示Web已安装
    WEB_INSTALLED=true
    log_success "Web 界面安装完成"
}

# 生成配置文件
generate_config() {
    log_info "生成配置文件..."
    
    # 生成 JWT 密钥
    JWT_SECRET=$(openssl rand -base64 32)
    
    # API 配置
    cat > "$INSTALL_DIR/config/api.env" << EOF
# NewHTTPS API Configuration - Standalone Mode
PORT=$API_PORT
NODE_ENV=production

# Standalone Mode Settings
STANDALONE_MODE=true
ENABLE_CERT_APPLY=true
ENABLE_WEB_INTERFACE=true

# JWT Configuration
JWT_SECRET=$JWT_SECRET

# Database Configuration
DATABASE_PATH=$INSTALL_DIR/data/newhttps.db

# ACME Configuration
ACME_DATA_DIR=$INSTALL_DIR/data/acme
DEFAULT_CA=letsencrypt
DEFAULT_EMAIL=admin@localhost

# Certificate Storage
CERT_STORAGE_DIR=$INSTALL_DIR/data/certificates
ENABLE_AUTO_BACKUP=true

# Security
ENABLE_RATE_LIMITING=true
ENABLE_CORS=true
CORS_ORIGIN=http://localhost:$WEB_PORT

# Logging Configuration
LOG_LEVEL=INFO
LOG_FILE=$INSTALL_DIR/logs/api.log
EOF

    # Web 配置
    cat > "$INSTALL_DIR/config/web.env" << EOF
# NewHTTPS Web Configuration - Standalone Mode
VUE_APP_API_BASE_URL=http://localhost:$API_PORT
VUE_APP_MODE=standalone
VUE_APP_ENABLE_CERT_APPLY=true
VUE_APP_ENABLE_AGENT_MANAGEMENT=true
EOF

    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/config"
    
    log_success "配置文件生成完成"
}

# 创建 systemd 服务
create_services() {
    log_info "创建系统服务..."
    
    # API 服务
    cat > /etc/systemd/system/newhttps-api.service << EOF
[Unit]
Description=NewHTTPS API Service
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/api
ExecStart=/bin/bash -lc '/usr/bin/node dist/index.js'
Restart=always
RestartSec=10
EnvironmentFile=$INSTALL_DIR/config/api.env

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

    # 检查是否需要创建 Web 服务
    if [ "$WEB_INSTALLED" = "true" ] && [ -f "$INSTALL_DIR/web/package.json" ]; then
        # 完整的 Web 应用服务
        cat > /etc/systemd/system/newhttps-web.service << EOF
[Unit]
Description=NewHTTPS Web Service
After=network.target newhttps-api.service

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/web
ExecStartPre=/bin/bash -lc '/usr/bin/npm install -g serve'
ExecStart=/bin/bash -lc '/usr/bin/npx serve -s dist -l $WEB_PORT'
Restart=always
RestartSec=10
EnvironmentFile=$INSTALL_DIR/config/web.env

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF
    elif [ "$WEB_INSTALLED" = "true" ]; then
        # 简单的静态文件服务
        cat > /etc/systemd/system/newhttps-web.service << EOF
[Unit]
Description=NewHTTPS Web Service (Static)
After=network.target newhttps-api.service

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/web/public
ExecStartPre=/bin/bash -lc '/usr/bin/npm install -g serve'
ExecStart=/bin/bash -lc '/usr/bin/npx serve -s . -l $WEB_PORT'
Restart=always
RestartSec=10

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF
    fi

    # 重载 systemd
    systemctl daemon-reload
    
    log_success "系统服务创建完成"
}

# 启动服务
start_services() {
    log_info "启动服务..."

    # 启用并启动 API 服务
    systemctl enable newhttps-api
    systemctl start newhttps-api

    # 等待 API 启动
    sleep 5

    # 只有在Web安装成功时才启动Web服务
    if [ "$WEB_INSTALLED" = "true" ]; then
        systemctl enable newhttps-web
        systemctl start newhttps-web
        # 等待服务启动
        sleep 10
    fi

    log_success "服务启动完成"
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    
    # 检查服务状态
    if systemctl is-active --quiet newhttps-api; then
        log_success "NewHTTPS API 服务运行正常"
    else
        log_error "NewHTTPS API 服务启动失败"
        systemctl status newhttps-api
    fi
    
    if [ "$WEB_INSTALLED" = "true" ]; then
        if systemctl is-active --quiet newhttps-web; then
            log_success "NewHTTPS Web 服务运行正常"
        else
            log_error "NewHTTPS Web 服务启动失败"
            systemctl status newhttps-web
        fi
    else
        log_info "Web 服务未安装，跳过检查"
    fi
    
    # 检查 API 健康状态
    sleep 5
    if curl -f http://localhost:$API_PORT/health >/dev/null 2>&1; then
        log_success "NewHTTPS API 健康检查通过"
    else
        log_warn "NewHTTPS API 健康检查失败，请检查日志"
    fi
}

# 显示安装结果
show_results() {
    echo
    log_success "NewHTTPS 独立安装完成！"
    echo
    echo "访问地址："
    if [ "$WEB_INSTALLED" = "true" ]; then
        echo "  - NewHTTPS Web 界面: http://localhost:$WEB_PORT"
    fi
    echo "  - NewHTTPS API: http://localhost:$API_PORT"
    echo "  - API 健康检查: http://localhost:$API_PORT/health"
    echo
    echo "默认登录信息："
    echo "  - 用户名: admin"
    echo "  - 密码: admin123"
    echo "  - 请登录后立即修改默认密码"
    echo
    echo "系统服务："
    echo "  - API 服务: systemctl status newhttps-api"
    if [ "$WEB_INSTALLED" = "true" ]; then
        echo "  - Web 服务: systemctl status newhttps-web"
    fi
    echo "  - 查看日志: journalctl -u newhttps-api -f"
    echo
    echo "下一步："
    if [ "$WEB_INSTALLED" = "true" ]; then
        echo "  1. 访问 NewHTTPS Web 界面进行初始化设置"
    else
        echo "  1. 手动安装 Web 界面或直接使用 API 进行管理"
    fi
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
    echo "  - 独立部署指南: docs/standalone-deployment.md"
    echo "  - 安装指南: docs/install.md"
    echo "  - 使用指南: docs/usage.md"
    echo
    echo "管理命令："
    echo "  - 重启服务: systemctl restart newhttps-api newhttps-web"
    echo "  - 停止服务: systemctl stop newhttps-api newhttps-web"
    echo "  - 查看状态: systemctl status newhttps-api newhttps-web"
}

# 主函数
main() {
    echo
    echo "========================================"
    echo "    NewHTTPS 独立安装脚本"
    echo "========================================"
    echo

    # 初始化变量
    WEB_INSTALLED=false

    # 设置错误处理
    set -e
    trap 'log_error "安装过程中发生错误，请检查日志"; exit 1' ERR

    check_root
    check_requirements
    create_user
    create_directories

    # API 安装
    if ! install_api; then
        log_error "API 安装失败，停止安装"
        exit 1
    fi

    # Web 安装（可选）
    install_web

    generate_config
    create_services
    start_services
    verify_installation
    show_results
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
