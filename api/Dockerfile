# NewHTTPS API Dockerfile
FROM node:18-alpine

# 设置工作目录
WORKDIR /app

# 安装系统依赖
RUN apk add --no-cache \
    curl \
    bash \
    openssl \
    ca-certificates

# 复制 package.json 和 package-lock.json
COPY package*.json ./

# 安装所有依赖（包括开发依赖，用于构建）
RUN npm ci && npm cache clean --force

# 复制源代码
COPY . .

# 构建 TypeScript
RUN npm run build

# 重新安装仅生产依赖
RUN npm ci --only=production && npm cache clean --force

# 创建非 root 用户
RUN addgroup -g 1001 -S newhttps && \
    adduser -S newhttps -u 1001 -G newhttps

# 创建必要的目录
RUN mkdir -p /app/data /app/logs /app/uploads && \
    chown -R newhttps:newhttps /app

# 切换到非 root 用户
USER newhttps

# 暴露端口
EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# 启动命令
CMD ["npm", "start"]
