import { Router } from 'express';
import { listStaff, createStaff, deleteStaff, updateStaffRole } from '../controllers/staff.controller';
import { authenticate, requireRole } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

// Only restaurant owners can manage staff
router.use(authenticate, requireRole('RESTAURANT'));

router.get('/', asyncHandler(listStaff));
router.post('/', asyncHandler(createStaff));
router.patch('/:id', asyncHandler(updateStaffRole));
router.delete('/:id', asyncHandler(deleteStaff));

export default router;
