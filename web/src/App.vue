<template>
  <a-config-provider :theme="{ algorithm: isDark ? theme.darkAlgorithm : theme.defaultAlgorithm }">
    <div id="app" :class="{ 'dark-theme': isDark }">
      <a-layout style="min-height: 100vh">
        <!-- 侧边栏 -->
        <a-layout-sider 
          v-model:collapsed="collapsed" 
          :trigger="null" 
          collapsible
          :width="240"
          class="app-sider"
        >
          <div class="logo">
            <img src="/logo.svg" alt="NewHTTPS" v-if="!collapsed" />
            <img src="/logo-mini.svg" alt="N" v-else />
            <span v-if="!collapsed">NewHTTPS</span>
          </div>
          
          <a-menu
            v-model:selectedKeys="selectedKeys"
            v-model:openKeys="openKeys"
            mode="inline"
            :theme="isDark ? 'dark' : 'light'"
            @click="handleMenuClick"
          >
            <a-menu-item key="dashboard">
              <template #icon><DashboardOutlined /></template>
              <span>仪表板</span>
            </a-menu-item>
            
            <a-menu-item key="certificates">
              <template #icon><SafetyCertificateOutlined /></template>
              <span>证书管理</span>
            </a-menu-item>
            
            <a-menu-item key="agents">
              <template #icon><CloudServerOutlined /></template>
              <span>Agent 管理</span>
            </a-menu-item>
            
            <a-sub-menu key="deployment">
              <template #icon><DeploymentUnitOutlined /></template>
              <template #title>部署管理</template>
              <a-menu-item key="deployment-tasks">部署任务</a-menu-item>
              <a-menu-item key="deployment-history">部署历史</a-menu-item>
            </a-sub-menu>
            
            <a-menu-item key="monitoring">
              <template #icon><MonitorOutlined /></template>
              <span>监控告警</span>
            </a-menu-item>
            
            <a-sub-menu key="settings">
              <template #icon><SettingOutlined /></template>
              <template #title>系统设置</template>
              <a-menu-item key="settings-general">基本设置</a-menu-item>
              <a-menu-item key="settings-ca">CA 配置</a-menu-item>
              <a-menu-item key="settings-notification">通知设置</a-menu-item>
            </a-sub-menu>
          </a-menu>
        </a-layout-sider>

        <!-- 主内容区 -->
        <a-layout>
          <!-- 顶部导航 -->
          <a-layout-header class="app-header">
            <div class="header-left">
              <a-button
                type="text"
                @click="collapsed = !collapsed"
                class="trigger"
              >
                <MenuUnfoldOutlined v-if="collapsed" />
                <MenuFoldOutlined v-else />
              </a-button>
              
              <a-breadcrumb class="breadcrumb">
                <a-breadcrumb-item v-for="item in breadcrumbs" :key="item.path">
                  {{ item.title }}
                </a-breadcrumb-item>
              </a-breadcrumb>
            </div>
            
            <div class="header-right">
              <!-- 通知 -->
              <a-badge :count="notificationCount" :offset="[10, 0]">
                <a-button type="text" @click="showNotifications">
                  <BellOutlined />
                </a-button>
              </a-badge>
              
              <!-- 主题切换 -->
              <a-button type="text" @click="toggleTheme">
                <BulbOutlined v-if="isDark" />
                <EyeOutlined v-else />
              </a-button>
              
              <!-- 用户菜单 -->
              <a-dropdown>
                <a-button type="text" class="user-button">
                  <UserOutlined />
                  <span>{{ userInfo.name || 'Admin' }}</span>
                  <DownOutlined />
                </a-button>
                <template #overlay>
                  <a-menu @click="handleUserMenuClick">
                    <a-menu-item key="profile">
                      <UserOutlined />
                      个人资料
                    </a-menu-item>
                    <a-menu-item key="change-password">
                      <LockOutlined />
                      修改密码
                    </a-menu-item>
                    <a-menu-divider />
                    <a-menu-item key="logout">
                      <LogoutOutlined />
                      退出登录
                    </a-menu-item>
                  </a-menu>
                </template>
              </a-dropdown>
            </div>
          </a-layout-header>

          <!-- 内容区域 -->
          <a-layout-content class="app-content">
            <router-view v-slot="{ Component }">
              <transition name="fade" mode="out-in">
                <component :is="Component" />
              </transition>
            </router-view>
          </a-layout-content>

          <!-- 底部 -->
          <a-layout-footer class="app-footer">
            <div class="footer-content">
              <span>NewHTTPS © 2024 - SSL Certificate Management System</span>
              <div class="footer-links">
                <a href="#" @click="showAbout">关于</a>
                <a href="#" @click="showHelp">帮助</a>
                <a href="https://github.com/your-repo/newhttps" target="_blank">GitHub</a>
              </div>
            </div>
          </a-layout-footer>
        </a-layout>
      </a-layout>

      <!-- 通知抽屉 -->
      <a-drawer
        v-model:open="notificationDrawerVisible"
        title="系统通知"
        placement="right"
        :width="400"
      >
        <notification-list />
      </a-drawer>
    </div>
  </a-config-provider>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { theme } from 'ant-design-vue'
