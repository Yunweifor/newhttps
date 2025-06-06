import { request } from './request'

export interface MonitoringOverview {
  totalCertificates: number
  expiringSoon: number
  totalAgents: number
  activeAgents: number
  offlineAgents: number
  systemHealth: 'healthy' | 'warning' | 'critical'
}

export interface MonitorAlert {
  id: string
  type: 'expiry_warning' | 'expiry_critical' | 'cert_invalid' | 'agent_offline'
  level: 'info' | 'warning' | 'error' | 'critical'
  title: string
  message: string
  domain?: string
  agentId?: string
  timestamp: string
  acknowledged: boolean
}

export interface CertificateHealth {
  id: string
  domains: string[]
  expiresAt: string
  daysUntilExpiry: number
  status: 'healthy' | 'warning' | 'critical' | 'expired'
  ca: string
}

export interface AgentHealth {
  id: string
  hostname: string
  os: string
  version: string
  lastSeen: string
  minutesSinceLastSeen: number
  status: 'online' | 'warning' | 'offline'
}

export interface MonitoringStats {
  certificates: {
    total: number
    active: number
    expiring: number
    expired: number
  }
  agents: {
    total: number
    online: number
    offline: number
  }
  alerts: {
    total: number
    unacknowledged: number
    critical: number
    warning: number
  }
}

export interface CertificateCheck {
  domain: string
  port: number
  isValid: boolean
  expiresAt: string
  issuer: string
  daysUntilExpiry: number
  lastChecked: string
}

// 获取监控概览
export const getMonitoringOverview = (): Promise<{
  success: boolean
  data: MonitoringOverview
}> => {
  return request.get('/api/v1/monitoring/overview')
}

// 获取告警列表
export const getAlerts = (params?: {
  limit?: number
  acknowledged?: boolean
}): Promise<{
  success: boolean
  data: MonitorAlert[]
  total: number
}> => {
  return request.get('/api/v1/monitoring/alerts', { params })
}

// 确认告警
export const acknowledgeAlert = (alertId: string): Promise<{
  success: boolean
  message: string
}> => {
  return request.post(`/api/v1/monitoring/alerts/${alertId}/acknowledge`)
}

// 获取证书健康状态
export const getCertificateHealth = (): Promise<{
  success: boolean
  data: CertificateHealth[]
  total: number
}> => {
  return request.get('/api/v1/monitoring/certificates')
}

// 获取Agent健康状态
export const getAgentHealth = (): Promise<{
  success: boolean
  data: AgentHealth[]
  total: number
}> => {
  return request.get('/api/v1/monitoring/agents')
}

// 手动触发证书检查
export const triggerCertificateCheck = (domain: string, port?: number): Promise<{
  success: boolean
  data: CertificateCheck
  message: string
}> => {
  return request.post('/api/v1/monitoring/check', { domain, port })
}

// 获取监控统计信息
export const getMonitoringStats = (): Promise<{
  success: boolean
  data: MonitoringStats
}> => {
  return request.get('/api/v1/monitoring/stats')
}
