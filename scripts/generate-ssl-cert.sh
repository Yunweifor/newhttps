#!/bin/bash

# NewHTTPS 自签名SSL证书生成脚本
# 适用于无域名环境，使用服务器IP: 8.134.166.234

set -euo pipefail

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SSL_DIR="$PROJECT_ROOT/ssl"
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
NewHTTPS 自签名SSL证书生成脚本

用法: $0 [选项]

选项:
    --ip IP             服务器IP地址 (默认: 8.134.166.234)
    --days DAYS         证书有效期天数 (默认: 365)
    --key-size SIZE     密钥长度 (默认: 2048)
    --force             强制覆盖现有证书
    --help              显示帮助信息

示例:
    $0                              # 使用默认配置生成证书
    $0 --ip 192.168.1.100          # 指定IP地址
    $0 --days 730 --key-size 4096  # 2年有效期，4096位密钥
    $0 --force                      # 强制重新生成证书

EOF
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."
    
    if ! command -v openssl &> /dev/null; then
        log_error "OpenSSL未安装，请先安装OpenSSL"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 创建SSL目录
create_ssl_directory() {
    log_info "创建SSL证书目录..."
    
    mkdir -p "$SSL_DIR"
    chmod 755 "$SSL_DIR"
    
    log_success "SSL目录创建完成: $SSL_DIR"
}

# 生成私钥
generate_private_key() {
    log_info "生成私钥 (${KEY_SIZE}位)..."
    
    openssl genrsa -out "$SSL_DIR/server.key" "$KEY_SIZE"
    chmod 600 "$SSL_DIR/server.key"
    
    log_success "私钥生成完成: $SSL_DIR/server.key"
}

# 创建证书配置文件
create_cert_config() {
    log_info "创建证书配置文件..."
    
    cat > "$SSL_DIR/server.conf" << EOF
[req]
default_bits = $KEY_SIZE
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=CN
ST=Beijing
L=Beijing
O=NewHTTPS
OU=SSL Certificate
CN=$SERVER_IP

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
IP.1 = $SERVER_IP
IP.2 = 127.0.0.1
DNS.1 = localhost
EOF

    log_success "证书配置文件创建完成: $SSL_DIR/server.conf"
}

# 生成证书签名请求
generate_csr() {
    log_info "生成证书签名请求..."
    
    openssl req -new \
        -key "$SSL_DIR/server.key" \
        -out "$SSL_DIR/server.csr" \
        -config "$SSL_DIR/server.conf"
    
    log_success "证书签名请求生成完成: $SSL_DIR/server.csr"
}

# 生成自签名证书
generate_certificate() {
    log_info "生成自签名证书 (有效期${CERT_DAYS}天)..."
    
    openssl x509 -req \
        -in "$SSL_DIR/server.csr" \
        -signkey "$SSL_DIR/server.key" \
        -out "$SSL_DIR/server.crt" \
        -days "$CERT_DAYS" \
        -extensions v3_req \
        -extfile "$SSL_DIR/server.conf"
    
    chmod 644 "$SSL_DIR/server.crt"
    
    log_success "自签名证书生成完成: $SSL_DIR/server.crt"
}

# 验证证书
verify_certificate() {
    log_info "验证证书..."
    
    # 检查证书有效性
    if openssl x509 -in "$SSL_DIR/server.crt" -text -noout > /dev/null 2>&1; then
        log_success "证书格式验证通过"
    else
        log_error "证书格式验证失败"
        exit 1
    fi
    
    # 检查私钥和证书匹配
    cert_modulus=$(openssl x509 -noout -modulus -in "$SSL_DIR/server.crt" | openssl md5)
    key_modulus=$(openssl rsa -noout -modulus -in "$SSL_DIR/server.key" | openssl md5)
    
    if [[ "$cert_modulus" == "$key_modulus" ]]; then
        log_success "私钥和证书匹配验证通过"
    else
        log_error "私钥和证书不匹配"
        exit 1
    fi
}

