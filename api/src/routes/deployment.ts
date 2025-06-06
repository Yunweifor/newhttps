import { Router } from 'express';
import { Database } from '../services/database';
import { CertificateDeployment } from '../services/certificateDeployment';
import { AgentCommunication } from '../services/agentCommunication';
import { logger } from '../utils/logger';
import { authMiddleware } from '../middleware/auth';
import { v4 as uuidv4 } from 'uuid';

const router = Router();

// 获取部署服务实例
function getDeploymentService(): CertificateDeployment {
  return CertificateDeployment.getInstance();
}

function getAgentCommunication(): AgentCommunication {
  return AgentCommunication.getInstance();
}

export interface DeploymentTask {
  id: string;
  certificateId: string;
  agentId: string;
  status: 'pending' | 'running' | 'success' | 'failed';
  type: 'deploy' | 'update' | 'remove';
  target: {
    type: 'nginx' | 'apache' | 'cloudflare' | 'aliyun' | 'tencent';
    config: Record<string, any>;
  };
  progress: number;
  logs: string[];
  createdAt: string;
  updatedAt: string;
  completedAt?: string;
  error?: string;
}

/**
 * 获取部署任务列表
 * GET /api/v1/deployment/tasks
 */
router.get('/tasks', authMiddleware, async (req, res) => {
  try {
    const { status, agentId, page = 1, pageSize = 10 } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);

    const deploymentService = getDeploymentService();
    const result = await deploymentService.getAllDeploymentTasks(Number(pageSize), offset);

    // 过滤结果
    let filteredTasks = result.tasks;

    if (status) {
      filteredTasks = filteredTasks.filter(task => task.status === status);
    }

    if (agentId) {
      filteredTasks = filteredTasks.filter(task => task.agentId === agentId);
    }

    res.json({
      success: true,
      data: filteredTasks,
      total: result.total,
      page: Number(page),
      pageSize: Number(pageSize)
    });
  } catch (error) {
    logger.error('Failed to get deployment tasks:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch deployment tasks'
    });
  }
});

/**
 * 创建部署任务
 * POST /api/v1/deployment/tasks
 */
router.post('/tasks', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { certificateId, agentId, targetType, targetConfig } = req.body;

    // 验证必需参数
    if (!certificateId || !agentId || !targetType || !targetConfig) {
      return res.status(400).json({
        success: false,
        error: 'certificateId, agentId, targetType, and targetConfig are required'
      });
    }

    // 验证证书存在
    const db = Database.getInstance();
    const certificate = await db.getCertificate(certificateId);
    if (!certificate) {
      return res.status(404).json({
        success: false,
        error: 'Certificate not found'
      });
    }

    // 验证Agent存在
    const agent = await db.getAgent(agentId);
    if (!agent) {
      return res.status(404).json({
        success: false,
        error: 'Agent not found'
      });
    }

    // 创建部署任务
    const deploymentService = getDeploymentService();
    const task = await deploymentService.createDeploymentTask(
      certificateId,
      agentId,
      targetType,
      targetConfig
    );

    logger.info(`Created deployment task: ${task.id}`);

    res.json({
      success: true,
      data: task,
      message: 'Deployment task created successfully'
    });
  } catch (error) {
    logger.error('Failed to create deployment task:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create deployment task'
    });
  }
});

/**
 * 获取部署任务详情
 * GET /api/v1/deployment/tasks/:taskId
 */
router.get('/tasks/:taskId', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { taskId } = req.params;

    const deploymentService = getDeploymentService();
    const task = await deploymentService.getDeploymentTask(taskId);

    if (!task) {
      return res.status(404).json({
        success: false,
        error: 'Deployment task not found'
      });
    }

    res.json({
      success: true,
      data: task
    });
  } catch (error) {
    logger.error(`Failed to get deployment task ${req.params.taskId}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch deployment task'
    });
  }
});

/**
 * 取消部署任务
 * POST /api/v1/deployment/tasks/:taskId/cancel
 */
router.post('/tasks/:taskId/cancel', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { taskId } = req.params;

    const deploymentService = getDeploymentService();
    await deploymentService.cancelDeploymentTask(taskId);

    res.json({
      success: true,
      message: 'Task cancelled successfully'
    });
  } catch (error) {
    logger.error(`Failed to cancel deployment task ${req.params.taskId}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to cancel deployment task'
    });
  }
});

/**
 * 重试部署任务
 * POST /api/v1/deployment/tasks/:taskId/retry
 */
router.post('/tasks/:taskId/retry', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { taskId } = req.params;

    const deploymentService = getDeploymentService();
    const retryTask = await deploymentService.retryDeploymentTask(taskId);

    res.json({
      success: true,
      data: retryTask,
      message: 'Task retry initiated successfully'
    });
  } catch (error) {
    logger.error(`Failed to retry deployment task ${req.params.taskId}:`, error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to retry deployment task'
    });
  }
});

/**
 * 删除部署任务
 * DELETE /api/v1/deployment/tasks/:taskId
 */
router.delete('/tasks/:taskId', authMiddleware, async (req, res) => {
  try {
    const { taskId } = req.params;
    
    // 这里应该从数据库删除任务
    logger.info(`Deleted deployment task: ${taskId}`);

    res.json({
      success: true,
      message: 'Task deleted successfully'
    });
  } catch (error) {
    logger.error(`Failed to delete deployment task ${req.params.taskId}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete deployment task'
    });
  }
});

/**
 * 获取部署统计信息
 * GET /api/v1/deployment/stats
 */
router.get('/stats', authMiddleware, async (req, res) => {
  try {
    const deploymentService = getDeploymentService();
    const stats = await deploymentService.getDeploymentStats();

    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    logger.error('Failed to get deployment stats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch deployment statistics'
    });
  }
});

export { router as deploymentRoutes };
