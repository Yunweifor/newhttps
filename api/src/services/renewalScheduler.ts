import * as cron from 'node-cron';
import { CertificateManager } from './certificateManager';
import { Database } from './database';
import { logger } from '../utils/logger';

export interface RenewalSchedule {
  id: string;
  certificateId: string;
  cronExpression: string;
  daysBeforeExpiry: number;
  enabled: boolean;
  lastRun?: Date;
  nextRun?: Date;
  lastResult?: 'success' | 'failed' | 'skipped';
  lastError?: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface RenewalJob {
  id: string;
  certificateId: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  startedAt?: Date;
  completedAt?: Date;
  error?: string;
  logs: string[];
}

/**
 * 证书自动续期调度器
 * 负责管理证书的自动续期任务
 */
export class RenewalScheduler {
  private static instance: RenewalScheduler;
  private certificateManager: CertificateManager;
  private database: Database;
  private scheduledTasks: Map<string, cron.ScheduledTask> = new Map();
  private isInitialized = false;

  private constructor() {
    this.certificateManager = new CertificateManager();
    this.database = Database.getInstance();
  }

  static getInstance(): RenewalScheduler {
    if (!RenewalScheduler.instance) {
      RenewalScheduler.instance = new RenewalScheduler();
    }
    return RenewalScheduler.instance;
  }

  /**
   * 初始化调度器
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      await this.certificateManager.initialize();
      await this.createRenewalTables();
      await this.loadScheduledTasks();
      
      // 启动主调度任务 - 每小时检查一次
      this.startMainScheduler();
      
      this.isInitialized = true;
      logger.info('Renewal scheduler initialized');
    } catch (error) {
      logger.error('Failed to initialize renewal scheduler:', error);
      throw error;
    }
  }

  /**
   * 创建续期调度
   */
  async createSchedule(schedule: Omit<RenewalSchedule, 'id' | 'createdAt' | 'updatedAt'>): Promise<RenewalSchedule> {
    const scheduleId = this.generateScheduleId();
    const now = new Date();
    
    const newSchedule: RenewalSchedule = {
      id: scheduleId,
      ...schedule,
      createdAt: now,
      updatedAt: now
    };

    // 验证cron表达式
    if (!cron.validate(schedule.cronExpression)) {
      throw new Error('Invalid cron expression');
    }

    // 保存到数据库
    await this.saveScheduleToDatabase(newSchedule);

    // 如果启用，则创建定时任务
    if (schedule.enabled) {
      await this.scheduleTask(newSchedule);
    }

    logger.info(`Created renewal schedule: ${scheduleId} for certificate: ${schedule.certificateId}`);
    return newSchedule;
  }

  /**
   * 更新续期调度
   */
  async updateSchedule(scheduleId: string, updates: Partial<RenewalSchedule>): Promise<RenewalSchedule> {
    const existingSchedule = await this.getScheduleById(scheduleId);
    if (!existingSchedule) {
      throw new Error('Schedule not found');
    }

    const updatedSchedule: RenewalSchedule = {
      ...existingSchedule,
      ...updates,
      updatedAt: new Date()
    };

    // 如果cron表达式改变，验证新的表达式
    if (updates.cronExpression && !cron.validate(updates.cronExpression)) {
      throw new Error('Invalid cron expression');
    }

    // 更新数据库
    await this.updateScheduleInDatabase(updatedSchedule);

    // 重新调度任务
    await this.rescheduleTask(updatedSchedule);

    logger.info(`Updated renewal schedule: ${scheduleId}`);
    return updatedSchedule;
  }

  /**
   * 删除续期调度
   */
  async deleteSchedule(scheduleId: string): Promise<void> {
    // 停止定时任务
    const task = this.scheduledTasks.get(scheduleId);
    if (task) {
      task.stop();
      this.scheduledTasks.delete(scheduleId);
    }

    // 从数据库删除
    await this.deleteScheduleFromDatabase(scheduleId);

    logger.info(`Deleted renewal schedule: ${scheduleId}`);
  }

  /**
   * 获取所有续期调度
   */
  async getAllSchedules(): Promise<RenewalSchedule[]> {
    return this.getSchedulesFromDatabase();
  }

  /**
   * 获取单个续期调度
   */
  async getScheduleById(scheduleId: string): Promise<RenewalSchedule | null> {
    return this.getScheduleFromDatabase(scheduleId);
  }

