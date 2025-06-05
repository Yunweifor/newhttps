<template>
  <div class="renewal-schedules">
    <a-card title="自动续期调度" :bordered="false">
      <template #extra>
        <a-space>
          <a-button type="primary" @click="showCreateModal = true">
            <template #icon><PlusOutlined /></template>
            创建调度
          </a-button>
          <a-button @click="loadSchedules">
            <template #icon><ReloadOutlined /></template>
            刷新
          </a-button>
        </a-space>
      </template>

      <!-- 统计卡片 -->
      <a-row :gutter="[16, 16]" style="margin-bottom: 16px;">
        <a-col :xs="24" :sm="8" :lg="4">
          <a-statistic title="总调度" :value="stats.total" />
        </a-col>
        <a-col :xs="24" :sm="8" :lg="4">
          <a-statistic title="已启用" :value="stats.enabled" :value-style="{ color: '#52c41a' }" />
        </a-col>
        <a-col :xs="24" :sm="8" :lg="4">
          <a-statistic title="已禁用" :value="stats.disabled" :value-style="{ color: '#faad14' }" />
        </a-col>
        <a-col :xs="24" :sm="8" :lg="4">
          <a-statistic title="成功" :value="stats.lastSuccess" :value-style="{ color: '#52c41a' }" />
        </a-col>
        <a-col :xs="24" :sm="8" :lg="4">
          <a-statistic title="失败" :value="stats.lastFailed" :value-style="{ color: '#ff4d4f' }" />
        </a-col>
        <a-col :xs="24" :sm="8" :lg="4">
          <a-statistic title="未运行" :value="stats.neverRun" :value-style="{ color: '#d9d9d9' }" />
        </a-col>
      </a-row>

      <a-table
        :columns="columns"
        :data-source="schedules"
        :loading="loading"
        :pagination="pagination"
        @change="handleTableChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'enabled'">
            <a-switch
              :checked="record.enabled"
              @change="(checked: boolean) => toggleSchedule(record, checked)"
              :loading="record.toggling"
            />
          </template>
          <template v-else-if="column.key === 'cronExpression'">
            <a-tooltip :title="describeCronExpression(record.cronExpression)">
              <a-tag>{{ record.cronExpression }}</a-tag>
            </a-tooltip>
          </template>
          <template v-else-if="column.key === 'lastResult'">
            <a-tag 
              v-if="record.lastResult"
              :color="getResultColor(record.lastResult)"
            >
              {{ getResultText(record.lastResult) }}
            </a-tag>
            <span v-else style="color: #d9d9d9;">未运行</span>
          </template>
          <template v-else-if="column.key === 'lastRun'">
            <span v-if="record.lastRun">{{ formatDate(record.lastRun) }}</span>
            <span v-else style="color: #d9d9d9;">从未运行</span>
          </template>
          <template v-else-if="column.key === 'actions'">
            <a-space>
              <a-button type="link" size="small" @click="editSchedule(record)">
                编辑
              </a-button>
              <a-button
                type="link"
                size="small"
                @click="triggerRenewal(record)"
                :loading="record.triggering"
              >
                立即续期
              </a-button>
              <a-button type="link" size="small" danger @click="deleteSchedule(record)">
                删除
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <!-- 创建/编辑调度模态框 -->
    <a-modal
      v-model:open="showCreateModal"
      :title="editingSchedule ? '编辑续期调度' : '创建续期调度'"
      @ok="handleSaveSchedule"
      @cancel="cancelEdit"
      width="600px"
    >
      <a-form :model="scheduleForm" layout="vertical">
        <a-form-item label="证书" required>
          <a-select 
            v-model:value="scheduleForm.certificateId" 
            placeholder="请选择证书"
            :disabled="!!editingSchedule"
          >
            <a-select-option v-for="cert in certificates" :key="cert.id" :value="cert.id">
              {{ cert.domains.join(', ') }}
            </a-select-option>
          </a-select>
        </a-form-item>
        
        <a-form-item label="调度规则" required>
          <a-select 
            v-model:value="scheduleForm.cronExpression" 
            placeholder="请选择调度规则"
            @change="onCronPresetChange"
          >
            <a-select-option value="0 2 * * *">每天凌晨2点</a-select-option>
            <a-select-option value="0 2 * * 0">每周日凌晨2点</a-select-option>
            <a-select-option value="0 2 1 * *">每月1号凌晨2点</a-select-option>
            <a-select-option value="0 */6 * * *">每6小时</a-select-option>
            <a-select-option value="0 */12 * * *">每12小时</a-select-option>
            <a-select-option value="custom">自定义</a-select-option>
          </a-select>
        </a-form-item>
        
        <a-form-item v-if="isCustomCron" label="自定义Cron表达式">
          <a-input 
            v-model:value="scheduleForm.cronExpression" 
            placeholder="例如: 0 2 * * *"
          />
          <div style="margin-top: 4px; color: #666; font-size: 12px;">
            格式: 分钟 小时 日 月 星期 (0-6, 0=周日)
          </div>
        </a-form-item>
        
        <a-form-item label="提前续期天数">
          <a-input-number 
            v-model:value="scheduleForm.daysBeforeExpiry" 
            :min="1" 
            :max="90" 
            placeholder="30"
          />
          <div style="margin-top: 4px; color: #666; font-size: 12px;">
            证书到期前多少天开始续期
          </div>
        </a-form-item>
        
        <a-form-item>
          <a-checkbox v-model:checked="scheduleForm.enabled">
            启用自动续期
          </a-checkbox>
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
import {
  getRenewalSchedules,
  createRenewalSchedule,
  updateRenewalSchedule,
  deleteRenewalSchedule,
  toggleRenewalSchedule,
  triggerCertificateRenewal,
  getRenewalStats,
  describeCronExpression,
  type RenewalSchedule,
  type CreateRenewalScheduleRequest
} from '../api/renewal'
import { getCertificates, type Certificate } from '../api/certificate'

