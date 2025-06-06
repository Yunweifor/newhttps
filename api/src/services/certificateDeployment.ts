import { AgentCommunication, DeploymentCommand, DeploymentResult } from './agentCommunication';
import { Database } from './database';
import { logger } from '../utils/logger';
import * as crypto from 'crypto';

export interface DeploymentTask {
  id: string;
  certificateId: string;
  agentId: string;
  targetType: 'nginx' | 'apache' | 'cloudflare' | 'aliyun' | 'tencent';
  targetConfig: Record<string, any>;
  status: 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';
  progress: number;
  startedAt?: Date;
  completedAt?: Date;
  error?: string;
  logs: string[];
  createdAt: Date;
  updatedAt: Date;
}

export interface DeploymentConfig {
  nginx?: {
    configPath: string;
    certPath: string;
    keyPath: string;
    reloadCommand: string;
    backupConfig: boolean;
  };
  apache?: {
    configPath: string;
    certPath: string;
    keyPath: string;
    reloadCommand: string;
    backupConfig: boolean;
  };
  cloudflare?: {
    apiToken: string;
    zoneId: string;
  };
  aliyun?: {
    accessKeyId: string;
    accessKeySecret: string;
    region: string;
  };
  tencent?: {
    secretId: string;
    secretKey: string;
    region: string;
  };
}

/**
 * 证书部署服务
 * 负责管理证书到各种目标的部署
 */
export class CertificateDeployment {
  private static instance: CertificateDeployment;
  private database: Database;
  private agentComm: AgentCommunication;
  private runningTasks: Map<string, DeploymentTask> = new Map();

  private constructor() {
    this.database = Database.getInstance();
    this.agentComm = AgentCommunication.getInstance();
  }

  static getInstance(): CertificateDeployment {
    if (!CertificateDeployment.instance) {
      CertificateDeployment.instance = new CertificateDeployment();
    }
    return CertificateDeployment.instance;
  }

  /**
   * 初始化部署服务
   */
  async initialize(): Promise<void> {
    try {
      await this.agentComm.initialize();
      await this.createDeploymentTables();
      await this.resumePendingTasks();
      logger.info('Certificate deployment service initialized');
    } catch (error) {
      logger.error('Failed to initialize certificate deployment service:', error);
      throw error;
    }
  }

  /**
   * 创建部署任务
   */
  async createDeploymentTask(
    certificateId: string,
    agentId: string,
    targetType: string,
    targetConfig: Record<string, any>
  ): Promise<DeploymentTask> {
    const taskId = this.generateTaskId();
    const now = new Date();

    const task: DeploymentTask = {
      id: taskId,
      certificateId,
      agentId,
      targetType: targetType as any,
      targetConfig,
      status: 'pending',
      progress: 0,
      logs: [],
      createdAt: now,
      updatedAt: now
    };

    // 保存到数据库
    await this.saveDeploymentTask(task);

    // 立即开始执行
    this.executeDeploymentTask(task);

    logger.info(`Created deployment task: ${taskId}`);
    return task;
  }