  /**
   * 手动触发续期
   */
  async triggerRenewal(certificateId: string): Promise<RenewalJob> {
    const jobId = this.generateJobId();
    const job: RenewalJob = {
      id: jobId,
      certificateId,
      status: 'pending',
      logs: []
    };

    try {
      job.status = 'running';
      job.startedAt = new Date();
      job.logs.push(`Started manual renewal for certificate: ${certificateId}`);

      // 执行续期
      const result = await this.certificateManager.renewCertificate(certificateId);
      
      job.status = 'completed';
      job.completedAt = new Date();
      job.logs.push(`Certificate renewed successfully`);

      logger.info(`Manual renewal completed for certificate: ${certificateId}`);
      return job;

    } catch (error) {
      job.status = 'failed';
      job.completedAt = new Date();
      job.error = error instanceof Error ? error.message : 'Unknown error';
      job.logs.push(`Renewal failed: ${job.error}`);

      logger.error(`Manual renewal failed for certificate: ${certificateId}`, error);
      return job;
    }
  }

  /**
   * 启动主调度器
   */
  private startMainScheduler(): void {
    // 每小时检查一次需要续期的证书
    cron.schedule('0 * * * *', async () => {
      try {
        await this.checkAndRenewCertificates();
      } catch (error) {
        logger.error('Main scheduler error:', error);
      }
    });

    logger.info('Main renewal scheduler started (runs every hour)');
  }

  /**
   * 检查并续期证书
   */
  private async checkAndRenewCertificates(): Promise<void> {
    logger.info('Checking certificates for renewal...');

    try {
      // 获取所有启用的调度
      const schedules = await this.getAllSchedules();
      const enabledSchedules = schedules.filter(s => s.enabled);

      for (const schedule of enabledSchedules) {
        try {
          await this.processSchedule(schedule);
        } catch (error) {
          logger.error(`Failed to process schedule ${schedule.id}:`, error);
        }
      }

    } catch (error) {
      logger.error('Failed to check certificates for renewal:', error);
    }
  }

  /**
   * 处理单个调度
   */
  private async processSchedule(schedule: RenewalSchedule): Promise<void> {
    try {
      // 检查证书是否需要续期
      const certificate = await this.certificateManager.getCertificateById(schedule.certificateId);
      if (!certificate) {
        logger.warn(`Certificate not found for schedule ${schedule.id}: ${schedule.certificateId}`);
        return;
      }

      // 检查是否需要续期
      const daysUntilExpiry = Math.ceil((certificate.expiresAt.getTime() - Date.now()) / (1000 * 60 * 60 * 24));
      
      if (daysUntilExpiry <= schedule.daysBeforeExpiry) {
        logger.info(`Certificate ${schedule.certificateId} expires in ${daysUntilExpiry} days, triggering renewal`);
        
        // 更新调度状态
        await this.updateScheduleLastRun(schedule.id, new Date(), 'skipped');

        // 执行续期
        try {
          await this.certificateManager.renewCertificate(schedule.certificateId);
          await this.updateScheduleLastRun(schedule.id, new Date(), 'success');
          logger.info(`Successfully renewed certificate: ${schedule.certificateId}`);
        } catch (error) {
          const errorMessage = error instanceof Error ? error.message : 'Unknown error';
          await this.updateScheduleLastRun(schedule.id, new Date(), 'failed', errorMessage);
          logger.error(`Failed to renew certificate ${schedule.certificateId}:`, error);
        }
      } else {
        logger.debug(`Certificate ${schedule.certificateId} does not need renewal yet (${daysUntilExpiry} days remaining)`);
      }

    } catch (error) {
      logger.error(`Error processing schedule ${schedule.id}:`, error);
    }
  }

  /**
   * 调度任务
   */
  private async scheduleTask(schedule: RenewalSchedule): Promise<void> {
    // 停止现有任务
    const existingTask = this.scheduledTasks.get(schedule.id);
    if (existingTask) {
      existingTask.stop();
    }

    // 创建新任务
    const task = cron.schedule(schedule.cronExpression, async () => {
      await this.processSchedule(schedule);
    }, {
      scheduled: false
    });

    // 启动任务
    task.start();
    this.scheduledTasks.set(schedule.id, task);

    logger.info(`Scheduled renewal task: ${schedule.id} with cron: ${schedule.cronExpression}`);
  }

