import { Router } from 'express';
import { createReview, listReviews } from '../controllers/reviews.controller';
import { authenticate } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

// Public
router.get('/restaurant/:restaurantId', asyncHandler(listReviews));

// Authenticated
router.post('/restaurant/:restaurantId', authenticate, asyncHandler(createReview));

export default router;