// 响应式数据
const loading = ref(false)
const showCreateModal = ref(false)
const schedules = ref<(RenewalSchedule & { toggling?: boolean; triggering?: boolean })[]>([])
const certificates = ref<Certificate[]>([])
const editingSchedule = ref<RenewalSchedule | null>(null)
const pagination = ref({
  current: 1,
  pageSize: 10,
  total: 0
})

const stats = ref({
  total: 0,
  enabled: 0,
  disabled: 0,
  lastSuccess: 0,
  lastFailed: 0,
  neverRun: 0
})

const scheduleForm = ref({
  certificateId: '',
  cronExpression: '0 2 * * *',
  daysBeforeExpiry: 30,
  enabled: true
})

// 计算属性
const isCustomCron = computed(() => {
  const presets = ['0 2 * * *', '0 2 * * 0', '0 2 1 * *', '0 */6 * * *', '0 */12 * * *']
  return !presets.includes(scheduleForm.value.cronExpression)
})

// 表格列配置
const columns = [
  {
    title: '证书ID',
    dataIndex: 'certificateId',
    key: 'certificateId',
    width: 120
  },
  {
    title: '调度规则',
    dataIndex: 'cronExpression',
    key: 'cronExpression'
  },
  {
    title: '提前天数',
    dataIndex: 'daysBeforeExpiry',
    key: 'daysBeforeExpiry',
    width: 100
  },
  {
    title: '状态',
    key: 'enabled',
    width: 80
  },
  {
    title: '最后运行',
    key: 'lastRun',
    width: 150
  },
  {
    title: '运行结果',
    key: 'lastResult',
    width: 100
  },
  {
    title: '操作',
    key: 'actions',
    width: 200
  }
]

// 方法
const loadSchedules = async () => {
  loading.value = true
  try {
    const response = await getRenewalSchedules()
    schedules.value = response.data.map(schedule => ({
      ...schedule,
      toggling: false,
      triggering: false
    }))
    pagination.value.total = response.total
  } catch (error) {
    message.error('加载续期调度失败')
    console.error('Failed to load renewal schedules:', error)
  } finally {
    loading.value = false
  }
}

const loadStats = async () => {
  try {
    const response = await getRenewalStats()
    stats.value = response.data
  } catch (error) {
    console.error('Failed to load renewal stats:', error)
  }
}

