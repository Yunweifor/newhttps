import { request } from './request'

export interface Agent {
  id: string
  name?: string
  hostname: string
  os: string
  nginx_version: string
  nginx_config: string
  version: string
  last_seen: string
  created_at: string
  status: 'active' | 'inactive' | 'error'
}

export interface AgentListResponse {
  success: boolean
  data: Agent[]
  total: number
}

export interface AgentResponse {
  success: boolean
  data: Agent
}

// 获取Agent列表
export const getAgents = (): Promise<AgentListResponse> => {
  return request.get('/api/v1/agent/list')
}

// 获取单个Agent
export const getAgent = (agentId: string): Promise<AgentResponse> => {
  return request.get(`/api/v1/agent/${agentId}`)
}

// 注册新Agent
export const registerAgent = (data: {
  agent_id: string
  hostname: string
  os?: string
  nginx_version?: string
  nginx_config?: string
  version?: string
}): Promise<AgentResponse> => {
  return request.post('/api/v1/agent/register', data)
}

// 获取Agent活动日志
export const getAgentActivities = (agentId: string, limit: number = 100): Promise<{
  success: boolean
  data: any[]
  total: number
}> => {
  return request.get(`/api/v1/agent/${agentId}/activities`, {
    params: { limit }
  })
}

// Agent心跳
export const sendHeartbeat = (agentId: string, data: {
  status?: string
  message?: string
}): Promise<{ success: boolean }> => {
  return request.post(`/api/v1/agent/${agentId}/heartbeat`, data)
}

// 更新Agent
export const updateAgent = (agentId: string, data: {
  hostname?: string
  os?: string
  nginx_version?: string
  nginx_config?: string
  version?: string
}): Promise<AgentResponse> => {
  return request.put(`/api/v1/agent/${agentId}`, data)
}

// 删除Agent
export const deleteAgent = (agentId: string): Promise<{ success: boolean }> => {
  return request.delete(`/api/v1/agent/${agentId}`)
}

// 获取Agent统计信息
export const getAgentStats = (): Promise<{
  success: boolean
  data: {
    total: number
    active: number
    inactive: number
    by_os: Record<string, number>
    by_version: Record<string, number>
  }
}> => {
  return request.get('/api/v1/agent/stats')
}
