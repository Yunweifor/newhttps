#!/bin/bash

# NewHTTPS Agent Server
# 接收来自服务器的部署命令并执行证书部署

set -euo pipefail

# 配置
AGENT_PORT=${AGENT_PORT:-8443}
AGENT_ID=${AGENT_ID:-$(hostname)}
API_KEY=${API_KEY:-""}
LOG_FILE=${LOG_FILE:-"/var/log/newhttps-agent.log"}
CERT_DIR=${CERT_DIR:-"/etc/ssl/newhttps"}
BACKUP_DIR=${BACKUP_DIR:-"/var/backups/newhttps"}

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

# 创建必要的目录
create_directories() {
    mkdir -p "$CERT_DIR" "$BACKUP_DIR"
    chmod 700 "$CERT_DIR" "$BACKUP_DIR"
}

# 验证API密钥
verify_api_key() {
    local provided_key="$1"
    if [[ -z "$API_KEY" ]]; then
        log_error "API_KEY not configured"
        return 1
    fi
    
    if [[ "$provided_key" != "$API_KEY" ]]; then
        log_error "Invalid API key"
        return 1
    fi
    
    return 0
}

# 处理部署命令
handle_deploy() {
    local request_body="$1"
    
    # 解析JSON请求（简化版本，实际应该使用jq）
    local cert_data=$(echo "$request_body" | grep -o '"cert":"[^"]*"' | cut -d'"' -f4)
    local key_data=$(echo "$request_body" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    local chain_data=$(echo "$request_body" | grep -o '"chain":"[^"]*"' | cut -d'"' -f4)
    local domains=$(echo "$request_body" | grep -o '"domains":\[[^]]*\]' | sed 's/"domains":\[//;s/\]//;s/"//g')
    
    if [[ -z "$cert_data" || -z "$key_data" ]]; then
        echo '{"success":false,"error":"Missing certificate or key data"}'
        return 1
    fi
    
    local domain=$(echo "$domains" | cut -d',' -f1)
    local cert_file="$CERT_DIR/${domain}.crt"
    local key_file="$CERT_DIR/${domain}.key"
    local chain_file="$CERT_DIR/${domain}-chain.crt"
    
    log "Deploying certificate for domain: $domain"
    
    # 备份现有证书
    if [[ -f "$cert_file" ]]; then
        local backup_timestamp=$(date +%Y%m%d_%H%M%S)
        cp "$cert_file" "$BACKUP_DIR/${domain}_${backup_timestamp}.crt" || true
        cp "$key_file" "$BACKUP_DIR/${domain}_${backup_timestamp}.key" || true
    fi
    
    # 写入新证书文件
    echo "$cert_data" | base64 -d > "$cert_file"
    echo "$key_data" | base64 -d > "$key_file"
    if [[ -n "$chain_data" ]]; then
        echo "$chain_data" | base64 -d > "$chain_file"
    fi
    
    # 设置正确的权限
    chmod 644 "$cert_file" "$chain_file"
    chmod 600 "$key_file"
    
    # 验证证书
    if ! openssl x509 -in "$cert_file" -noout -text >/dev/null 2>&1; then
        log_error "Invalid certificate file"
        echo '{"success":false,"error":"Invalid certificate file"}'
        return 1
    fi
    
    # 验证私钥
    if ! openssl rsa -in "$key_file" -check -noout >/dev/null 2>&1; then
        log_error "Invalid private key file"
        echo '{"success":false,"error":"Invalid private key file"}'
        return 1
    fi
    
    # 检查证书和私钥是否匹配
    local cert_modulus=$(openssl x509 -noout -modulus -in "$cert_file" | openssl md5)
    local key_modulus=$(openssl rsa -noout -modulus -in "$key_file" | openssl md5)
    
    if [[ "$cert_modulus" != "$key_modulus" ]]; then
        log_error "Certificate and private key do not match"
        echo '{"success":false,"error":"Certificate and private key do not match"}'
        return 1
    fi
    
    # 更新Nginx配置（如果存在）
    update_nginx_config "$domain" "$cert_file" "$key_file" "$chain_file"
    
    log "Certificate deployed successfully for domain: $domain"
    echo '{"success":true,"message":"Certificate deployed successfully"}'
    return 0
}

# 更新Nginx配置
update_nginx_config() {
    local domain="$1"
    local cert_file="$2"
    local key_file="$3"
    local chain_file="$4"
    
    # 查找Nginx配置文件
    local nginx_configs=(
        "/etc/nginx/sites-enabled/${domain}"
        "/etc/nginx/sites-enabled/${domain}.conf"
        "/etc/nginx/conf.d/${domain}.conf"
        "/etc/nginx/nginx.conf"
    )
    
    local config_updated=false
    
    for config_file in "${nginx_configs[@]}"; do
        if [[ -f "$config_file" ]] && grep -q "$domain" "$config_file"; then
            log "Updating Nginx config: $config_file"
            
            # 备份配置文件
            local backup_timestamp=$(date +%Y%m%d_%H%M%S)
            cp "$config_file" "$BACKUP_DIR/$(basename "$config_file")_${backup_timestamp}"
            
            # 更新SSL证书路径
            sed -i.bak \
                -e "s|ssl_certificate[[:space:]]\+[^;]*;|ssl_certificate $cert_file;|g" \
                -e "s|ssl_certificate_key[[:space:]]\+[^;]*;|ssl_certificate_key $key_file;|g" \
                "$config_file"
            
            config_updated=true
            break
        fi
    done
    
    if [[ "$config_updated" == "true" ]]; then
        # 测试Nginx配置
        if nginx -t >/dev/null 2>&1; then
            # 重载Nginx
            if systemctl reload nginx >/dev/null 2>&1; then
                log "Nginx reloaded successfully"
            else
                log_error "Failed to reload Nginx"
            fi
        else
            log_error "Nginx configuration test failed"
        fi
    else
        log "No Nginx configuration found for domain: $domain"
    fi
}

# 处理验证请求
handle_verify() {
    local request_body="$1"
    
    # 解析域名和端口
    local domain=$(echo "$request_body" | grep -o '"domain":"[^"]*"' | cut -d'"' -f4)
    local port=$(echo "$request_body" | grep -o '"port":[0-9]*' | cut -d':' -f2)
    
    if [[ -z "$domain" ]]; then
        echo '{"success":false,"error":"Missing domain"}'
        return 1
    fi
    
    port=${port:-443}
    
    log "Verifying certificate for domain: $domain:$port"
    
    # 检查SSL证书
    local cert_info
    if cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:$port" 2>/dev/null | openssl x509 -noout -text 2>/dev/null); then
        local expiry_date=$(echo "$cert_info" | grep "Not After" | cut -d':' -f2- | xargs)
        log "Certificate verification successful. Expires: $expiry_date"
        echo "{\"success\":true,\"message\":\"Certificate verification successful\",\"expiry\":\"$expiry_date\"}"
        return 0
    else
        log_error "Certificate verification failed for $domain:$port"
        echo '{"success":false,"error":"Certificate verification failed"}'
        return 1
    fi
}

# 处理ping请求
handle_ping() {
    echo '{"status":"ok","timestamp":"'$(date -Iseconds)'","agent_id":"'$AGENT_ID'"}'
}

# HTTP请求处理器
handle_request() {
    local method="$1"
    local path="$2"
    local headers="$3"
    local body="$4"
    
    # 验证API密钥
    local auth_header=$(echo "$headers" | grep -i "authorization:" | cut -d' ' -f2-)
    if [[ "$auth_header" != "Bearer $API_KEY" ]]; then
        echo "HTTP/1.1 401 Unauthorized"
        echo "Content-Type: application/json"
        echo ""
        echo '{"error":"Unauthorized"}'
        return
    fi
    
    # 路由处理
    case "$path" in
        "/api/v1/ping")
            echo "HTTP/1.1 200 OK"
            echo "Content-Type: application/json"
            echo ""
            handle_ping
            ;;
        "/api/v1/deploy")
            if [[ "$method" == "POST" ]]; then
                echo "HTTP/1.1 200 OK"
                echo "Content-Type: application/json"
                echo ""
                handle_deploy "$body"
            else
                echo "HTTP/1.1 405 Method Not Allowed"
                echo ""
            fi
            ;;
        "/api/v1/verify")
            if [[ "$method" == "POST" ]]; then
                echo "HTTP/1.1 200 OK"
                echo "Content-Type: application/json"
                echo ""
                handle_verify "$body"
            else
                echo "HTTP/1.1 405 Method Not Allowed"
                echo ""
            fi
            ;;
        *)
            echo "HTTP/1.1 404 Not Found"
            echo ""
            ;;
    esac
}

