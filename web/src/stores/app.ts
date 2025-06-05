import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useAppStore = defineStore('app', () => {
  // 状态
  const collapsed = ref(false)
  const isDark = ref(false)
  const loading = ref(false)
  const notificationCount = ref(0)

  // 计算属性
  const theme = computed(() => isDark.value ? 'dark' : 'light')

  // 方法
  const toggleSidebar = () => {
    collapsed.value = !collapsed.value
  }

  const toggleTheme = () => {
    isDark.value = !isDark.value
    // 保存到本地存储
    localStorage.setItem('theme', isDark.value ? 'dark' : 'light')
  }

  const setLoading = (value: boolean) => {
    loading.value = value
  }

  const setNotificationCount = (count: number) => {
    notificationCount.value = count
  }

  const initialize = () => {
    // 从本地存储恢复主题设置
    const savedTheme = localStorage.getItem('theme')
    if (savedTheme) {
      isDark.value = savedTheme === 'dark'
    } else {
      // 检查系统主题偏好
      isDark.value = window.matchMedia('(prefers-color-scheme: dark)').matches
    }

    // 从本地存储恢复侧边栏状态
    const savedCollapsed = localStorage.getItem('sidebar-collapsed')
    if (savedCollapsed) {
      collapsed.value = savedCollapsed === 'true'
    }
  }

  // 监听侧边栏状态变化并保存
  const saveSidebarState = () => {
    localStorage.setItem('sidebar-collapsed', collapsed.value.toString())
  }

  return {
    // 状态
    collapsed,
    isDark,
    loading,
    notificationCount,
    
    // 计算属性
    theme,
    
    // 方法
    toggleSidebar,
    toggleTheme,
    setLoading,
    setNotificationCount,
    initialize,
    saveSidebarState
  }
})
