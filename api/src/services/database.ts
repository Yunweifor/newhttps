import sqlite3 from 'sqlite3';
import path from 'path';
import fs from 'fs-extra';
import { logger } from '../utils/logger';

export interface Agent {
  id: string;
  hostname: string;
  os: string;
  nginx_version: string;
  nginx_config: string;
  version: string;
  last_seen: string;
  created_at: string;
  status: 'active' | 'inactive' | 'error';
}

export interface AgentActivity {
  id: number;
  agent_id: string;
  action: string;
  details: any;
  timestamp: string;
}

export interface RenewalSchedule {
  id: string;
  certificate_id: string;
  cron_expression: string;
  days_before_expiry: number;
  enabled: boolean;
  last_run?: string;
  next_run?: string;
  last_result?: 'success' | 'failed' | 'skipped';
  last_error?: string;
  created_at: string;
  updated_at: string;
}

export interface Certificate {
  id: string;
  domains: string;
  certificate: string;
  private_key: string;
  certificate_chain: string;
  ca: string;
  status: 'active' | 'expired' | 'revoked' | 'pending';
  issued_at: string;
  expires_at: string;
  created_at: string;
  updated_at: string;
  auto_renew: boolean;
  renew_days: number;
}

/**
 * 数据库服务类
 * 使用 SQLite 存储 Agent 信息和活动日志
 */
export class Database {
  private static instance: Database;
  private db: sqlite3.Database | null = null;
  private dbPath: string;

  private constructor() {
    this.dbPath = path.join(process.cwd(), 'data', 'newhttps.db');
  }

  public static getInstance(): Database {
    if (!Database.instance) {
      Database.instance = new Database();
    }
    return Database.instance;
  }

  /**
   * 初始化数据库
   */
  async init(): Promise<void> {
    try {
      // 确保数据目录存在
      await fs.ensureDir(path.dirname(this.dbPath));

      return new Promise((resolve, reject) => {
        this.db = new sqlite3.Database(this.dbPath, (err) => {
          if (err) {
            logger.error('Failed to open database:', err);
            reject(err);
          } else {
            logger.info(`Database connected: ${this.dbPath}`);
            this.createTables().then(resolve).catch(reject);
          }
        });
      });
    } catch (error) {
      logger.error('Database initialization failed:', error);
      throw error;
    }
  }

