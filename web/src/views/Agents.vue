<template>
  <div class="agents">
    <a-card title="Agent管理" :bordered="false">
      <template #extra>
        <a-space>
          <a-button type="primary" @click="showAddModal = true">
            <template #icon><PlusOutlined /></template>
            注册Agent
          </a-button>
          <a-button @click="loadAgents">
            <template #icon><ReloadOutlined /></template>
            刷新
          </a-button>
        </a-space>
      </template>

      <!-- 统计卡片 -->
      <a-row :gutter="[16, 16]" style="margin-bottom: 16px;">
        <a-col :xs="24" :sm="8" :lg="6">
          <a-statistic title="总Agent数" :value="stats.total" />
        </a-col>
        <a-col :xs="24" :sm="8" :lg="6">
          <a-statistic title="在线" :value="stats.active" :value-style="{ color: '#52c41a' }" />
        </a-col>
        <a-col :xs="24" :sm="8" :lg="6">
          <a-statistic title="离线" :value="stats.inactive" :value-style="{ color: '#ff4d4f' }" />
        </a-col>
        <a-col :xs="24" :sm="8" :lg="6">
          <a-statistic title="在线率" :value="onlineRate" suffix="%" :value-style="{ color: '#1890ff' }" />
        </a-col>
      </a-row>

      <a-table
        :columns="columns"
        :data-source="agents"
        :loading="loading"
        :pagination="pagination"
        @change="handleTableChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'status'">
            <a-badge
              :status="getStatusBadge(record.status)"
              :text="getStatusText(record.status)"
            />
          </template>
          <template v-else-if="column.key === 'lastSeen'">
            <a-tooltip :title="formatDate(record.last_seen)">
              {{ getRelativeTime(record.last_seen) }}
            </a-tooltip>
          </template>
          <template v-else-if="column.key === 'actions'">
            <a-space>
              <a-button type="link" size="small" @click="viewAgent(record)">
                查看
              </a-button>
              <a-button type="link" size="small" @click="editAgent(record)">
                编辑
              </a-button>
              <a-button type="link" size="small" @click="viewLogs(record)">
                日志
              </a-button>
              <a-button
                type="link"
                size="small"
                danger
                @click="deleteAgent(record)"
              >
                删除
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <!-- 注册Agent模态框 -->
    <a-modal
      v-model:open="showAddModal"
      title="注册新Agent"
      @ok="handleRegisterAgent"
      @cancel="showAddModal = false"
      width="600px"
    >
      <a-form :model="addForm" layout="vertical">
        <a-form-item label="Agent ID" required>
          <a-input
            v-model:value="addForm.agent_id"
            placeholder="请输入唯一的Agent ID"
          />
        </a-form-item>

        <a-form-item label="主机名" required>
          <a-input
            v-model:value="addForm.hostname"
            placeholder="请输入主机名"
          />
        </a-form-item>

        <a-form-item label="操作系统">
          <a-input
            v-model:value="addForm.os"
            placeholder="例如: Ubuntu 22.04"
          />
        </a-form-item>

        <a-form-item label="Nginx版本">
          <a-input
            v-model:value="addForm.nginx_version"
            placeholder="例如: 1.22.1"
          />
        </a-form-item>

        <a-form-item label="Nginx配置路径">
          <a-input
            v-model:value="addForm.nginx_config"
            placeholder="例如: /etc/nginx/nginx.conf"
          />
        </a-form-item>

        <a-form-item label="Agent版本">
          <a-input
            v-model:value="addForm.version"
            placeholder="例如: 1.0.0"
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- Agent详情模态框 -->
    <a-modal
      v-model:open="showDetailModal"
      title="Agent详情"
      :footer="null"
      width="800px"
    >
      <a-descriptions v-if="selectedAgent" :column="2" bordered>
        <a-descriptions-item label="Agent ID">
          {{ selectedAgent.id }}
        </a-descriptions-item>
        <a-descriptions-item label="主机名">
          {{ selectedAgent.hostname }}
        </a-descriptions-item>
        <a-descriptions-item label="操作系统">
          {{ selectedAgent.os }}
        </a-descriptions-item>
        <a-descriptions-item label="Nginx版本">
          {{ selectedAgent.nginx_version }}
        </a-descriptions-item>
        <a-descriptions-item label="Agent版本">
          {{ selectedAgent.version }}
        </a-descriptions-item>
        <a-descriptions-item label="状态">
          <a-badge
            :status="getStatusBadge(getAgentStatus(selectedAgent))"
            :text="getStatusText(getAgentStatus(selectedAgent))"
          />
        </a-descriptions-item>
        <a-descriptions-item label="创建时间">
          {{ formatDate(selectedAgent.created_at) }}
        </a-descriptions-item>
        <a-descriptions-item label="最后活跃">
          {{ formatDate(selectedAgent.last_seen) }}
        </a-descriptions-item>
        <a-descriptions-item label="Nginx配置" :span="2">
          <a-typography-text code>{{ selectedAgent.nginx_config || '未配置' }}</a-typography-text>
        </a-descriptions-item>
      </a-descriptions>

      <a-divider>最近活动</a-divider>

      <a-list
        :data-source="agentActivities"
        :loading="activitiesLoading"
        size="small"
      >
        <template #renderItem="{ item }">
          <a-list-item>
            <a-list-item-meta>
              <template #title>
                <a-space>
                  <a-tag>{{ item.action }}</a-tag>
                  <span>{{ formatDate(item.timestamp) }}</span>
                </a-space>
              </template>
              <template #description>
                {{ item.details ? JSON.stringify(item.details) : '无详细信息' }}
              </template>
            </a-list-item-meta>
          </a-list-item>
        </template>
      </a-list>
    </a-modal>

    <!-- Agent编辑模态框 -->
    <a-modal
      v-model:open="showEditModal"
      title="编辑Agent"
      @ok="handleEditAgent"
      @cancel="showEditModal = false"
      width="600px"
    >
      <a-form :model="editForm" layout="vertical">
        <a-form-item label="Agent ID">
          <a-input
            v-model:value="editForm.agent_id"
            disabled
          />
        </a-form-item>

        <a-form-item label="主机名" required>
          <a-input
            v-model:value="editForm.hostname"
            placeholder="请输入主机名"
          />
        </a-form-item>

        <a-form-item label="操作系统">
          <a-input
            v-model:value="editForm.os"
            placeholder="例如: Ubuntu 22.04"
          />
        </a-form-item>

        <a-form-item label="Nginx版本">
          <a-input
            v-model:value="editForm.nginx_version"
            placeholder="例如: 1.22.1"
          />
        </a-form-item>

        <a-form-item label="Nginx配置路径">
          <a-input
            v-model:value="editForm.nginx_config"
            placeholder="例如: /etc/nginx/nginx.conf"
          />
        </a-form-item>

        <a-form-item label="Agent版本">
          <a-input
            v-model:value="editForm.version"
            placeholder="例如: 1.0.0"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { message } from 'ant-design-vue'
