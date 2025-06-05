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
