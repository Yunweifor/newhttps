import * as cron from 'node-cron';
import { Database } from './database';
import { logger } from '../utils/logger';
import * as tls from 'tls';
import * as https from 'https';

export interface CertificateCheck {
  id: string;
  domain: string;
  port: number;
  isValid: boolean;
  expiresAt?: Date;
  issuer?: string;
  daysUntilExpiry?: number;
  lastChecked: Date;
  error?: string;
}

export interface MonitorAlert {
  id: string;
  type: 'expiry_warning' | 'expiry_critical' | 'cert_invalid' | 'agent_offline';
  level: 'info' | 'warning' | 'error' | 'critical';
  title: string;
  message: string;
  domain?: string;
  agentId?: string;
  timestamp: Date;
  acknowledged: boolean;
}

/**
 * 证书监控服务
 * 负责自动检测证书状态、到期时间和健康状况
 */
export class CertificateMonitor {
  private static instance: CertificateMonitor;
  private database: Database;
  private isRunning = false;
  private checkInterval: NodeJS.Timeout | null = null;

  private constructor() {
    this.database = Database.getInstance();
  }

  static getInstance(): CertificateMonitor {
    if (!CertificateMonitor.instance) {
      CertificateMonitor.instance = new CertificateMonitor();
    }
    return CertificateMonitor.instance;
  }

  /**
   * 启动监控服务
   */
  async start(): Promise<void> {
    if (this.isRunning) {
      logger.warn('Certificate monitor is already running');
      return;
    }

    try {
      await this.database.init();
      await this.createMonitorTables();
      
      // 启动定时检查 - 每小时检查一次
      cron.schedule('0 * * * *', async () => {
        await this.performChecks();
      });

      // 立即执行一次检查
      await this.performChecks();

      this.isRunning = true;
      logger.info('Certificate monitor started');
    } catch (error) {
      logger.error('Failed to start certificate monitor:', error);
      throw error;
    }
  }

  /**
   * 停止监控服务
   */
  stop(): void {
    if (this.checkInterval) {
      clearInterval(this.checkInterval);
      this.checkInterval = null;
    }
    this.isRunning = false;
    logger.info('Certificate monitor stopped');
  }

  /**
   * 执行证书检查
   */
  private async performChecks(): Promise<void> {
    logger.info('Starting certificate checks...');

    try {
      // 检查数据库中的所有证书
      const certificates = await this.database.getAllCertificates();
      
      for (const cert of certificates) {
        try {
          const domains = JSON.parse(cert.domains);
          for (const domain of domains) {
            await this.checkDomainCertificate(domain);
          }
        } catch (error) {
          logger.error(`Failed to check certificate ${cert.id}:`, error);
        }
      }

      // 检查Agent状态
      await this.checkAgentStatus();

      logger.info('Certificate checks completed');
    } catch (error) {
      logger.error('Failed to perform certificate checks:', error);
    }
  }

  /**
   * 检查单个域名的证书
   */
  private async checkDomainCertificate(domain: string, port: number = 443): Promise<CertificateCheck> {
    const checkId = `${domain}:${port}`;
    const check: CertificateCheck = {
      id: checkId,
      domain,
      port,
      isValid: false,
      lastChecked: new Date()
    };

    try {
      const certInfo = await this.getCertificateInfo(domain, port);
      
      check.isValid = true;
      check.expiresAt = certInfo.expiresAt;
      check.issuer = certInfo.issuer;
      check.daysUntilExpiry = Math.ceil((certInfo.expiresAt.getTime() - Date.now()) / (1000 * 60 * 60 * 24));

      // 生成告警
      await this.checkForAlerts(check);

      logger.debug(`Certificate check for ${domain}: ${check.daysUntilExpiry} days until expiry`);
    } catch (error) {
      check.error = error instanceof Error ? error.message : 'Unknown error';
      logger.warn(`Certificate check failed for ${domain}:`, error);
      
      // 生成错误告警
      await this.createAlert({
        type: 'cert_invalid',
        level: 'error',
        title: '证书检查失败',
        message: `域名 ${domain} 的证书检查失败: ${check.error}`,
        domain
      });
    }

    // 保存检查结果
    await this.saveCertificateCheck(check);
    return check;
  }

