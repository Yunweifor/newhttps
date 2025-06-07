# NewHTTPS Docker Optimization Guide

## Overview

This document describes the comprehensive Docker containerization strategy for NewHTTPS, featuring multi-stage builds, incremental updates, and optimized caching for efficient development and deployment workflows.

## Architecture

### Multi-Stage Build Strategy

The NewHTTPS Docker setup uses a three-tier architecture:

1. **Base Image** (`Dockerfile.base`)
   - Contains system dependencies and runtime environment
   - Rarely changes, maximizing cache efficiency
   - Shared across all application services

2. **Application Images** (`Dockerfile.optimized`)
   - API Service: Node.js + TypeScript + Express
   - Web Service: Vue.js + TypeScript + Nginx
   - Built on top of the base image

3. **Environment-Specific Configurations**
   - Development: Hot reload, debugging tools
   - Production: Optimized, security-hardened
   - Staging: Production-like with additional monitoring

## File Structure

```
newhttps/
├── Dockerfile.base                 # Base image with system dependencies
├── api/
│   └── Dockerfile.optimized       # API service multi-stage build
├── web/
│   └── Dockerfile.optimized       # Web service multi-stage build
├── docker-compose.optimized.yml   # Production-optimized compose
├── docker-compose.dev.yml         # Development environment
├── scripts/
│   ├── build.sh                   # Intelligent build script
│   └── deploy.sh                  # Zero-downtime deployment
└── .github/workflows/
    └── docker-build.yml           # CI/CD pipeline
```

## Build Process

### 1. Base Image Build

The base image contains:
- Node.js 18 Alpine Linux
- System dependencies (curl, bash, openssl, etc.)
- Global npm packages (pm2, typescript)
- Application user and directory structure
- Health check utilities

```bash
# Build base image
./scripts/build.sh base
```

### 2. Application Image Build

Application images use multi-stage builds:

**Stage 1: Dependencies**
- Install npm packages
- Cached separately for faster rebuilds

**Stage 2: Builder**
- Copy source code
- Build TypeScript/Vue.js application
- Remove dev dependencies

**Stage 3: Production**
- Copy built artifacts
- Minimal runtime environment
- Security hardening

```bash
# Build all services
./scripts/build.sh all

# Build specific service
./scripts/build.sh api
./scripts/build.sh web
```

## Incremental Update Strategy

### Cache Optimization

1. **Layer Ordering**: Dependencies installed before source code
2. **Multi-stage Caching**: Each stage cached independently
3. **Build Context Optimization**: Minimal context for faster uploads
4. **Registry Caching**: Pull cache from registry for CI/CD

### Update Scenarios

**Scenario 1: Code Changes Only**
- Base image: Cached (no rebuild)
- Dependencies: Cached (no reinstall)
- Application: Rebuilt (fast)

**Scenario 2: Dependency Changes**
- Base image: Cached (no rebuild)
- Dependencies: Rebuilt (moderate)
- Application: Rebuilt (fast)

**Scenario 3: System Changes**
- Base image: Rebuilt (slow, infrequent)
- Dependencies: Rebuilt (moderate)
- Application: Rebuilt (fast)

## Usage Instructions

### Development Environment

```bash
# Start development environment with hot reload
./scripts/deploy.sh dev --build

# Or using docker-compose directly
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f
```

**Development Features:**
- Hot reload for both API and Web
- Source code mounted as volumes
- Debug ports exposed
- SQLite browser for database inspection

### Production Deployment

```bash
# Deploy production environment
./scripts/deploy.sh prod --build --backup

# Deploy specific version
./scripts/deploy.sh prod --version v1.0.0 --backup

# Pull and deploy from registry
./scripts/deploy.sh prod --pull
```

**Production Features:**
- Optimized images with minimal attack surface
- Health checks and automatic restarts
- Volume persistence for data
- Backup and rollback capabilities

### CI/CD Integration

The GitHub Actions workflow provides:

1. **Parallel Builds**: Base, API, and Web images built concurrently
2. **Multi-platform**: AMD64 and ARM64 support
3. **Security Scanning**: Trivy vulnerability scanning
4. **Automated Deployment**: Staging on main, production on tags
5. **Cache Optimization**: GitHub Actions cache for faster builds

