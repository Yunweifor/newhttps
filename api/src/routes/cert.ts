import { Router } from 'express';
import { CertdClient } from '../services/certdClient';
import { Database } from '../services/database';
import { logger } from '../utils/logger';
import { authMiddleware } from '../middleware/auth';

const router = Router();

// 获取 Certd 客户端实例
function getCertdClient(): CertdClient {
  const config = {
    baseURL: process.env.CERTD_BASE_URL || 'http://localhost:7001',
    token: process.env.CERTD_TOKEN,
    timeout: 30000
  };
  return new CertdClient(config);
}

/**
 * 获取所有证书列表
 * GET /api/v1/cert/list
 */
router.get('/list', authMiddleware, async (req, res) => {
  try {
    const certdClient = getCertdClient();
    const certificates = await certdClient.getCertificates();
    
    res.json({
      success: true,
      data: certificates,
      total: certificates.length
    });
  } catch (error) {
    logger.error('Failed to get certificate list:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch certificates'
    });
  }
});

/**
 * 根据域名获取证书信息
 * GET /api/v1/cert/domain/:domain
 */
router.get('/domain/:domain', async (req, res): Promise<void> => {
  try {
    const { domain } = req.params;
    const certdClient = getCertdClient();
    const certificate = await certdClient.getCertificateByDomain(domain);
    
    if (!certificate) {
      return res.status(404).json({
        success: false,
        error: 'Certificate not found for domain'
      });
    }

    res.json({
      success: true,
      data: certificate
    });
  } catch (error) {
    logger.error(`Failed to get certificate for domain ${req.params.domain}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch certificate'
    });
  }
});

/**
 * 下载证书文件
 * GET /api/v1/cert/:certId/download
 */
router.get('/:certId/download', async (req, res): Promise<void> => {
  try {
    const { certId } = req.params;
    const { format = 'pem', agent_id } = req.query;
    
    // 验证 agent_id
    if (!agent_id) {
      return res.status(400).json({
        success: false,
        error: 'agent_id is required'
      });
    }

    const db = Database.getInstance();
    const agent = await db.getAgent(agent_id as string);
    
    if (!agent) {
      return res.status(404).json({
        success: false,
        error: 'Agent not found'
      });
    }

    const certdClient = getCertdClient();
    const certBuffer = await certdClient.downloadCertificate(certId, format as any);
    
    // 记录下载日志
    await db.logAgentActivity(agent_id as string, 'download', {
      certId,
      format,
      size: certBuffer.length
    });

    // 设置响应头
    const filename = `${certId}.${format}`;
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-Type', 'application/octet-stream');
    res.setHeader('Content-Length', certBuffer.length);
    
    res.send(certBuffer);
  } catch (error) {
    logger.error(`Failed to download certificate ${req.params.certId}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to download certificate'
    });
  }
});

/**
 * 检查证书更新
 * POST /api/v1/cert/check-updates
 */
router.post('/check-updates', async (req, res): Promise<void> => {
  try {
    const { agent_id, certificates } = req.body;
    
    if (!agent_id || !Array.isArray(certificates)) {
      return res.status(400).json({
        success: false,
        error: 'agent_id and certificates array are required'
      });
    }

    const db = Database.getInstance();
    const agent = await db.getAgent(agent_id);
    
    if (!agent) {
      return res.status(404).json({
        success: false,
        error: 'Agent not found'
      });
    }

    const certdClient = getCertdClient();
    const updates = [];

    for (const localCert of certificates) {
      const remoteCert = await certdClient.getCertificateByDomain(localCert.domain);
      
      if (remoteCert && remoteCert.updatedAt > localCert.updatedAt) {
        updates.push({
          domain: localCert.domain,
          certId: remoteCert.id,
          oldVersion: localCert.updatedAt,
          newVersion: remoteCert.updatedAt,
          expires: remoteCert.expires
        });
      }
    }

    // 更新 agent 最后检查时间
    await db.updateAgentLastSeen(agent_id);

    res.json({
      success: true,
      data: {
        hasUpdates: updates.length > 0,
        updates
      }
    });
  } catch (error) {
    logger.error('Failed to check certificate updates:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to check updates'
    });
  }
});

/**
 * 获取证书详细信息（包含文件内容）
 * GET /api/v1/cert/:certId/details
 */
router.get('/:certId/details', async (req, res): Promise<void> => {
  try {
    const { certId } = req.params;
    const { agent_id } = req.query;
    
    if (!agent_id) {
      return res.status(400).json({
        success: false,
        error: 'agent_id is required'
      });
    }

    const db = Database.getInstance();
    const agent = await db.getAgent(agent_id as string);
    
    if (!agent) {
      return res.status(404).json({
        success: false,
        error: 'Agent not found'
      });
    }

    const certdClient = getCertdClient();
    const certificates = await certdClient.getCertificates();
    const certificate = certificates.find(cert => cert.id === certId);
    
    if (!certificate) {
      return res.status(404).json({
        success: false,
        error: 'Certificate not found'
      });
    }

    res.json({
      success: true,
      data: certificate
    });
  } catch (error) {
    logger.error(`Failed to get certificate details ${req.params.certId}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch certificate details'
    });
  }
});

export { router as certRoutes };
