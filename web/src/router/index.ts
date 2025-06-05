import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'

// 路由配置
const routes: RouteRecordRaw[] = [
  {
    path: '/',
    redirect: '/dashboard'
  },
  {
    path: '/dashboard',
    name: 'Dashboard',
    component: () => import('@/views/Dashboard.vue'),
    meta: {
      title: '仪表板',
      requiresAuth: true
    }
  },
  {
    path: '/certificates',
    name: 'Certificates',
    component: () => import('@/views/Certificates.vue'),
    meta: {
      title: '证书管理',
      requiresAuth: true
    }
  },
  {
    path: '/agents',
    name: 'Agents',
    component: () => import('@/views/Agents.vue'),
    meta: {
      title: 'Agent管理',
      requiresAuth: true
    }
  },
  {
    path: '/deployment',
    name: 'Deployment',
    redirect: '/deployment/tasks',
    meta: {
      title: '部署管理',
      requiresAuth: true
    },
    children: [
      {
        path: 'tasks',
        name: 'DeploymentTasks',
        component: () => import('@/views/deployment/Tasks.vue'),
        meta: {
          title: '部署任务',
          requiresAuth: true
        }
      },
      {
        path: 'history',
        name: 'DeploymentHistory',
        component: () => import('@/views/deployment/History.vue'),
        meta: {
          title: '部署历史',
          requiresAuth: true
        }
      }
    ]
  },
  {
    path: '/monitoring',
    name: 'Monitoring',
    component: () => import('@/views/Monitoring.vue'),
    meta: {
      title: '监控中心',
      requiresAuth: true
    }
  },
  {
    path: '/settings',
    name: 'Settings',
    redirect: '/settings/general',
    meta: {
      title: '系统设置',
      requiresAuth: true
    },
    children: [
      {
        path: 'general',
        name: 'SettingsGeneral',
        component: () => import('@/views/settings/General.vue'),
        meta: {
          title: '通用设置',
          requiresAuth: true
        }
      },
      {
        path: 'ca',
        name: 'SettingsCA',
        component: () => import('@/views/settings/CA.vue'),
        meta: {
          title: 'CA配置',
          requiresAuth: true
        }
      },
      {
        path: 'notification',
        name: 'SettingsNotification',
        component: () => import('@/views/settings/Notification.vue'),
        meta: {
          title: '通知设置',
          requiresAuth: true
        }
      }
    ]
  },
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/Login.vue'),
    meta: {
      title: '登录',
      requiresAuth: false
    }
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    component: () => import('@/views/NotFound.vue'),
    meta: {
      title: '页面未找到',
      requiresAuth: false
    }
  }
]

// 创建路由实例
const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition
    } else {
      return { top: 0 }
    }
  }
})

// 路由守卫
router.beforeEach((to, from, next) => {
  // 设置页面标题
  if (to.meta?.title) {
    document.title = `${to.meta.title} - NewHTTPS`
  } else {
    document.title = 'NewHTTPS - SSL证书自动化管理平台'
  }

  // 检查是否需要认证
  if (to.meta?.requiresAuth) {
    // 这里应该检查用户登录状态
    // 暂时跳过认证检查
    next()
  } else {
    next()
  }
})

export default router
