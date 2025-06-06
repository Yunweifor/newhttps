<template>
  <div class="certificates">
    <a-card title="证书管理" :bordered="false">
      <template #extra>
        <a-space>
          <a-select
            v-model:value="selectedAgent"
            placeholder="选择Agent"
            style="width: 200px"
            :disabled="agents.length === 0"
          >
            <a-select-option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name || agent.hostname }} ({{ agent.hostname }})
            </a-select-option>
          </a-select>
          <a-button type="primary" @click="showAddModal = true">
            <template #icon><PlusOutlined /></template>
            申请证书
          </a-button>
          <a-button @click="loadCertificates">
            <template #icon><ReloadOutlined /></template>
            刷新
          </a-button>
        </a-space>
      </template>

      <a-table
        :columns="columns"
        :data-source="certificates"
        :loading="loading"
        :pagination="pagination"
        @change="handleTableChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'status'">
            <a-tag :color="getStatusColor(record.status)">
              {{ getStatusText(record.status) }}
            </a-tag>
          </template>
          <template v-else-if="column.key === 'expiresAt'">
            <span :style="{ color: isExpiringSoon(record.expiresAt) ? '#faad14' : undefined }">
              {{ formatDate(record.expiresAt) }}
            </span>
          </template>
          <template v-else-if="column.key === 'actions'">
            <a-space>
              <a-button type="link" size="small" @click="viewCertificate(record)">
                查看
              </a-button>
              <a-button type="link" size="small" @click="handleDownloadCertificate(record)">
                下载
              </a-button>
              <a-button type="link" size="small" @click="handleRenewCertificate(record)">
                续期
              </a-button>
              <a-button type="link" size="small" danger @click="handleDeleteCertificate(record)">
                删除
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <!-- 添加证书模态框 -->
    <a-modal
      v-model:open="showAddModal"
      title="申请证书"
      @ok="handleAddCertificate"
      @cancel="showAddModal = false"
      width="600px"
    >
      <a-form :model="addForm" layout="vertical">
        <a-form-item label="域名" required>
          <a-input
            v-model:value="addForm.domains[0]"
            placeholder="请输入域名，如：example.com 或 *.example.com"
          />
          <div style="margin-top: 8px; color: #666; font-size: 12px;">
            支持单域名、通配符域名（*.example.com）
          </div>
        </a-form-item>

        <a-form-item label="证书颁发机构" required>
          <a-select v-model:value="addForm.ca" placeholder="请选择CA">
            <a-select-option value="letsencrypt">Let's Encrypt</a-select-option>
            <a-select-option value="letsencrypt-staging">Let's Encrypt (测试)</a-select-option>
            <a-select-option value="zerossl">ZeroSSL</a-select-option>
            <a-select-option value="google">Google Trust Services</a-select-option>
          </a-select>
        </a-form-item>

        <a-form-item label="邮箱地址" required>
          <a-input v-model:value="addForm.email" placeholder="请输入邮箱地址" />
        </a-form-item>

        <a-form-item label="验证方式">
          <a-select v-model:value="addForm.challengeType">
            <a-select-option value="http-01">HTTP-01 验证</a-select-option>
            <a-select-option value="dns-01">DNS-01 验证</a-select-option>
          </a-select>
        </a-form-item>

        <a-form-item>
          <a-checkbox v-model:checked="addForm.autoRenew">
            启用自动续期
          </a-checkbox>
        </a-form-item>

        <a-form-item v-if="addForm.autoRenew" label="续期提前天数">
          <a-input-number
            v-model:value="addForm.renewDays"
            :min="1"
            :max="90"
            placeholder="30"
          />
          <div style="margin-top: 4px; color: #666; font-size: 12px;">
            证书到期前多少天开始续期
          </div>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { message } from 'ant-design-vue'
import { PlusOutlined, ReloadOutlined } from '@ant-design/icons-vue'
import dayjs from 'dayjs'
import {
  getCertificates,
  createCertificate,
  renewCertificate,
  deleteCertificate,
  downloadCertificate,
  type Certificate,
  type CertificateCreateRequest
} from '../api/certificate'
import { getAgents, type Agent } from '../api/agent'

// 响应式数据
const loading = ref(false)
const showAddModal = ref(false)
const certificates = ref<Certificate[]>([])
const agents = ref<Agent[]>([])
const selectedAgent = ref<string>('')
const pagination = ref({
  current: 1,
  pageSize: 10,
  total: 0
})

const addForm = ref({
  domains: [''],
  ca: 'letsencrypt' as const,
  email: '',
  challengeType: 'http-01' as const,
  autoRenew: true,
  renewDays: 30
})