import { PlusOutlined, ReloadOutlined } from '@ant-design/icons-vue'
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'
import {
  getAgents,
  getAgentStats,
  getAgentActivities,
  registerAgent,
  updateAgent,
  deleteAgent as deleteAgentAPI,
  type Agent
} from '../api/agent'

dayjs.extend(relativeTime)

// 响应式数据
const loading = ref(false)
const showAddModal = ref(false)
const showDetailModal = ref(false)
const showEditModal = ref(false)
const activitiesLoading = ref(false)
const agents = ref<Agent[]>([])
const selectedAgent = ref<Agent | null>(null)
const agentActivities = ref<any[]>([])
const pagination = ref({
  current: 1,
  pageSize: 10,
  total: 0
})

const stats = ref({
  total: 0,
  active: 0,
  inactive: 0
})

const addForm = ref({
  agent_id: '',
  hostname: '',
  os: '',
  nginx_version: '',
  nginx_config: '',
  version: '1.0.0'
})

const editForm = ref({
  agent_id: '',
  hostname: '',
  os: '',
  nginx_version: '',
  nginx_config: '',
  version: ''
})

// 计算属性
const onlineRate = computed(() => {
  if (stats.value.total === 0) return 0
  return Math.round((stats.value.active / stats.value.total) * 100)
})

// 表格列配置
const columns = [
  {
    title: 'Agent ID',
    dataIndex: 'id',
    key: 'id',
    width: 150
  },
  {
    title: '主机名',
    dataIndex: 'hostname',
    key: 'hostname'
  },
  {
    title: '操作系统',
    dataIndex: 'os',
    key: 'os'
  },
  {
    title: 'Nginx版本',
    dataIndex: 'nginx_version',
    key: 'nginx_version'
  },
  {
    title: '状态',
    key: 'status',
    width: 100
  },
  {
    title: '最后活跃',
    key: 'lastSeen',
    width: 120
  },
  {
    title: '操作',
    key: 'actions',
    width: 200
  }
]

// 方法
const loadAgents = async () => {
  loading.value = true
  try {
    const response = await getAgents()
    agents.value = response.data
    pagination.value.total = response.total
  } catch (error) {
    console.warn('Failed to load agents:', error)
    agents.value = []
    pagination.value.total = 0
  } finally {
    loading.value = false
  }
}

