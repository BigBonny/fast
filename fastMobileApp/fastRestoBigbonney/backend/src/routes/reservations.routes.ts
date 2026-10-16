import { Router } from 'express';
import {
  createReservation,
  listMyReservations,
  cancelMyReservation,
  listRestaurantReservations,
  updateReservationStatus,
} from '../controllers/reservations.controller';
import { authenticate, requireRole } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

router.use(authenticate);

// Client
router.post('/restaurant/:restaurantId', asyncHandler(createReservation));
router.get('/mine', asyncHandler(listMyReservations));
router.patch('/:id/cancel', asyncHandler(cancelMyReservation));

// Restaurant side (owner or non-guest staff — guests rejected in controller)
router.get('/manage', requireRole('RESTAURANT', 'STAFF'), asyncHandler(listRestaurantReservations));
router.patch('/:id/status', requireRole('RESTAURANT', 'STAFF'), asyncHandler(updateReservationStatus));

export default router;
