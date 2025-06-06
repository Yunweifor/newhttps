<template>
  <div class="deployment-tasks">
    <a-card title="部署任务" :bordered="false">
      <template #extra>
        <a-space>
          <a-button type="primary" @click="showCreateModal = true">
            <template #icon><PlusOutlined /></template>
            创建任务
          </a-button>
          <a-button @click="loadTasks">
            <template #icon><ReloadOutlined /></template>
            刷新
          </a-button>
        </a-space>
      </template>

      <a-table
        :columns="columns"
        :data-source="tasks"
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
          <template v-else-if="column.key === 'progress'">
            <a-progress
              :percent="record.progress"
              :status="record.status === 'failed' ? 'exception' : undefined"
              size="small"
            />
          </template>
          <template v-else-if="column.key === 'target'">
            <a-tag>{{ record.target.type }}</a-tag>
          </template>
          <template v-else-if="column.key === 'actions'">
            <a-space>
              <a-button type="link" size="small" @click="viewTask(record)">
                查看
              </a-button>
              <a-button
                v-if="record.status === 'failed'"
                type="link"
                size="small"
                @click="retryTask(record)"
              >
                重试
              </a-button>
              <a-button
                v-if="record.status === 'pending' || record.status === 'running'"
                type="link"
                size="small"
                danger
                @click="cancelTask(record)"
              >
                取消
              </a-button>
              <a-button
                v-if="record.status === 'success' || record.status === 'failed'"
                type="link"
                size="small"
                danger
                @click="deleteTask(record)"
              >
                删除
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <!-- 创建任务模态框 -->
    <a-modal
      v-model:open="showCreateModal"
      title="创建部署任务"
      @ok="handleCreateTask"
      @cancel="showCreateModal = false"
      width="600px"
    >
      <a-form :model="createForm" layout="vertical">
        <a-form-item label="证书" required>
          <a-select v-model:value="createForm.certificateId" placeholder="请选择证书">
            <a-select-option v-for="cert in certificates" :key="cert.id" :value="cert.id">
              {{ cert.domains.join(', ') }}
            </a-select-option>
          </a-select>
        </a-form-item>

        <a-form-item label="目标Agent" required>
          <a-select v-model:value="createForm.agentId" placeholder="请选择Agent">
            <a-select-option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.hostname }} ({{ agent.id }})
            </a-select-option>
          </a-select>
        </a-form-item>

        <a-form-item label="任务类型" required>
          <a-select v-model:value="createForm.type" placeholder="请选择任务类型">
            <a-select-option value="deploy">部署证书</a-select-option>
            <a-select-option value="update">更新证书</a-select-option>
            <a-select-option value="remove">移除证书</a-select-option>
          </a-select>
        </a-form-item>

        <a-form-item label="目标类型" required>
          <a-select v-model:value="createForm.target.type" placeholder="请选择目标类型">
            <a-select-option value="nginx">Nginx</a-select-option>
            <a-select-option value="apache">Apache</a-select-option>
            <a-select-option value="cloudflare">Cloudflare</a-select-option>
            <a-select-option value="aliyun">阿里云</a-select-option>
            <a-select-option value="tencent">腾讯云</a-select-option>
          </a-select>
        </a-form-item>

        <a-form-item v-if="createForm.target.type === 'nginx'" label="Nginx配置">
          <a-input v-model:value="createForm.target.config.configPath" placeholder="配置文件路径" />
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
  getDeploymentTasks,
  createDeploymentTask,
  retryDeploymentTask,
  cancelDeploymentTask,
  deleteDeploymentTask,
  type DeploymentTask,
  type CreateDeploymentTaskRequest
} from '../../api/deployment'
import { getCertificates, type Certificate } from '../../api/certificate'
import { getAgents, type Agent } from '../../api/agent'

// 响应式数据
const loading = ref(false)
const showCreateModal = ref(false)
const tasks = ref<DeploymentTask[]>([])
const certificates = ref<Certificate[]>([])
const agents = ref<Agent[]>([])
const pagination = ref({
  current: 1,
  pageSize: 10,
  total: 0
})

const createForm = ref({
  certificateId: '',
  agentId: '',
  type: 'deploy' as const,
  target: {
    type: 'nginx' as const,
    config: {
      configPath: '/etc/nginx/sites-enabled'
    }
  }
})

