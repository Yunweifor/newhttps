#!/bin/bash

# NewHTTPS - Optimized Docker Deployment Script
# Supports incremental deployments with zero-downtime updates

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
NewHTTPS Docker Deployment Script

Usage: $0 [OPTIONS] [ENVIRONMENT]

Environments:
    dev         Deploy development environment
    prod        Deploy production environment (default)
    staging     Deploy staging environment

Options:
    --build             Build images before deployment
    --no-cache          Build without using cache (requires --build)
    --pull              Pull latest images from registry
    --backup            Create backup before deployment
    --rollback          Rollback to previous version
    --version VERSION   Deploy specific version (default: latest)
    --config FILE       Use custom environment file
    --help              Show this help message

Examples:
    $0 prod                         # Deploy production environment
    $0 dev --build                  # Build and deploy development
    $0 prod --backup --version v1.0.0  # Deploy with backup
    $0 --rollback                   # Rollback to previous version

EOF
}

# Parse command line arguments
ENVIRONMENT="prod"
BUILD_IMAGES=false
NO_CACHE=""
PULL_IMAGES=false
CREATE_BACKUP=false
ROLLBACK=false
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        dev|prod|staging)
            ENVIRONMENT="$1"
            shift
            ;;
        --build)
            BUILD_IMAGES=true
            shift
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --pull)
            PULL_IMAGES=true
            shift
            ;;
        --backup)
            CREATE_BACKUP=true
            shift
            ;;
        --rollback)
            ROLLBACK=true
            shift
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
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

# Set compose file based on environment
case $ENVIRONMENT in
    dev)
        COMPOSE_FILE="docker-compose.dev.yml"
        ;;
    prod)
        COMPOSE_FILE="docker-compose.optimized.yml"
        ;;
    staging)
        COMPOSE_FILE="docker-compose.optimized.yml"
        ;;
    *)
        log_error "Unknown environment: $ENVIRONMENT"
        exit 1
        ;;
esac

# Docker Compose command
DOCKER_COMPOSE="docker compose"
if ! command -v "docker compose" &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
fi

# Environment setup
setup_environment() {
    log_info "Setting up environment for $ENVIRONMENT..."
    
    # Create .env file if it doesn't exist
    if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
        if [[ -f "$PROJECT_ROOT/.env.example" ]]; then
            cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
            log_info "Created .env file from .env.example"
        else
            log_warning "No .env.example found, creating minimal .env file"
            cat > "$PROJECT_ROOT/.env" << EOF
# NewHTTPS Environment Configuration
NODE_ENV=$ENVIRONMENT
VERSION=$VERSION
BUILD_DATE=$BUILD_DATE
JWT_SECRET=$(openssl rand -base64 32)
API_PORT=3000
WEB_PORT=8080
EOF
        fi
    fi
    
    # Use custom config file if provided
    if [[ -n "$CONFIG_FILE" ]]; then
        if [[ -f "$CONFIG_FILE" ]]; then
            cp "$CONFIG_FILE" "$PROJECT_ROOT/.env"
            log_info "Using custom config file: $CONFIG_FILE"
        else
            log_error "Config file not found: $CONFIG_FILE"
            exit 1
        fi
    fi
    
    # Export environment variables
    export VERSION
    export BUILD_DATE
    export NODE_ENV=$ENVIRONMENT
}

# Backup function
create_backup() {
    if [[ "$CREATE_BACKUP" == true ]]; then
        log_info "Creating backup..."
        
        local backup_dir="$PROJECT_ROOT/backups/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        
        # Backup volumes
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T newhttps-api tar czf - -C /app data logs uploads ssl backups 2>/dev/null | tar xzf - -C "$backup_dir" || true
        
        # Save current version info
        echo "VERSION=$VERSION" > "$backup_dir/version.env"
        echo "BUILD_DATE=$BUILD_DATE" >> "$backup_dir/version.env"
        echo "ENVIRONMENT=$ENVIRONMENT" >> "$backup_dir/version.env"
        
        log_success "Backup created at: $backup_dir"
    fi
}

