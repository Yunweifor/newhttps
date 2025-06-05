import { AbstractTaskPlugin, IsTaskPlugin, pluginGroups, RunStrategy, TaskInput } from '@certd/pipeline';
import axios from 'axios';
import _ from 'lodash';

export interface NewHttpsDeployOptions {
  // NewHTTPS API 配置
  apiUrl: string;
  apiToken?: string;
  
  // 部署目标配置
  targetAgents: string[]; // Agent ID 列表
  deployMode: 'all' | 'selective'; // 部署模式
  
  // 高级选项
  timeout: number;
  retryCount: number;
  backupEnabled: boolean;
  testAfterDeploy: boolean;
  
  // 通知配置
  notifyOnSuccess: boolean;
  notifyOnFailure: boolean;
  webhookUrl?: string;
}

/**
 * NewHTTPS 部署插件
 * 将证书部署到配置的 NewHTTPS Agent
 */
@IsTaskPlugin({
  name: 'NewHttpsDeploy',
  title: 'NewHTTPS 部署',
  group: pluginGroups.deploy.key,
  desc: '将证书部署到 NewHTTPS Agent 管理的服务器',
  icon: 'svg:icon-deploy',
  default: {
    strategy: {
      runStrategy: RunStrategy.SkipWhenSucceed,
    },
  },
})
export class NewHttpsDeployPlugin extends AbstractTaskPlugin {
  async onInstance() {
    // 插件实例化时的初始化逻辑
  }

  /**
   * 执行部署任务
   */
  async execute(): Promise<void> {
    const options = this.getOptions<NewHttpsDeployOptions>();
    const { cert, key, crt } = this.getCertificateFiles();
    
    this.logger.info('开始 NewHTTPS 部署任务');
    this.logger.info(`目标 Agents: ${options.targetAgents.join(', ')}`);

    try {
      // 验证配置
      this.validateOptions(options);
      
      // 获取可用的 Agents
      const availableAgents = await this.getAvailableAgents(options);
      
      // 过滤目标 Agents
      const targetAgents = this.filterTargetAgents(availableAgents, options);
      
      if (targetAgents.length === 0) {
        throw new Error('没有找到可用的目标 Agent');
      }

      this.logger.info(`找到 ${targetAgents.length} 个可用的目标 Agent`);

      // 执行部署
      const deployResults = await this.deployToAgents(targetAgents, { cert, key, crt }, options);
      
      // 处理部署结果
      await this.handleDeployResults(deployResults, options);
      
      this.logger.info('NewHTTPS 部署任务完成');
      
    } catch (error) {
      this.logger.error('NewHTTPS 部署失败:', error);
      
      // 发送失败通知
      if (options.notifyOnFailure) {
        await this.sendNotification('failure', error.message, options);
      }
      
      throw error;
    }
  }

  /**
   * 验证插件配置
   */
  private validateOptions(options: NewHttpsDeployOptions): void {
    if (!options.apiUrl) {
      throw new Error('NewHTTPS API URL 不能为空');
    }
    
    if (!options.targetAgents || options.targetAgents.length === 0) {
      throw new Error('目标 Agent 列表不能为空');
    }
    
    if (!options.timeout || options.timeout < 1000) {
      options.timeout = 30000; // 默认 30 秒
    }
    
    if (!options.retryCount || options.retryCount < 0) {
      options.retryCount = 3; // 默认重试 3 次
    }
  }

  /**
   * 获取证书文件内容
   */
  private getCertificateFiles(): { cert: string; key: string; crt: string } {
    const certInfo = this.ctx.get('certInfo');
    
    if (!certInfo) {
      throw new Error('未找到证书信息，请确保在证书申请任务之后运行此插件');
    }

    return {
      cert: certInfo.crt || '',
      key: certInfo.key || '',
      crt: certInfo.crt || ''
    };
  }

  /**
   * 获取可用的 Agents
   */
  private async getAvailableAgents(options: NewHttpsDeployOptions): Promise<any[]> {
    try {
      const response = await axios.get(`${options.apiUrl}/api/v1/agent/list`, {
        headers: this.getAuthHeaders(options),
        timeout: options.timeout
      });

      if (!response.data.success) {
        throw new Error(`获取 Agent 列表失败: ${response.data.error}`);
      }

      return response.data.data || [];
    } catch (error) {
      this.logger.error('获取 Agent 列表失败:', error);
      throw new Error(`无法连接到 NewHTTPS API: ${error.message}`);
    }
  }

  /**
   * 过滤目标 Agents
   */
  private filterTargetAgents(availableAgents: any[], options: NewHttpsDeployOptions): any[] {
    if (options.deployMode === 'all') {
      return availableAgents.filter(agent => agent.status === 'active');
    }
    
    return availableAgents.filter(agent => 
      agent.status === 'active' && 
      options.targetAgents.includes(agent.id)
    );
  }

  /**
   * 部署证书到 Agents
   */
  private async deployToAgents(
    agents: any[], 
    certificates: { cert: string; key: string; crt: string }, 
    options: NewHttpsDeployOptions
  ): Promise<any[]> {
    const deployPromises = agents.map(agent => 
      this.deployToSingleAgent(agent, certificates, options)
    );

    return Promise.allSettled(deployPromises);
  }

