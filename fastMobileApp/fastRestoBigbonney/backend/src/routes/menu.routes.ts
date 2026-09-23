import { Router } from 'express';
import { listMenuItems, createMenuItem, updateMenuItem, deleteMenuItem, scanMenu, addSupplement, updateSupplement, deleteSupplement, suggestPrepTime } from '../controllers/menu.controller';
import { authenticate, requireRole, requireRestaurantAccess } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

// Public
router.get('/restaurant/:restaurantId', asyncHandler(listMenuItems));

// AI
router.post('/suggest-prep-time', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(suggestPrepTime));

// Restaurant owner
router.post('/restaurant/:restaurantId/scan', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(scanMenu));
router.post('/restaurant/:restaurantId', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(createMenuItem));
router.patch('/:id', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(updateMenuItem));
router.delete('/:id', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(deleteMenuItem));

// Supplements
router.post('/:menuItemId/supplements', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(addSupplement));
router.patch('/supplements/:id', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(updateSupplement));
router.delete('/supplements/:id', authenticate, requireRestaurantAccess('STAFF'), asyncHandler(deleteSupplement));

export default router;