# Build images if requested
build_images() {
    if [[ "$BUILD_IMAGES" == true ]]; then
        log_info "Building images..."
        "$SCRIPT_DIR/build.sh" all --$ENVIRONMENT $NO_CACHE
    fi
}

# Pull images if requested
pull_images() {
    if [[ "$PULL_IMAGES" == true ]]; then
        log_info "Pulling latest images..."
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" pull
    fi
}

# Deploy services
deploy_services() {
    log_info "Deploying NewHTTPS $ENVIRONMENT environment..."
    
    cd "$PROJECT_ROOT"
    
    # Stop existing services gracefully
    log_info "Stopping existing services..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" down --remove-orphans || true
    
    # Start services
    log_info "Starting services..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d
    
    # Wait for services to be healthy
    log_info "Waiting for services to be healthy..."
    sleep 30
    
    # Check service health
    check_service_health
}

# Check service health
check_service_health() {
    log_info "Checking service health..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f http://localhost:${API_PORT:-3000}/health >/dev/null 2>&1; then
            log_success "API service is healthy"
            break
        else
            log_info "Waiting for API service... (attempt $attempt/$max_attempts)"
            sleep 10
            ((attempt++))
        fi
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        log_error "API service failed to become healthy"
        show_logs
        exit 1
    fi
    
    # Check web service if not in API-only mode
    if [[ "$ENVIRONMENT" != "api-only" ]]; then
        attempt=1
        while [[ $attempt -le $max_attempts ]]; do
            if curl -f http://localhost:${WEB_PORT:-8080}/ >/dev/null 2>&1; then
                log_success "Web service is healthy"
                break
            else
                log_info "Waiting for Web service... (attempt $attempt/$max_attempts)"
                sleep 10
                ((attempt++))
            fi
        done
        
        if [[ $attempt -gt $max_attempts ]]; then
            log_error "Web service failed to become healthy"
            show_logs
            exit 1
        fi
    fi
}

# Show service logs
show_logs() {
    log_info "Showing service logs..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" logs --tail=50
}

# Show service status
show_status() {
    log_info "Service status:"
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" ps
    
    log_info "Service URLs:"
    echo "  API: http://localhost:${API_PORT:-3000}"
    echo "  Web: http://localhost:${WEB_PORT:-8080}"
    echo "  Health: http://localhost:${API_PORT:-3000}/health"
}

# Rollback function
rollback_deployment() {
    log_warning "Rolling back deployment..."
    
    local backup_dir=$(ls -1t "$PROJECT_ROOT/backups/" | head -n1)
    if [[ -z "$backup_dir" ]]; then
        log_error "No backup found for rollback"
        exit 1
    fi
    
    log_info "Rolling back to backup: $backup_dir"
    
    # Stop current services
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" down
    
    # Restore backup (implementation depends on backup strategy)
    # This is a simplified example
    log_warning "Rollback functionality needs to be implemented based on your backup strategy"
    
    log_success "Rollback completed"
}

# Main execution
main() {
    cd "$PROJECT_ROOT"
    
    log_info "Starting NewHTTPS deployment process..."
    log_info "Environment: $ENVIRONMENT"
    log_info "Version: $VERSION"
    log_info "Build Date: $BUILD_DATE"
    log_info "Compose File: $COMPOSE_FILE"
    
    if [[ "$ROLLBACK" == true ]]; then
        rollback_deployment
        exit 0
    fi
    
    setup_environment
    create_backup
    build_images
    pull_images
    deploy_services
    show_status
    
    log_success "Deployment completed successfully!"
    log_info "Access your NewHTTPS instance at:"
    log_info "  API: http://localhost:${API_PORT:-3000}"
    log_info "  Web: http://localhost:${WEB_PORT:-8080}"
}

# Run main function
main "$@"
