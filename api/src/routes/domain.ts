import { Router } from 'express';
import { authMiddleware } from '../middleware/auth';
import { AcmeClient } from '../services/acmeClient';
import { logger } from '../utils/logger';

const router = Router();

/**
 * 验证域名
 */
router.post('/validate', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { domain } = req.body;

    if (!domain) {
      return res.status(400).json({
        success: false,
        error: 'Domain is required'
      });
    }

    // 创建 ACME 客户端实例
    const acmeClient = new AcmeClient();
    await acmeClient.initialize();

    // 执行域名验证
    const validationResult = await acmeClient.validateDomain(domain);

    if (validationResult.valid) {
      logger.info(`Domain validation successful: ${domain}`);
      res.json({
        success: true,
        domain,
        validation: validationResult.details,
        message: 'Domain validation successful'
      });
    } else {
      logger.warn(`Domain validation failed: ${domain} - ${validationResult.error}`);
      res.status(400).json({
        success: false,
        domain,
        error: validationResult.error,
        details: validationResult.details
      });
    }

  } catch (error) {
    logger.error('Domain validation error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error during domain validation'
    });
  }
});

/**
 * 批量验证域名
 */
router.post('/validate-batch', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { domains } = req.body;

    if (!domains || !Array.isArray(domains) || domains.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Domains array is required'
      });
    }

    if (domains.length > 10) {
      return res.status(400).json({
        success: false,
        error: 'Maximum 10 domains allowed per batch'
      });
    }

    // 创建 ACME 客户端实例
    const acmeClient = new AcmeClient();
    await acmeClient.initialize();

    // 并行验证所有域名
    const validationPromises = domains.map(async (domain: string) => {
      try {
        const result = await acmeClient.validateDomain(domain);
        return {
          domain,
          ...result
        };
      } catch (error) {
        return {
          domain,
          valid: false,
          error: error instanceof Error ? error.message : 'Unknown error'
        };
      }
    });

    const results = await Promise.all(validationPromises);
    
    const validDomains = results.filter(r => r.valid);
    const invalidDomains = results.filter(r => !r.valid);

    logger.info(`Batch validation completed: ${validDomains.length}/${domains.length} domains valid`);

    res.json({
      success: true,
      summary: {
        total: domains.length,
        valid: validDomains.length,
        invalid: invalidDomains.length
      },
      results
    });

  } catch (error) {
    logger.error('Batch domain validation error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error during batch domain validation'
    });
  }
});

/**
 * 检查域名 DNS 记录
 */
router.get('/dns/:domain', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { domain } = req.params;

    if (!domain) {
      return res.status(400).json({
        success: false,
        error: 'Domain is required'
      });
    }

    const dns = require('dns').promises;
    
    try {
      // 并行查询多种记录类型
      const [aRecords, aaaaRecords, cnameRecords, mxRecords, txtRecords] = await Promise.allSettled([
        dns.resolve4(domain),
        dns.resolve6(domain),
        dns.resolveCname(domain),
        dns.resolveMx(domain),
        dns.resolveTxt(domain)
      ]);

      const dnsInfo = {
        domain,
        records: {
          a: aRecords.status === 'fulfilled' ? aRecords.value : [],
          aaaa: aaaaRecords.status === 'fulfilled' ? aaaaRecords.value : [],
          cname: cnameRecords.status === 'fulfilled' ? cnameRecords.value : [],
          mx: mxRecords.status === 'fulfilled' ? mxRecords.value : [],
          txt: txtRecords.status === 'fulfilled' ? txtRecords.value : []
        },
        hasRecords: false
      };

      // 检查是否有任何记录
      dnsInfo.hasRecords = Object.values(dnsInfo.records).some(records => records.length > 0);

      logger.info(`DNS lookup completed for domain: ${domain}`);

      res.json({
        success: true,
        ...dnsInfo
      });

    } catch (error) {
      logger.warn(`DNS lookup failed for domain: ${domain}`, error);
      res.status(400).json({
        success: false,
        domain,
        error: 'DNS lookup failed',
        details: error instanceof Error ? error.message : 'Unknown DNS error'
      });
    }

  } catch (error) {
    logger.error('DNS lookup error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error during DNS lookup'
    });
  }
});

/**
 * 检查域名 HTTP 可达性
 */
router.get('/connectivity/:domain', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { domain } = req.params;
    const { port = 80, secure = false } = req.query;

    if (!domain) {
      return res.status(400).json({
        success: false,
        error: 'Domain is required'
      });
    }

    const testPort = parseInt(port as string) || (secure === 'true' ? 443 : 80);
    const useSecure = secure === 'true';

    // 测试连接
    const connectivityResult = await testDomainConnectivity(domain, testPort, useSecure);

    logger.info(`Connectivity test completed for ${domain}:${testPort} (secure: ${useSecure})`);

    res.json({
      success: true,
      domain,
      port: testPort,
      secure: useSecure,
      ...connectivityResult
    });

  } catch (error) {
    logger.error('Connectivity test error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error during connectivity test'
    });
  }
});

/**
 * 测试域名连接性
 */
async function testDomainConnectivity(
  domain: string, 
  port: number, 
  secure: boolean
): Promise<{ accessible: boolean; status?: number; error?: string; responseTime?: number }> {
  return new Promise((resolve) => {
    const startTime = Date.now();
    const module = secure ? require('https') : require('http');
    
    const req = module.request({
      hostname: domain,
      port: port,
      path: '/',
      method: 'HEAD',
      timeout: 10000,
      rejectUnauthorized: false
    }, (res: any) => {
      const responseTime = Date.now() - startTime;
      resolve({
        accessible: true,
        status: res.statusCode,
        responseTime
      });
    });
    
    req.on('error', (error: any) => {
      const responseTime = Date.now() - startTime;
      resolve({
        accessible: false,
        error: error.message,
        responseTime
      });
    });
    
    req.on('timeout', () => {
      req.destroy();
      const responseTime = Date.now() - startTime;
      resolve({
        accessible: false,
        error: 'Connection timeout',
        responseTime
      });
    });
    
    req.end();
  });
}

export default router;