  /**
   * 重新调度任务
   */
  private async rescheduleTask(schedule: RenewalSchedule): Promise<void> {
    // 停止现有任务
    const existingTask = this.scheduledTasks.get(schedule.id);
    if (existingTask) {
      existingTask.stop();
      this.scheduledTasks.delete(schedule.id);
    }

    // 如果启用，创建新任务
    if (schedule.enabled) {
      await this.scheduleTask(schedule);
    }
  }

  /**
   * 加载已调度的任务
   */
  private async loadScheduledTasks(): Promise<void> {
    try {
      const schedules = await this.getAllSchedules();
      const enabledSchedules = schedules.filter(s => s.enabled);

      for (const schedule of enabledSchedules) {
        await this.scheduleTask(schedule);
      }

      logger.info(`Loaded ${enabledSchedules.length} scheduled renewal tasks`);
    } catch (error) {
      logger.error('Failed to load scheduled tasks:', error);
    }
  }

  // 数据库操作方法
  private async createRenewalTables(): Promise<void> {
    // 数据表已在Database类的createTables方法中创建
    logger.debug('Renewal tables created');
  }

  private async saveScheduleToDatabase(schedule: RenewalSchedule): Promise<void> {
    const dbSchedule = {
      id: schedule.id,
      certificate_id: schedule.certificateId,
      cron_expression: schedule.cronExpression,
      days_before_expiry: schedule.daysBeforeExpiry,
      enabled: schedule.enabled,
      last_run: schedule.lastRun?.toISOString(),
      next_run: schedule.nextRun?.toISOString(),
      last_result: schedule.lastResult,
      last_error: schedule.lastError
    };

    await this.database.saveRenewalSchedule(dbSchedule);
  }

  private async updateScheduleInDatabase(schedule: RenewalSchedule): Promise<void> {
    const dbSchedule = {
      id: schedule.id,
      certificate_id: schedule.certificateId,
      cron_expression: schedule.cronExpression,
      days_before_expiry: schedule.daysBeforeExpiry,
      enabled: schedule.enabled,
      last_run: schedule.lastRun?.toISOString() || undefined,
      next_run: schedule.nextRun?.toISOString() || undefined,
      last_result: schedule.lastResult || undefined,
      last_error: schedule.lastError || undefined,
      created_at: schedule.createdAt.toISOString(),
      updated_at: schedule.updatedAt.toISOString()
    };

    await this.database.updateRenewalSchedule(dbSchedule as any);
  }

  private async deleteScheduleFromDatabase(scheduleId: string): Promise<void> {
    await this.database.deleteRenewalSchedule(scheduleId);
  }

  private async getSchedulesFromDatabase(): Promise<RenewalSchedule[]> {
    const dbSchedules = await this.database.getAllRenewalSchedules();
    return dbSchedules.map(this.convertDbScheduleToSchedule);
  }

  private async getScheduleFromDatabase(scheduleId: string): Promise<RenewalSchedule | null> {
    const dbSchedule = await this.database.getRenewalSchedule(scheduleId);
    return dbSchedule ? this.convertDbScheduleToSchedule(dbSchedule) : null;
  }

  private async updateScheduleLastRun(
    scheduleId: string,
    lastRun: Date,
    result: 'success' | 'failed' | 'skipped',
    error?: string
  ): Promise<void> {
    const schedule = await this.getScheduleById(scheduleId);
    if (schedule) {
      schedule.lastRun = lastRun;
      schedule.lastResult = result;
      schedule.lastError = error;
      schedule.updatedAt = new Date();

      await this.updateScheduleInDatabase(schedule);
    }
  }

  // 转换数据库格式到业务对象格式
  private convertDbScheduleToSchedule(dbSchedule: any): RenewalSchedule {
    return {
      id: dbSchedule.id,
      certificateId: dbSchedule.certificate_id,
      cronExpression: dbSchedule.cron_expression,
      daysBeforeExpiry: dbSchedule.days_before_expiry,
      enabled: Boolean(dbSchedule.enabled),
      lastRun: dbSchedule.last_run ? new Date(dbSchedule.last_run) : undefined,
      nextRun: dbSchedule.next_run ? new Date(dbSchedule.next_run) : undefined,
      lastResult: dbSchedule.last_result,
      lastError: dbSchedule.last_error,
      createdAt: new Date(dbSchedule.created_at),
      updatedAt: new Date(dbSchedule.updated_at)
    };
  }

  // 工具方法
  private generateScheduleId(): string {
    return `schedule_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  private generateJobId(): string {
    return `job_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}
