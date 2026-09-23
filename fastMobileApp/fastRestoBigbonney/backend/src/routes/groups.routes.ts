import { Router } from 'express';
import {
  createGroup,
  joinGroup,
  getMyGroups,
  getGroup,
  leaveGroup,
  lockGroup,
  submitGroup,
  updateMyGroupMember,
  updateMyPaymentStatus,
  saveGroupCart,
  getGroupCarts,
  updateHostLocation,
  getRestaurantGroupOrders,
} from '../controllers/groups.controller';
import { authenticate, requireRestaurantAccess } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

router.post('/', authenticate, asyncHandler(createGroup));
router.post('/join', authenticate, asyncHandler(joinGroup));
router.get('/mine', authenticate, asyncHandler(getMyGroups));
router.get('/restaurant', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(getRestaurantGroupOrders));
router.get('/:id', authenticate, asyncHandler(getGroup));
router.get('/:id/cart', authenticate, asyncHandler(getGroupCarts));
router.put('/:id/cart', authenticate, asyncHandler(saveGroupCart));
router.patch('/:id/location', authenticate, asyncHandler(updateHostLocation));
router.patch('/:id/member', authenticate, asyncHandler(updateMyGroupMember));
router.patch('/:id/payment-status', authenticate, asyncHandler(updateMyPaymentStatus));
router.patch('/:id/member/payment-status', authenticate, asyncHandler(updateMyPaymentStatus));
router.post('/:id/lock', authenticate, asyncHandler(lockGroup));
router.post('/:id/submit', authenticate, asyncHandler(submitGroup));
router.post('/:id/leave', authenticate, asyncHandler(leaveGroup));

export default router;
