import { Router } from 'express';
import {
  listNotifications,
  markAsRead,
  markAllAsRead,
  deleteNotification,
  clearAllNotifications,
  createNotification,
} from '../controllers/notifications.controller';
import { authenticate } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

router.use(authenticate);

router.get('/', asyncHandler(listNotifications));
router.post('/', asyncHandler(createNotification));
router.post('/read-all', asyncHandler(markAllAsRead));
router.patch('/:id/read', asyncHandler(markAsRead));
router.delete('/:id', asyncHandler(deleteNotification));
router.delete('/', asyncHandler(clearAllNotifications));

export default router;
