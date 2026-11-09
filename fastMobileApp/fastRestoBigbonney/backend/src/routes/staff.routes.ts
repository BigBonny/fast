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
import { redeemLimiter } from '../middleware/rateLimits';

const router = Router();

// Authenticated — redeem an invite code from inside a Pro account.
// Registered BEFORE the owner-only middleware below on purpose.
// The public join/guest-login routes were removed: assistants must
// create a professional account first, then redeem the code inside.
// Per-account cap (shared across instances, see middleware/rateLimits.ts),
// so one account can't spray guesses from many IPs.
router.post('/redeem', authenticate, redeemLimiter, asyncHandler(redeemInviteCode));

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
