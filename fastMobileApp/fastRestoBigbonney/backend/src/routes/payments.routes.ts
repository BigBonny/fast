import { Router } from 'express';
import {
  checkoutCancelPage,
  checkoutSuccessPage,
  confirmCheckoutSession,
  createCheckoutSession,
  createConnectAccountLink,
  getConnectStatus,
} from '../controllers/payments.controller';
import { authenticate, requireRole } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

router.get('/checkout/success', asyncHandler(checkoutSuccessPage));
router.get('/checkout/cancel', asyncHandler(checkoutCancelPage));
router.post('/checkout-session', authenticate, asyncHandler(createCheckoutSession));
router.post('/checkout-session/:sessionId/confirm', authenticate, asyncHandler(confirmCheckoutSession));

router.post('/connect/account-link', authenticate, requireRole('RESTAURANT'), asyncHandler(createConnectAccountLink));
router.get('/connect/status', authenticate, requireRole('RESTAURANT'), asyncHandler(getConnectStatus));

export default router;