import { useAppStore } from '@/stores/app'
import { useUserStore } from '@/stores/user'
import {
  DashboardOutlined,
  SafetyCertificateOutlined,
  CloudServerOutlined,
  DeploymentUnitOutlined,
  MonitorOutlined,
  SettingOutlined,
  MenuUnfoldOutlined,
  MenuFoldOutlined,
  BellOutlined,
  BulbOutlined,
  EyeOutlined,
  UserOutlined,
  DownOutlined,
  LockOutlined,
  LogoutOutlined
} from '@ant-design/icons-vue'

const router = useRouter()
const route = useRoute()
const appStore = useAppStore()
const userStore = useUserStore()

// 响应式数据
const collapsed = ref(false)
const selectedKeys = ref<string[]>([])
const openKeys = ref<string[]>([])
const notificationDrawerVisible = ref(false)

// 计算属性
const isDark = computed(() => appStore.isDarkMode)
const userInfo = computed(() => userStore.userInfo)
const notificationCount = computed(() => appStore.notificationCount)

const breadcrumbs = computed(() => {
  const matched = route.matched.filter(item => item.meta && item.meta.title)
  return matched.map(item => ({
    path: item.path,
    title: item.meta?.title || ''
  }))
})

// 方法
const toggleTheme = () => {
  appStore.toggleTheme()
}

const handleMenuClick = ({ key }: { key: string }) => {
  selectedKeys.value = [key]
  
  // 路由映射
  const routeMap: Record<string, string> = {
    dashboard: '/dashboard',
    certificates: '/certificates',
    agents: '/agents',
    'deployment-tasks': '/deployment/tasks',
    'deployment-history': '/deployment/history',
    monitoring: '/monitoring',
    'settings-general': '/settings/general',
    'settings-ca': '/settings/ca',
    'settings-notification': '/settings/notification'
  }
  
  const targetRoute = routeMap[key]
  if (targetRoute && targetRoute !== route.path) {
    router.push(targetRoute)
  }
}

const handleUserMenuClick = ({ key }: { key: string }) => {
  switch (key) {
    case 'profile':
      router.push('/profile')
      break
    case 'change-password':
      router.push('/change-password')
      break
    case 'logout':
      userStore.logout()
      router.push('/login')
      break
  }
}

const showNotifications = () => {
  notificationDrawerVisible.value = true
}

const showAbout = () => {
  // 显示关于对话框
}

const showHelp = () => {
  // 显示帮助文档
}

// 监听路由变化，更新选中的菜单项
watch(
  () => route.path,
  (newPath) => {
    // 根据路径设置选中的菜单项
    const pathToKey: Record<string, string> = {
      '/dashboard': 'dashboard',
      '/certificates': 'certificates',
      '/agents': 'agents',
      '/deployment/tasks': 'deployment-tasks',
      '/deployment/history': 'deployment-history',
      '/monitoring': 'monitoring',
      '/settings/general': 'settings-general',
      '/settings/ca': 'settings-ca',
      '/settings/notification': 'settings-notification'
    }
    
    const key = pathToKey[newPath]
    if (key) {
      selectedKeys.value = [key]
      
      // 设置展开的子菜单
      if (key.startsWith('deployment-')) {
        openKeys.value = ['deployment']
      } else if (key.startsWith('settings-')) {
        openKeys.value = ['settings']
      }
    }
  },
  { immediate: true }
)

// 生命周期
onMounted(() => {
  // 初始化应用
  appStore.initialize()
  
  // 检查用户登录状态
  if (!userStore.isLoggedIn) {
    router.push('/login')
  }
})
</script>

<style scoped>
.app-sider {
  background: #fff;
  box-shadow: 2px 0 8px rgba(0, 0, 0, 0.1);
}

.dark-theme .app-sider {
  background: #001529;
}

.logo {
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 16px;
  font-size: 18px;
  font-weight: bold;
  color: #1890ff;
  border-bottom: 1px solid #f0f0f0;
}

.dark-theme .logo {
  color: #fff;
  border-bottom-color: #303030;
}

.logo img {
  height: 32px;
  margin-right: 8px;
}

.app-header {
  background: #fff;
  padding: 0 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  z-index: 10;
}

.dark-theme .app-header {
  background: #141414;
  border-bottom: 1px solid #303030;
}

.header-left {
  display: flex;
  align-items: center;
}

.trigger {
  font-size: 18px;
  margin-right: 16px;
}

.breadcrumb {
  margin: 0;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 8px;
}

.user-button {
  display: flex;
  align-items: center;
  gap: 8px;
}

.app-content {
  margin: 24px;
  padding: 24px;
  background: #fff;
  border-radius: 8px;
  min-height: calc(100vh - 200px);
}

.dark-theme .app-content {
  background: #141414;
}

.app-footer {
  text-align: center;
  background: #f0f2f5;
  padding: 12px 0;
}

.dark-theme .app-footer {
  background: #000;
  border-top: 1px solid #303030;
}

.footer-content {
  display: flex;
  justify-content: space-between;
  align-items: center;
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 24px;
}

.footer-links {
  display: flex;
  gap: 16px;
}

.footer-links a {
  color: #666;
  text-decoration: none;
}

.footer-links a:hover {
  color: #1890ff;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
