import { Router } from 'express';
import {
  placeOrder,
  getOrder,
  getMyOrders,
  getRestaurantOrders,
  updateOrderStatus,
  updateOrderTracking,
  verifyPickup,
  redeemPickupCode,
  cancelMyOrder,
  signalClientDelay,
  setFastFeedback,
} from '../controllers/orders.controller';
import { authenticate, requireRole, requireRestaurantAccess } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

// Client
router.post('/', authenticate, asyncHandler(placeOrder));
router.get('/mine', authenticate, asyncHandler(getMyOrders));
router.post('/:id/cancel', authenticate, asyncHandler(cancelMyOrder));
router.post('/:id/delay', authenticate, asyncHandler(signalClientDelay));
router.post('/:id/feedback', authenticate, asyncHandler(setFastFeedback));

// Restaurant (before /:id to avoid conflict)
router.get('/restaurant', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(getRestaurantOrders));
// Cashier types the client's XXXX-FAST code without opening the order first.
router.post('/redeem-pickup', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(redeemPickupCode));
// GUEST (kitchen/cook accounts) can work the order board — accept, prep, ready.
// Stats/payouts/settings stay STAFF+ only.
router.patch('/:id/status', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(updateOrderStatus));
router.post('/:id/verify-pickup', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(verifyPickup));

// Shared / client detail
router.get('/:id', authenticate, asyncHandler(getOrder));
router.patch('/:id/tracking', authenticate, asyncHandler(updateOrderTracking));

export default router;
