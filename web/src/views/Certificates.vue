<template>
  <div class="certificates">
    <a-card title="证书管理" :bordered="false">
      <template #extra>
        <a-space>
          <a-button type="primary" @click="showAddModal = true">
            <template #icon><PlusOutlined /></template>
            添加证书
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
              <a-button type="link" size="small" @click="downloadCertificate(record)">
                下载
              </a-button>
              <a-button type="link" size="small" danger @click="deleteCertificate(record)">
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
      title="添加证书"
      @ok="handleAddCertificate"
      @cancel="showAddModal = false"
    >
      <a-form :model="addForm" layout="vertical">
        <a-form-item label="域名" required>
          <a-input v-model:value="addForm.domain" placeholder="请输入域名" />
        </a-form-item>
        <a-form-item label="证书类型">
          <a-select v-model:value="addForm.type" placeholder="请选择证书类型">
            <a-select-option value="single">单域名</a-select-option>
            <a-select-option value="wildcard">通配符</a-select-option>
            <a-select-option value="multi">多域名</a-select-option>
          </a-select>
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

// 响应式数据
const loading = ref(false)
const showAddModal = ref(false)
const certificates = ref([])
const pagination = ref({
  current: 1,
  pageSize: 10,
  total: 0
})

const addForm = ref({
  domain: '',
  type: 'single'
})

// 表格列配置
const columns = [
  {
    title: '域名',
    dataIndex: 'domain',
    key: 'domain'
  },
  {
    title: '类型',
    dataIndex: 'type',
    key: 'type'
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
    // 模拟API调用
    await new Promise(resolve => setTimeout(resolve, 1000))
    certificates.value = [
      {
        id: '1',
        domain: 'example.com',
        type: '单域名',
        status: 'active',
        issuedAt: '2024-01-01',
        expiresAt: '2024-04-01'
      },
      {
        id: '2',
        domain: '*.test.com',
        type: '通配符',
        status: 'expiring',
        issuedAt: '2024-02-01',
        expiresAt: '2024-03-15'
      }
    ]
    pagination.value.total = certificates.value.length
  } catch (error) {
    message.error('加载证书列表失败')
  } finally {
    loading.value = false
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

const handleAddCertificate = () => {
  // 添加证书逻辑
  message.success('证书添加成功')
  showAddModal.value = false
  loadCertificates()
}

const viewCertificate = (record: any) => {
  message.info(`查看证书: ${record.domain}`)
}

const downloadCertificate = (record: any) => {
  message.info(`下载证书: ${record.domain}`)
}

const deleteCertificate = (record: any) => {
  message.info(`删除证书: ${record.domain}`)
}

// 生命周期
onMounted(() => {
  loadCertificates()
})
</script>

<style scoped>
.certificates {
  padding: 24px;
}
</style>
