import { request } from './request'

export interface DeploymentTask {
  id: string
  certificateId: string
  agentId: string
  status: 'pending' | 'running' | 'success' | 'failed'
  type: 'deploy' | 'update' | 'remove'
  target: {
    type: 'nginx' | 'apache' | 'cloudflare' | 'aliyun' | 'tencent'
    config: Record<string, any>
  }
  progress: number
  logs: string[]
  createdAt: string
  updatedAt: string
  completedAt?: string
  error?: string
}

export interface DeploymentHistory {
  id: string
  taskId: string
  action: string
  status: 'success' | 'failed'
  message: string
  timestamp: string
  details?: Record<string, any>
}

export interface CreateDeploymentTaskRequest {
  certificateId: string
  agentId: string
  type: 'deploy' | 'update' | 'remove'
  target: {
    type: 'nginx' | 'apache' | 'cloudflare' | 'aliyun' | 'tencent'
    config: Record<string, any>
  }
}

export interface DeploymentTaskListResponse {
  success: boolean
  data: DeploymentTask[]
  total: number
}

export interface DeploymentTaskResponse {
  success: boolean
  data: DeploymentTask
}

export interface DeploymentHistoryResponse {
  success: boolean
  data: DeploymentHistory[]
  total: number
}

// 获取部署任务列表
export const getDeploymentTasks = (params?: {
  status?: string
  agentId?: string
  page?: number
  pageSize?: number
}): Promise<DeploymentTaskListResponse> => {
  return request.get('/api/v1/deployment/tasks', { params })
}

// 获取单个部署任务
export const getDeploymentTask = (taskId: string): Promise<DeploymentTaskResponse> => {
  return request.get(`/api/v1/deployment/tasks/${taskId}`)
}

// 创建部署任务
export const createDeploymentTask = (data: CreateDeploymentTaskRequest): Promise<DeploymentTaskResponse> => {
  return request.post('/api/v1/deployment/tasks', data)
}

// 取消部署任务
export const cancelDeploymentTask = (taskId: string): Promise<{ success: boolean }> => {
  return request.post(`/api/v1/deployment/tasks/${taskId}/cancel`)
}

// 重试部署任务
export const retryDeploymentTask = (taskId: string): Promise<DeploymentTaskResponse> => {
  return request.post(`/api/v1/deployment/tasks/${taskId}/retry`)
}

// 删除部署任务
export const deleteDeploymentTask = (taskId: string): Promise<{ success: boolean }> => {
  return request.delete(`/api/v1/deployment/tasks/${taskId}`)
}

// 获取部署历史
export const getDeploymentHistory = (params?: {
  taskId?: string
  agentId?: string
  page?: number
  pageSize?: number
}): Promise<DeploymentHistoryResponse> => {
  return request.get('/api/v1/deployment/history', { params })
}

// 获取部署统计信息
export const getDeploymentStats = (): Promise<{
  success: boolean
  data: {
    total: number
    pending: number
    running: number
    success: number
    failed: number
    byAgent: Record<string, number>
    byType: Record<string, number>
  }
}> => {
  return request.get('/api/v1/deployment/stats')
}
