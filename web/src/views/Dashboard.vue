<template>
  <div class="dashboard">
    <a-row :gutter="[16, 16]">
      <!-- 统计卡片 -->
      <a-col :xs="24" :sm="12" :lg="6">
        <a-card>
          <a-statistic
            title="证书总数"
            :value="stats.totalCerts"
            :value-style="{ color: '#1890ff' }"
          >
            <template #prefix>
              <SafetyCertificateOutlined />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      
      <a-col :xs="24" :sm="12" :lg="6">
        <a-card>
          <a-statistic
            title="活跃Agent"
            :value="stats.activeAgents"
            :value-style="{ color: '#52c41a' }"
          >
            <template #prefix>
              <CloudServerOutlined />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      
      <a-col :xs="24" :sm="12" :lg="6">
        <a-card>
          <a-statistic
            title="即将过期"
            :value="stats.expiringSoon"
            :value-style="{ color: '#faad14' }"
          >
            <template #prefix>
              <ClockCircleOutlined />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      
      <a-col :xs="24" :sm="12" :lg="6">
        <a-card>
          <a-statistic
            title="部署任务"
            :value="stats.deploymentTasks"
            :value-style="{ color: '#722ed1' }"
          >
            <template #prefix>
              <DeploymentUnitOutlined />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>

    <a-row :gutter="[16, 16]" style="margin-top: 16px;">
      <!-- 证书状态图表 -->
      <a-col :xs="24" :lg="12">
        <a-card title="证书状态分布" :bordered="false">
          <div class="chart-placeholder">
            <a-empty description="图表功能开发中..." />
          </div>
        </a-card>
      </a-col>
      
      <!-- 最近活动 -->
      <a-col :xs="24" :lg="12">
        <a-card title="最近活动" :bordered="false">
          <a-list
            :data-source="recentActivities"
            :loading="loading"
          >
            <template #renderItem="{ item }">
              <a-list-item>
                <a-list-item-meta
                  :description="item.description"
                >
                  <template #title>
                    <span>{{ item.title }}</span>
                    <a-tag :color="item.type === 'success' ? 'green' : item.type === 'warning' ? 'orange' : 'blue'" style="margin-left: 8px;">
                      {{ item.status }}
                    </a-tag>
                  </template>
                  <template #avatar>
                    <a-avatar :style="{ backgroundColor: item.type === 'success' ? '#52c41a' : item.type === 'warning' ? '#faad14' : '#1890ff' }">
                      <template #icon>
                        <SafetyCertificateOutlined v-if="item.type === 'cert'" />
                        <CloudServerOutlined v-else-if="item.type === 'agent'" />
                        <DeploymentUnitOutlined v-else />
                      </template>
                    </a-avatar>
                  </template>
                </a-list-item-meta>
                <template #actions>
                  <span style="color: #999; font-size: 12px;">{{ item.time }}</span>
                </template>
              </a-list-item>
            </template>
          </a-list>
        </a-card>
      </a-col>
    </a-row>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import {
  SafetyCertificateOutlined,
  CloudServerOutlined,
  ClockCircleOutlined,
  DeploymentUnitOutlined
} from '@ant-design/icons-vue'
import { getCertificates } from '../api/certificate'
import { getAgentStats } from '../api/agent'
import { getDeploymentStats } from '../api/deployment'

// 响应式数据
const loading = ref(false)
const stats = ref({
  totalCerts: 0,
  activeAgents: 0,
  expiringSoon: 0,
  deploymentTasks: 0
})

const recentActivities = ref([
  {
    title: '证书自动续期成功',
    description: 'example.com 的 SSL 证书已成功续期',
    type: 'success',
    status: '成功',
    time: '2分钟前'
  },
  {
    title: 'Agent 连接异常',
    description: 'Agent-001 连接超时，请检查网络状态',
    type: 'warning',
    status: '警告',
    time: '5分钟前'
  },
  {
    title: '新证书申请',
    description: 'test.example.com 的证书申请已提交',
    type: 'info',
    status: '处理中',
    time: '10分钟前'
  }
])

// 方法
const loadStats = async () => {
  loading.value = true
  try {
    // 并行加载所有统计数据
    const [certsResponse, agentStatsResponse, deploymentStatsResponse] = await Promise.all([
      getCertificates().catch(() => ({ data: [], total: 0 })),
      getAgentStats().catch(() => ({ data: { total: 0, active: 0 } })),
      getDeploymentStats().catch(() => ({ data: { total: 0 } }))
    ])

    // 计算即将过期的证书数量
    const now = new Date()
    const thirtyDaysFromNow = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000)
    const expiringSoon = certsResponse.data.filter((cert: any) => {
      const expiresAt = new Date(cert.expiresAt)
      return expiresAt <= thirtyDaysFromNow && expiresAt > now
    }).length

    stats.value = {
      totalCerts: certsResponse.total,
      activeAgents: agentStatsResponse.data.active,
      expiringSoon,
      deploymentTasks: deploymentStatsResponse.data.total
    }
  } catch (error) {
    console.error('Failed to load stats:', error)
  } finally {
    loading.value = false
  }
}

// 生命周期
onMounted(() => {
  loadStats()
})
</script>

<style scoped>
.dashboard {
  padding: 24px;
}

.chart-placeholder {
  height: 300px;
  display: flex;
  align-items: center;
  justify-content: center;
}
</style>
