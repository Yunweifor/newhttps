<template>
  <div class="monitoring">
    <!-- 系统状态概览 -->
    <a-row :gutter="[16, 16]" style="margin-bottom: 24px;">
      <a-col :xs="24" :sm="12" :lg="6">
        <a-card>
          <a-statistic
            title="证书总数"
            :value="systemStats.totalCerts"
            :value-style="{ color: '#1890ff' }"
          />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :lg="6">
        <a-card>
          <a-statistic
            title="即将过期"
            :value="systemStats.expiringSoon"
            :value-style="{ color: systemStats.expiringSoon > 0 ? '#ff4d4f' : '#52c41a' }"
          />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :lg="6">
        <a-card>
          <a-statistic
            title="在线Agent"
            :value="systemStats.activeAgents"
            :value-style="{ color: '#52c41a' }"
          />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :lg="6">
        <a-card>
          <a-statistic
            title="部署任务"
            :value="systemStats.deploymentTasks"
            :value-style="{ color: '#722ed1' }"
          />
        </a-card>
      </a-col>
    </a-row>

    <!-- 告警信息 -->
    <a-card title="告警信息" style="margin-bottom: 24px;">
      <a-list
        :data-source="alerts"
        :loading="alertsLoading"
      >
        <template #renderItem="{ item }">
          <a-list-item>
            <a-list-item-meta>
              <template #avatar>
                <a-avatar :style="{ backgroundColor: getAlertColor(item.level) }">
                  <component :is="getAlertIcon(item.level)" />
                </a-avatar>
              </template>
              <template #title>
                <a-space>
                  <a-tag :color="getAlertColor(item.level)">{{ item.level }}</a-tag>
                  <span>{{ item.title }}</span>
                </a-space>
              </template>
              <template #description>
                {{ item.message }}
              </template>
            </a-list-item-meta>
            <template #actions>
              <span>{{ formatDate(item.timestamp) }}</span>
            </template>
          </a-list-item>
        </template>
      </a-list>
    </a-card>

    <!-- 证书状态监控 -->
    <a-row :gutter="[16, 16]">
      <a-col :xs="24" :lg="12">
        <a-card title="证书过期监控">
          <a-table
            :columns="certColumns"
            :data-source="expiringCerts"
            :loading="certsLoading"
            :pagination="false"
            size="small"
          >
            <template #bodyCell="{ column, record }">
              <template v-if="column.key === 'status'">
                <a-tag :color="getCertStatusColor(record.daysLeft)">
                  {{ getCertStatusText(record.daysLeft) }}
                </a-tag>
              </template>
              <template v-else-if="column.key === 'daysLeft'">
                <span :style="{ color: record.daysLeft <= 7 ? '#ff4d4f' : record.daysLeft <= 30 ? '#faad14' : '#52c41a' }">
                  {{ record.daysLeft }} 天
                </span>
              </template>
            </template>
          </a-table>
        </a-card>
      </a-col>

      <a-col :xs="24" :lg="12">
        <a-card title="Agent状态监控">
          <a-table
            :columns="agentColumns"
            :data-source="agentStatus"
            :loading="agentsLoading"
            :pagination="false"
            size="small"
          >
            <template #bodyCell="{ column, record }">
              <template v-if="column.key === 'status'">
                <a-badge
                  :status="getAgentStatusBadge(record.status)"
                  :text="getAgentStatusText(record.status)"
                />
              </template>
              <template v-else-if="column.key === 'lastSeen'">
                {{ getRelativeTime(record.lastSeen) }}
              </template>
            </template>
          </a-table>
        </a-card>
      </a-col>
    </a-row>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import {
  ExclamationCircleOutlined,
  WarningOutlined,
  InfoCircleOutlined,
  CheckCircleOutlined
} from '@ant-design/icons-vue'
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'
import {
  getMonitoringOverview,
  getAlerts,
  getCertificateHealth,
  getAgentHealth,
  acknowledgeAlert,
  type MonitorAlert,
  type CertificateHealth,
  type AgentHealth
} from '../api/monitoring'

dayjs.extend(relativeTime)

// 响应式数据
const alertsLoading = ref(false)
const certsLoading = ref(false)
const agentsLoading = ref(false)

const systemStats = ref({
  totalCerts: 0,
  expiringSoon: 0,
  activeAgents: 0,
  deploymentTasks: 0
})

const alerts = ref<MonitorAlert[]>([])
const expiringCerts = ref<CertificateHealth[]>([])
const agentStatus = ref<AgentHealth[]>([])