// 表格列配置
const columns = [
  {
    title: 'ID',
    dataIndex: 'id',
    key: 'id',
    width: 100
  },
  {
    title: '证书',
    dataIndex: 'certificateId',
    key: 'certificateId'
  },
  {
    title: 'Agent',
    dataIndex: 'agentId',
    key: 'agentId'
  },
  {
    title: '类型',
    dataIndex: 'type',
    key: 'type'
  },
  {
    title: '目标',
    key: 'target'
  },
  {
    title: '状态',
    dataIndex: 'status',
    key: 'status'
  },
  {
    title: '进度',
    key: 'progress'
  },
  {
    title: '创建时间',
    dataIndex: 'createdAt',
    key: 'createdAt',
    customRender: ({ record }: { record: DeploymentTask }) => dayjs(record.createdAt).format('YYYY-MM-DD HH:mm:ss')
  },
  {
    title: '操作',
    key: 'actions'
  }
]

// 方法
const loadTasks = async () => {
  loading.value = true
  try {
    const response = await getDeploymentTasks({
      page: pagination.value.current,
      pageSize: pagination.value.pageSize
    })
    tasks.value = response.data
    pagination.value.total = response.total
  } catch (error) {
    console.warn('Failed to load deployment tasks:', error)
    // 设置空数据，避免显示错误
    tasks.value = []
    pagination.value.total = 0
  } finally {
    loading.value = false
  }
}

const loadCertificates = async () => {
  try {
    const response = await getCertificates()
    certificates.value = response.data
  } catch (error) {
    console.warn('Failed to load certificates:', error)
    certificates.value = []
  }
}

const loadAgents = async () => {
  try {
    const response = await getAgents()
    agents.value = response.data
  } catch (error) {
    console.warn('Failed to load agents:', error)
    agents.value = []
  }
}

const getStatusColor = (status: string) => {
  const colors: Record<string, string> = {
    pending: 'blue',
    running: 'orange',
    success: 'green',
    failed: 'red'
  }
  return colors[status] || 'default'
}

const getStatusText = (status: string) => {
  const texts: Record<string, string> = {
    pending: '等待中',
    running: '执行中',
    success: '成功',
    failed: '失败'
  }
  return texts[status] || '未知'
}

const handleTableChange = (pag: any) => {
  pagination.value = pag
  loadTasks()
}

const handleCreateTask = async () => {
  try {
    // 验证表单
    if (!createForm.value.certificateId || !createForm.value.agentId) {
      message.error('请填写完整的任务信息')
      return
    }

    const createRequest: CreateDeploymentTaskRequest = {
      certificateId: createForm.value.certificateId,
      agentId: createForm.value.agentId,
      type: createForm.value.type,
      target: createForm.value.target
    }

    await createDeploymentTask(createRequest)
    message.success('部署任务创建成功')
    showCreateModal.value = false

    // 重置表单
    createForm.value = {
      certificateId: '',
      agentId: '',
      type: 'deploy',
      target: {
        type: 'nginx',
        config: {
          configPath: '/etc/nginx/sites-enabled'
        }
      }
    }

    loadTasks()
  } catch (error) {
    message.error('创建部署任务失败')
    console.error('Failed to create deployment task:', error)
  }
}

const viewTask = (record: DeploymentTask) => {
  message.info(`查看任务: ${record.id}`)
}

const retryTask = async (record: DeploymentTask) => {
  try {
    await retryDeploymentTask(record.id)
    message.success('任务重试成功')
    loadTasks()
  } catch (error) {
    message.error('任务重试失败')
    console.error('Failed to retry task:', error)
  }
}

const cancelTask = async (record: DeploymentTask) => {
  try {
    await cancelDeploymentTask(record.id)
    message.success('任务取消成功')
    loadTasks()
  } catch (error) {
    message.error('任务取消失败')
    console.error('Failed to cancel task:', error)
  }
}

const deleteTask = async (record: DeploymentTask) => {
  try {
    await deleteDeploymentTask(record.id)
    message.success('任务删除成功')
    loadTasks()
  } catch (error) {
    message.error('任务删除失败')
    console.error('Failed to delete task:', error)
  }
}

// 生命周期
onMounted(() => {
  loadTasks()
  loadCertificates()
  loadAgents()
})
</script>

<style scoped>
.deployment-tasks {
  padding: 24px;
}
</style>
