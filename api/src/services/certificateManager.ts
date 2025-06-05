import { AcmeClient, AcmeConfig, CertificateRequest, CertificateResult } from './acmeClient';
import { Database } from './database';
import { logger } from '../utils/logger';
import { promises as fs } from 'fs';
import path from 'path';
import crypto from 'crypto';

export interface Certificate {
  id: string;
  domains: string[];
  certificate: string;
  privateKey: string;
  certificateChain: string;
  ca: string;
  status: 'active' | 'expired' | 'revoked' | 'pending';
  issuedAt: Date;
  expiresAt: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface CertificateCreateRequest {
  domains: string[];
  ca: 'letsencrypt' | 'letsencrypt-staging' | 'zerossl' | 'google';
  email: string;
  challengeType?: 'http-01' | 'dns-01';
  autoRenew?: boolean;
  renewDays?: number;
}

/**
 * 证书管理服务
 * 提供完整的证书生命周期管理
 */
export class CertificateManager {
  private acmeClient: AcmeClient;
  private database: Database;
  private certsDir: string;

  constructor(dataDir: string = './data') {
    this.acmeClient = new AcmeClient(path.join(dataDir, 'acme'));
    this.database = Database.getInstance();
    this.certsDir = path.join(dataDir, 'certificates');
  }

  /**
   * 初始化证书管理器
   */
  async initialize(): Promise<void> {
    try {
      await fs.mkdir(this.certsDir, { recursive: true });
      await this.acmeClient.initialize();
      await this.createCertificatesTable();
      logger.info('Certificate manager initialized');
    } catch (error) {
      logger.error('Failed to initialize certificate manager:', error);
      throw error;
    }
  }

  /**
   * 申请新证书
   */
  async createCertificate(request: CertificateCreateRequest): Promise<Certificate> {
    logger.info(`Creating certificate for domains: ${request.domains.join(', ')}`);

    try {
      // 验证域名
      this.validateDomains(request.domains);

      // 检查是否已存在相同域名的证书
      const existing = await this.findCertificateByDomains(request.domains);
      if (existing && existing.status === 'active') {
        throw new Error('Certificate already exists for these domains');
      }

      // 准备 ACME 请求
      const acmeRequest: CertificateRequest = {
        domains: request.domains,
        config: {
          ca: request.ca,
          email: request.email,
          challengeType: request.challengeType || 'http-01'
        },
        challengeHandler: this.createChallengeHandler(),
        cleanupHandler: this.createCleanupHandler()
      };

      // 申请证书
      const result = await this.acmeClient.requestCertificate(acmeRequest);

      // 生成证书 ID
      const certId = this.generateCertificateId(request.domains);

      // 保存证书文件
      await this.saveCertificateFiles(certId, result);

      // 创建证书记录
      const certificate: Certificate = {
        id: certId,
        domains: request.domains,
        certificate: result.certificate,
        privateKey: result.privateKey,
        certificateChain: result.certificateChain,
        ca: request.ca,
        status: 'active',
        issuedAt: new Date(),
        expiresAt: result.expiresAt,
        createdAt: new Date(),
        updatedAt: new Date()
      };

      // 保存到数据库
      await this.saveCertificateToDatabase(certificate);

      // 如果启用自动续期，添加到续期队列
      if (request.autoRenew !== false) {
        await this.scheduleRenewal(certId, request.renewDays || 30);
      }

      logger.info(`Certificate created successfully: ${certId}`);
      return certificate;

    } catch (error) {
      logger.error('Failed to create certificate:', error);
      throw error;
    }
  }

