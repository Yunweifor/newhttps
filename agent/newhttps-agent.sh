#!/usr/bin/env bash

# NewHTTPS Agent - 本地SSL证书部署代理
# 结合 Certd-2 证书申请能力和 httpsok.sh 本地部署能力
# Version: 1.0.0

################################################
# 配置变量 - 用户可以修改这些变量
################################################
NGINX_BIN=nginx
# NGINX_CONFIG=/etc/nginx/nginx.conf
# NGINX_CONFIG_HOME=/etc/nginx
# NEWHTTPS_API_URL=http://localhost:3000
# NEWHTTPS_AGENT_ID=""
# NEWHTTPS_TOKEN=""
##################################################

VER=1.0.0
PROJECT_NAME="newhttps-agent"
PROJECT_ENTRY="newhttps-agent.sh"

PROJECT_HOME="$HOME/.newhttps"
PROJECT_BACKUPS="$HOME/.newhttps/backups"
PROJECT_CERTS="$HOME/.newhttps/certs"
PROJECT_ENTRY_BIN="$PROJECT_HOME/$PROJECT_ENTRY"

PROJECT_CONFIG_FILE="$PROJECT_HOME/config"
PROJECT_LOG_FILE="$PROJECT_HOME/$PROJECT_NAME.log"
AGENT_ID_FILE="$PROJECT_HOME/agent_id"

# 默认配置
NEWHTTPS_API_URL="http://localhost:3000"
NEWHTTPS_AGENT_ID=""
NEWHTTPS_TOKEN=""
CHECK_INTERVAL=3600  # 1小时检查一次

OS=""
NGINX_VERSION=""
MODE="normal"

# 颜色输出函数
_err() {
  echo -e "\033[31m$(date +"%F %T") [ERROR] $@\033[0m" | tee -a "$PROJECT_LOG_FILE" >&2
}

_info() {
  echo -e "$(date +"%F %T") [INFO] $@" | tee -a "$PROJECT_LOG_FILE" >&2
}

_suc() {
  echo -e "\033[32m$(date +"%F %T") [SUCCESS] $@\033[0m" | tee -a "$PROJECT_LOG_FILE" >&2
}

_warn() {
  echo -e "\033[33m$(date +"%F %T") [WARN] $@\033[0m" | tee -a "$PROJECT_LOG_FILE" >&2
}

_debug() {
  if [ "$DEBUG" = "1" ]; then
    echo -e "\033[36m$(date +"%F %T") [DEBUG] $@\033[0m" | tee -a "$PROJECT_LOG_FILE" >&2
  fi
}

# 工具函数
_exists() {
  cmd="$1"
  if [ -z "$cmd" ]; then
    return 1
  fi
  
  if eval type type >/dev/null 2>&1; then
    eval type "$cmd" >/dev/null 2>&1
  elif command >/dev/null 2>&1; then
    command -v "$cmd" >/dev/null 2>&1
  else
    which "$cmd" >/dev/null 2>&1
  fi
  return $?
}

_mkdirs() {
  _dir="$1"
  if [ ! "$_dir" = "" ]; then
    if [ ! -d "$_dir" ]; then
      mkdir -p "$_dir" && _suc "Created directory $_dir"
    fi
  fi
}

_random_md5() {
  if _exists md5sum; then
    head -c 32 /dev/urandom | md5sum | awk '{print $1}'
  elif _exists md5; then
    head -c 32 /dev/urandom | md5
  else
    # 备用方案：使用时间戳和随机数
    echo "$(date +%s)$(( RANDOM * RANDOM ))" | sha256sum | awk '{print $1}' | head -c 32
  fi
}

# 显示欢迎信息
showWelcome() {
  echo
  echo -e "\033[1;36mNewHTTPS Agent - SSL Certificate Deployment Agent\033[0m"
  echo -e "\033[1;36mVersion: $VER\033[0m"
  echo -e "\033[1;36mCombining Certd-2 + httpsok.sh capabilities\033[0m"
  echo
}

# 初始化目录
_initpath() {
  _mkdirs "$PROJECT_HOME"
  _mkdirs "$PROJECT_BACKUPS"
  _mkdirs "$PROJECT_CERTS"
}

