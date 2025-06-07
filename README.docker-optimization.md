# NewHTTPS Docker Optimization

## 🚀 Overview

This document describes the comprehensive Docker containerization strategy for NewHTTPS, featuring:

- **Multi-stage builds** with intelligent caching
- **Incremental updates** for fast development cycles
- **Zero-downtime deployments** for production
- **CI/CD integration** with GitHub Actions
- **Security hardening** and best practices

## 📋 Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- Make (optional, for convenience commands)
- Git (for version tagging)

### 1. Setup Environment

```bash
# Clone the repository
git clone https://github.com/Yunweifor/newhttps.git
cd newhttps

# Setup development environment
make setup
# or manually:
# cp .env.optimized .env
# ./scripts/build.sh base
```

### 2. Development Workflow

```bash
# Start development environment with hot reload
make dev
# or: ./scripts/deploy.sh dev --build

# View logs
make logs

# Run tests
make test

# Check health
make health
```

### 3. Production Deployment

```bash
# Deploy production environment
make prod
# or: ./scripts/deploy.sh prod --build --backup

# Check status
make status

# View production logs
make logs
```

## 🏗️ Architecture

### Multi-Stage Build Strategy

```mermaid
graph TD
    A[Base Image] --> B[API Dependencies]
    A --> C[Web Dependencies]
    B --> D[API Builder]
    C --> E[Web Builder]
    D --> F[API Production]
    E --> G[Web Production]
    
    style A fill:#e1f5fe
    style F fill:#c8e6c9
    style G fill:#c8e6c9
```

### Build Stages

1. **Base Image** (`Dockerfile.base`)
   - Alpine Linux + Node.js 18
   - System dependencies (curl, bash, openssl)
   - Application user and directories
   - Global npm packages (pm2, typescript)

2. **Dependencies Stage**
   - Install npm packages
   - Cached separately for faster rebuilds

3. **Builder Stage**
   - Copy source code
   - Build TypeScript/Vue.js
   - Remove dev dependencies

4. **Production Stage**
   - Copy built artifacts
   - Minimal runtime environment
   - Security hardening

## 📁 File Structure

```
newhttps/
├── Dockerfile.base                 # Base image with system deps
├── api/
│   └── Dockerfile.optimized       # API multi-stage build
├── web/
│   └── Dockerfile.optimized       # Web multi-stage build
├── docker-compose.optimized.yml   # Production compose
├── docker-compose.dev.yml         # Development compose
├── scripts/
│   ├── build.sh                   # Intelligent build script
│   └── deploy.sh                  # Zero-downtime deployment
├── .github/workflows/
│   └── docker-build.yml           # CI/CD pipeline
├── Makefile                       # Convenience commands
├── .env.optimized                 # Environment template
└── docs/
    └── docker-optimization.md     # Detailed documentation
```

## 🔧 Build Commands

### Using Make (Recommended)

```bash
# Build all services
make build

# Build specific service
make build-api
make build-web
make build-base

# Build for different environments
make build-dev
make build-prod

# Build without cache
make build-no-cache

# Push to registry
make push
```

### Using Scripts Directly

```bash
# Build all services
./scripts/build.sh all

# Build with options
./scripts/build.sh all --no-cache --version v1.0.0

# Build for development
./scripts/build.sh all --dev

# Push to registry
./scripts/build.sh all --push --registry ghcr.io/username
```

## 🚀 Deployment Commands

### Development Environment

```bash
# Start with hot reload
make dev
# or: ./scripts/deploy.sh dev --build

# Quick start (no build)
make dev-quick
# or: ./scripts/deploy.sh dev

# View development logs
make logs
docker-compose -f docker-compose.dev.yml logs -f
```

### Production Environment

```bash
# Deploy with backup
make prod
# or: ./scripts/deploy.sh prod --build --backup

# Deploy specific version
./scripts/deploy.sh prod --version v1.0.0 --backup

# Deploy from registry
./scripts/deploy.sh prod --pull

# Rollback deployment
make rollback
# or: ./scripts/deploy.sh --rollback
```