  /**
   * 创建数据表
   */
  private async createTables(): Promise<void> {
    const createAgentsTable = `
      CREATE TABLE IF NOT EXISTS agents (
        id TEXT PRIMARY KEY,
        hostname TEXT NOT NULL,
        os TEXT,
        nginx_version TEXT,
        nginx_config TEXT,
        version TEXT,
        last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        status TEXT DEFAULT 'active'
      )
    `;

    const createActivitiesTable = `
      CREATE TABLE IF NOT EXISTS agent_activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        agent_id TEXT NOT NULL,
        action TEXT NOT NULL,
        details TEXT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (agent_id) REFERENCES agents (id)
      )
    `;

    const createCertificatesTable = `
      CREATE TABLE IF NOT EXISTS certificates (
        id TEXT PRIMARY KEY,
        domains TEXT NOT NULL,
        certificate TEXT NOT NULL,
        private_key TEXT NOT NULL,
        certificate_chain TEXT NOT NULL,
        ca TEXT NOT NULL,
        status TEXT DEFAULT 'active',
        issued_at DATETIME NOT NULL,
        expires_at DATETIME NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        auto_renew BOOLEAN DEFAULT 1,
        renew_days INTEGER DEFAULT 30
      )
    `;

    const createRenewalSchedulesTable = `
      CREATE TABLE IF NOT EXISTS renewal_schedules (
        id TEXT PRIMARY KEY,
        certificate_id TEXT NOT NULL,
        cron_expression TEXT NOT NULL,
        days_before_expiry INTEGER DEFAULT 30,
        enabled BOOLEAN DEFAULT 1,
        last_run DATETIME,
        next_run DATETIME,
        last_result TEXT,
        last_error TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (certificate_id) REFERENCES certificates (id)
      )
    `;

    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      this.db.serialize(() => {
        this.db!.run(createAgentsTable, (err) => {
          if (err) {
            logger.error('Failed to create agents table:', err);
            reject(err);
            return;
          }
        });

        this.db!.run(createActivitiesTable, (err) => {
          if (err) {
            logger.error('Failed to create activities table:', err);
            reject(err);
            return;
          }
        });

        this.db!.run(createCertificatesTable, (err) => {
          if (err) {
            logger.error('Failed to create certificates table:', err);
            reject(err);
            return;
          }
        });

        this.db!.run(createRenewalSchedulesTable, (err) => {
          if (err) {
            logger.error('Failed to create renewal schedules table:', err);
            reject(err);
            return;
          }
          resolve();
        });
      });
    });
  }

  /**
   * 注册或更新 Agent
   */
  async registerAgent(agent: Omit<Agent, 'last_seen' | 'created_at' | 'status'>): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = `
        INSERT OR REPLACE INTO agents 
        (id, hostname, os, nginx_version, nginx_config, version, last_seen)
        VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      `;

      this.db.run(sql, [
        agent.id,
        agent.hostname,
        agent.os,
        agent.nginx_version,
        agent.nginx_config,
        agent.version
      ], (err) => {
        if (err) {
          logger.error('Failed to register agent:', err);
          reject(err);
        } else {
          logger.info(`Agent registered: ${agent.id}`);
          resolve();
        }
      });
    });
  }

  /**
   * 获取 Agent 信息
   */
  async getAgent(agentId: string): Promise<Agent | null> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = 'SELECT * FROM agents WHERE id = ?';
      
      this.db.get(sql, [agentId], (err, row: Agent) => {
        if (err) {
          logger.error('Failed to get agent:', err);
          reject(err);
        } else {
          resolve(row || null);
        }
      });
    });
  }

  /**
   * 获取所有 Agent 列表
   */
  async getAllAgents(): Promise<Agent[]> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = 'SELECT * FROM agents ORDER BY last_seen DESC';
      
      this.db.all(sql, [], (err, rows: Agent[]) => {
        if (err) {
          logger.error('Failed to get agents:', err);
          reject(err);
        } else {
          resolve(rows || []);
        }
      });
    });
  }

  /**
   * 更新 Agent 最后活跃时间
   */
  async updateAgentLastSeen(agentId: string): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = 'UPDATE agents SET last_seen = CURRENT_TIMESTAMP WHERE id = ?';
      
      this.db.run(sql, [agentId], (err) => {
        if (err) {
          logger.error('Failed to update agent last seen:', err);
          reject(err);
        } else {
          resolve();
        }
      });
    });
  }

  /**
   * 记录 Agent 活动
   */
  async logAgentActivity(agentId: string, action: string, details: any = {}): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = `
        INSERT INTO agent_activities (agent_id, action, details)
        VALUES (?, ?, ?)
      `;
      
      this.db.run(sql, [agentId, action, JSON.stringify(details)], (err) => {
        if (err) {
          logger.error('Failed to log agent activity:', err);
          reject(err);
        } else {
          resolve();
        }
      });
    });
  }

  /**
   * 获取 Agent 活动日志
   */
  async getAgentActivities(agentId: string, limit: number = 100): Promise<AgentActivity[]> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = `
        SELECT * FROM agent_activities 
        WHERE agent_id = ? 
        ORDER BY timestamp DESC 
        LIMIT ?
      `;
      
      this.db.all(sql, [agentId, limit], (err, rows: AgentActivity[]) => {
        if (err) {
          logger.error('Failed to get agent activities:', err);
          reject(err);
        } else {
          // 解析 details JSON
          const activities = rows.map(row => ({
            ...row,
            details: JSON.parse(row.details || '{}')
          }));
          resolve(activities);
        }
      });
    });
  }

  /**
   * 保存证书到数据库
   */
  async saveCertificate(certificate: Omit<Certificate, 'created_at' | 'updated_at'>): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = `
        INSERT OR REPLACE INTO certificates
        (id, domains, certificate, private_key, certificate_chain, ca, status,
         issued_at, expires_at, auto_renew, renew_days)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;

      this.db.run(sql, [
        certificate.id,
        certificate.domains,
        certificate.certificate,
        certificate.private_key,
        certificate.certificate_chain,
        certificate.ca,
        certificate.status,
        certificate.issued_at,
        certificate.expires_at,
        certificate.auto_renew ? 1 : 0,
        certificate.renew_days
      ], (err) => {
        if (err) {
          logger.error('Failed to save certificate:', err);
          reject(err);
        } else {
          logger.info(`Certificate saved: ${certificate.id}`);
          resolve();
        }
      });
    });
  }

  /**
   * 获取证书
   */
  async getCertificate(certificateId: string): Promise<Certificate | null> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = 'SELECT * FROM certificates WHERE id = ?';

      this.db.get(sql, [certificateId], (err, row: Certificate) => {
        if (err) {
          logger.error('Failed to get certificate:', err);
          reject(err);
        } else {
          resolve(row || null);
        }
      });
    });
  }

  /**
   * 获取所有证书
   */
  async getAllCertificates(): Promise<Certificate[]> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = 'SELECT * FROM certificates ORDER BY created_at DESC';

      this.db.all(sql, [], (err, rows: Certificate[]) => {
        if (err) {
          logger.error('Failed to get certificates:', err);
          reject(err);
        } else {
          resolve(rows || []);
        }
      });
    });
  }

  /**
   * 更新证书
   */
  async updateCertificate(certificate: Certificate): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = `
        UPDATE certificates SET
        domains = ?, certificate = ?, private_key = ?, certificate_chain = ?,
        ca = ?, status = ?, issued_at = ?, expires_at = ?,
        auto_renew = ?, renew_days = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `;

      this.db.run(sql, [
        certificate.domains,
        certificate.certificate,
        certificate.private_key,
        certificate.certificate_chain,
        certificate.ca,
        certificate.status,
        certificate.issued_at,
        certificate.expires_at,
        certificate.auto_renew ? 1 : 0,
        certificate.renew_days,
        certificate.id
      ], (err) => {
        if (err) {
          logger.error('Failed to update certificate:', err);
          reject(err);
        } else {
          logger.info(`Certificate updated: ${certificate.id}`);
          resolve();
        }
      });
    });
  }

  /**
   * 删除证书
   */
  async deleteCertificate(certificateId: string): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = 'DELETE FROM certificates WHERE id = ?';

      this.db.run(sql, [certificateId], (err) => {
        if (err) {
          logger.error('Failed to delete certificate:', err);
          reject(err);
        } else {
          logger.info(`Certificate deleted: ${certificateId}`);
          resolve();
        }
      });
    });
  }

  /**
   * 保存续期调度
   */
  async saveRenewalSchedule(schedule: Omit<RenewalSchedule, 'created_at' | 'updated_at'>): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = `
        INSERT OR REPLACE INTO renewal_schedules
        (id, certificate_id, cron_expression, days_before_expiry, enabled,
         last_run, next_run, last_result, last_error)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;

      this.db.run(sql, [
        schedule.id,
        schedule.certificate_id,
        schedule.cron_expression,
        schedule.days_before_expiry,
        schedule.enabled ? 1 : 0,
        schedule.last_run || null,
        schedule.next_run || null,
        schedule.last_result || null,
        schedule.last_error || null
      ], (err) => {
        if (err) {
          logger.error('Failed to save renewal schedule:', err);
          reject(err);
        } else {
          logger.info(`Renewal schedule saved: ${schedule.id}`);
          resolve();
        }
      });
    });
  }

  /**
   * 获取续期调度
   */
  async getRenewalSchedule(scheduleId: string): Promise<RenewalSchedule | null> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = 'SELECT * FROM renewal_schedules WHERE id = ?';

      this.db.get(sql, [scheduleId], (err, row: RenewalSchedule) => {
        if (err) {
          logger.error('Failed to get renewal schedule:', err);
          reject(err);
        } else {
          resolve(row || null);
        }
      });
    });
  }

  /**
   * 获取所有续期调度
   */
  async getAllRenewalSchedules(): Promise<RenewalSchedule[]> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = 'SELECT * FROM renewal_schedules ORDER BY created_at DESC';

      this.db.all(sql, [], (err, rows: RenewalSchedule[]) => {
        if (err) {
          logger.error('Failed to get renewal schedules:', err);
          reject(err);
        } else {
          resolve(rows || []);
        }
      });
    });
  }

  /**
   * 更新续期调度
   */
  async updateRenewalSchedule(schedule: RenewalSchedule): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = `
        UPDATE renewal_schedules SET
        certificate_id = ?, cron_expression = ?, days_before_expiry = ?, enabled = ?,
        last_run = ?, next_run = ?, last_result = ?, last_error = ?,
        updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `;

      this.db.run(sql, [
        schedule.certificate_id,
        schedule.cron_expression,
        schedule.days_before_expiry,
        schedule.enabled ? 1 : 0,
        schedule.last_run || null,
        schedule.next_run || null,
        schedule.last_result || null,
        schedule.last_error || null,
        schedule.id
      ], (err) => {
        if (err) {
          logger.error('Failed to update renewal schedule:', err);
          reject(err);
        } else {
          logger.info(`Renewal schedule updated: ${schedule.id}`);
          resolve();
        }
      });
    });
  }

  /**
   * 删除续期调度
   */
  async deleteRenewalSchedule(scheduleId: string): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = 'DELETE FROM renewal_schedules WHERE id = ?';

      this.db.run(sql, [scheduleId], (err) => {
        if (err) {
          logger.error('Failed to delete renewal schedule:', err);
          reject(err);
        } else {
          logger.info(`Renewal schedule deleted: ${scheduleId}`);
          resolve();
        }
      });
    });
  }

  /**
   * 更新Agent信息
   */
  async updateAgent(agent: Agent): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = `
        UPDATE agents SET
        hostname = ?, os = ?, nginx_version = ?, nginx_config = ?, version = ?
        WHERE id = ?
      `;

      this.db.run(sql, [
        agent.hostname,
        agent.os,
        agent.nginx_version,
        agent.nginx_config,
        agent.version,
        agent.id
      ], (err) => {
        if (err) {
          logger.error('Failed to update agent:', err);
          reject(err);
        } else {
          logger.info(`Agent updated: ${agent.id}`);
          resolve();
        }
      });
    });
  }

  /**
   * 删除Agent
   */
  async deleteAgent(agentId: string): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not initialized'));
        return;
      }

      const sql = 'DELETE FROM agents WHERE id = ?';

      this.db.run(sql, [agentId], (err) => {
        if (err) {
          logger.error('Failed to delete agent:', err);
          reject(err);
        } else {
          logger.info(`Agent deleted: ${agentId}`);
          resolve();
        }
      });
    });
  }

  /**
   * 关闭数据库连接
   */
  async close(): Promise<void> {
    return new Promise((resolve) => {
      if (this.db) {
        this.db.close((err) => {
          if (err) {
            logger.error('Error closing database:', err);
          } else {
            logger.info('Database connection closed');
          }
          resolve();
        });
      } else {
        resolve();
      }
    });
  }
}
