import { Router } from 'express';
import {
  getDriverProfile,
  replaceDriverSchedules,
  updateDriverAvailability,
} from '../controllers/drivers.controller';
import { authenticate, requireRole } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

router.use(authenticate, requireRole('LIVREUR'));
router.get('/me', asyncHandler(getDriverProfile));
router.patch('/availability', asyncHandler(updateDriverAvailability));
router.patch('/schedules', asyncHandler(replaceDriverSchedules));

export default router;