# 检测操作系统
_detect_os() {
  if [ -f /etc/os-release ]; then
    OS=$(grep 'PRETTY_NAME' /etc/os-release | awk -F '=' '{print $2}' | tr -d '"')
  elif [ -f /etc/redhat-release ]; then
    OS=$(cat /etc/redhat-release)
  elif [ -f /etc/alpine-release ]; then
    OS="alpine"
  else
    OS="unknown"
  fi
}

# 检测 Nginx
_detect_nginx() {
  # 检查 nginx 命令是否可用
  $NGINX_BIN -V > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    _info "nginx not found in PATH, searching for nginx process..."
    pid=$(ps -e | grep nginx | grep -v 'grep' | head -n 1 | awk '{print $1}')
    if [ -n "$pid" ]; then
      NGINX_BIN=$(readlink -f /proc/"$pid"/exe)
      $NGINX_BIN -V > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        _err "Cannot find valid nginx binary"
        return 1
      else
        _info "Found nginx binary: $NGINX_BIN"
      fi
    else
      _err "Nginx is not running or not installed"
      return 1
    fi
  fi

  NGINX_VERSION=$($NGINX_BIN -v 2>&1 | awk -F ': ' '{print $2}' | head -n 1 | head -c 20)

  # 获取 nginx 配置文件路径
  if [ -z "$NGINX_CONFIG" ]; then
    NGINX_CONFIG=$(ps -eo pid,cmd | grep nginx | grep master | grep '\-c' | awk -F '-c' '{print $2}' | sed 's/ //g')
  fi

  if [ -z "$NGINX_CONFIG" ] || [ "$NGINX_CONFIG" = "nginx.conf" ]; then
    NGINX_CONFIG=$($NGINX_BIN -t 2>&1 | grep 'configuration' | head -n 1 | awk -F 'file' '{print $2}' | awk '{print $1}')
  fi

  if [ -z "$NGINX_CONFIG_HOME" ]; then
    NGINX_CONFIG_HOME=$(dirname "$NGINX_CONFIG")
  fi

  _info "Nginx version: $NGINX_VERSION"
  _info "Nginx config: $NGINX_CONFIG"
  _info "Nginx config home: $NGINX_CONFIG_HOME"

  return 0
}

