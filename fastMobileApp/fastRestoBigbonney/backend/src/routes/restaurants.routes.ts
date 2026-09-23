import { Router } from 'express';
import {
  listRestaurants,
  getRestaurant,
  createRestaurant,
  updateRestaurant,
  getMyRestaurant,
  toggleRushMode,
  toggleFullMode,
  updatePayoutFrequency,
} from '../controllers/restaurants.controller';
import { authenticate, requireRole, requireRestaurantAccess } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

// Public
router.get('/', asyncHandler(listRestaurants));
router.get('/:id', asyncHandler(getRestaurant));

// Restaurant owner
router.get('/account/mine', authenticate, requireRestaurantAccess('GUEST'), asyncHandler(getMyRestaurant));
router.post('/', authenticate, requireRole('RESTAURANT'), asyncHandler(createRestaurant));
router.patch('/:id', authenticate, requireRole('RESTAURANT'), asyncHandler(updateRestaurant));
router.post('/toggle-rush', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(toggleRushMode));
router.post('/toggle-full', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(toggleFullMode));
router.patch('/payout-frequency', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(updatePayoutFrequency));

export default router;