  /**
   * 获取域名证书信息
   */
  private async getCertificateInfo(domain: string, port: number): Promise<{
    expiresAt: Date;
    issuer: string;
  }> {
    return new Promise((resolve, reject) => {
      const options = {
        host: domain,
        port,
        servername: domain,
        rejectUnauthorized: false
      };

      const socket = tls.connect(options, () => {
        const cert = socket.getPeerCertificate();
        
        if (!cert || !cert.valid_to) {
          socket.destroy();
          reject(new Error('No certificate found'));
          return;
        }

        const expiresAt = new Date(cert.valid_to);
        const issuer = cert.issuer?.CN || 'Unknown';

        socket.destroy();
        resolve({ expiresAt, issuer });
      });

      socket.on('error', (error) => {
        reject(error);
      });

      socket.setTimeout(10000, () => {
        socket.destroy();
        reject(new Error('Connection timeout'));
      });
    });
  }

  /**
   * 检查是否需要生成告警
   */
  private async checkForAlerts(check: CertificateCheck): Promise<void> {
    if (!check.daysUntilExpiry) return;

    // 7天内过期 - 紧急告警
    if (check.daysUntilExpiry <= 7) {
      await this.createAlert({
        type: 'expiry_critical',
        level: 'critical',
        title: '证书即将过期',
        message: `域名 ${check.domain} 的证书将在 ${check.daysUntilExpiry} 天后过期`,
        domain: check.domain
      });
    }
    // 30天内过期 - 警告
    else if (check.daysUntilExpiry <= 30) {
      await this.createAlert({
        type: 'expiry_warning',
        level: 'warning',
        title: '证书即将过期',
        message: `域名 ${check.domain} 的证书将在 ${check.daysUntilExpiry} 天后过期`,
        domain: check.domain
      });
    }
  }

  /**
   * 检查Agent状态
   */
  private async checkAgentStatus(): Promise<void> {
    try {
      const agents = await this.database.getAllAgents();
      const now = new Date();
      const offlineThreshold = new Date(now.getTime() - 60 * 60 * 1000); // 1小时

      for (const agent of agents) {
        const lastSeen = new Date(agent.last_seen);
        
        if (lastSeen < offlineThreshold) {
          await this.createAlert({
            type: 'agent_offline',
            level: 'warning',
            title: 'Agent离线',
            message: `Agent ${agent.hostname} (${agent.id}) 已离线超过 1 小时`,
            agentId: agent.id
          });
        }
      }
    } catch (error) {
      logger.error('Failed to check agent status:', error);
    }
  }

  /**
   * 创建告警
   */
  private async createAlert(alertData: Omit<MonitorAlert, 'id' | 'timestamp' | 'acknowledged'>): Promise<void> {
    const alert: MonitorAlert = {
      id: `alert_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      ...alertData,
      timestamp: new Date(),
      acknowledged: false
    };

    try {
      await this.saveAlert(alert);
      logger.info(`Created alert: ${alert.title} - ${alert.message}`);
    } catch (error) {
      logger.error('Failed to create alert:', error);
    }
  }

  /**
   * 获取所有告警
   */
  async getAlerts(limit: number = 50): Promise<MonitorAlert[]> {
    // 这里应该从数据库获取告警
    // 目前返回模拟数据
    return [
      {
        id: 'alert_1',
        type: 'expiry_critical',
        level: 'error',
        title: '证书即将过期',
        message: 'example.com 证书将在 3 天后过期',
        domain: 'example.com',
        timestamp: new Date(),
        acknowledged: false
      }
    ];
  }

  /**
   * 确认告警
   */
  async acknowledgeAlert(alertId: string): Promise<void> {
    // 这里应该更新数据库中的告警状态
    logger.info(`Alert acknowledged: ${alertId}`);
  }

  // 数据库操作方法
  private async createMonitorTables(): Promise<void> {
    // 这里应该创建监控相关的数据表
    logger.debug('Creating monitor tables...');
  }

  private async saveCertificateCheck(check: CertificateCheck): Promise<void> {
    // 保存证书检查结果到数据库
    logger.debug(`Saving certificate check: ${check.id}`);
  }

  private async saveAlert(alert: MonitorAlert): Promise<void> {
    // 保存告警到数据库
    logger.debug(`Saving alert: ${alert.id}`);
  }
}
