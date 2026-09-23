import { Router } from 'express';
import { getStats, exportStats } from '../controllers/stats.controller';
import { authenticate, requireRole } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

router.get('/export', authenticate, requireRole('RESTAURANT'), asyncHandler(exportStats));
router.get('/', authenticate, requireRole('RESTAURANT'), asyncHandler(getStats));

export default router;