// 表格列配置
const certColumns = [
  {
    title: '域名',
    dataIndex: 'domain',
    key: 'domain'
  },
  {
    title: '剩余天数',
    dataIndex: 'daysLeft',
    key: 'daysLeft'
  },
  {
    title: '状态',
    key: 'status'
  }
]

const agentColumns = [
  {
    title: 'Agent ID',
    dataIndex: 'id',
    key: 'id'
  },
  {
    title: '主机名',
    dataIndex: 'hostname',
    key: 'hostname'
  },
  {
    title: '状态',
    key: 'status'
  },
  {
    title: '最后活跃',
    key: 'lastSeen'
  }
]

// 定时器
let refreshTimer: number | null = null

// 方法
const loadSystemStats = async () => {
  try {
    const response = await getMonitoringOverview()
    systemStats.value = {
      totalCerts: response.data.totalCertificates,
      expiringSoon: response.data.expiringSoon,
      activeAgents: response.data.activeAgents,
      deploymentTasks: 0 // 暂时设为0，后续从部署统计获取
    }
  } catch (error) {
    console.warn('Failed to load system stats:', error)
  }
}

const loadExpiringCerts = async () => {
  certsLoading.value = true
  try {
    const response = await getCertificateHealth()
    // 只显示需要关注的证书（60天内过期）
    const filtered = response.data
      .filter(cert => cert.daysUntilExpiry <= 60)
      .slice(0, 10)

    expiringCerts.value = filtered.map(cert => ({
      ...cert,
      domain: cert.domains[0],
      daysLeft: cert.daysUntilExpiry
    }))
  } catch (error) {
    console.warn('Failed to load expiring certificates:', error)
  } finally {
    certsLoading.value = false
  }
}

const loadAgentStatus = async () => {
  agentsLoading.value = true
  try {
    const response = await getAgentHealth()
    agentStatus.value = response.data.slice(0, 10)
  } catch (error) {
    console.warn('Failed to load agent status:', error)
  } finally {
    agentsLoading.value = false
  }
}

const loadAlerts = async () => {
  alertsLoading.value = true
  try {
    const response = await getAlerts({ limit: 10, acknowledged: false })
    alerts.value = response.data
  } catch (error) {
    console.warn('Failed to load alerts:', error)
  } finally {
    alertsLoading.value = false
  }
}

const getAlertColor = (level: string) => {
  const colors: Record<string, string> = {
    error: '#ff4d4f',
    warning: '#faad14',
    info: '#1890ff',
    success: '#52c41a'
  }
  return colors[level] || '#d9d9d9'
}

const getAlertIcon = (level: string) => {
  const icons: Record<string, any> = {
    error: ExclamationCircleOutlined,
    warning: WarningOutlined,
    info: InfoCircleOutlined,
    success: CheckCircleOutlined
  }
  return icons[level] || InfoCircleOutlined
}

const getCertStatusColor = (daysLeft: number) => {
  if (daysLeft <= 7) return 'red'
  if (daysLeft <= 30) return 'orange'
  return 'green'
}

const getCertStatusText = (daysLeft: number) => {
  if (daysLeft <= 0) return '已过期'
  if (daysLeft <= 7) return '紧急'
  if (daysLeft <= 30) return '警告'
  return '正常'
}

const getAgentStatusBadge = (status: string) => {
  const badges: Record<string, string> = {
    online: 'success',
    warning: 'warning',
    offline: 'error'
  }
  return badges[status] || 'default'
}

const getAgentStatusText = (status: string) => {
  const texts: Record<string, string> = {
    online: '在线',
    warning: '警告',
    offline: '离线'
  }
  return texts[status] || '未知'
}

const formatDate = (date: string) => {
  return dayjs(date).format('YYYY-MM-DD HH:mm:ss')
}

const getRelativeTime = (date: string) => {
  return dayjs(date).fromNow()
}

const startAutoRefresh = () => {
  refreshTimer = window.setInterval(() => {
    loadSystemStats()
    loadExpiringCerts()
    loadAgentStatus()
    loadAlerts()
  }, 30000) // 每30秒刷新一次
}

const stopAutoRefresh = () => {
  if (refreshTimer) {
    window.clearInterval(refreshTimer)
    refreshTimer = null
  }
}

// 生命周期
onMounted(() => {
  loadSystemStats()
  loadExpiringCerts()
  loadAgentStatus()
  loadAlerts()
  startAutoRefresh()
})

onUnmounted(() => {
  stopAutoRefresh()
})
</script>

<style scoped>
.monitoring {
  padding: 24px;
}
</style>