## Performance Optimizations

### Image Size Reduction

- **Alpine Linux**: Minimal base OS (~5MB)
- **Multi-stage Builds**: Remove build tools from final image
- **Dependency Pruning**: Production-only npm packages
- **Layer Optimization**: Combine RUN commands to reduce layers

### Build Speed Improvements

- **Dependency Caching**: npm packages cached separately
- **Parallel Builds**: Multiple services built concurrently
- **Registry Caching**: Pull cache from remote registry
- **Incremental Builds**: Only rebuild changed components

### Runtime Performance

- **PM2 Process Manager**: Better process management for API
- **Nginx Optimization**: Efficient static file serving
- **Health Checks**: Proactive service monitoring
- **Resource Limits**: Prevent resource exhaustion

## Security Best Practices

### Container Security

- **Non-root User**: All services run as non-root
- **Minimal Attack Surface**: Only necessary packages installed
- **Security Scanning**: Automated vulnerability detection
- **Read-only Filesystems**: Where possible

### Network Security

- **Internal Networks**: Services communicate via Docker networks
- **Port Exposure**: Only necessary ports exposed
- **Environment Variables**: Secrets managed via environment

### Data Security

- **Volume Encryption**: Consider encrypted volumes for sensitive data
- **Backup Encryption**: Encrypt backups at rest
- **Access Control**: Proper file permissions

## Monitoring and Maintenance

### Health Monitoring

```bash
# Check service health
curl http://localhost:3000/health

# View service status
docker-compose -f docker-compose.optimized.yml ps

# Monitor resource usage
docker stats
```

### Log Management

```bash
# View application logs
docker-compose logs -f newhttps-api
docker-compose logs -f newhttps-web

# Log rotation (configure in docker-compose)
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### Backup and Recovery

```bash
# Create backup before deployment
./scripts/deploy.sh prod --backup

# Manual backup
docker-compose exec newhttps-api tar czf - -C /app data logs | gzip > backup.tar.gz

# Restore from backup
# (Implementation depends on backup strategy)
```

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Check Docker daemon status
   - Verify network connectivity
   - Clear build cache: `docker builder prune`

2. **Service Startup Issues**
   - Check logs: `docker-compose logs service-name`
   - Verify environment variables
   - Check port conflicts

3. **Performance Issues**
   - Monitor resource usage: `docker stats`
   - Check disk space: `df -h`
   - Review container limits

### Debug Commands

```bash
# Enter running container
docker-compose exec newhttps-api bash

# Check container configuration
docker inspect container-name

# View build history
docker history image-name

# Clean up resources
docker system prune -a
```

## Migration from Current Setup

### Step-by-Step Migration

1. **Backup Current Data**
   ```bash
   docker-compose exec newhttps-api tar czf - -C /app data > current-backup.tar
   ```

2. **Build New Images**
   ```bash
   ./scripts/build.sh all
   ```

3. **Test in Development**
   ```bash
   ./scripts/deploy.sh dev --build
   ```

4. **Deploy to Production**
   ```bash
   ./scripts/deploy.sh prod --backup
   ```

5. **Verify Migration**
   - Check service health
   - Verify data integrity
   - Test functionality

### Rollback Plan

If issues occur during migration:

```bash
# Stop new services
docker-compose -f docker-compose.optimized.yml down

# Start original services
docker-compose -f docker-compose.yml up -d

# Restore data if needed
docker-compose exec newhttps-api tar xzf - -C /app < current-backup.tar
```

## Future Enhancements

### Planned Improvements

1. **Kubernetes Support**: Helm charts for Kubernetes deployment
2. **Service Mesh**: Istio integration for advanced networking
3. **Observability**: Prometheus metrics and Grafana dashboards
4. **Auto-scaling**: Horizontal pod autoscaling based on metrics
5. **Blue-Green Deployment**: Zero-downtime deployment strategy

### Monitoring Integration

- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Jaeger**: Distributed tracing
- **ELK Stack**: Centralized logging

This optimized Docker setup provides a robust, scalable, and maintainable foundation for the NewHTTPS project while supporting efficient development workflows and production deployments.