# 显示证书信息
show_certificate_info() {
    log_info "证书信息:"
    
    echo ""
    echo "证书文件:"
    echo "  私钥: $SSL_DIR/server.key"
    echo "  证书: $SSL_DIR/server.crt"
    echo "  配置: $SSL_DIR/server.conf"
    echo "  CSR: $SSL_DIR/server.csr"
    echo ""
    
    echo "证书详情:"
    openssl x509 -in "$SSL_DIR/server.crt" -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After :|DNS:|IP Address:)"
    echo ""
    
    echo "证书指纹:"
    echo "  SHA1: $(openssl x509 -in "$SSL_DIR/server.crt" -fingerprint -sha1 -noout | cut -d= -f2)"
    echo "  SHA256: $(openssl x509 -in "$SSL_DIR/server.crt" -fingerprint -sha256 -noout | cut -d= -f2)"
    echo ""
}

# 创建使用说明
create_usage_instructions() {
    log_info "创建使用说明..."
    
    cat > "$SSL_DIR/README.md" << EOF
# NewHTTPS 自签名SSL证书

## 证书信息

- **服务器IP**: $SERVER_IP
- **有效期**: $CERT_DAYS 天
- **密钥长度**: $KEY_SIZE 位
- **生成时间**: $(date)

## 文件说明

- \`server.key\` - 私钥文件
- \`server.crt\` - 证书文件
- \`server.conf\` - 证书配置文件
- \`server.csr\` - 证书签名请求

## 使用方法

### 1. Docker Compose配置

在 \`docker-compose.production.yml\` 中已配置:

\`\`\`yaml
volumes:
  - ./ssl:/etc/nginx/ssl-custom:ro
\`\`\`

### 2. Nginx配置

在 \`nginx/nginx.production.conf\` 中已配置:

\`\`\`nginx
ssl_certificate /etc/nginx/ssl-custom/server.crt;
ssl_certificate_key /etc/nginx/ssl-custom/server.key;
\`\`\`

### 3. 访问地址

- **HTTPS**: https://$SERVER_IP
- **HTTP**: http://$SERVER_IP

### 4. 浏览器警告

由于是自签名证书，浏览器会显示安全警告。这是正常的，点击"高级"→"继续访问"即可。

### 5. 证书更新

证书将在 $(date -d "+$CERT_DAYS days") 过期。
更新证书请重新运行: \`./scripts/generate-ssl-cert.sh --force\`

## 安全说明

- 私钥文件权限已设置为600，仅所有者可读写
- 证书文件权限已设置为644，所有者可读写，其他用户只读
- 请妥善保管私钥文件，不要泄露给他人

EOF

    log_success "使用说明创建完成: $SSL_DIR/README.md"
}

# 清理临时文件
cleanup_temp_files() {
    log_info "清理临时文件..."
    
    rm -f "$SSL_DIR/server.csr"
    
    log_success "临时文件清理完成"
}

# 解析命令行参数
SERVER_IP="8.134.166.234"
CERT_DAYS=365
KEY_SIZE=2048
FORCE_OVERWRITE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --ip)
            SERVER_IP="$2"
            shift 2
            ;;
        --days)
            CERT_DAYS="$2"
            shift 2
            ;;
        --key-size)
            KEY_SIZE="$2"
            shift 2
            ;;
        --force)
            FORCE_OVERWRITE=true
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
    
    log_info "开始生成SSL证书..."
    log_info "服务器IP: $SERVER_IP"
    log_info "有效期: $CERT_DAYS 天"
    log_info "密钥长度: $KEY_SIZE 位"
    
    # 检查是否已存在证书
    if [[ -f "$SSL_DIR/server.crt" ]] && [[ "$FORCE_OVERWRITE" != true ]]; then
        log_warning "SSL证书已存在: $SSL_DIR/server.crt"
        log_warning "如需重新生成，请使用 --force 参数"
        exit 1
    fi
    
    check_dependencies
    create_ssl_directory
    generate_private_key
    create_cert_config
    generate_csr
    generate_certificate
    verify_certificate
    show_certificate_info
    create_usage_instructions
    cleanup_temp_files
    
    log_success "SSL证书生成完成！"
    echo ""
    echo "🔒 HTTPS访问地址: https://$SERVER_IP"
    echo "📋 证书详情请查看: $SSL_DIR/README.md"
    echo ""
    echo "⚠️  浏览器安全警告是正常的，点击'高级'→'继续访问'即可"
}

# 执行主函数
main "$@"