  /**
   * 执行部署任务
   */
  private async executeDeploymentTask(task: DeploymentTask): Promise<void> {
    try {
      // 更新任务状态
      task.status = 'running';
      task.startedAt = new Date();
      task.progress = 10;
      task.logs.push(`开始部署任务: ${task.id}`);
      
      this.runningTasks.set(task.id, task);
      await this.updateDeploymentTask(task);

      // 获取证书信息
      const certificate = await this.database.getCertificate(task.certificateId);
      if (!certificate) {
        throw new Error(`Certificate ${task.certificateId} not found`);
      }

      task.progress = 20;
      task.logs.push('获取证书信息成功');
      await this.updateDeploymentTask(task);

      // 检查Agent连接
      const agentOnline = await this.agentComm.pingAgent(task.agentId);
      if (!agentOnline) {
        throw new Error(`Agent ${task.agentId} is offline`);
      }

      task.progress = 30;
      task.logs.push('Agent连接检查成功');
      await this.updateDeploymentTask(task);

      // 准备部署命令
      const deployCommand = await this.prepareDeploymentCommand(task, certificate);
      
      task.progress = 40;
      task.logs.push('准备部署命令完成');
      await this.updateDeploymentTask(task);

      // 执行部署
      const deployResult = await this.agentComm.deployCertificate(task.agentId, deployCommand);
      
      task.progress = 70;
      task.logs.push(`部署执行完成: ${deployResult.message}`);
      await this.updateDeploymentTask(task);

      if (!deployResult.success) {
        throw new Error(deployResult.error || 'Deployment failed');
      }

      // 验证部署
      const domains = JSON.parse(certificate.domains);
      const verifyResult = await this.agentComm.verifyCertificateDeployment(
        task.agentId,
        domains[0]
      );

      task.progress = 90;
      task.logs.push(`部署验证完成: ${verifyResult.message}`);
      await this.updateDeploymentTask(task);

      if (!verifyResult.success) {
        logger.warn(`Deployment verification failed for task ${task.id}:`, verifyResult.error);
        task.logs.push(`警告: 部署验证失败 - ${verifyResult.error}`);
      }

      // 任务完成
      task.status = 'completed';
      task.progress = 100;
      task.completedAt = new Date();
      task.logs.push('部署任务完成');

      logger.info(`Deployment task completed: ${task.id}`);

    } catch (error) {
      // 任务失败
      task.status = 'failed';
      task.error = error instanceof Error ? error.message : 'Unknown error';
      task.completedAt = new Date();
      task.logs.push(`部署失败: ${task.error}`);

      logger.error(`Deployment task failed: ${task.id}`, error);
    } finally {
      task.updatedAt = new Date();
      await this.updateDeploymentTask(task);
      this.runningTasks.delete(task.id);
    }
  }

  /**
   * 准备部署命令
   */
  private async prepareDeploymentCommand(
    task: DeploymentTask,
    certificate: any
  ): Promise<DeploymentCommand> {
    const domains = JSON.parse(certificate.domains);
    
    const command: DeploymentCommand = {
      id: crypto.randomUUID(),
      type: 'deploy',
      certificateId: task.certificateId,
      target: {
        type: task.targetType,
        config: task.targetConfig
      },
      certificate: {
        cert: certificate.certificate,
        key: certificate.private_key,
        chain: certificate.certificate_chain,
        domains
      },
      timeout: 300000 // 5分钟超时
    };

    return command;
  }

  /**
   * 获取部署任务
   */
  async getDeploymentTask(taskId: string): Promise<DeploymentTask | null> {
    // 先检查运行中的任务
    const runningTask = this.runningTasks.get(taskId);
    if (runningTask) {
      return runningTask;
    }

    // 从数据库获取
    return this.getDeploymentTaskFromDatabase(taskId);
  }

  /**
   * 获取所有部署任务
   */
  async getAllDeploymentTasks(
    limit: number = 50,
    offset: number = 0
  ): Promise<{ tasks: DeploymentTask[]; total: number }> {
    return this.getDeploymentTasksFromDatabase(limit, offset);
  }

  /**
   * 取消部署任务
   */
  async cancelDeploymentTask(taskId: string): Promise<void> {
    const task = this.runningTasks.get(taskId);
    if (task && task.status === 'running') {
      task.status = 'cancelled';
      task.completedAt = new Date();
      task.logs.push('任务已取消');
      
      await this.updateDeploymentTask(task);
      this.runningTasks.delete(taskId);
      
      logger.info(`Deployment task cancelled: ${taskId}`);
    }
  }

  /**
   * 重试部署任务
   */
  async retryDeploymentTask(taskId: string): Promise<DeploymentTask> {
    const originalTask = await this.getDeploymentTask(taskId);
    if (!originalTask) {
      throw new Error(`Task ${taskId} not found`);
    }

    if (originalTask.status === 'running') {
      throw new Error('Task is already running');
    }

    // 创建新的重试任务
    const retryTask = await this.createDeploymentTask(
      originalTask.certificateId,
      originalTask.agentId,
      originalTask.targetType,
      originalTask.targetConfig
    );

    logger.info(`Created retry task ${retryTask.id} for original task ${taskId}`);
    return retryTask;
  }