  /**
   * 续期证书
   */
  async renewCertificate(certificateId: string): Promise<Certificate> {
    logger.info(`Renewing certificate: ${certificateId}`);

    try {
      // 获取现有证书
      const existing = await this.getCertificateById(certificateId);
      if (!existing) {
        throw new Error('Certificate not found');
      }

      // 检查是否需要续期
      if (!this.needsRenewal(existing)) {
        logger.info(`Certificate ${certificateId} does not need renewal yet`);
        return existing;
      }

      // 准备续期请求
      const acmeConfig: AcmeConfig = {
        ca: existing.ca as any,
        email: 'admin@example.com', // 这里应该从配置或数据库获取
        challengeType: 'http-01'
      };

      // 执行续期
      const result = await this.acmeClient.renewCertificate(
        existing.certificate,
        existing.privateKey,
        acmeConfig
      );

      // 更新证书信息
      const updatedCertificate: Certificate = {
        ...existing,
        certificate: result.certificate,
        privateKey: result.privateKey,
        certificateChain: result.certificateChain,
        issuedAt: new Date(),
        expiresAt: result.expiresAt,
        updatedAt: new Date()
      };

      // 保存新证书文件
      await this.saveCertificateFiles(certificateId, result);

      // 更新数据库
      await this.updateCertificateInDatabase(updatedCertificate);

      logger.info(`Certificate renewed successfully: ${certificateId}`);
      return updatedCertificate;

    } catch (error) {
      logger.error(`Failed to renew certificate ${certificateId}:`, error);
      throw error;
    }
  }

  /**
   * 获取所有证书
   */
  async getAllCertificates(): Promise<Certificate[]> {
    try {
      return await this.getCertificatesFromDatabase();
    } catch (error) {
      logger.error('Failed to get certificates:', error);
      throw error;
    }
  }

  /**
   * 根据 ID 获取证书
   */
  async getCertificateById(id: string): Promise<Certificate | null> {
    try {
      return await this.getCertificateFromDatabase(id);
    } catch (error) {
      logger.error(`Failed to get certificate ${id}:`, error);
      return null;
    }
  }

  /**
   * 根据域名查找证书
   */
  async findCertificateByDomain(domain: string): Promise<Certificate | null> {
    try {
      const certificates = await this.getAllCertificates();
      return certificates.find(cert => 
        cert.domains.includes(domain) && cert.status === 'active'
      ) || null;
    } catch (error) {
      logger.error(`Failed to find certificate for domain ${domain}:`, error);
      return null;
    }
  }

  /**
   * 检查需要续期的证书
   */
  async checkRenewals(daysBeforeExpiry: number = 30): Promise<Certificate[]> {
    try {
      const certificates = await this.getAllCertificates();
      const renewalDate = new Date();
      renewalDate.setDate(renewalDate.getDate() + daysBeforeExpiry);

      return certificates.filter(cert => 
        cert.status === 'active' && cert.expiresAt <= renewalDate
      );
    } catch (error) {
      logger.error('Failed to check renewals:', error);
      return [];
    }
  }

  /**
   * 删除证书
   */
  async deleteCertificate(certificateId: string): Promise<void> {
    try {
      // 删除证书文件
      await this.deleteCertificateFiles(certificateId);

      // 从数据库删除
      await this.deleteCertificateFromDatabase(certificateId);

      logger.info(`Certificate deleted: ${certificateId}`);
    } catch (error) {
      logger.error(`Failed to delete certificate ${certificateId}:`, error);
      throw error;
    }
  }

  /**
   * 验证域名格式
   */
  private validateDomains(domains: string[]): void {
    if (!domains || domains.length === 0) {
      throw new Error('At least one domain is required');
    }

    const domainRegex = /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;
    
    for (const domain of domains) {
      if (!domainRegex.test(domain)) {
        throw new Error(`Invalid domain format: ${domain}`);
      }
    }
  }

  /**
   * 生成证书 ID
   */
  private generateCertificateId(domains: string[]): string {
    const domainsStr = domains.sort().join(',');
    const hash = crypto.createHash('sha256').update(domainsStr).digest('hex');
    return hash.substring(0, 16);
  }

  /**
   * 检查证书是否需要续期
   */
  private needsRenewal(certificate: Certificate, daysBeforeExpiry: number = 30): boolean {
    const renewalDate = new Date();
    renewalDate.setDate(renewalDate.getDate() + daysBeforeExpiry);
    return certificate.expiresAt <= renewalDate;
  }

  /**
   * 根据域名查找证书
   */
  private async findCertificateByDomains(domains: string[]): Promise<Certificate | null> {
    const certificates = await this.getAllCertificates();
    return certificates.find(cert => {
      const certDomains = cert.domains.sort();
      const requestDomains = domains.sort();
      return JSON.stringify(certDomains) === JSON.stringify(requestDomains);
    }) || null;
  }