const loadCertificates = async () => {
  try {
    const response = await getCertificates()
    certificates.value = response.data
  } catch (error) {
    console.error('Failed to load certificates:', error)
  }
}

const handleTableChange = (pag: any) => {
  pagination.value = pag
  loadSchedules()
}

const handleSaveSchedule = async () => {
  try {
    // 验证表单
    if (!scheduleForm.value.certificateId || !scheduleForm.value.cronExpression) {
      message.error('请填写完整的调度信息')
      return
    }

    if (editingSchedule.value) {
      // 更新调度
      await updateRenewalSchedule(editingSchedule.value.id, scheduleForm.value)
      message.success('续期调度更新成功')
    } else {
      // 创建调度
      const createRequest: CreateRenewalScheduleRequest = {
        certificateId: scheduleForm.value.certificateId,
        cronExpression: scheduleForm.value.cronExpression,
        daysBeforeExpiry: scheduleForm.value.daysBeforeExpiry,
        enabled: scheduleForm.value.enabled
      }
      await createRenewalSchedule(createRequest)
      message.success('续期调度创建成功')
    }

    showCreateModal.value = false
    resetForm()
    loadSchedules()
    loadStats()
  } catch (error) {
    message.error(editingSchedule.value ? '更新续期调度失败' : '创建续期调度失败')
    console.error('Failed to save renewal schedule:', error)
  }
}

const editSchedule = (record: RenewalSchedule) => {
  editingSchedule.value = record
  scheduleForm.value = {
    certificateId: record.certificateId,
    cronExpression: record.cronExpression,
    daysBeforeExpiry: record.daysBeforeExpiry,
    enabled: record.enabled
  }
  showCreateModal.value = true
}

const cancelEdit = () => {
  showCreateModal.value = false
  resetForm()
}

const resetForm = () => {
  editingSchedule.value = null
  scheduleForm.value = {
    certificateId: '',
    cronExpression: '0 2 * * *',
    daysBeforeExpiry: 30,
    enabled: true
  }
}

const toggleSchedule = async (record: RenewalSchedule, enabled: boolean) => {
  const schedule = schedules.value.find(s => s.id === record.id)
  if (schedule) {
    schedule.toggling = true
  }

  try {
    await toggleRenewalSchedule(record.id, enabled)
    message.success(`续期调度已${enabled ? '启用' : '禁用'}`)
    loadSchedules()
    loadStats()
  } catch (error) {
    message.error('切换续期调度状态失败')
    console.error('Failed to toggle renewal schedule:', error)
  } finally {
    if (schedule) {
      schedule.toggling = false
    }
  }
}

const triggerRenewal = async (record: RenewalSchedule) => {
  const schedule = schedules.value.find(s => s.id === record.id)
  if (schedule) {
    schedule.triggering = true
  }

  try {
    await triggerCertificateRenewal(record.certificateId)
    message.success('证书续期已触发')
    loadSchedules()
  } catch (error) {
    message.error('触发证书续期失败')
    console.error('Failed to trigger certificate renewal:', error)
  } finally {
    if (schedule) {
      schedule.triggering = false
    }
  }
}

const deleteSchedule = async (record: RenewalSchedule) => {
  try {
    await deleteRenewalSchedule(record.id)
    message.success('续期调度删除成功')
    loadSchedules()
    loadStats()
  } catch (error) {
    message.error('删除续期调度失败')
    console.error('Failed to delete renewal schedule:', error)
  }
}

const onCronPresetChange = (value: string) => {
  if (value !== 'custom') {
    scheduleForm.value.cronExpression = value
  }
}

const getResultColor = (result: string) => {
  const colors: Record<string, string> = {
    success: 'green',
    failed: 'red',
    skipped: 'orange'
  }
  return colors[result] || 'default'
}

const getResultText = (result: string) => {
  const texts: Record<string, string> = {
    success: '成功',
    failed: '失败',
    skipped: '跳过'
  }
  return texts[result] || '未知'
}

const formatDate = (date: string) => {
  return dayjs(date).format('YYYY-MM-DD HH:mm:ss')
}

// 生命周期
onMounted(() => {
  loadSchedules()
  loadStats()
  loadCertificates()
})
</script>

<style scoped>
.renewal-schedules {
  padding: 24px;
}
</style>
