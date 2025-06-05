import axios, { AxiosInstance } from 'axios';
import { logger } from '../utils/logger';

export interface CertdConfig {
  baseURL: string;
  token?: string;
  timeout?: number;
}

export interface CertInfo {
  id: string;
  domain: string;
  domains: string[];
  crt: string;
  key: string;
  ca?: string;
  expires: string;
  status: 'valid' | 'expired' | 'expiring';
  createdAt: string;
  updatedAt: string;
}

export interface PipelineInfo {
  id: string;
  name: string;
  status: 'running' | 'success' | 'failed' | 'pending';
  lastRun?: string;
  nextRun?: string;
  cert?: CertInfo;
}

/**
 * Certd-2 客户端
 * 用于与 Certd-2 系统进行交互
 */
export class CertdClient {
  private client: AxiosInstance;
  private config: CertdConfig;

  constructor(config: CertdConfig) {
    this.config = config;
    this.client = axios.create({
      baseURL: config.baseURL,
      timeout: config.timeout || 30000,
      headers: {
        'Content-Type': 'application/json',
        ...(config.token && { 'Authorization': `Bearer ${config.token}` })
      }
    });

    // 请求拦截器
    this.client.interceptors.request.use(
      (config) => {
        logger.debug(`Certd API Request: ${config.method?.toUpperCase()} ${config.url}`);
        return config;
      },
      (error) => {
        logger.error('Certd API Request Error:', error);
        return Promise.reject(error);
      }
    );

    // 响应拦截器
    this.client.interceptors.response.use(
      (response) => {
        logger.debug(`Certd API Response: ${response.status} ${response.config.url}`);
        return response;
      },
      (error) => {
        logger.error('Certd API Response Error:', error.response?.data || error.message);
        return Promise.reject(error);
      }
    );
  }

  /**
   * 获取所有证书列表
   */
  async getCertificates(): Promise<CertInfo[]> {
    try {
      const response = await this.client.get('/api/pi/cert');
      return response.data.data || [];
    } catch (error) {
      logger.error('Failed to get certificates:', error);
      throw new Error('Failed to fetch certificates from Certd');
    }
  }

  /**
   * 根据域名获取证书
   */
  async getCertificateByDomain(domain: string): Promise<CertInfo | null> {
    try {
      const certificates = await this.getCertificates();
      return certificates.find(cert => 
        cert.domain === domain || cert.domains.includes(domain)
      ) || null;
    } catch (error) {
      logger.error(`Failed to get certificate for domain ${domain}:`, error);
      return null;
    }
  }

  /**
   * 获取流水线列表
   */
  async getPipelines(): Promise<PipelineInfo[]> {
    try {
      const response = await this.client.get('/api/pi/pipeline');
      return response.data.data || [];
    } catch (error) {
      logger.error('Failed to get pipelines:', error);
      throw new Error('Failed to fetch pipelines from Certd');
    }
  }

  /**
   * 触发流水线运行
   */
  async runPipeline(pipelineId: string): Promise<boolean> {
    try {
      await this.client.post(`/api/pi/pipeline/${pipelineId}/run`);
      logger.info(`Pipeline ${pipelineId} triggered successfully`);
      return true;
    } catch (error) {
      logger.error(`Failed to run pipeline ${pipelineId}:`, error);
      return false;
    }
  }

  /**
   * 获取流水线状态
   */
  async getPipelineStatus(pipelineId: string): Promise<string> {
    try {
      const response = await this.client.get(`/api/pi/pipeline/${pipelineId}/status`);
      return response.data.status || 'unknown';
    } catch (error) {
      logger.error(`Failed to get pipeline status ${pipelineId}:`, error);
      return 'unknown';
    }
  }

  /**
   * 下载证书文件
   */
  async downloadCertificate(certId: string, format: 'pem' | 'pfx' | 'jks' = 'pem'): Promise<Buffer> {
    try {
      const response = await this.client.get(`/api/pi/cert/${certId}/download`, {
        params: { format },
        responseType: 'arraybuffer'
      });
      return Buffer.from(response.data);
    } catch (error) {
      logger.error(`Failed to download certificate ${certId}:`, error);
      throw new Error('Failed to download certificate');
    }
  }

  /**
   * 检查连接状态
   */
  async checkConnection(): Promise<boolean> {
    try {
      await this.client.get('/api/health');
      return true;
    } catch (error) {
      logger.error('Certd connection check failed:', error);
      return false;
    }
  }
}