  /**
   * 保存证书文件到磁盘
   */
  private async saveCertificateFiles(certId: string, result: CertificateResult): Promise<void> {
    const certDir = path.join(this.certsDir, certId);
    await fs.mkdir(certDir, { recursive: true });

    await fs.writeFile(path.join(certDir, 'cert.pem'), result.certificate);
    await fs.writeFile(path.join(certDir, 'key.pem'), result.privateKey);
    await fs.writeFile(path.join(certDir, 'chain.pem'), result.certificateChain);
    await fs.writeFile(path.join(certDir, 'fullchain.pem'), 
      result.certificate + '\n' + result.certificateChain);
  }

  /**
   * 删除证书文件
   */
  private async deleteCertificateFiles(certId: string): Promise<void> {
    const certDir = path.join(this.certsDir, certId);
    try {
      await fs.rm(certDir, { recursive: true, force: true });
    } catch (error) {
      logger.warn(`Failed to delete certificate files for ${certId}:`, error);
    }
  }

  /**
   * 创建挑战处理器
   */
  private createChallengeHandler() {
    return async (domain: string, token: string, keyAuth: string) => {
      // 这里可以实现自定义的挑战处理逻辑
      // 例如：自动配置 Web 服务器、DNS 记录等
      logger.info(`Setting up challenge for domain ${domain}`);
      
      // 创建挑战文件目录
      const challengeDir = path.join(this.certsDir, '.well-known', 'acme-challenge');
      await fs.mkdir(challengeDir, { recursive: true });
      
      // 写入挑战文件
      const challengeFile = path.join(challengeDir, token);
      await fs.writeFile(challengeFile, keyAuth);
      
      logger.info(`Challenge file created: ${challengeFile}`);
    };
  }

  /**
   * 创建清理处理器
   */
  private createCleanupHandler() {
    return async (domain: string, token: string) => {
      logger.info(`Cleaning up challenge for domain ${domain}`);
      
      const challengeFile = path.join(this.certsDir, '.well-known', 'acme-challenge', token);
      try {
        await fs.unlink(challengeFile);
        logger.debug(`Challenge file removed: ${challengeFile}`);
      } catch (error) {
        logger.warn(`Failed to remove challenge file: ${error instanceof Error ? error.message : String(error)}`);
      }
    };
  }

  /**
   * 创建证书表
   */
  private async createCertificatesTable(): Promise<void> {
    // 这里应该实现数据库表创建逻辑
    // 由于 Database 类已经存在，这里只是占位符
    logger.debug('Certificates table ready');
  }

  /**
   * 保存证书到数据库
   */
  private async saveCertificateToDatabase(certificate: Certificate): Promise<void> {
    // 实际实现需要在 Database 类中添加证书相关方法
    logger.debug(`Saving certificate to database: ${certificate.id}`);
  }

  /**
   * 从数据库获取证书
   */
  private async getCertificateFromDatabase(id: string): Promise<Certificate | null> {
    // 实际实现需要在 Database 类中添加证书相关方法
    logger.debug(`Getting certificate from database: ${id}`);
    return null;
  }

  /**
   * 从数据库获取所有证书
   */
  private async getCertificatesFromDatabase(): Promise<Certificate[]> {
    // 实际实现需要在 Database 类中添加证书相关方法
    logger.debug('Getting all certificates from database');
    return [];
  }

  /**
   * 更新数据库中的证书
   */
  private async updateCertificateInDatabase(certificate: Certificate): Promise<void> {
    // 实际实现需要在 Database 类中添加证书相关方法
    logger.debug(`Updating certificate in database: ${certificate.id}`);
  }

  /**
   * 从数据库删除证书
   */
  private async deleteCertificateFromDatabase(id: string): Promise<void> {
    // 实际实现需要在 Database 类中添加证书相关方法
    logger.debug(`Deleting certificate from database: ${id}`);
  }

  /**
   * 安排证书续期
   */
  private async scheduleRenewal(certificateId: string, daysBeforeExpiry: number): Promise<void> {
    // 这里可以实现续期调度逻辑
    // 例如：添加到任务队列、设置定时器等
    logger.debug(`Scheduled renewal for certificate ${certificateId} (${daysBeforeExpiry} days before expiry)`);
  }
}