// 表格列配置
const columns = [
  {
    title: '域名',
    dataIndex: 'domains',
    key: 'domains',
    customRender: ({ record }: { record: Certificate }) => record.domains.join(', ')
  },
  {
    title: 'CA',
    dataIndex: 'ca',
    key: 'ca'
  },
  {
    title: '状态',
    dataIndex: 'status',
    key: 'status'
  },
  {
    title: '颁发时间',
    dataIndex: 'issuedAt',
    key: 'issuedAt'
  },
  {
    title: '过期时间',
    dataIndex: 'expiresAt',
    key: 'expiresAt'
  },
  {
    title: '操作',
    key: 'actions'
  }
]

// 方法
const loadCertificates = async () => {
  loading.value = true
  try {
    const response = await getCertificates()
    certificates.value = response.data
    pagination.value.total = response.total
  } catch (error) {
    console.warn('Failed to load certificates:', error)
    // 设置空数据，避免显示错误
    certificates.value = []
    pagination.value.total = 0
  } finally {
    loading.value = false
  }
}

const loadAgents = async () => {
  try {
    const response = await getAgents()
    agents.value = response.data
    // 如果有agents，默认选择第一个
    if (agents.value.length > 0 && !selectedAgent.value) {
      selectedAgent.value = agents.value[0].id
    }
  } catch (error) {
    console.warn('Failed to load agents:', error)
    // 设置空数据
    agents.value = []
  }
}

const getStatusColor = (status: string) => {
  const colors: Record<string, string> = {
    active: 'green',
    expiring: 'orange',
    expired: 'red',
    pending: 'blue'
  }
  return colors[status] || 'default'
}

const getStatusText = (status: string) => {
  const texts: Record<string, string> = {
    active: '有效',
    expiring: '即将过期',
    expired: '已过期',
    pending: '申请中'
  }
  return texts[status] || '未知'
}

const isExpiringSoon = (expiresAt: string) => {
  const expireDate = dayjs(expiresAt)
  const now = dayjs()
  return expireDate.diff(now, 'day') <= 30
}

const formatDate = (date: string) => {
  return dayjs(date).format('YYYY-MM-DD')
}

const handleTableChange = (pag: any) => {
  pagination.value = pag
  loadCertificates()
}

const handleAddCertificate = async () => {
  try {
    // 验证表单
    if (!addForm.value.domains[0] || !addForm.value.email) {
      message.error('请填写完整的证书信息')
      return
    }

    const createRequest: CertificateCreateRequest = {
      domains: addForm.value.domains.filter(domain => domain.trim()),
      ca: addForm.value.ca,
      email: addForm.value.email,
      challengeType: addForm.value.challengeType,
      autoRenew: addForm.value.autoRenew,
      renewDays: addForm.value.renewDays
    }

    await createCertificate(createRequest)
    message.success('证书申请成功')
    showAddModal.value = false

    // 重置表单
    addForm.value = {
      domains: [''],
      ca: 'letsencrypt',
      email: '',
      challengeType: 'http-01',
      autoRenew: true,
      renewDays: 30
    }

    loadCertificates()
  } catch (error) {
    message.error('证书申请失败')
    console.error('Failed to create certificate:', error)
  }
}

const viewCertificate = (record: Certificate) => {
  message.info(`查看证书: ${record.domains.join(', ')}`)
}

const handleDownloadCertificate = async (record: Certificate) => {
  try {
    if (!selectedAgent.value) {
      message.error('请先选择一个Agent')
      return
    }

    const blob = await downloadCertificate(record.id, 'pem', selectedAgent.value)

    // 创建下载链接
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `${record.domains[0]}.pem`
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)

    message.success('证书下载成功')
  } catch (error) {
    message.error('证书下载失败')
    console.error('Failed to download certificate:', error)
  }
}

const handleRenewCertificate = async (record: Certificate) => {
  try {
    await renewCertificate(record.id)
    message.success('证书续期成功')
    loadCertificates()
  } catch (error) {
    message.error('证书续期失败')
    console.error('Failed to renew certificate:', error)
  }
}

const handleDeleteCertificate = async (record: Certificate) => {
  try {
    await deleteCertificate(record.id)
    message.success('证书删除成功')
    loadCertificates()
  } catch (error) {
    message.error('证书删除失败')
    console.error('Failed to delete certificate:', error)
  }
}

// 生命周期
onMounted(() => {
  loadCertificates()
  loadAgents()
})
</script>

<style scoped>
.certificates {
  padding: 24px;
}
</style>