# 检查系统依赖
_check_dependencies() {
  _info "Checking system dependencies..."

  # 检查必需的命令
  local missing_deps=()

  if ! _exists curl && ! _exists wget; then
    missing_deps+=("curl or wget")
  fi

  if ! _exists openssl; then
    missing_deps+=("openssl")
  fi

  if ! _exists jq; then
    missing_deps+=("jq")
  fi

  if ! _exists md5sum && ! _exists md5; then
    missing_deps+=("md5sum or md5")
  fi

  if [ ${#missing_deps[@]} -gt 0 ]; then
    _err "Missing required dependencies: ${missing_deps[*]}"
    _info "Please install missing dependencies:"
    _info "  Ubuntu/Debian: apt-get install curl openssl jq coreutils"
    _info "  CentOS/RHEL: yum install curl openssl jq coreutils"
    _info "  Alpine: apk add curl openssl jq coreutils"
    return 1
  fi

  _suc "All dependencies are available"
  return 0
}

# 初始化系统参数
_init_params() {
  _detect_os

  if ! _check_dependencies; then
    _err "Dependency check failed"
    exit 1
  fi

  if ! _detect_nginx; then
    _err "Failed to detect nginx, please install nginx first"
    exit 1
  fi

  _info "OS: $OS"
  _info "Nginx: $NGINX_VERSION"
}

# 加载配置文件
_load_config() {
  if [ -f "$PROJECT_CONFIG_FILE" ]; then
    source "$PROJECT_CONFIG_FILE"
    _debug "Loaded config from $PROJECT_CONFIG_FILE"
  fi
  
  # 从环境变量覆盖配置
  if [ -n "$NEWHTTPS_API_URL_ENV" ]; then
    NEWHTTPS_API_URL="$NEWHTTPS_API_URL_ENV"
  fi
  
  if [ -n "$NEWHTTPS_TOKEN_ENV" ]; then
    NEWHTTPS_TOKEN="$NEWHTTPS_TOKEN_ENV"
  fi
}

# 保存配置文件
_save_config() {
  cat > "$PROJECT_CONFIG_FILE" << EOF
# NewHTTPS Agent Configuration
NEWHTTPS_API_URL="$NEWHTTPS_API_URL"
NEWHTTPS_AGENT_ID="$NEWHTTPS_AGENT_ID"
NEWHTTPS_TOKEN="$NEWHTTPS_TOKEN"
CHECK_INTERVAL=$CHECK_INTERVAL
NGINX_BIN="$NGINX_BIN"
NGINX_CONFIG="$NGINX_CONFIG"
NGINX_CONFIG_HOME="$NGINX_CONFIG_HOME"
EOF
  _suc "Configuration saved to $PROJECT_CONFIG_FILE"
}

# 生成或加载 Agent ID
_init_agent_id() {
  if [ -f "$AGENT_ID_FILE" ]; then
    NEWHTTPS_AGENT_ID=$(cat "$AGENT_ID_FILE")
    _debug "Loaded agent ID: $NEWHTTPS_AGENT_ID"
  else
    NEWHTTPS_AGENT_ID=$(_random_md5)
    echo "$NEWHTTPS_AGENT_ID" > "$AGENT_ID_FILE"
    _info "Generated new agent ID: $NEWHTTPS_AGENT_ID"
  fi
}

# HTTP 请求函数
_http_get() {
  url="$1"
  headers="$2"

  if _exists curl; then
    if [ -n "$headers" ]; then
      curl -s -H "$headers" "$url"
    else
      curl -s "$url"
    fi
  elif _exists wget; then
    if [ -n "$headers" ]; then
      wget -q -O - --header="$headers" "$url"
    else
      wget -q -O - "$url"
    fi
  else
    _err "Neither curl nor wget is available"
    return 1
  fi
}

_http_post() {
  url="$1"
  data="$2"
  headers="$3"

  if _exists curl; then
    if [ -n "$headers" ]; then
      curl -s -X POST -H "Content-Type: application/json" -H "$headers" -d "$data" "$url"
    else
      curl -s -X POST -H "Content-Type: application/json" -d "$data" "$url"
    fi
  else
    _err "curl is required for POST requests"
    return 1
  fi
}

# 注册 Agent 到 API 服务器
_register_agent() {
  _info "Registering agent with API server..."

  agent_info=$(cat << EOF
{
  "agent_id": "$NEWHTTPS_AGENT_ID",
  "hostname": "$(hostname)",
  "os": "$OS",
  "nginx_version": "$NGINX_VERSION",
  "nginx_config": "$NGINX_CONFIG",
  "version": "$VER"
}
EOF
)

  auth_header=""
  if [ -n "$NEWHTTPS_TOKEN" ]; then
    auth_header="Authorization: Bearer $NEWHTTPS_TOKEN"
  fi

  response=$(_http_post "$NEWHTTPS_API_URL/api/v1/agent/register" "$agent_info" "$auth_header")

  if echo "$response" | grep -q '"success":true'; then
    _suc "Agent registered successfully"
    return 0
  else
    _err "Failed to register agent: $response"
    return 1
  fi
}

# 解析 Nginx 配置，提取 SSL 证书信息
_parse_nginx_config() {
  _info "Parsing nginx configuration..."

  # 使用类似 httpsok.sh 的方法解析配置
  config_text=$(cat "$NGINX_CONFIG" | _process_include)

  # 提取 SSL 证书路径
  echo "$config_text" | awk '
    /ssl_certificate[^_]/ && !/ssl_certificate_key/ {
      gsub(/;/, "")
      gsub(/ssl_certificate/, "")
      gsub(/^[ \t]+/, "")
      gsub(/[ \t]+$/, "")
      if ($0 !~ /^#/ && $0 != "") {
        cert_file = $0
        getline
        if ($0 ~ /ssl_certificate_key/) {
          gsub(/;/, "")
          gsub(/ssl_certificate_key/, "")
          gsub(/^[ \t]+/, "")
          gsub(/[ \t]+$/, "")
          key_file = $0
          print cert_file "," key_file
        }
      }
    }
  ' > "$PROJECT_HOME/cert_paths.tmp"

  if [ -s "$PROJECT_HOME/cert_paths.tmp" ]; then
    _info "Found SSL certificates in nginx config"
    cat "$PROJECT_HOME/cert_paths.tmp"
  else
    _warn "No SSL certificates found in nginx config"
  fi
}

# 处理 include 指令（简化版）
_process_include() {
  awk -v NGINX_CONFIG_HOME="$NGINX_CONFIG_HOME" '
    /^[[:space:]]*include[[:space:]]/ && !/mime\.types/ {
      gsub(/;/, "")
      gsub(/include/, "")
      gsub(/^[[:space:]]+/, "")
      gsub(/[[:space:]]+$/, "")

      include_path = $0
      if (substr(include_path, 1, 1) != "/") {
        include_path = NGINX_CONFIG_HOME "/" include_path
      }

      # 简单处理，不递归展开
      print "# include " include_path
      next
    }
    { print }
  '
}

# 检查证书更新
_check_cert_updates() {
  _info "Checking for certificate updates..."

  # 获取本地证书信息
  local_certs="[]"
  if [ -f "$PROJECT_HOME/cert_paths.tmp" ]; then
    local_certs=$(cat "$PROJECT_HOME/cert_paths.tmp" | while read line; do
      if [ -n "$line" ]; then
        cert_file=$(echo "$line" | cut -d',' -f1)
        if [ -f "$cert_file" ]; then
          # 提取域名和更新时间
          domain=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed 's/.*CN=\([^,]*\).*/\1/')
          updated_at=$(stat -c %Y "$cert_file" 2>/dev/null || stat -f %m "$cert_file" 2>/dev/null)
          echo "{\"domain\":\"$domain\",\"cert_file\":\"$cert_file\",\"updated_at\":$updated_at}"
        fi
      fi
    done | jq -s '.')
  fi

  check_data=$(cat << EOF
{
  "agent_id": "$NEWHTTPS_AGENT_ID",
  "certificates": $local_certs
}
EOF
)

  auth_header=""
  if [ -n "$NEWHTTPS_TOKEN" ]; then
    auth_header="Authorization: Bearer $NEWHTTPS_TOKEN"
  fi

  response=$(_http_post "$NEWHTTPS_API_URL/api/v1/cert/check-updates" "$check_data" "$auth_header")

  if echo "$response" | grep -q '"success":true'; then
    has_updates=$(echo "$response" | jq -r '.data.hasUpdates')
    if [ "$has_updates" = "true" ]; then
      _info "Certificate updates available"
      echo "$response" | jq -r '.data.updates[]' > "$PROJECT_HOME/pending_updates.json"
      return 0
    else
      _info "No certificate updates available"
      return 1
    fi
  else
    _err "Failed to check updates: $response"
    return 1
  fi
}

# 下载证书
_download_cert() {
  cert_id="$1"
  domain="$2"

  _info "Downloading certificate for domain: $domain"

  auth_header=""
  if [ -n "$NEWHTTPS_TOKEN" ]; then
    auth_header="Authorization: Bearer $NEWHTTPS_TOKEN"
  fi

  # 下载证书详情
  cert_url="$NEWHTTPS_API_URL/api/v1/cert/$cert_id/details?agent_id=$NEWHTTPS_AGENT_ID"
  cert_details=$(_http_get "$cert_url" "$auth_header")

  if ! echo "$cert_details" | grep -q '"success":true'; then
    _err "Failed to get certificate details: $cert_details"
    return 1
  fi

  # 提取证书内容
  cert_crt=$(echo "$cert_details" | jq -r '.data.crt')
  cert_key=$(echo "$cert_details" | jq -r '.data.key')

  if [ "$cert_crt" = "null" ] || [ "$cert_key" = "null" ]; then
    _err "Invalid certificate data received"
    return 1
  fi

  # 保存到临时文件
  temp_crt="$PROJECT_CERTS/${domain}.crt.tmp"
  temp_key="$PROJECT_CERTS/${domain}.key.tmp"

  echo "$cert_crt" > "$temp_crt"
  echo "$cert_key" > "$temp_key"

  # 验证证书
  if ! openssl x509 -in "$temp_crt" -noout -text >/dev/null 2>&1; then
    _err "Downloaded certificate is invalid"
    rm -f "$temp_crt" "$temp_key"
    return 1
  fi

  _suc "Certificate downloaded successfully for domain: $domain"
  return 0
}

# 备份现有证书
_backup_cert() {
  cert_file="$1"
  key_file="$2"

  if [ ! -f "$cert_file" ] || [ ! -f "$key_file" ]; then
    _warn "Certificate files not found, skipping backup"
    return 0
  fi

  timestamp=$(date +"%Y%m%d_%H%M%S")
  cert_backup="$PROJECT_BACKUPS/$(basename "$cert_file").$timestamp"
  key_backup="$PROJECT_BACKUPS/$(basename "$key_file").$timestamp"

  cp "$cert_file" "$cert_backup" && cp "$key_file" "$key_backup"

  if [ $? -eq 0 ]; then
    _suc "Backed up certificates to $PROJECT_BACKUPS"
    return 0
  else
    _err "Failed to backup certificates"
    return 1
  fi
}

# 部署证书
_deploy_cert() {
  domain="$1"
  cert_file="$2"
  key_file="$3"

  _info "Deploying certificate for domain: $domain"

  temp_crt="$PROJECT_CERTS/${domain}.crt.tmp"
  temp_key="$PROJECT_CERTS/${domain}.key.tmp"

  if [ ! -f "$temp_crt" ] || [ ! -f "$temp_key" ]; then
    _err "Temporary certificate files not found"
    return 1
  fi

  # 备份现有证书
  if ! _backup_cert "$cert_file" "$key_file"; then
    _warn "Backup failed, but continuing with deployment"
  fi

  # 创建目标目录
  cert_dir=$(dirname "$cert_file")
  key_dir=$(dirname "$key_file")

  if [ ! -d "$cert_dir" ]; then
    mkdir -p "$cert_dir"
  fi

  if [ ! -d "$key_dir" ]; then
    mkdir -p "$key_dir"
  fi

  # 复制新证书
  cp "$temp_crt" "$cert_file" && cp "$temp_key" "$key_file"

  if [ $? -eq 0 ]; then
    # 设置正确的权限
    chmod 644 "$cert_file"
    chmod 600 "$key_file"

    # 清理临时文件
    rm -f "$temp_crt" "$temp_key"

    _suc "Certificate deployed successfully for domain: $domain"
    return 0
  else
    _err "Failed to deploy certificate for domain: $domain"
    return 1
  fi
}

# 测试 Nginx 配置
_test_nginx() {
  _info "Testing nginx configuration..."

  cd "$NGINX_CONFIG_HOME"
  test_result=$($NGINX_BIN -t 2>&1)

  if [ $? -eq 0 ]; then
    _suc "Nginx configuration test passed"
    return 0
  else
    _err "Nginx configuration test failed: $test_result"
    return 1
  fi
}

# 重载 Nginx
_reload_nginx() {
  _info "Reloading nginx..."

  cd "$NGINX_CONFIG_HOME"

  if ! _test_nginx; then
    _err "Cannot reload nginx due to configuration errors"
    return 1
  fi

  reload_result=$($NGINX_BIN -s reload 2>&1)

  if [ $? -eq 0 ]; then
    _suc "Nginx reloaded successfully"
    return 0
  else
    # 检查 nginx 是否在运行
    pid=$(ps -e | grep nginx | grep -v 'grep' | head -n 1 | awk '{print $1}')
    if [ -z "$pid" ]; then
      _warn "Nginx is not running, trying to start..."
      service nginx start 2>/dev/null || systemctl start nginx 2>/dev/null
    else
      _err "Nginx reload failed: $reload_result"
      return 1
    fi
  fi
}

# 处理证书更新
_process_updates() {
  if [ ! -f "$PROJECT_HOME/pending_updates.json" ]; then
    _info "No pending updates to process"
    return 0
  fi

  _info "Processing certificate updates..."

  updated_count=0
  failed_count=0

  # 解析 nginx 配置获取证书路径映射
  _parse_nginx_config >/dev/null

  while read -r update_line; do
    if [ -z "$update_line" ]; then
      continue
    fi

    domain=$(echo "$update_line" | jq -r '.domain')
    cert_id=$(echo "$update_line" | jq -r '.certId')

    _info "Processing update for domain: $domain"

    # 查找对应的证书文件路径
    cert_paths=$(grep "$domain" "$PROJECT_HOME/cert_paths.tmp" 2>/dev/null)
    if [ -z "$cert_paths" ]; then
      _warn "No certificate path found for domain: $domain"
      continue
    fi

    cert_file=$(echo "$cert_paths" | cut -d',' -f1)
    key_file=$(echo "$cert_paths" | cut -d',' -f2)

    # 下载新证书
    if _download_cert "$cert_id" "$domain"; then
      # 部署证书
      if _deploy_cert "$domain" "$cert_file" "$key_file"; then
        updated_count=$((updated_count + 1))
        _suc "Successfully updated certificate for domain: $domain"
      else
        failed_count=$((failed_count + 1))
        _err "Failed to deploy certificate for domain: $domain"
      fi
    else
      failed_count=$((failed_count + 1))
      _err "Failed to download certificate for domain: $domain"
    fi

  done < "$PROJECT_HOME/pending_updates.json"

  # 如果有成功更新的证书，重载 nginx
  if [ $updated_count -gt 0 ]; then
    _info "Updated $updated_count certificates, reloading nginx..."
    if _reload_nginx; then
      _suc "All certificate updates completed successfully"
    else
      _err "Certificate updates completed but nginx reload failed"
    fi
  fi

  if [ $failed_count -gt 0 ]; then
    _warn "$failed_count certificate updates failed"
  fi

  # 清理待处理更新文件
  rm -f "$PROJECT_HOME/pending_updates.json"

  return 0
}

# 主运行函数
_run() {
  _info "Starting NewHTTPS Agent..."

  # 初始化
  _initpath
  _load_config
  _init_agent_id
  _init_params

  # 注册 agent
  if ! _register_agent; then
    _err "Failed to register agent, exiting"
    return 1
  fi

  # 解析 nginx 配置
  _parse_nginx_config >/dev/null

  # 检查证书更新
  if _check_cert_updates; then
    # 处理更新
    _process_updates
  else
    _info "No certificate updates needed"
  fi

  _suc "NewHTTPS Agent run completed"
}

# 安装函数
_install() {
  _info "Installing NewHTTPS Agent..."

  _initpath
  _init_agent_id
  _init_params

  # 复制脚本到安装目录
  if [ "$0" != "$PROJECT_ENTRY_BIN" ]; then
    cp "$0" "$PROJECT_ENTRY_BIN"
    chmod +x "$PROJECT_ENTRY_BIN"
    _suc "Agent script installed to $PROJECT_ENTRY_BIN"
  fi

  # 安装 cron 任务
  _install_cron

  # 创建配置文件
  _save_config

  _suc "NewHTTPS Agent installation completed"
  echo
  echo "Next steps:"
  echo "1. Configure your API URL and token:"
  echo "   $PROJECT_ENTRY_BIN --config"
  echo "2. Test the agent:"
  echo "   $PROJECT_ENTRY_BIN --run"
}

# 安装 cron 任务
_install_cron() {
  if ! _exists crontab; then
    _warn "crontab not found, please install cron"
    return 1
  fi

  # 检查是否已经安装了 cron 任务
  if crontab -l 2>/dev/null | grep -q "$PROJECT_ENTRY"; then
    _info "Cron job already exists"
    return 0
  fi

  # 生成随机的分钟数，避免所有服务器同时运行
  random_minute=$(($(date +%s) % 60))

  _info "Installing cron job..."

  # 添加 cron 任务
  (crontab -l 2>/dev/null; echo "$random_minute * * * * '$PROJECT_ENTRY_BIN' --run >> '$PROJECT_LOG_FILE' 2>&1") | crontab -

  if [ $? -eq 0 ]; then
    _suc "Cron job installed successfully (runs every hour at minute $random_minute)"
  else
    _err "Failed to install cron job"
    return 1
  fi
}

# 卸载函数
_uninstall() {
  _info "Uninstalling NewHTTPS Agent..."

  # 移除 cron 任务
  if _exists crontab; then
    crontab -l 2>/dev/null | grep -v "$PROJECT_ENTRY" | crontab -
    _info "Removed cron job"
  fi

  # 移除安装目录
  if [ -d "$PROJECT_HOME" ]; then
    read -p "Remove all data including backups? (y/N): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
      rm -rf "$PROJECT_HOME"
      _suc "Removed all agent data"
    else
      rm -f "$PROJECT_ENTRY_BIN" "$PROJECT_CONFIG_FILE" "$AGENT_ID_FILE"
      _suc "Removed agent binary and config (kept backups)"
    fi
  fi

  _suc "NewHTTPS Agent uninstalled"
}

# 配置函数
_configure() {
  _info "Configuring NewHTTPS Agent..."

  _initpath
  _load_config

  echo
  echo "Current configuration:"
  echo "API URL: ${NEWHTTPS_API_URL:-not set}"
  echo "Agent ID: ${NEWHTTPS_AGENT_ID:-not set}"
  echo "Token: ${NEWHTTPS_TOKEN:+***set***}"
  echo

  read -p "API URL [$NEWHTTPS_API_URL]: " new_api_url
  if [ -n "$new_api_url" ]; then
    NEWHTTPS_API_URL="$new_api_url"
  fi

  read -p "Token: " new_token
  if [ -n "$new_token" ]; then
    NEWHTTPS_TOKEN="$new_token"
  fi

  read -p "Check interval in seconds [$CHECK_INTERVAL]: " new_interval
  if [ -n "$new_interval" ]; then
    CHECK_INTERVAL="$new_interval"
  fi

  _save_config
  _suc "Configuration updated"
}

# 状态检查函数
_status() {
  _info "NewHTTPS Agent Status"
  echo

  _load_config

  echo "Configuration:"
  echo "  API URL: ${NEWHTTPS_API_URL:-not set}"
  echo "  Agent ID: ${NEWHTTPS_AGENT_ID:-not set}"
  echo "  Token: ${NEWHTTPS_TOKEN:+***set***}"
  echo "  Check Interval: ${CHECK_INTERVAL}s"
  echo

  echo "System:"
  echo "  OS: $OS"
  echo "  Nginx: $NGINX_VERSION"
  echo "  Config: $NGINX_CONFIG"
  echo

  echo "Files:"
  echo "  Home: $PROJECT_HOME"
  echo "  Log: $PROJECT_LOG_FILE"
  echo "  Backups: $PROJECT_BACKUPS"
  echo

  # 检查 cron 任务
  if _exists crontab && crontab -l 2>/dev/null | grep -q "$PROJECT_ENTRY"; then
    echo "Cron job: installed"
  else
    echo "Cron job: not installed"
  fi

  # 检查 API 连接
  if [ -n "$NEWHTTPS_API_URL" ] && [ -n "$NEWHTTPS_TOKEN" ]; then
    auth_header="Authorization: Bearer $NEWHTTPS_TOKEN"
    if _http_get "$NEWHTTPS_API_URL/health" "$auth_header" >/dev/null 2>&1; then
      echo "API connection: OK"
    else
      echo "API connection: Failed"
    fi
  else
    echo "API connection: Not configured"
  fi
}

# 显示帮助
_show_help() {
  echo "NewHTTPS Agent v$VER"
  echo "SSL Certificate Deployment Agent combining Certd-2 + httpsok.sh"
  echo
  echo "Usage: $PROJECT_ENTRY [OPTION]"
  echo
  echo "Options:"
  echo "  --run, -r           Run certificate check and update"
  echo "  --install, -i       Install agent and setup cron job"
  echo "  --uninstall, -u     Uninstall agent"
  echo "  --config, -c        Configure agent settings"
  echo "  --status, -s        Show agent status"
  echo "  --version, -v       Show version"
  echo "  --help, -h          Show this help"
  echo
  echo "Examples:"
  echo "  $PROJECT_ENTRY --install"
  echo "  $PROJECT_ENTRY --config"
  echo "  $PROJECT_ENTRY --run"
  echo
  echo "For more information, visit: https://github.com/your-repo/newhttps"
}

# 命令行参数处理
_process_args() {
  while [ ${#} -gt 0 ]; do
    case "${1}" in
      --help | -h)
        _show_help
        return 0
        ;;
      --version | -v)
        echo "$PROJECT_ENTRY v$VER"
        return 0
        ;;
      --run | -r)
        _run
        return $?
        ;;
      --install | -i)
        _install
        return $?
        ;;
      --uninstall | -u)
        _uninstall
        return $?
        ;;
      --config | -c)
        _configure
        return $?
        ;;
      --status | -s)
        _status
        return $?
        ;;
      --debug)
        DEBUG=1
        ;;
      *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        return 1
        ;;
    esac
    shift 1
  done
}

# 主函数
main() {
  # 如果没有参数，显示帮助
  if [ $# -eq 0 ]; then
    showWelcome
    _show_help
    return 0
  fi

  # 处理命令行参数
  _process_args "$@"
}

# 脚本入口点
main "$@"
