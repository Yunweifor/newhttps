import axios, { AxiosInstance } from 'axios';
import * as crypto from 'crypto';
import { Database } from './database';
import { logger } from '../utils/logger';

export interface AgentConnection {
  id: string;
  hostname: string;
  endpoint: string;
  apiKey: string;
  lastPing?: Date;
  isOnline: boolean;
  version: string;
}

export interface DeploymentCommand {
  id: string;
  type: 'deploy' | 'update' | 'remove' | 'verify';
  certificateId: string;
  target: {
    type: 'nginx' | 'apache' | 'cloudflare' | 'aliyun' | 'tencent';
    config: Record<string, any>;
  };
  certificate?: {
    cert: string;
    key: string;
    chain: string;
    domains: string[];
  };
  timeout: number;
}

export interface DeploymentResult {
  success: boolean;
  message: string;
  details?: any;
  error?: string;
  timestamp: Date;
}

/**
 * Agent通信服务
 * 负责与远程Agent进行安全通信和证书部署
 */
export class AgentCommunication {
  private static instance: AgentCommunication;
  private database: Database;
  private agentClients: Map<string, AxiosInstance> = new Map();
  private connectionPool: Map<string, AgentConnection> = new Map();

  private constructor() {
    this.database = Database.getInstance();
  }

  static getInstance(): AgentCommunication {
    if (!AgentCommunication.instance) {
      AgentCommunication.instance = new AgentCommunication();
    }
    return AgentCommunication.instance;
  }

  /**
   * 初始化Agent连接
   */
  async initialize(): Promise<void> {
    try {
      await this.loadAgentConnections();
      await this.pingAllAgents();
      logger.info('Agent communication service initialized');
    } catch (error) {
      logger.error('Failed to initialize agent communication:', error);
      throw error;
    }
  }

  /**
   * 加载所有Agent连接
   */
  private async loadAgentConnections(): Promise<void> {
    try {
      const agents = await this.database.getAllAgents();
      
      for (const agent of agents) {
        const connection: AgentConnection = {
          id: agent.id,
          hostname: agent.hostname,
          endpoint: this.buildAgentEndpoint(agent.hostname),
          apiKey: this.generateApiKey(agent.id),
          isOnline: false,
          version: agent.version
        };

        this.connectionPool.set(agent.id, connection);
        this.createAgentClient(connection);
      }

      logger.info(`Loaded ${agents.length} agent connections`);
    } catch (error) {
      logger.error('Failed to load agent connections:', error);
      throw error;
    }
  }

  /**
   * 创建Agent HTTP客户端
   */
  private createAgentClient(connection: AgentConnection): void {
    const client = axios.create({
      baseURL: connection.endpoint,
      timeout: 30000,
      headers: {
        'Authorization': `Bearer ${connection.apiKey}`,
        'Content-Type': 'application/json',
        'User-Agent': 'NewHTTPS-Server/1.0.0'
      }
    });

    // 请求拦截器
    client.interceptors.request.use(
      (config) => {
        config.headers['X-Request-ID'] = crypto.randomUUID();
        config.headers['X-Timestamp'] = Date.now().toString();
        return config;
      },
      (error) => Promise.reject(error)
    );

    // 响应拦截器
    client.interceptors.response.use(
      (response) => response,
      (error) => {
        logger.warn(`Agent ${connection.id} request failed:`, error.message);
        return Promise.reject(error);
      }
    );

    this.agentClients.set(connection.id, client);
  }

  /**
   * 部署证书到Agent
   */
  async deployCertificate(
    agentId: string, 
    command: DeploymentCommand
  ): Promise<DeploymentResult> {
    const startTime = Date.now();
    
    try {
      const connection = this.connectionPool.get(agentId);
      if (!connection) {
        throw new Error(`Agent ${agentId} not found`);
      }

      if (!connection.isOnline) {
        throw new Error(`Agent ${agentId} is offline`);
      }

      const client = this.agentClients.get(agentId);
      if (!client) {
        throw new Error(`No client available for agent ${agentId}`);
      }

      logger.info(`Deploying certificate to agent ${agentId}:`, {
        commandId: command.id,
        type: command.type,
        target: command.target.type
      });

      // 发送部署命令到Agent
      const response = await client.post('/api/v1/deploy', {
        command,
        timestamp: Date.now()
      });

      const result: DeploymentResult = {
        success: response.data.success,
        message: response.data.message || 'Deployment completed',
        details: response.data.details,
        timestamp: new Date()
      };

      const duration = Date.now() - startTime;
      logger.info(`Certificate deployment completed for agent ${agentId} in ${duration}ms`);

      return result;

    } catch (error) {
      const duration = Date.now() - startTime;
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      
      logger.error(`Certificate deployment failed for agent ${agentId} after ${duration}ms:`, error);

      return {
        success: false,
        message: 'Deployment failed',
        error: errorMessage,
        timestamp: new Date()
      };
    }
  }

