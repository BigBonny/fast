import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';
import { getMyLoyaltyCards, redeemLoyalty } from '../controllers/loyalty.controller';

const router = Router();
router.use(authenticate);
router.get('/cards', asyncHandler(getMyLoyaltyCards));
router.post('/:restaurantId/redeem', asyncHandler(redeemLoyalty));
export default router;
