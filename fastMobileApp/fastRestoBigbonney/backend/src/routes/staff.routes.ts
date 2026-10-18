import { Router } from 'express';
import {
  listStaff,
  createStaff,
  deleteStaff,
  updateStaffRole,
  getInviteCode,
  rotateInviteCode,
  revokeInviteCode,
  redeemInviteCode,
} from '../controllers/staff.controller';
import { authenticate, requireRole } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

// Authenticated — redeem an invite code from inside a Pro account.
// Registered BEFORE the owner-only middleware below on purpose.
// The public join/guest-login routes were removed: assistants must
// create a professional account first, then redeem the code inside.
router.post('/redeem', authenticate, asyncHandler(redeemInviteCode));

// Only restaurant owners can manage staff
router.use(authenticate, requireRole('RESTAURANT'));

router.get('/', asyncHandler(listStaff));
router.post('/', asyncHandler(createStaff));
router.get('/invite-code', asyncHandler(getInviteCode));
router.post('/invite-code/rotate', asyncHandler(rotateInviteCode));
router.delete('/invite-code', asyncHandler(revokeInviteCode));
router.patch('/:id', asyncHandler(updateStaffRole));
router.delete('/:id', asyncHandler(deleteStaff));

export default router;
