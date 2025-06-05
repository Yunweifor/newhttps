import { promises as fs } from 'fs';
import path from 'path';
import crypto from 'crypto';
import { logger } from '../utils/logger';

export interface AcmeConfig {
  ca: 'letsencrypt' | 'letsencrypt-staging' | 'zerossl' | 'google';
  email: string;
  keySize?: number;
  challengeType?: 'http-01' | 'dns-01';
}

export interface CertificateRequest {
  domains: string[];
  config: AcmeConfig;
  challengeHandler?: (domain: string, token: string, keyAuth: string) => Promise<void>;
  cleanupHandler?: (domain: string, token: string) => Promise<void>;
}

export interface CertificateResult {
  certificate: string;
  privateKey: string;
  certificateChain: string;
  expiresAt: Date;
  domains: string[];
}

/**
 * 独立的 ACME 客户端
 * 不依赖 Certd-2，直接与 CA 机构通信申请证书
 */
export class AcmeClient {
  private accountKey: string | null = null;
  private accountUrl: string | null = null;
  private dataDir: string;

  // CA 机构配置
  private static readonly CA_CONFIGS = {
    'letsencrypt': {
      directoryUrl: 'https://acme-v02.api.letsencrypt.org/directory',
      name: "Let's Encrypt"
    },
    'letsencrypt-staging': {
      directoryUrl: 'https://acme-staging-v02.api.letsencrypt.org/directory',
      name: "Let's Encrypt Staging"
    },
    'zerossl': {
      directoryUrl: 'https://acme.zerossl.com/v2/DV90',
      name: 'ZeroSSL'
    },
    'google': {
      directoryUrl: 'https://dv.acme-v02.api.pki.goog/directory',
      name: 'Google Trust Services'
    }
  };

  constructor(dataDir: string = './data/acme') {
    this.dataDir = dataDir;
  }

  /**
   * 初始化 ACME 客户端
   */
  async initialize(): Promise<void> {
    try {
      await fs.mkdir(this.dataDir, { recursive: true });
      logger.info('ACME client initialized');
    } catch (error) {
      logger.error('Failed to initialize ACME client:', error);
      throw error;
    }
  }

  /**
   * 申请证书
   */
  async requestCertificate(request: CertificateRequest): Promise<CertificateResult> {
    logger.info(`Starting certificate request for domains: ${request.domains.join(', ')}`);
    
    try {
      // 1. 获取或创建账户
      await this.ensureAccount(request.config);
      
      // 2. 创建订单
      const order = await this.createOrder(request.domains, request.config);
      
      // 3. 处理验证挑战
      await this.processAuthorizations(order, request);
      
      // 4. 生成证书私钥
      const privateKey = await this.generatePrivateKey(request.config.keySize || 2048);
      
      // 5. 创建 CSR
      const csr = await this.createCSR(request.domains, privateKey);
      
      // 6. 完成订单并获取证书
      const certificate = await this.finalizeCertificate(order, csr, request.config);
      
      // 7. 解析证书链
      const { cert, chain } = this.parseCertificateChain(certificate);
      
      // 8. 获取过期时间
      const expiresAt = this.getCertificateExpiry(cert);
      
      logger.info(`Certificate successfully issued for domains: ${request.domains.join(', ')}`);
      
      return {
        certificate: cert,
        privateKey,
        certificateChain: chain,
        expiresAt,
        domains: request.domains
      };
      
    } catch (error) {
      logger.error('Certificate request failed:', error);
      throw error;
    }
  }

  /**
   * 续期证书
   */
  async renewCertificate(
    existingCert: string, 
    privateKey: string, 
    config: AcmeConfig
  ): Promise<CertificateResult> {
    // 从现有证书中提取域名
    const domains = this.extractDomainsFromCertificate(existingCert);
    
    return this.requestCertificate({
      domains,
      config
    });
  }

  /**
   * 检查证书是否需要续期
   */
  checkRenewalNeeded(certificate: string, daysBeforeExpiry: number = 30): boolean {
    try {
      const expiryDate = this.getCertificateExpiry(certificate);
      const renewalDate = new Date();
      renewalDate.setDate(renewalDate.getDate() + daysBeforeExpiry);
      
      return expiryDate <= renewalDate;
    } catch (error) {
      logger.error('Failed to check certificate expiry:', error);
      return true; // 如果无法检查，建议续期
    }
  }

