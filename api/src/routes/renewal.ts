import { Router } from 'express';
import { RenewalScheduler } from '../services/renewalScheduler';
import { logger } from '../utils/logger';
import { authMiddleware } from '../middleware/auth';

const router = Router();

// 获取续期调度器实例
function getRenewalScheduler(): RenewalScheduler {
  return RenewalScheduler.getInstance();
}

/**
 * 获取所有续期调度
 * GET /api/v1/renewal/schedules
 */
router.get('/schedules', authMiddleware, async (req, res) => {
  try {
    const scheduler = getRenewalScheduler();
    const schedules = await scheduler.getAllSchedules();
    
    res.json({
      success: true,
      data: schedules,
      total: schedules.length
    });
  } catch (error) {
    logger.error('Failed to get renewal schedules:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch renewal schedules'
    });
  }
});

/**
 * 获取单个续期调度
 * GET /api/v1/renewal/schedules/:scheduleId
 */
router.get('/schedules/:scheduleId', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { scheduleId } = req.params;
    const scheduler = getRenewalScheduler();
    const schedule = await scheduler.getScheduleById(scheduleId);
    
    if (!schedule) {
      return res.status(404).json({
        success: false,
        error: 'Renewal schedule not found'
      });
    }
    
    res.json({
      success: true,
      data: schedule
    });
  } catch (error) {
    logger.error(`Failed to get renewal schedule ${req.params.scheduleId}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch renewal schedule'
    });
  }
});

/**
 * 创建续期调度
 * POST /api/v1/renewal/schedules
 */
router.post('/schedules', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { certificateId, cronExpression, daysBeforeExpiry, enabled } = req.body;

    // 验证必需参数
    if (!certificateId || !cronExpression) {
      return res.status(400).json({
        success: false,
        error: 'certificateId and cronExpression are required'
      });
    }

    const scheduler = getRenewalScheduler();
    const schedule = await scheduler.createSchedule({
      certificateId,
      cronExpression,
      daysBeforeExpiry: daysBeforeExpiry || 30,
      enabled: enabled !== false
    });

    res.json({
      success: true,
      data: schedule
    });
  } catch (error) {
    logger.error('Failed to create renewal schedule:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create renewal schedule'
    });
  }
});

/**
 * 更新续期调度
 * PUT /api/v1/renewal/schedules/:scheduleId
 */
router.put('/schedules/:scheduleId', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { scheduleId } = req.params;
    const updates = req.body;

    const scheduler = getRenewalScheduler();
    const schedule = await scheduler.updateSchedule(scheduleId, updates);

    res.json({
      success: true,
      data: schedule
    });
  } catch (error) {
    logger.error(`Failed to update renewal schedule ${req.params.scheduleId}:`, error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update renewal schedule'
    });
  }
});

/**
 * 删除续期调度
 * DELETE /api/v1/renewal/schedules/:scheduleId
 */
router.delete('/schedules/:scheduleId', authMiddleware, async (req, res) => {
  try {
    const { scheduleId } = req.params;

    const scheduler = getRenewalScheduler();
    await scheduler.deleteSchedule(scheduleId);

    res.json({
      success: true,
      message: 'Renewal schedule deleted successfully'
    });
  } catch (error) {
    logger.error(`Failed to delete renewal schedule ${req.params.scheduleId}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete renewal schedule'
    });
  }
});

/**
 * 手动触发证书续期
 * POST /api/v1/renewal/trigger/:certificateId
 */
router.post('/trigger/:certificateId', authMiddleware, async (req, res) => {
  try {
    const { certificateId } = req.params;

    const scheduler = getRenewalScheduler();
    const job = await scheduler.triggerRenewal(certificateId);

    res.json({
      success: true,
      data: job
    });
  } catch (error) {
    logger.error(`Failed to trigger renewal for certificate ${req.params.certificateId}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to trigger certificate renewal'
    });
  }
});

/**
 * 启用/禁用续期调度
 * POST /api/v1/renewal/schedules/:scheduleId/toggle
 */
router.post('/schedules/:scheduleId/toggle', authMiddleware, async (req, res): Promise<any> => {
  try {
    const { scheduleId } = req.params;
    const { enabled } = req.body;

    if (typeof enabled !== 'boolean') {
      return res.status(400).json({
        success: false,
        error: 'enabled field is required and must be a boolean'
      });
    }

    const scheduler = getRenewalScheduler();
    const schedule = await scheduler.updateSchedule(scheduleId, { enabled });

    res.json({
      success: true,
      data: schedule,
      message: `Renewal schedule ${enabled ? 'enabled' : 'disabled'} successfully`
    });
  } catch (error) {
    logger.error(`Failed to toggle renewal schedule ${req.params.scheduleId}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to toggle renewal schedule'
    });
  }
});

/**
 * 获取续期统计信息
 * GET /api/v1/renewal/stats
 */
router.get('/stats', authMiddleware, async (req, res) => {
  try {
    const scheduler = getRenewalScheduler();
    const schedules = await scheduler.getAllSchedules();
    
    const stats = {
      total: schedules.length,
      enabled: schedules.filter(s => s.enabled).length,
      disabled: schedules.filter(s => !s.enabled).length,
      lastSuccess: schedules.filter(s => s.lastResult === 'success').length,
      lastFailed: schedules.filter(s => s.lastResult === 'failed').length,
      neverRun: schedules.filter(s => !s.lastRun).length
    };

    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    logger.error('Failed to get renewal stats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch renewal statistics'
    });
  }
});

export { router as renewalRoutes };