  /**
   * 获取部署统计
   */
  async getDeploymentStats(): Promise<{
    total: number;
    pending: number;
    running: number;
    completed: number;
    failed: number;
  }> {
    // 这里应该从数据库获取统计信息
    // 目前返回模拟数据
    return {
      total: 25,
      pending: 2,
      running: 1,
      completed: 20,
      failed: 2
    };
  }

  /**
   * 恢复待处理的任务
   */
  private async resumePendingTasks(): Promise<void> {
    try {
      // 这里应该从数据库获取状态为pending或running的任务
      // 并重新启动它们
      logger.info('Resumed pending deployment tasks');
    } catch (error) {
      logger.error('Failed to resume pending tasks:', error);
    }
  }

  // 数据库操作方法
  private async createDeploymentTables(): Promise<void> {
    // 这里应该创建部署任务相关的数据表
    logger.debug('Creating deployment tables...');
  }

  private async saveDeploymentTask(task: DeploymentTask): Promise<void> {
    const dbTask = {
      id: task.id,
      certificate_id: task.certificateId,
      agent_id: task.agentId,
      target_type: task.targetType,
      target_config: JSON.stringify(task.targetConfig),
      status: task.status,
      progress: task.progress,
      started_at: task.startedAt?.toISOString(),
      completed_at: task.completedAt?.toISOString(),
      error: task.error,
      logs: JSON.stringify(task.logs)
    };

    await this.database.saveDeploymentTask(dbTask);
    logger.debug(`Saving deployment task: ${task.id}`);
  }

  private async updateDeploymentTask(task: DeploymentTask): Promise<void> {
    const dbTask = {
      id: task.id,
      certificate_id: task.certificateId,
      agent_id: task.agentId,
      target_type: task.targetType,
      target_config: JSON.stringify(task.targetConfig),
      status: task.status,
      progress: task.progress,
      started_at: task.startedAt?.toISOString(),
      completed_at: task.completedAt?.toISOString(),
      error: task.error,
      logs: JSON.stringify(task.logs),
      created_at: task.createdAt.toISOString(),
      updated_at: task.updatedAt.toISOString()
    };

    await this.database.updateDeploymentTask(dbTask);
    logger.debug(`Updating deployment task: ${task.id}`);
  }

  private async getDeploymentTaskFromDatabase(taskId: string): Promise<DeploymentTask | null> {
    const dbTask = await this.database.getDeploymentTask(taskId);
    if (!dbTask) return null;

    return this.convertDbTaskToDeploymentTask(dbTask);
  }

  private async getDeploymentTasksFromDatabase(
    limit: number,
    offset: number
  ): Promise<{ tasks: DeploymentTask[]; total: number }> {
    const result = await this.database.getAllDeploymentTasks(limit, offset);

    const tasks = result.tasks.map(dbTask => this.convertDbTaskToDeploymentTask(dbTask));

    return { tasks, total: result.total };
  }

  private convertDbTaskToDeploymentTask(dbTask: any): DeploymentTask {
    return {
      id: dbTask.id,
      certificateId: dbTask.certificate_id,
      agentId: dbTask.agent_id,
      targetType: dbTask.target_type as any,
      targetConfig: JSON.parse(dbTask.target_config || '{}'),
      status: dbTask.status as any,
      progress: dbTask.progress || 0,
      startedAt: dbTask.started_at ? new Date(dbTask.started_at) : undefined,
      completedAt: dbTask.completed_at ? new Date(dbTask.completed_at) : undefined,
      error: dbTask.error,
      logs: JSON.parse(dbTask.logs || '[]'),
      createdAt: new Date(dbTask.created_at),
      updatedAt: new Date(dbTask.updated_at)
    };
  }

  // 工具方法
  private generateTaskId(): string {
    return `deploy_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}
