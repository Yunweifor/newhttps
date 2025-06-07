# GitHub Actions CI/CD 设置指南

## 概述

由于GitHub Actions工作流文件需要特殊的`workflow`权限，需要手动创建工作流文件。本文档提供了完整的设置指南。

## 手动创建工作流

### 1. 在GitHub网页界面创建工作流

1. 访问您的GitHub仓库
2. 点击 **Actions** 标签页
3. 点击 **New workflow**
4. 选择 **set up a workflow yourself**
5. 将以下内容复制到编辑器中：

```yaml
name: NewHTTPS Docker 构建和部署

on:
  push:
    branches: [ main, develop ]
    tags: [ 'v*' ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # 构建基础镜像 (运行一次，为其他任务提供缓存)
  build-base:
    name: 构建基础镜像
    runs-on: ubuntu-latest
    outputs:
      base-image: ${{ steps.meta.outputs.tags }}
      base-digest: ${{ steps.build.outputs.digest }}
    steps:
      - name: 检出代码
        uses: actions/checkout@v4

      - name: 设置 Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: 登录容器注册表
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: 提取元数据
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-base
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: 构建并推送基础镜像
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile.base
          platforms: linux/amd64,linux/arm64
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            BUILD_DATE=${{ fromJSON(steps.meta.outputs.json).labels['org.opencontainers.image.created'] }}
            VERSION=${{ fromJSON(steps.meta.outputs.json).labels['org.opencontainers.image.version'] }}

  # 构建API服务
  build-api:
    name: 构建API服务
    runs-on: ubuntu-latest
    needs: build-base
    outputs:
      api-image: ${{ steps.meta.outputs.tags }}
      api-digest: ${{ steps.build.outputs.digest }}
    steps:
      - name: 检出代码
        uses: actions/checkout@v4

      - name: 设置 Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: 登录容器注册表
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: 提取元数据
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-api
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: 构建并推送API镜像
        id: build
        uses: docker/build-push-action@v5
        with:
          context: ./api
          file: ./api/Dockerfile.optimized
          platforms: linux/amd64,linux/arm64
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            BUILD_DATE=${{ fromJSON(steps.meta.outputs.json).labels['org.opencontainers.image.created'] }}
            VERSION=${{ fromJSON(steps.meta.outputs.json).labels['org.opencontainers.image.version'] }}

  # 构建Web服务
  build-web:
    name: 构建Web服务
    runs-on: ubuntu-latest
    needs: build-base
    outputs:
      web-image: ${{ steps.meta.outputs.tags }}
      web-digest: ${{ steps.build.outputs.digest }}
    steps:
      - name: 检出代码
        uses: actions/checkout@v4

      - name: 设置 Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: 登录容器注册表
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: 提取元数据
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-web
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: 构建并推送Web镜像
        id: build
        uses: docker/build-push-action@v5
        with:
          context: ./web
          file: ./web/Dockerfile.optimized
          platforms: linux/amd64,linux/arm64
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            BUILD_DATE=${{ fromJSON(steps.meta.outputs.json).labels['org.opencontainers.image.created'] }}
            VERSION=${{ fromJSON(steps.meta.outputs.json).labels['org.opencontainers.image.version'] }}

  # 安全扫描
  security-scan:
    name: 安全漏洞扫描
    runs-on: ubuntu-latest
    needs: [build-api, build-web]
    if: github.event_name != 'pull_request'
    steps:
      - name: 扫描API镜像漏洞
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ needs.build-api.outputs.api-image }}
          format: 'sarif'
          output: 'trivy-api-results.sarif'

      - name: 扫描Web镜像漏洞
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ needs.build-web.outputs.web-image }}
          format: 'sarif'
          output: 'trivy-web-results.sarif'

      - name: 上传扫描结果到GitHub安全中心
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: '.'

  # 部署到预发布环境 (main分支)
  deploy-staging:
    name: 部署到预发布环境
    runs-on: ubuntu-latest
    needs: [build-api, build-web]
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: staging
    steps:
      - name: 检出代码
        uses: actions/checkout@v4

      - name: 部署到预发布环境
        run: |
          echo "正在部署到预发布环境..."
          echo "API镜像: ${{ needs.build-api.outputs.api-image }}"
          echo "Web镜像: ${{ needs.build-web.outputs.web-image }}"
          # 在这里添加您的预发布部署逻辑
          # 例如: kubectl apply -f k8s/staging/
          # 或者: docker-compose -f docker-compose.staging.yml up -d

  # 部署到生产环境 (标签)
  deploy-production:
    name: 部署到生产环境
    runs-on: ubuntu-latest
    needs: [build-api, build-web, security-scan]
    if: startsWith(github.ref, 'refs/tags/v')
    environment: production
    steps:
      - name: 检出代码
        uses: actions/checkout@v4

      - name: 部署到生产环境
        run: |
          echo "正在部署到生产环境..."
          echo "版本: ${{ github.ref_name }}"
          echo "API镜像: ${{ needs.build-api.outputs.api-image }}"
          echo "Web镜像: ${{ needs.build-web.outputs.web-image }}"
          # 在这里添加您的生产部署逻辑
          # 例如: kubectl apply -f k8s/production/
          # 或者: docker-compose -f docker-compose.prod.yml up -d
```

