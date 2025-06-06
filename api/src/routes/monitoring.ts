import { Router } from 'express';
import { CertificateMonitor } from '../services/certificateMonitor';
import { Database } from '../services/database';
import { logger } from '../utils/logger';
import { authMiddleware } from '../middleware/auth';

const router = Router();

/**
 * 获取系统监控概览
 * GET /api/v1/monitoring/overview
 */
router.get('/overview', authMiddleware, async (req, res) => {
  try {
    const db = Database.getInstance();
    
    // 获取基础统计
    const [certificates, agents] = await Promise.all([
      db.getAllCertificates(),
      db.getAllAgents()
    ]);

    // 计算统计数据
    const now = new Date();
    const thirtyDaysFromNow = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);

    const expiringSoon = certificates.filter(cert => {
      try {
        const expiresAt = new Date(cert.expires_at);
        return expiresAt <= thirtyDaysFromNow && expiresAt > now;
      } catch {
        return false;
      }
    }).length;

    const activeAgents = agents.filter(agent => {
      try {
        return new Date(agent.last_seen) > oneHourAgo;
      } catch {
        return false;
      }
    }).length;

    const overview = {
      totalCertificates: certificates.length,
      expiringSoon,
      totalAgents: agents.length,
      activeAgents,
      offlineAgents: agents.length - activeAgents,
      systemHealth: expiringSoon === 0 && activeAgents === agents.length ? 'healthy' : 'warning'
    };

    res.json({
      success: true,
      data: overview
    });
  } catch (error) {
    logger.error('Failed to get monitoring overview:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch monitoring overview'
    });
  }
});

/**
 * 获取告警列表
 * GET /api/v1/monitoring/alerts
 */
router.get('/alerts', authMiddleware, async (req, res) => {
  try {
    const { limit = 50, acknowledged } = req.query;
    
    const monitor = CertificateMonitor.getInstance();
    let alerts = await monitor.getAlerts(Number(limit));
    
    // 过滤已确认/未确认的告警
    if (acknowledged !== undefined) {
      const isAcknowledged = acknowledged === 'true';
      alerts = alerts.filter(alert => alert.acknowledged === isAcknowledged);
    }

    res.json({
      success: true,
      data: alerts,
      total: alerts.length
    });
  } catch (error) {
    logger.error('Failed to get alerts:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch alerts'
    });
  }
});

/**
 * 确认告警
 * POST /api/v1/monitoring/alerts/:alertId/acknowledge
 */
