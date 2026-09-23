import { Router } from 'express';
import {
  getAvailableDeliveries,
  acceptDelivery,
  updateDeliveryStatus,
  getMyActiveDelivery,
  getOrderDeliveryForClient,
} from '../controllers/deliveries.controller';
import { authenticate, requireRole } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

router.get('/order/:orderId', authenticate, asyncHandler(getOrderDeliveryForClient));

// Only eligible drivers can view or manage delivery opportunities.
router.get('/available', authenticate, requireRole('LIVREUR'), asyncHandler(getAvailableDeliveries));
router.get('/active', authenticate, requireRole('LIVREUR'), asyncHandler(getMyActiveDelivery));
router.post('/:id/accept', authenticate, requireRole('LIVREUR'), asyncHandler(acceptDelivery));
router.patch('/:id/status', authenticate, requireRole('LIVREUR'), asyncHandler(updateDeliveryStatus));

export default router;
