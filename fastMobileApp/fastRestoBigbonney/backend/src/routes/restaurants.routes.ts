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
  createRestaurantRequest,
  listMyRestaurantRequests,
} from '../controllers/restaurants.controller';
import { authenticate, requireRole, requireRestaurantAccess } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

// Client suggestions — must be registered before '/:id' so "requests"
// isn't swallowed as a restaurant id.
router.post('/requests', authenticate, asyncHandler(createRestaurantRequest));
router.get('/requests/mine', authenticate, asyncHandler(listMyRestaurantRequests));

// Public
router.get('/', asyncHandler(listRestaurants));
router.get('/:id', asyncHandler(getRestaurant));

// Restaurant owner
router.get('/account/mine', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(getMyRestaurant));
router.post('/', authenticate, requireRole('RESTAURANT'), asyncHandler(createRestaurant));
router.patch('/:id', authenticate, requireRole('RESTAURANT'), asyncHandler(updateRestaurant));
router.post('/toggle-rush', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(toggleRushMode));
router.post('/toggle-full', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(toggleFullMode));
router.patch('/payout-frequency', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(updatePayoutFrequency));

export default router;