# 简单的HTTP服务器
start_server() {
    log "Starting NewHTTPS Agent Server on port $AGENT_PORT"
    log "Agent ID: $AGENT_ID"
    
    # 使用netcat作为简单的HTTP服务器
    while true; do
        {
            # 读取HTTP请求
            local request_line
            read -r request_line
            local method=$(echo "$request_line" | cut -d' ' -f1)
            local path=$(echo "$request_line" | cut -d' ' -f2)
            
            # 读取headers
            local headers=""
            local line
            while read -r line && [[ "$line" != $'\r' ]]; do
                headers="$headers$line"$'\n'
            done
            
            # 读取body（如果有Content-Length）
            local content_length=$(echo "$headers" | grep -i "content-length:" | cut -d' ' -f2 | tr -d '\r')
            local body=""
            if [[ -n "$content_length" && "$content_length" -gt 0 ]]; then
                body=$(head -c "$content_length")
            fi
            
            # 处理请求
            handle_request "$method" "$path" "$headers" "$body"
            
        } | nc -l -p "$AGENT_PORT" -q 1
        
        # 短暂休息避免CPU占用过高
        sleep 0.1
    done
}

# 主函数
main() {
    if [[ $# -gt 0 && "$1" == "--help" ]]; then
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --help          Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  AGENT_PORT      Port to listen on (default: 8443)"
        echo "  AGENT_ID        Agent identifier (default: hostname)"
        echo "  API_KEY         API key for authentication"
        echo "  LOG_FILE        Log file path (default: /var/log/newhttps-agent.log)"
        echo "  CERT_DIR        Certificate directory (default: /etc/ssl/newhttps)"
        echo "  BACKUP_DIR      Backup directory (default: /var/backups/newhttps)"
        exit 0
    fi
    
    # 检查依赖
    for cmd in openssl nc nginx; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done
    
    # 检查API密钥
    if [[ -z "$API_KEY" ]]; then
        log_error "API_KEY environment variable is required"
        exit 1
    fi
    
    # 创建目录
    create_directories
    
    # 启动服务器
    start_server
}

# 信号处理
trap 'log "Agent server stopped"; exit 0' SIGTERM SIGINT

# 运行主函数
main "$@"