## 📊 Performance Optimizations

### Image Size Comparison

| Component | Original | Optimized | Reduction |
|-----------|----------|-----------|-----------|
| Base Image | N/A | ~150MB | New |
| API Image | ~800MB | ~200MB | 75% |
| Web Image | ~600MB | ~50MB | 92% |
| **Total** | ~1.4GB | ~400MB | **71%** |

### Build Time Improvements

| Scenario | Original | Optimized | Improvement |
|----------|----------|-----------|-------------|
| Cold Build | 8-12 min | 6-8 min | 25-33% |
| Code Change | 8-12 min | 1-2 min | **85-90%** |
| Dependency Change | 8-12 min | 3-4 min | 60-67% |
| CI/CD Build | 10-15 min | 4-6 min | 60-67% |

## 🔒 Security Features

### Container Security

- ✅ Non-root user execution
- ✅ Minimal attack surface (Alpine Linux)
- ✅ Security scanning with Trivy
- ✅ Read-only root filesystem where possible
- ✅ Capability dropping
- ✅ Resource limits

### Network Security

- ✅ Internal Docker networks
- ✅ Minimal port exposure
- ✅ Environment-based secrets
- ✅ HTTPS enforcement
- ✅ CORS configuration

### Data Security

- ✅ Volume encryption support
- ✅ Backup encryption
- ✅ Proper file permissions
- ✅ Audit logging

## 🔄 CI/CD Integration

### GitHub Actions Workflow

The included workflow provides:

- **Parallel Builds**: Base, API, and Web images built concurrently
- **Multi-platform**: AMD64 and ARM64 support
- **Security Scanning**: Automated vulnerability detection
- **Automated Deployment**: Staging on main, production on tags
- **Cache Optimization**: GitHub Actions cache for faster builds

### Workflow Triggers

- **Push to main**: Build and deploy to staging
- **Push tags (v*)**: Build, scan, and deploy to production
- **Pull requests**: Build and test only

## 📈 Monitoring

### Health Checks

```bash
# Check all services
make health

# Check specific service
make health-api
make health-web

# View service status
make status
```

### Resource Monitoring

```bash
# View resource usage
make stats

# View running processes
make top

# View logs
make logs
make logs-api
make logs-web
```

## 🛠️ Development Tools

### Interactive Shells

```bash
# API container shell
make shell-api

# Web container shell
make shell-web

# Database shell
make shell-db
```

### Testing

```bash
# Run all tests
make test

# Run specific tests
make test-api
make test-web

# Run linting
make lint
```

## 🔧 Maintenance

### Cleanup

```bash
# Clean build cache
make clean

# Clean all Docker resources (careful!)
make clean-all
```

### Backup and Recovery

```bash
# Create backup
make backup

# Rollback to previous version
make rollback
```

## 🚨 Troubleshooting

### Common Issues

1. **Build Failures**
   ```bash
   # Clear build cache
   make clean
   
   # Rebuild without cache
   make build-no-cache
   ```

2. **Service Won't Start**
   ```bash
   # Check logs
   make logs
   
   # Check service status
   make status
   
   # Restart services
   make restart
   ```

3. **Port Conflicts**
   ```bash
   # Check what's using the port
   lsof -i :3000
   lsof -i :8080
   
   # Change ports in .env file
   API_PORT=3001
   WEB_PORT=8081
   ```

### Debug Commands

```bash
# Enter running container
make shell-api

# Check container configuration
docker inspect newhttps-api

# View build history
docker history newhttps-api:latest

# Check resource usage
docker stats
```

## 📚 Additional Resources

- [Detailed Documentation](docs/docker-optimization.md)
- [Original Docker Setup](README.docker.md)
- [API Documentation](docs/api.md)
- [Troubleshooting Guide](docs/troubleshooting.md)

## 🤝 Contributing

When contributing to the Docker setup:

1. Test changes in development environment
2. Update documentation if needed
3. Ensure CI/CD pipeline passes
4. Follow security best practices

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

**NewHTTPS Docker Optimization - Making SSL certificate management simple and efficient!** 🚀✨
