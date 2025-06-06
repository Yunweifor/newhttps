import { request } from './request'

export interface Certificate {
  id: string
  domains: string[]
  certificate: string
  privateKey: string
  certificateChain: string
  ca: string
  status: 'active' | 'expired' | 'revoked' | 'pending'
  issuedAt: string
  expiresAt: string
  createdAt: string
  updatedAt: string
}

export interface CertificateCreateRequest {
  domains: string[]
  ca: 'letsencrypt' | 'letsencrypt-staging' | 'zerossl' | 'google'
  email: string
  challengeType?: 'http-01' | 'dns-01'
  autoRenew?: boolean
  renewDays?: number
}

export interface CertificateListResponse {
  success: boolean
  data: Certificate[]
  total: number
}

export interface CertificateResponse {
  success: boolean
  data: Certificate
  message?: string
  error?: string
}

// 获取证书列表
export const getCertificates = (): Promise<CertificateListResponse> => {
  return request.get('/api/v1/cert/list')
}

// 根据域名获取证书
export const getCertificateByDomain = (domain: string): Promise<CertificateResponse> => {
  return request.get(`/api/v1/cert/domain/${domain}`)
}

// 申请新证书
export const createCertificate = (data: CertificateCreateRequest): Promise<CertificateResponse> => {
  return request.post('/api/v1/cert/create', data)
}

// 续期证书
export const renewCertificate = (certificateId: string): Promise<CertificateResponse> => {
  return request.post(`/api/v1/cert/${certificateId}/renew`)
}

// 下载证书
export const downloadCertificate = (certificateId: string, format: string = 'pem', agentId: string): Promise<Blob> => {
  return request.get(`/api/v1/cert/${certificateId}/download`, {
    params: { format, agent_id: agentId },
    responseType: 'blob'
  })
}

// 删除证书
export const deleteCertificate = (certificateId: string): Promise<{ success: boolean }> => {
  return request.delete(`/api/v1/cert/${certificateId}`)
}

// 获取证书详细信息
export const getCertificateDetails = (certificateId: string, agentId: string): Promise<CertificateResponse> => {
  return request.get(`/api/v1/cert/${certificateId}/details`, {
    params: { agent_id: agentId }
  })
}
