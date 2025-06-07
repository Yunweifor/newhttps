#!/bin/bash

# NewHTTPS Git Hooks 设置脚本
# 自动设置Git钩子，提供类似CI/CD的本地自动化

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# 创建pre-commit钩子
create_pre_commit_hook() {
    log_info "创建pre-commit钩子..."
    
    cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash

# NewHTTPS Pre-commit Hook
# 在提交前执行代码检查和基本测试

set -e

echo "🔍 执行提交前检查..."

# 检查Docker文件语法
echo "检查Dockerfile语法..."
if command -v hadolint &> /dev/null; then
    hadolint Dockerfile.base || echo "⚠️  Dockerfile.base 语法警告"
    hadolint api/Dockerfile.optimized || echo "⚠️  API Dockerfile 语法警告"
    hadolint web/Dockerfile.optimized || echo "⚠️  Web Dockerfile 语法警告"
else
    echo "⚠️  hadolint未安装，跳过Dockerfile检查"
fi

# 检查docker-compose文件语法
echo "检查docker-compose文件语法..."
docker-compose -f docker-compose.optimized.yml config > /dev/null || {
    echo "❌ docker-compose.optimized.yml 语法错误"
    exit 1
}

# 检查环境配置文件
echo "检查环境配置..."
if [[ ! -f .env.example ]]; then
    echo "❌ .env.example 文件缺失"
    exit 1
fi

# 运行快速构建测试
echo "执行快速构建测试..."
if ! docker build -f Dockerfile.base -t newhttps-base:test . > /dev/null 2>&1; then
    echo "❌ 基础镜像构建失败"
    exit 1
fi

echo "✅ 提交前检查通过"
EOF

    chmod +x "$HOOKS_DIR/pre-commit"
    log_success "pre-commit钩子创建完成"
}

# 创建pre-push钩子
create_pre_push_hook() {
    log_info "创建pre-push钩子..."
    
    cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/bin/bash

# NewHTTPS Pre-push Hook
# 在推送前执行完整构建和测试

set -e

echo "🚀 执行推送前检查..."

# 获取当前分支
current_branch=$(git rev-parse --abbrev-ref HEAD)

# 如果是main分支，执行完整检查
if [[ "$current_branch" == "main" ]]; then
    echo "检测到main分支，执行完整检查..."
    
    # 执行完整构建
    echo "执行完整构建..."
    ./scripts/build.sh all --no-cache
    
    # 运行测试（如果存在）
    if [[ -f scripts/local-ci.sh ]]; then
        echo "运行测试套件..."
        ./scripts/local-ci.sh test --skip-security
    fi
    
    echo "✅ main分支检查通过"
else
    echo "非main分支，执行基础检查..."
    
    # 执行基础构建检查
    ./scripts/build.sh base
    
    echo "✅ 基础检查通过"
fi

echo "🎉 推送前检查完成"
EOF

    chmod +x "$HOOKS_DIR/pre-push"
    log_success "pre-push钩子创建完成"
}

# 创建post-merge钩子
create_post_merge_hook() {
    log_info "创建post-merge钩子..."
    
    cat > "$HOOKS_DIR/post-merge" << 'EOF'
#!/bin/bash

# NewHTTPS Post-merge Hook
# 合并后自动更新开发环境

set -e

echo "🔄 执行合并后操作..."

# 检查是否有Docker相关文件变更
if git diff-tree -r --name-only --no-commit-id HEAD | grep -E "(Dockerfile|docker-compose|\.env)" > /dev/null; then
    echo "检测到Docker配置变更，重新构建开发环境..."
    
    # 停止现有开发环境
    docker-compose -f docker-compose.dev.yml down 2>/dev/null || true
    
    # 重新构建并启动
    make dev-quick
    
    echo "✅ 开发环境已更新"
else
    echo "无Docker配置变更，跳过重建"
fi

echo "🎉 合并后操作完成"
EOF

    chmod +x "$HOOKS_DIR/post-merge"
    log_success "post-merge钩子创建完成"
}

# 创建commit-msg钩子
create_commit_msg_hook() {
    log_info "创建commit-msg钩子..."
    
    cat > "$HOOKS_DIR/commit-msg" << 'EOF'
#!/bin/bash

# NewHTTPS Commit Message Hook
# 检查提交信息格式

commit_regex='^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: .{1,50}'

if ! grep -qE "$commit_regex" "$1"; then
    echo "❌ 提交信息格式不正确"
    echo "格式: type(scope): description"
    echo "类型: feat, fix, docs, style, refactor, test, chore"
    echo "示例: feat(api): 添加证书自动续期功能"
    exit 1
fi

echo "✅ 提交信息格式正确"
EOF

    chmod +x "$HOOKS_DIR/commit-msg"
    log_success "commit-msg钩子创建完成"
}

# 主函数
main() {
    cd "$PROJECT_ROOT"
    
    log_info "设置NewHTTPS Git Hooks..."
    
    # 检查是否在Git仓库中
    if [[ ! -d .git ]]; then
        echo "❌ 当前目录不是Git仓库"
        exit 1
    fi
    
    # 创建hooks目录（如果不存在）
    mkdir -p "$HOOKS_DIR"
    
    # 创建各种钩子
    create_pre_commit_hook
    create_pre_push_hook
    create_post_merge_hook
    create_commit_msg_hook
    
    log_success "Git Hooks设置完成！"
    
    echo ""
    echo "已设置的钩子："
    echo "  📝 pre-commit  - 提交前代码检查"
    echo "  🚀 pre-push    - 推送前构建测试"
    echo "  🔄 post-merge  - 合并后环境更新"
    echo "  💬 commit-msg  - 提交信息格式检查"
    echo ""
    echo "使用说明："
    echo "  • 正常使用git commit和git push即可自动触发检查"
    echo "  • 如需跳过钩子，使用 --no-verify 参数"
    echo "  • 钩子文件位置: .git/hooks/"
}

# 执行主函数
main "$@"