  /**
   * 部署证书到单个 Agent
   */
  private async deployToSingleAgent(
    agent: any, 
    certificates: { cert: string; key: string; crt: string }, 
    options: NewHttpsDeployOptions
  ): Promise<any> {
    this.logger.info(`开始部署到 Agent: ${agent.hostname} (${agent.id})`);

    let retryCount = 0;
    
    while (retryCount <= options.retryCount) {
      try {
        const response = await axios.post(
          `${options.apiUrl}/api/v1/agent/${agent.id}/deploy`,
          {
            certificates,
            options: {
              backup: options.backupEnabled,
              test: options.testAfterDeploy
            }
          },
          {
            headers: this.getAuthHeaders(options),
            timeout: options.timeout
          }
        );

        if (response.data.success) {
          this.logger.info(`Agent ${agent.hostname} 部署成功`);
          return { agent, success: true, result: response.data };
        } else {
          throw new Error(response.data.error || '部署失败');
        }
      } catch (error) {
        retryCount++;
        this.logger.warn(`Agent ${agent.hostname} 部署失败 (尝试 ${retryCount}/${options.retryCount + 1}): ${error.message}`);
        
        if (retryCount > options.retryCount) {
          return { agent, success: false, error: error.message };
        }
        
        // 等待后重试
        await new Promise(resolve => setTimeout(resolve, 1000 * retryCount));
      }
    }
  }

  /**
   * 处理部署结果
   */
  private async handleDeployResults(results: any[], options: NewHttpsDeployOptions): Promise<void> {
    const successful = results.filter(result => 
      result.status === 'fulfilled' && result.value.success
    );
    
    const failed = results.filter(result => 
      result.status === 'rejected' || !result.value.success
    );

    this.logger.info(`部署完成: 成功 ${successful.length}, 失败 ${failed.length}`);

    if (failed.length > 0) {
      const failedAgents = failed.map(result => {
        const agent = result.value?.agent || { hostname: 'unknown' };
        const error = result.reason?.message || result.value?.error || 'unknown error';
        return `${agent.hostname}: ${error}`;
      });
      
      this.logger.warn('部分 Agent 部署失败:', failedAgents);
    }

    // 发送成功通知
    if (successful.length > 0 && options.notifyOnSuccess) {
      await this.sendNotification('success', `成功部署到 ${successful.length} 个 Agent`, options);
    }

    // 如果所有部署都失败，抛出错误
    if (successful.length === 0) {
      throw new Error('所有 Agent 部署都失败了');
    }
  }

  /**
   * 获取认证头
   */
  private getAuthHeaders(options: NewHttpsDeployOptions): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };

    if (options.apiToken) {
      headers['Authorization'] = `Bearer ${options.apiToken}`;
    }

    return headers;
  }

  /**
   * 发送通知
   */
  private async sendNotification(type: 'success' | 'failure', message: string, options: NewHttpsDeployOptions): Promise<void> {
    if (!options.webhookUrl) {
      return;
    }

    try {
      await axios.post(options.webhookUrl, {
        type,
        message,
        timestamp: new Date().toISOString(),
        plugin: 'NewHTTPS Deploy'
      }, {
        timeout: 5000
      });
    } catch (error) {
      this.logger.warn('发送通知失败:', error.message);
    }
  }

  /**
   * 获取插件配置定义
   */
  getDefineConfig(): TaskInput[] {
    return [
      {
        key: 'apiUrl',
        title: 'NewHTTPS API URL',
        type: 'text',
        component: {
          placeholder: 'http://localhost:3000'
        },
        required: true,
        helper: 'NewHTTPS API 服务器地址'
      },
      {
        key: 'apiToken',
        title: 'API Token',
        type: 'password',
        component: {
          placeholder: '输入 API Token'
        },
        helper: 'NewHTTPS API 认证令牌'
      },
      {
        key: 'targetAgents',
        title: '目标 Agent',
        type: 'text',
        component: {
          placeholder: 'agent1,agent2,agent3'
        },
        required: true,
        helper: '目标 Agent ID 列表，用逗号分隔'
      },
      {
        key: 'deployMode',
        title: '部署模式',
        type: 'select',
        component: {
          options: [
            { value: 'selective', label: '选择性部署' },
            { value: 'all', label: '部署到所有活跃 Agent' }
          ]
        },
        default: 'selective'
      },
      {
        key: 'timeout',
        title: '超时时间 (毫秒)',
        type: 'number',
        default: 30000,
        helper: '单个 Agent 部署超时时间'
      },
      {
        key: 'retryCount',
        title: '重试次数',
        type: 'number',
        default: 3,
        helper: '部署失败时的重试次数'
      },
      {
        key: 'backupEnabled',
        title: '启用备份',
        type: 'switch',
        default: true,
        helper: '部署前备份现有证书'
      },
      {
        key: 'testAfterDeploy',
        title: '部署后测试',
        type: 'switch',
        default: true,
        helper: '部署后测试 Nginx 配置'
      },
      {
        key: 'notifyOnSuccess',
        title: '成功时通知',
        type: 'switch',
        default: false
      },
      {
        key: 'notifyOnFailure',
        title: '失败时通知',
        type: 'switch',
        default: true
      },
      {
        key: 'webhookUrl',
        title: 'Webhook URL',
        type: 'text',
        component: {
          placeholder: 'https://your-webhook-url.com'
        },
        helper: '通知 Webhook 地址'
      }
    ];
  }
}