  /**
   * 验证证书部署
   */
  async verifyCertificateDeployment(
    agentId: string,
    domain: string,
    port: number = 443
  ): Promise<DeploymentResult> {
    try {
      const connection = this.connectionPool.get(agentId);
      if (!connection) {
        throw new Error(`Agent ${agentId} not found`);
      }

      const client = this.agentClients.get(agentId);
      if (!client) {
        throw new Error(`No client available for agent ${agentId}`);
      }

      const response = await client.post('/api/v1/verify', {
        domain,
        port,
        timestamp: Date.now()
      });

      return {
        success: response.data.success,
        message: response.data.message || 'Verification completed',
        details: response.data.details,
        timestamp: new Date()
      };

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      
      return {
        success: false,
        message: 'Verification failed',
        error: errorMessage,
        timestamp: new Date()
      };
    }
  }

  /**
   * 检查Agent状态
   */
  async pingAgent(agentId: string): Promise<boolean> {
    try {
      const connection = this.connectionPool.get(agentId);
      if (!connection) {
        return false;
      }

      const client = this.agentClients.get(agentId);
      if (!client) {
        return false;
      }

      const response = await client.get('/api/v1/ping', {
        timeout: 5000
      });

      const isOnline = response.status === 200 && response.data.status === 'ok';
      
      // 更新连接状态
      connection.isOnline = isOnline;
      connection.lastPing = new Date();

      if (isOnline) {
        // 更新数据库中的最后活跃时间
        await this.database.updateAgentLastSeen(agentId);
      }

      return isOnline;

    } catch (error) {
      const connection = this.connectionPool.get(agentId);
      if (connection) {
        connection.isOnline = false;
      }
      
      logger.debug(`Agent ${agentId} ping failed:`, error instanceof Error ? error.message : 'Unknown error');
      return false;
    }
  }

  /**
   * 检查所有Agent状态
   */
  async pingAllAgents(): Promise<Map<string, boolean>> {
    const results = new Map<string, boolean>();
    const pingPromises: Promise<void>[] = [];

    for (const [agentId] of this.connectionPool) {
      const pingPromise = this.pingAgent(agentId).then(isOnline => {
        results.set(agentId, isOnline);
      });
      pingPromises.push(pingPromise);
    }

    await Promise.allSettled(pingPromises);
    
    const onlineCount = Array.from(results.values()).filter(Boolean).length;
    logger.debug(`Agent ping completed: ${onlineCount}/${results.size} agents online`);

    return results;
  }

  /**
   * 获取Agent连接状态
   */
  getAgentConnection(agentId: string): AgentConnection | undefined {
    return this.connectionPool.get(agentId);
  }

  /**
   * 获取所有在线Agent
   */
  getOnlineAgents(): AgentConnection[] {
    return Array.from(this.connectionPool.values()).filter(conn => conn.isOnline);
  }

  /**
   * 添加新的Agent连接
   */
  async addAgentConnection(agentId: string): Promise<void> {
    try {
      const agent = await this.database.getAgent(agentId);
      if (!agent) {
        throw new Error(`Agent ${agentId} not found in database`);
      }

      const connection: AgentConnection = {
        id: agent.id,
        hostname: agent.hostname,
        endpoint: this.buildAgentEndpoint(agent.hostname),
        apiKey: this.generateApiKey(agent.id),
        isOnline: false,
        version: agent.version
      };

      this.connectionPool.set(agentId, connection);
      this.createAgentClient(connection);

      // 立即检查连接状态
      await this.pingAgent(agentId);

      logger.info(`Added agent connection: ${agentId}`);
    } catch (error) {
      logger.error(`Failed to add agent connection ${agentId}:`, error);
      throw error;
    }
  }

  /**
   * 移除Agent连接
   */
  removeAgentConnection(agentId: string): void {
    this.connectionPool.delete(agentId);
    this.agentClients.delete(agentId);
    logger.info(`Removed agent connection: ${agentId}`);
  }

  /**
   * 构建Agent端点URL
   */
  private buildAgentEndpoint(hostname: string): string {
    // 默认使用HTTPS和8443端口
    // 实际部署时应该从配置或数据库获取
    return `https://${hostname}:8443`;
  }

  /**
   * 生成Agent API密钥
   */
  private generateApiKey(agentId: string): string {
    // 使用Agent ID和密钥生成API密钥
    const secret = process.env.AGENT_SECRET || 'default-secret-key';
    return crypto.createHmac('sha256', secret)
      .update(agentId)
      .digest('hex');
  }
}
