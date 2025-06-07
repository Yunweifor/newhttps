#!/bin/bash

# NewHTTPS 本地CI/CD脚本 - GitHub Actions替代方案
# 提供类似CI/CD的本地自动化构建、测试和部署功能

set -euo pipefail

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
VERSION=${VERSION:-$(git rev-parse --short HEAD 2>/dev/null || echo "latest")}

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
NewHTTPS 本地CI/CD脚本

用法: $0 [选项] [命令]

命令:
    check       代码检查和测试
    build       构建所有镜像
    test        运行测试套件
    security    安全扫描
    deploy      部署到指定环境
    full        完整CI/CD流程

选项:
    --env ENV           目标环境 (dev/staging/prod)
    --skip-tests        跳过测试
    --skip-security     跳过安全扫描
    --push              推送镜像到注册表
    --clean             构建前清理缓存
    --help              显示帮助信息

示例:
    $0 full --env prod              # 完整生产部署流程
    $0 build --clean                # 清理缓存后构建
    $0 deploy --env staging         # 部署到预发布环境

EOF
}

# 代码检查
code_check() {
    log_info "执行代码检查..."
    
    # 检查Git状态
    if [[ -n $(git status --porcelain) ]]; then
        log_warning "工作目录有未提交的更改"
        git status --short
    fi
    
    # 检查必要文件
    local required_files=(
        "Dockerfile.base"
        "api/Dockerfile.optimized"
        "web/Dockerfile.optimized"
        "docker-compose.optimized.yml"
        ".env.example"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            log_error "必要文件缺失: $file"
            exit 1
        fi
    done
    
    log_success "代码检查通过"
}

# 运行测试
run_tests() {
    if [[ "$SKIP_TESTS" == true ]]; then
        log_warning "跳过测试"
        return 0
    fi
    
    log_info "运行测试套件..."
    
    # 启动测试环境
    docker-compose -f docker-compose.dev.yml up -d --build
    
    # 等待服务启动
    sleep 30
    
    # 运行API测试
    if docker-compose -f docker-compose.dev.yml exec -T newhttps-api-dev npm test; then
        log_success "API测试通过"
    else
        log_error "API测试失败"
        docker-compose -f docker-compose.dev.yml logs newhttps-api-dev
        exit 1
    fi
    
    # 运行Web测试
    if docker-compose -f docker-compose.dev.yml exec -T newhttps-web-dev npm test; then
        log_success "Web测试通过"
    else
        log_error "Web测试失败"
        docker-compose -f docker-compose.dev.yml logs newhttps-web-dev
        exit 1
    fi
    
    # 清理测试环境
    docker-compose -f docker-compose.dev.yml down
    
    log_success "所有测试通过"
}

# 安全扫描
security_scan() {
    if [[ "$SKIP_SECURITY" == true ]]; then
        log_warning "跳过安全扫描"
        return 0
    fi
    
    log_info "执行安全扫描..."
    
    # 检查是否安装了trivy
    if ! command -v trivy &> /dev/null; then
        log_warning "Trivy未安装，跳过安全扫描"
        log_info "安装Trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
        return 0
    fi
    
    # 扫描镜像
    local images=("newhttps-base:latest" "newhttps-api:latest" "newhttps-web:latest")
    
    for image in "${images[@]}"; do
        log_info "扫描镜像: $image"
        if trivy image --exit-code 1 --severity HIGH,CRITICAL "$image"; then
            log_success "$image 安全扫描通过"
        else
            log_error "$image 发现高危漏洞"
            exit 1
        fi
    done
    
    log_success "安全扫描完成"
}

# 构建镜像
build_images() {
    log_info "构建Docker镜像..."
    
    local build_args=""
    if [[ "$CLEAN_BUILD" == true ]]; then
        build_args="--no-cache"
    fi
    
    if [[ "$PUSH_IMAGES" == true ]]; then
        build_args="$build_args --push"
    fi
    
    "$SCRIPT_DIR/build.sh" all --$TARGET_ENV $build_args
    
    log_success "镜像构建完成"
}

# 部署服务
deploy_services() {
    log_info "部署到 $TARGET_ENV 环境..."
    
    local deploy_args="--build"
    if [[ "$TARGET_ENV" == "prod" ]]; then
        deploy_args="$deploy_args --backup"
    fi
    
    "$SCRIPT_DIR/deploy.sh" "$TARGET_ENV" $deploy_args
    
    log_success "部署完成"
}

# 完整CI/CD流程
full_pipeline() {
    log_info "开始完整CI/CD流程..."
    
    code_check
    build_images
    run_tests
    security_scan
    deploy_services
    
    log_success "完整CI/CD流程执行成功！"
    log_info "访问地址:"
    log_info "  API: http://localhost:3000"
    log_info "  Web: http://localhost:8080"
}

# 解析命令行参数
TARGET_ENV="dev"
SKIP_TESTS=false
SKIP_SECURITY=false
PUSH_IMAGES=false
CLEAN_BUILD=false
COMMAND=""

while [[ $# -gt 0 ]]; do
    case $1 in
        check|build|test|security|deploy|full)
            COMMAND="$1"
            shift
            ;;
        --env)
            TARGET_ENV="$2"
            shift 2
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --skip-security)
            SKIP_SECURITY=true
            shift
            ;;
        --push)
            PUSH_IMAGES=true
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
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
    
    log_info "NewHTTPS 本地CI/CD - $COMMAND"
    log_info "环境: $TARGET_ENV"
    log_info "版本: $VERSION"
    
    case $COMMAND in
        check)
            code_check
            ;;
        build)
            build_images
            ;;
        test)
            run_tests
            ;;
        security)
            security_scan
            ;;
        deploy)
            deploy_services
            ;;
        full)
            full_pipeline
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
