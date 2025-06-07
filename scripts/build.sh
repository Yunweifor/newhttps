#!/bin/bash

# NewHTTPS - Optimized Docker Build Script
# Supports incremental builds with multi-stage caching

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
VERSION=${VERSION:-$(git rev-parse --short HEAD 2>/dev/null || echo "latest")}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
NewHTTPS Docker Build Script

Usage: $0 [OPTIONS] [COMMAND]

Commands:
    base        Build only the base image
    api         Build only the API service
    web         Build only the Web interface
    all         Build all services (default)
    clean       Clean up build cache and unused images

Options:
    --no-cache          Build without using cache
    --push              Push images to registry after build
    --dev               Build development images
    --prod              Build production images (default)
    --version VERSION   Set version tag (default: git short hash)
    --registry URL      Set Docker registry URL
    --help              Show this help message

Examples:
    $0 all                          # Build all services
    $0 base --no-cache             # Build base image without cache
    $0 api --dev                   # Build API service for development
    $0 all --push --version v1.0.0 # Build and push all with version tag

EOF
}

# Parse command line arguments
COMMAND="all"
NO_CACHE=""
PUSH_IMAGES=false
BUILD_ENV="prod"
REGISTRY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        base|api|web|all|clean)
            COMMAND="$1"
            shift
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --push)
            PUSH_IMAGES=true
            shift
            ;;
        --dev)
            BUILD_ENV="dev"
            shift
            ;;
        --prod)
            BUILD_ENV="prod"
            shift
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Set image names with registry prefix if provided
if [[ -n "$REGISTRY" ]]; then
    BASE_IMAGE="$REGISTRY/newhttps-base"
    API_IMAGE="$REGISTRY/newhttps-api"
    WEB_IMAGE="$REGISTRY/newhttps-web"
else
    BASE_IMAGE="newhttps-base"
    API_IMAGE="newhttps-api"
    WEB_IMAGE="newhttps-web"
fi

# Build functions
build_base() {
    log_info "Building base image..."

    docker build \
        $NO_CACHE \
        --build-arg BUILD_DATE="$BUILD_DATE" \
        --build-arg VERSION="$VERSION" \
        --tag "$BASE_IMAGE:$VERSION" \
        --tag "$BASE_IMAGE:latest" \
        --file Dockerfile.base \
        "$PROJECT_ROOT"

    log_success "Base image built successfully"
}

build_api() {
    log_info "Building API service..."

    local dockerfile="Dockerfile.optimized"
    local target="production"

    if [[ "$BUILD_ENV" == "dev" ]]; then
        target="dependencies"
    fi

    docker build \
        $NO_CACHE \
        --build-arg BUILD_DATE="$BUILD_DATE" \
        --build-arg VERSION="$VERSION" \
        --target "$target" \
        --tag "$API_IMAGE:$VERSION" \
        --tag "$API_IMAGE:latest" \
        --file "$dockerfile" \
        "$PROJECT_ROOT/api"

    log_success "API service built successfully"
}

build_web() {
    log_info "Building Web interface..."

    local dockerfile="Dockerfile.optimized"
    local target="production"

    if [[ "$BUILD_ENV" == "dev" ]]; then
        target="dependencies"
    fi

    docker build \
        $NO_CACHE \
        --build-arg BUILD_DATE="$BUILD_DATE" \
        --build-arg VERSION="$VERSION" \
        --target "$target" \
        --tag "$WEB_IMAGE:$VERSION" \
        --tag "$WEB_IMAGE:latest" \
        --file "$dockerfile" \
        "$PROJECT_ROOT/web"

    log_success "Web interface built successfully"
}

push_images() {
    if [[ "$PUSH_IMAGES" == true ]]; then
        log_info "Pushing images to registry..."

        case $COMMAND in
            base)
                docker push "$BASE_IMAGE:$VERSION"
                docker push "$BASE_IMAGE:latest"
                ;;
            api)
                docker push "$API_IMAGE:$VERSION"
                docker push "$API_IMAGE:latest"
                ;;
            web)
                docker push "$WEB_IMAGE:$VERSION"
                docker push "$WEB_IMAGE:latest"
                ;;
            all)
                docker push "$BASE_IMAGE:$VERSION"
                docker push "$BASE_IMAGE:latest"
                docker push "$API_IMAGE:$VERSION"
                docker push "$API_IMAGE:latest"
                docker push "$WEB_IMAGE:$VERSION"
                docker push "$WEB_IMAGE:latest"
                ;;
        esac

        log_success "Images pushed successfully"
    fi
}

clean_build_cache() {
    log_info "Cleaning build cache and unused images..."

    # Remove dangling images
    docker image prune -f

    # Remove build cache
    docker builder prune -f

    # Remove unused volumes
    docker volume prune -f

    log_success "Build cache cleaned"
}

# Main execution
main() {
    cd "$PROJECT_ROOT"

    log_info "Starting NewHTTPS Docker build process..."
    log_info "Version: $VERSION"
    log_info "Build Date: $BUILD_DATE"
    log_info "Environment: $BUILD_ENV"
    log_info "Command: $COMMAND"

    case $COMMAND in
        base)
            build_base
            ;;
        api)
            build_base  # API depends on base
            build_api
            ;;
        web)
            build_base  # Web depends on base
            build_web
            ;;
        all)
            build_base
            build_api
            build_web
            ;;
        clean)
            clean_build_cache
            exit 0
            ;;
    esac

    push_images

    log_success "Build process completed successfully!"
}

# Run main function
main "$@"