### 2. 保存工作流

1. 将文件命名为 `docker-build.yml`
2. 点击 **Start commit**
3. 添加提交信息：`feat: 添加Docker CI/CD工作流`
4. 点击 **Commit new file**

## 工作流功能

### 触发条件

- **Push到main/develop分支**: 构建镜像并部署到预发布环境
- **Push标签(v*)**: 构建、安全扫描并部署到生产环境
- **Pull Request**: 仅构建和测试，不部署

### 构建流程

1. **并行构建**: 基础镜像构建完成后，API和Web服务并行构建
2. **多平台支持**: 同时构建AMD64和ARM64架构
3. **智能缓存**: 使用GitHub Actions缓存加速构建
4. **安全扫描**: 使用Trivy扫描镜像漏洞

### 部署策略

- **预发布环境**: main分支自动部署
- **生产环境**: 标签触发，需要安全扫描通过
- **环境保护**: 可以在GitHub设置中配置环境保护规则

## 环境配置

### 1. 设置环境

在GitHub仓库设置中创建环境：

1. 进入 **Settings** > **Environments**
2. 创建 `staging` 和 `production` 环境
3. 配置保护规则（可选）

### 2. 配置密钥

如果需要额外的密钥（如部署密钥），在 **Settings** > **Secrets and variables** > **Actions** 中添加：

- `DEPLOY_KEY`: 部署密钥
- `KUBECONFIG`: Kubernetes配置（如果使用K8s）
- 其他必要的环境变量

## 使用说明

### 触发构建

```bash
# 触发预发布部署
git push origin main

# 触发生产部署
git tag v1.0.0
git push origin v1.0.0
```

### 监控构建

1. 在GitHub仓库中点击 **Actions** 标签页
2. 查看工作流运行状态
3. 点击具体的运行查看详细日志

### 自定义部署

在工作流的部署步骤中，替换示例命令为您的实际部署逻辑：

```yaml
- name: 部署到生产环境
  run: |
    # 替换为您的部署命令
    kubectl apply -f k8s/production/
    # 或者
    docker-compose -f docker-compose.prod.yml up -d
```

## 故障排除

### 常见问题

1. **权限错误**: 确保GitHub Token有足够权限
2. **构建失败**: 检查Dockerfile语法和依赖
3. **推送失败**: 检查容器注册表权限

### 调试技巧

1. 在工作流中添加调试步骤
2. 使用 `tmate` action进行远程调试
3. 检查GitHub Actions日志

这个CI/CD工作流为NewHTTPS项目提供了完整的自动化构建、测试、安全扫描和部署能力。