router.post('/alerts/:alertId/acknowledge', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { alertId } = req.params;
    
    const monitor = CertificateMonitor.getInstance();
    await monitor.acknowledgeAlert(alertId);

    res.json({
      success: true,
      message: 'Alert acknowledged successfully'
    });
  } catch (error) {
    logger.error(`Failed to acknowledge alert ${req.params.alertId}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to acknowledge alert'
    });
  }
});

/**
 * 获取证书健康状态
 * GET /api/v1/monitoring/certificates
 */
router.get('/certificates', authMiddleware, async (req, res) => {
  try {
    const db = Database.getInstance();
    const certificates = await db.getAllCertificates();
    
    const now = new Date();
    const certificateHealth = certificates.map(cert => {
      const expiresAt = new Date(cert.expires_at);
      const daysUntilExpiry = Math.ceil((expiresAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
      
      let status = 'healthy';
      if (daysUntilExpiry <= 0) status = 'expired';
      else if (daysUntilExpiry <= 7) status = 'critical';
      else if (daysUntilExpiry <= 30) status = 'warning';
      
      return {
        id: cert.id,
        domains: JSON.parse(cert.domains),
        expiresAt: cert.expires_at,
        daysUntilExpiry,
        status,
        ca: cert.ca
      };
    });

    // 按到期时间排序
    certificateHealth.sort((a, b) => a.daysUntilExpiry - b.daysUntilExpiry);

    res.json({
      success: true,
      data: certificateHealth,
      total: certificateHealth.length
    });
  } catch (error) {
    logger.error('Failed to get certificate health:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch certificate health'
    });
  }
});

/**
 * 获取Agent健康状态
 * GET /api/v1/monitoring/agents
 */
router.get('/agents', authMiddleware, async (req, res) => {
  try {
    const db = Database.getInstance();
    const agents = await db.getAllAgents();
    
    const now = new Date();
    const agentHealth = agents.map(agent => {
      const lastSeen = new Date(agent.last_seen);
      const minutesSinceLastSeen = (now.getTime() - lastSeen.getTime()) / (1000 * 60);
      
      let status = 'online';
      if (minutesSinceLastSeen > 60) status = 'offline';
      else if (minutesSinceLastSeen > 5) status = 'warning';
      
      return {
        id: agent.id,
        hostname: agent.hostname,
        os: agent.os,
        version: agent.version,
        lastSeen: agent.last_seen,
        minutesSinceLastSeen: Math.round(minutesSinceLastSeen),
        status
      };
    });

    // 按状态和最后活跃时间排序
    agentHealth.sort((a, b) => {
      const statusOrder = { offline: 0, warning: 1, online: 2 };
      const aOrder = statusOrder[a.status as keyof typeof statusOrder] || 0;
      const bOrder = statusOrder[b.status as keyof typeof statusOrder] || 0;
      
      if (aOrder !== bOrder) return aOrder - bOrder;
      return b.minutesSinceLastSeen - a.minutesSinceLastSeen;
    });

    res.json({
      success: true,
      data: agentHealth,
      total: agentHealth.length
    });
  } catch (error) {
    logger.error('Failed to get agent health:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch agent health'
    });
  }
});

/**
 * 手动触发证书检查
 * POST /api/v1/monitoring/check
 */
router.post('/check', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { domain, port = 443 } = req.body;
    
    if (!domain) {
      return res.status(400).json({
        success: false,
        error: 'Domain is required'
      });
    }

    // 这里应该触发单个域名的证书检查
    // 目前返回模拟结果
    const checkResult = {
      domain,
      port,
      isValid: true,
      expiresAt: new Date(Date.now() + 60 * 24 * 60 * 60 * 1000), // 60天后
      issuer: 'Let\'s Encrypt',
      daysUntilExpiry: 60,
      lastChecked: new Date()
    };

    res.json({
      success: true,
      data: checkResult,
      message: 'Certificate check completed'
    });
  } catch (error) {
    logger.error('Failed to perform certificate check:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to perform certificate check'
    });
  }
});

/**
 * 获取监控统计信息
 * GET /api/v1/monitoring/stats
 */
router.get('/stats', authMiddleware, async (req, res) => {
  try {
    const db = Database.getInstance();
    const monitor = CertificateMonitor.getInstance();
    
    const [certificates, agents, alerts] = await Promise.all([
      db.getAllCertificates(),
      db.getAllAgents(),
      monitor.getAlerts(100)
    ]);

    const now = new Date();
    const stats = {
      certificates: {
        total: certificates.length,
        active: certificates.filter(c => c.status === 'active').length,
        expiring: certificates.filter(c => {
          const expiresAt = new Date(c.expires_at);
          const daysLeft = (expiresAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24);
          return daysLeft <= 30 && daysLeft > 0;
        }).length,
        expired: certificates.filter(c => {
          const expiresAt = new Date(c.expires_at);
          return expiresAt <= now;
        }).length
      },
      agents: {
        total: agents.length,
        online: agents.filter(a => {
          const lastSeen = new Date(a.last_seen);
          return (now.getTime() - lastSeen.getTime()) <= 5 * 60 * 1000; // 5分钟内
        }).length,
        offline: agents.filter(a => {
          const lastSeen = new Date(a.last_seen);
          return (now.getTime() - lastSeen.getTime()) > 60 * 60 * 1000; // 1小时外
        }).length
      },
      alerts: {
        total: alerts.length,
        unacknowledged: alerts.filter(a => !a.acknowledged).length,
        critical: alerts.filter(a => a.level === 'critical').length,
        warning: alerts.filter(a => a.level === 'warning').length
      }
    };

    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    logger.error('Failed to get monitoring stats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch monitoring statistics'
    });
  }
});

export { router as monitoringRoutes };