const loadStats = async () => {
  try {
    const response = await getAgentStats()
    stats.value = {
      total: response.data.total,
      active: response.data.active,
      inactive: response.data.inactive
    }
  } catch (error) {
    console.warn('Failed to load agent stats:', error)
  }
}

const handleTableChange = (pag: any) => {
  pagination.value = pag
  loadAgents()
}

const handleRegisterAgent = async () => {
  try {
    // 验证表单
    if (!addForm.value.agent_id?.trim()) {
      message.error('请输入Agent ID')
      return
    }

    if (!addForm.value.hostname?.trim()) {
      message.error('请输入主机名')
      return
    }

    const registerData = {
      agent_id: addForm.value.agent_id.trim(),
      hostname: addForm.value.hostname.trim(),
      os: addForm.value.os?.trim() || 'Unknown',
      nginx_version: addForm.value.nginx_version?.trim() || 'Unknown',
      nginx_config: addForm.value.nginx_config?.trim() || '',
      version: addForm.value.version?.trim() || '1.0.0'
    }

    await registerAgent(registerData)
    message.success('Agent注册成功')
    showAddModal.value = false

    // 重置表单
    addForm.value = {
      agent_id: '',
      hostname: '',
      os: '',
      nginx_version: '',
      nginx_config: '',
      version: '1.0.0'
    }

    // 重新加载数据
    await Promise.all([loadAgents(), loadStats()])
  } catch (error: any) {
    const errorMessage = error?.response?.data?.error || error?.message || 'Agent注册失败'
    message.error(errorMessage)
    console.error('Failed to register agent:', error)
  }
}

const viewAgent = async (record: Agent) => {
  selectedAgent.value = record
  showDetailModal.value = true

  // 加载Agent活动日志
  activitiesLoading.value = true
  try {
    const response = await getAgentActivities(record.id, 10)
    agentActivities.value = response.data
  } catch (error) {
    console.warn('Failed to load agent activities:', error)
    agentActivities.value = []
  } finally {
    activitiesLoading.value = false
  }
}

const editAgent = (record: Agent) => {
  editForm.value = {
    agent_id: record.id,
    hostname: record.hostname,
    os: record.os,
    nginx_version: record.nginx_version,
    nginx_config: record.nginx_config,
    version: record.version
  }
  showEditModal.value = true
}

const handleEditAgent = async () => {
  try {
    // 验证表单
    if (!editForm.value.hostname?.trim()) {
      message.error('请输入主机名')
      return
    }

    const updateData = {
      hostname: editForm.value.hostname.trim(),
      os: editForm.value.os?.trim(),
      nginx_version: editForm.value.nginx_version?.trim(),
      nginx_config: editForm.value.nginx_config?.trim(),
      version: editForm.value.version?.trim()
    }

    await updateAgent(editForm.value.agent_id, updateData)
    message.success('Agent信息更新成功')
    showEditModal.value = false

    // 重新加载数据
    await loadAgents()
  } catch (error: any) {
    const errorMessage = error?.response?.data?.error || error?.message || 'Agent更新失败'
    message.error(errorMessage)
    console.error('Failed to update agent:', error)
  }
}

const viewLogs = (record: Agent) => {
  message.info(`查看Agent日志: ${record.id}`)
  // TODO: 实现Agent日志查看
}

const deleteAgent = async (record: Agent) => {
  try {
    await deleteAgentAPI(record.id)
    message.success('Agent删除成功')
    await Promise.all([loadAgents(), loadStats()])
  } catch (error: any) {
    const errorMessage = error?.response?.data?.error || error?.message || 'Agent删除失败'
    message.error(errorMessage)
    console.error('Failed to delete agent:', error)
  }
}

const getStatusBadge = (status: string) => {
  const statusMap: Record<string, string> = {
    active: 'success',
    inactive: 'error',
    error: 'warning'
  }
  return statusMap[status] || 'default'
}

const getStatusText = (status: string) => {
  const statusMap: Record<string, string> = {
    active: '在线',
    inactive: '离线',
    error: '错误'
  }
  return statusMap[status] || '未知'
}

const formatDate = (date: string) => {
  return dayjs(date).format('YYYY-MM-DD HH:mm:ss')
}

const getRelativeTime = (date: string) => {
  return dayjs(date).fromNow()
}

const getAgentStatus = (agent: Agent) => {
  const now = new Date()
  const lastSeen = new Date(agent.last_seen)
  const diffMinutes = (now.getTime() - lastSeen.getTime()) / (1000 * 60)

  if (diffMinutes <= 5) return 'active'
  if (diffMinutes <= 60) return 'inactive'
  return 'error'
}

// 生命周期
onMounted(() => {
  loadAgents()
  loadStats()
})
</script>

<style scoped>
.agents {
  padding: 24px;
}
</style>
