import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import dotenv from 'dotenv';
import path from 'path';

import { errorHandler } from './middleware/errorHandler';
import { authMiddleware } from './middleware/auth';
import { certRoutes } from './routes/cert';
import { agentRoutes } from './routes/agent';
import { configRoutes } from './routes/config';
import { deploymentRoutes } from './routes/deployment';
import { renewalRoutes } from './routes/renewal';
import { monitoringRoutes } from './routes/monitoring';
import { Database } from './services/database';
import { RenewalScheduler } from './services/renewalScheduler';
import { CertificateMonitor } from './services/certificateMonitor';
import { CertificateDeployment } from './services/certificateDeployment';
import { logger } from './utils/logger';

// 加载环境变量
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// 中间件
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// 静态文件服务
app.use('/static', express.static(path.join(__dirname, '../public')));

// 健康检查
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

// API 路由
app.use('/api/v1/cert', certRoutes);
app.use('/api/v1/agent', agentRoutes);
app.use('/api/v1/deployment', deploymentRoutes);
app.use('/api/v1/renewal', renewalRoutes);
app.use('/api/v1/monitoring', monitoringRoutes);
app.use('/api/v1/config', authMiddleware, configRoutes);

// 错误处理
app.use(errorHandler);

// 404 处理
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.originalUrl} not found`
  });
});

// 启动服务器
async function startServer() {
  try {
    // 初始化数据库
    await Database.getInstance().init();

    // 初始化续期调度器
    await RenewalScheduler.getInstance().initialize();

    // 启动证书监控服务
    await CertificateMonitor.getInstance().start();

    // 初始化证书部署服务
    await CertificateDeployment.getInstance().initialize();

    app.listen(PORT, () => {
      logger.info(`NewHTTPS API Server running on port ${PORT}`);
      logger.info(`Health check: http://localhost:${PORT}/health`);
      logger.info('Certificate renewal scheduler started');
      logger.info('Certificate monitoring service started');
      logger.info('Certificate deployment service started');
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

// 优雅关闭
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});

startServer();

export default app;
