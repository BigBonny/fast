import { Router } from 'express';
import {
  requestRefund,
  approveRefund,
  rejectRefund,
  listRefundRequests,
} from '../controllers/refunds.controller';
import { authenticate, requireRestaurantAccess } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

// Client
router.post('/:id/refund', authenticate, asyncHandler(requestRefund));

// Restaurant
router.get('/refund-requests', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(listRefundRequests));
router.patch('/:id/refund/approve', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(approveRefund));
router.patch('/:id/refund/reject', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(rejectRefund));

export default router;
