import { request } from './request'

export interface RenewalSchedule {
  id: string
  certificateId: string
  cronExpression: string
  daysBeforeExpiry: number
  enabled: boolean
  lastRun?: string
  nextRun?: string
  lastResult?: 'success' | 'failed' | 'skipped'
  lastError?: string
  createdAt: string
  updatedAt: string
}

export interface RenewalJob {
  id: string
  certificateId: string
  status: 'pending' | 'running' | 'completed' | 'failed'
  startedAt?: string
  completedAt?: string
  error?: string
  logs: string[]
}

export interface CreateRenewalScheduleRequest {
  certificateId: string
  cronExpression: string
  daysBeforeExpiry?: number
  enabled?: boolean
}

export interface RenewalScheduleListResponse {
  success: boolean
  data: RenewalSchedule[]
  total: number
}

export interface RenewalScheduleResponse {
  success: boolean
  data: RenewalSchedule
}

export interface RenewalJobResponse {
  success: boolean
  data: RenewalJob
}

export interface RenewalStatsResponse {
  success: boolean
  data: {
    total: number
    enabled: number
    disabled: number
    lastSuccess: number
    lastFailed: number
    neverRun: number
  }
}

// 获取续期调度列表
export const getRenewalSchedules = (): Promise<RenewalScheduleListResponse> => {
  return request.get('/api/v1/renewal/schedules')
}

// 获取单个续期调度
export const getRenewalSchedule = (scheduleId: string): Promise<RenewalScheduleResponse> => {
  return request.get(`/api/v1/renewal/schedules/${scheduleId}`)
}

// 创建续期调度
export const createRenewalSchedule = (data: CreateRenewalScheduleRequest): Promise<RenewalScheduleResponse> => {
  return request.post('/api/v1/renewal/schedules', data)
}

// 更新续期调度
export const updateRenewalSchedule = (scheduleId: string, data: Partial<RenewalSchedule>): Promise<RenewalScheduleResponse> => {
  return request.put(`/api/v1/renewal/schedules/${scheduleId}`, data)
}

// 删除续期调度
export const deleteRenewalSchedule = (scheduleId: string): Promise<{ success: boolean }> => {
  return request.delete(`/api/v1/renewal/schedules/${scheduleId}`)
}

// 启用/禁用续期调度
export const toggleRenewalSchedule = (scheduleId: string, enabled: boolean): Promise<RenewalScheduleResponse> => {
  return request.post(`/api/v1/renewal/schedules/${scheduleId}/toggle`, { enabled })
}

// 手动触发证书续期
export const triggerCertificateRenewal = (certificateId: string): Promise<RenewalJobResponse> => {
  return request.post(`/api/v1/renewal/trigger/${certificateId}`)
}

// 获取续期统计信息
export const getRenewalStats = (): Promise<RenewalStatsResponse> => {
  return request.get('/api/v1/renewal/stats')
}

// 常用的cron表达式预设
export const CRON_PRESETS = {
  DAILY: '0 2 * * *',           // 每天凌晨2点
  WEEKLY: '0 2 * * 0',          // 每周日凌晨2点
  MONTHLY: '0 2 1 * *',         // 每月1号凌晨2点
  HOURLY: '0 * * * *',          // 每小时
  EVERY_6_HOURS: '0 */6 * * *', // 每6小时
  EVERY_12_HOURS: '0 */12 * * *' // 每12小时
}

// cron表达式验证
export const validateCronExpression = (expression: string): boolean => {
  // 简单的cron表达式验证
  const cronRegex = /^(\*|([0-9]|1[0-9]|2[0-9]|3[0-9]|4[0-9]|5[0-9])|\*\/([0-9]|1[0-9]|2[0-9]|3[0-9]|4[0-9]|5[0-9])) (\*|([0-9]|1[0-9]|2[0-3])|\*\/([0-9]|1[0-9]|2[0-3])) (\*|([1-9]|1[0-9]|2[0-9]|3[0-1])|\*\/([1-9]|1[0-9]|2[0-9]|3[0-1])) (\*|([1-9]|1[0-2])|\*\/([1-9]|1[0-2])) (\*|([0-6])|\*\/([0-6]))$/
  return cronRegex.test(expression)
}

// 解析cron表达式为人类可读的描述
export const describeCronExpression = (expression: string): string => {
  const presetDescriptions: Record<string, string> = {
    '0 2 * * *': '每天凌晨2点',
    '0 2 * * 0': '每周日凌晨2点',
    '0 2 1 * *': '每月1号凌晨2点',
    '0 * * * *': '每小时',
    '0 */6 * * *': '每6小时',
    '0 */12 * * *': '每12小时'
  }
  
  return presetDescriptions[expression] || expression
}
