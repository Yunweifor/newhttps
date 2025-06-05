import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

interface User {
  id: string
  username: string
  email: string
  role: string
  avatar?: string
}

export const useUserStore = defineStore('user', () => {
  // 状态
  const user = ref<User | null>(null)
  const token = ref<string | null>(null)

  // 计算属性
  const isLoggedIn = computed(() => !!token.value && !!user.value)
  const userRole = computed(() => user.value?.role || 'guest')
  const userName = computed(() => user.value?.username || '未知用户')

  // 方法
  const setUser = (userData: User) => {
    user.value = userData
  }

  const setToken = (tokenValue: string) => {
    token.value = tokenValue
    // 保存到本地存储
    localStorage.setItem('auth-token', tokenValue)
  }

  const login = (userData: User, tokenValue: string) => {
    setUser(userData)
    setToken(tokenValue)
  }

  const logout = () => {
    user.value = null
    token.value = null
    // 清除本地存储
    localStorage.removeItem('auth-token')
    localStorage.removeItem('user-info')
  }

  const updateUser = (userData: Partial<User>) => {
    if (user.value) {
      user.value = { ...user.value, ...userData }
      // 保存到本地存储
      localStorage.setItem('user-info', JSON.stringify(user.value))
    }
  }

  const initialize = () => {
    // 从本地存储恢复用户信息
    const savedToken = localStorage.getItem('auth-token')
    const savedUser = localStorage.getItem('user-info')
    
    if (savedToken && savedUser) {
      try {
        token.value = savedToken
        user.value = JSON.parse(savedUser)
      } catch (error) {
        console.error('Failed to parse saved user info:', error)
        logout()
      }
    }
  }

  const checkPermission = (permission: string): boolean => {
    // 简单的权限检查逻辑
    if (!user.value) return false
    
    // 管理员拥有所有权限
    if (user.value.role === 'admin') return true
    
    // 其他角色的权限检查逻辑
    const rolePermissions: Record<string, string[]> = {
      user: ['read:certificates', 'read:agents'],
      operator: ['read:certificates', 'read:agents', 'write:certificates'],
      admin: ['*'] // 所有权限
    }
    
    const permissions = rolePermissions[user.value.role] || []
    return permissions.includes('*') || permissions.includes(permission)
  }

  return {
    // 状态
    user,
    token,
    
    // 计算属性
    isLoggedIn,
    userRole,
    userName,
    
    // 方法
    setUser,
    setToken,
    login,
    logout,
    updateUser,
    initialize,
    checkPermission
  }
})