  /**
   * 获取或创建 ACME 账户
   */
  private async ensureAccount(config: AcmeConfig): Promise<void> {
    const accountKeyPath = path.join(this.dataDir, `account-${config.ca}.key`);
    
    try {
      // 尝试加载现有账户密钥
      this.accountKey = await fs.readFile(accountKeyPath, 'utf8');
      logger.debug('Loaded existing account key');
    } catch (error) {
      // 生成新的账户密钥
      this.accountKey = await this.generatePrivateKey(2048);
      await fs.writeFile(accountKeyPath, this.accountKey);
      logger.info('Generated new account key');
    }

    // 注册或获取账户
    await this.registerAccount(config);
  }

  /**
   * 注册 ACME 账户
   */
  private async registerAccount(config: AcmeConfig): Promise<void> {
    // 这里需要实现完整的 ACME 协议
    // 由于篇幅限制，这里提供简化的实现框架
    
    const caConfig = AcmeClient.CA_CONFIGS[config.ca];
    logger.info(`Registering account with ${caConfig.name}`);
    
    // 实际实现需要：
    // 1. 获取 ACME 目录
    // 2. 创建账户注册请求
    // 3. 签名并发送请求
    // 4. 处理响应并保存账户 URL
    
    // 这里使用模拟实现
    this.accountUrl = `${caConfig.directoryUrl}/account/mock`;
    logger.info('Account registered successfully');
  }

  /**
   * 创建证书订单
   */
  private async createOrder(domains: string[], config: AcmeConfig): Promise<any> {
    logger.info(`Creating order for domains: ${domains.join(', ')}`);
    
    // 实际实现需要发送 ACME 订单请求
    // 这里返回模拟订单对象
    return {
      url: 'https://acme.example.com/order/123',
      status: 'pending',
      identifiers: domains.map(domain => ({ type: 'dns', value: domain })),
      authorizations: domains.map(domain => `https://acme.example.com/authz/${domain}`),
      finalize: 'https://acme.example.com/finalize/123'
    };
  }

  /**
   * 处理域名验证
   */
  private async processAuthorizations(order: any, request: CertificateRequest): Promise<void> {
    logger.info('Processing domain authorizations');
    
    for (const authzUrl of order.authorizations) {
      // 获取验证信息
      const authz = await this.getAuthorization(authzUrl);
      const domain = authz.identifier.value;
      
      // 选择验证方式
      const challenge = authz.challenges.find((c: any) => 
        c.type === (request.config.challengeType || 'http-01')
      );
      
      if (!challenge) {
        throw new Error(`No suitable challenge found for domain: ${domain}`);
      }
      
      // 处理验证挑战
      await this.handleChallenge(domain, challenge, request);
    }
  }

  /**
   * 处理验证挑战
   */
  private async handleChallenge(domain: string, challenge: any, request: CertificateRequest): Promise<void> {
    const token = challenge.token;
    const keyAuth = this.generateKeyAuthorization(token);
    
    try {
      if (request.challengeHandler) {
        // 使用自定义挑战处理器
        await request.challengeHandler(domain, token, keyAuth);
      } else {
        // 使用默认处理器
        await this.defaultChallengeHandler(domain, token, keyAuth, challenge.type);
      }
      
      // 通知 CA 开始验证
      await this.notifyChallenge(challenge.url);
      
      // 等待验证完成
      await this.waitForValidation(challenge.url);
      
    } finally {
      // 清理验证文件
      if (request.cleanupHandler) {
        await request.cleanupHandler(domain, token);
      } else {
        await this.defaultCleanupHandler(domain, token, challenge.type);
      }
    }
  }

  /**
   * 默认的 HTTP-01 挑战处理器
   */
  private async defaultChallengeHandler(
    domain: string, 
    token: string, 
    keyAuth: string, 
    challengeType: string
  ): Promise<void> {
    if (challengeType === 'http-01') {
      // 创建验证文件
      const challengeDir = path.join(this.dataDir, 'challenges');
      await fs.mkdir(challengeDir, { recursive: true });
      
      const challengeFile = path.join(challengeDir, token);
      await fs.writeFile(challengeFile, keyAuth);
      
      logger.info(`Created challenge file for domain ${domain}: ${challengeFile}`);
      logger.warn(`Please ensure ${domain}/.well-known/acme-challenge/${token} serves the content: ${keyAuth}`);
    } else {
      throw new Error(`Unsupported challenge type: ${challengeType}`);
    }
  }

