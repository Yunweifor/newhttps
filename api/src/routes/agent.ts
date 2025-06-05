import { Router } from 'express';
import { Database } from '../services/database';
import { logger } from '../utils/logger';
import { authMiddleware } from '../middleware/auth';

const router = Router();

/**
 * 注册 Agent
 * POST /api/v1/agent/register
 */
router.post('/register', async (req, res): Promise<any> => {
  try {
    const { agent_id, hostname, os, nginx_version, nginx_config, version } = req.body;
    
    if (!agent_id || !hostname) {
      return res.status(400).json({
        success: false,
        error: 'agent_id and hostname are required'
      });
    }

    const db = Database.getInstance();
    await db.registerAgent({
      id: agent_id,
      hostname,
      os: os || 'unknown',
      nginx_version: nginx_version || 'unknown',
      nginx_config: nginx_config || '',
      version: version || '1.0.0'
    });

    // 记录注册活动
    await db.logAgentActivity(agent_id, 'register', {
      hostname,
      os,
      nginx_version,
      version
    });

    res.json({
      success: true,
      message: 'Agent registered successfully',
      data: {
        agent_id,
        registered_at: new Date().toISOString()
      }
    });
  } catch (error) {
    logger.error('Failed to register agent:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to register agent'
    });
  }
});

/**
 * 获取 Agent 列表
 * GET /api/v1/agent/list
 */
router.get('/list', authMiddleware, async (req, res) => {
  try {
    const db = Database.getInstance();
    const agents = await db.getAllAgents();

    res.json({
      success: true,
      data: agents,
      total: agents.length
    });
  } catch (error) {
    logger.error('Failed to get agent list:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch agents'
    });
  }
});

/**
 * 获取 Agent 详细信息
 * GET /api/v1/agent/:agentId
 */
router.get('/:agentId', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { agentId } = req.params;
    const db = Database.getInstance();
    const agent = await db.getAgent(agentId);

    if (!agent) {
      return res.status(404).json({
        success: false,
        error: 'Agent not found'
      });
    }

    res.json({
      success: true,
      data: agent
    });
  } catch (error) {
    logger.error(`Failed to get agent ${req.params.agentId}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch agent'
    });
  }
});

/**
 * 获取 Agent 活动日志
 * GET /api/v1/agent/:agentId/activities
 */
router.get('/:agentId/activities', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { agentId } = req.params;
    const { limit = 100 } = req.query;
    
    const db = Database.getInstance();
    const agent = await db.getAgent(agentId);
    
    if (!agent) {
      return res.status(404).json({
        success: false,
        error: 'Agent not found'
      });
    }

    const activities = await db.getAgentActivities(agentId, Number(limit));

    res.json({
      success: true,
      data: activities,
      total: activities.length
    });
  } catch (error) {
    logger.error(`Failed to get agent activities ${req.params.agentId}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch agent activities'
    });
  }
});

/**
 * Agent 心跳检测
 * POST /api/v1/agent/:agentId/heartbeat
 */
router.post('/:agentId/heartbeat', async (req, res): Promise<any> => {
  try {
    const { agentId } = req.params;
    const { status, message } = req.body;
    
    const db = Database.getInstance();
    const agent = await db.getAgent(agentId);
    
    if (!agent) {
      return res.status(404).json({
        success: false,
        error: 'Agent not found'
      });
    }

    // 更新最后活跃时间
    await db.updateAgentLastSeen(agentId);
    
    // 记录心跳活动
    await db.logAgentActivity(agentId, 'heartbeat', {
      status: status || 'ok',
      message: message || 'Agent is alive'
    });

    res.json({
      success: true,
      message: 'Heartbeat received',
      data: {
        agent_id: agentId,
        timestamp: new Date().toISOString()
      }
    });
  } catch (error) {
    logger.error(`Failed to process heartbeat for agent ${req.params.agentId}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to process heartbeat'
    });
  }
});

/**
 * 删除 Agent
 * DELETE /api/v1/agent/:agentId
 */
router.delete('/:agentId', authMiddleware, async (req, res) => {
  try {
    const { agentId } = req.params;
    
    // 这里可以添加删除逻辑
    // 目前只是标记为非活跃状态
    
    res.json({
      success: true,
      message: 'Agent deleted successfully'
    });
  } catch (error) {
    logger.error(`Failed to delete agent ${req.params.agentId}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete agent'
    });
  }
});

/**
 * Agent 统计信息
 * GET /api/v1/agent/stats
 */
router.get('/stats', authMiddleware, async (req, res) => {
  try {
    const db = Database.getInstance();
    const agents = await db.getAllAgents();
    
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    
    const stats = {
      total: agents.length,
      active: agents.filter(agent => new Date(agent.last_seen) > oneHourAgo).length,
      inactive: agents.filter(agent => new Date(agent.last_seen) <= oneHourAgo).length,
      by_os: agents.reduce((acc, agent) => {
        acc[agent.os] = (acc[agent.os] || 0) + 1;
        return acc;
      }, {} as Record<string, number>),
      by_version: agents.reduce((acc, agent) => {
        acc[agent.version] = (acc[agent.version] || 0) + 1;
        return acc;
      }, {} as Record<string, number>)
    };

    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    logger.error('Failed to get agent stats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch agent statistics'
    });
  }
});

export { router as agentRoutes };
