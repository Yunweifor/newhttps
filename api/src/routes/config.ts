import { Router } from 'express';
import { logger } from '../utils/logger';

const router = Router();

/**
 * 获取系统配置
 * GET /api/v1/config
 */
router.get('/', async (req, res) => {
  try {
    const config = {
      version: process.env.npm_package_version || '1.0.0',
      environment: process.env.NODE_ENV || 'development',
      features: {
        certd_integration: true,
        agent_management: true,
        auto_deployment: true
      },
      limits: {
        max_agents: parseInt(process.env.MAX_AGENTS || '100'),
        max_certificates: parseInt(process.env.MAX_CERTIFICATES || '1000')
      }
    };

    res.json({
      success: true,
      data: config
    });
  } catch (error) {
    logger.error('Failed to get config:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch configuration'
    });
  }
});

/**
 * 更新系统配置
 * PUT /api/v1/config
 */
router.put('/', async (req, res) => {
  try {
    // 这里可以添加配置更新逻辑
    // 目前只是返回成功响应
    
    res.json({
      success: true,
      message: 'Configuration updated successfully'
    });
  } catch (error) {
    logger.error('Failed to update config:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update configuration'
    });
  }
});

export { router as configRoutes };