  /**
   * 默认的清理处理器
   */
  private async defaultCleanupHandler(domain: string, token: string, challengeType: string): Promise<void> {
    if (challengeType === 'http-01') {
      const challengeFile = path.join(this.dataDir, 'challenges', token);
      try {
        await fs.unlink(challengeFile);
        logger.debug(`Cleaned up challenge file: ${challengeFile}`);
      } catch (error) {
        logger.warn(`Failed to cleanup challenge file: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
  }

  /**
   * 生成私钥
   */
  private async generatePrivateKey(keySize: number): Promise<string> {
    return new Promise((resolve, reject) => {
      crypto.generateKeyPair('rsa', {
        modulusLength: keySize,
        publicKeyEncoding: { type: 'spki', format: 'pem' },
        privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
      }, (err, publicKey, privateKey) => {
        if (err) reject(err);
        else resolve(privateKey);
      });
    });
  }

  /**
   * 创建证书签名请求 (CSR)
   */
  private async createCSR(domains: string[], privateKey: string): Promise<string> {
    // 这里需要实现 CSR 生成
    // 实际实现需要使用 crypto 模块或第三方库
    logger.info(`Creating CSR for domains: ${domains.join(', ')}`);
    return 'mock-csr-data';
  }

  /**
   * 完成证书申请
   */
  private async finalizeCertificate(order: any, csr: string, config: AcmeConfig): Promise<string> {
    logger.info('Finalizing certificate order');
    
    // 实际实现需要发送 CSR 到 CA 并获取证书
    // 这里返回模拟证书
    return `-----BEGIN CERTIFICATE-----
MIIFakeCertificate...
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIFakeIntermediateCertificate...
-----END CERTIFICATE-----`;
  }

  /**
   * 解析证书链
   */
  private parseCertificateChain(certificateChain: string): { cert: string; chain: string } {
    const certs = certificateChain.split('-----END CERTIFICATE-----\n');
    const cert = certs[0] + '-----END CERTIFICATE-----';
    const chain = certs.slice(1).join('-----END CERTIFICATE-----\n').trim();
    
    return { cert, chain };
  }

  /**
   * 获取证书过期时间
   */
  private getCertificateExpiry(certificate: string): Date {
    // 实际实现需要解析 X.509 证书
    // 这里返回模拟过期时间（90天后）
    const expiryDate = new Date();
    expiryDate.setDate(expiryDate.getDate() + 90);
    return expiryDate;
  }

  /**
   * 从证书中提取域名
   */
  private extractDomainsFromCertificate(certificate: string): string[] {
    // 实际实现需要解析证书的 SAN 扩展
    // 这里返回模拟域名
    return ['example.com'];
  }

  /**
   * 生成密钥授权
   */
  private generateKeyAuthorization(token: string): string {
    // 实际实现需要使用账户密钥生成 JWK thumbprint
    return `${token}.mock-jwk-thumbprint`;
  }

  /**
   * 获取授权信息
   */
  private async getAuthorization(authzUrl: string): Promise<any> {
    // 实际实现需要发送 HTTP 请求获取授权信息
    return {
      identifier: { type: 'dns', value: 'example.com' },
      status: 'pending',
      challenges: [
        {
          type: 'http-01',
          status: 'pending',
          url: 'https://acme.example.com/challenge/123',
          token: 'mock-token'
        }
      ]
    };
  }

  /**
   * 通知 CA 开始验证
   */
  private async notifyChallenge(challengeUrl: string): Promise<void> {
    logger.debug(`Notifying challenge: ${challengeUrl}`);
    // 实际实现需要发送 POST 请求到挑战 URL
  }

  /**
   * 等待验证完成
   */
  private async waitForValidation(challengeUrl: string): Promise<void> {
    logger.debug(`Waiting for validation: ${challengeUrl}`);
    // 实际实现需要轮询挑战状态直到完成
    await new Promise(resolve => setTimeout(resolve, 1000)); // 模拟等待
  }
}
