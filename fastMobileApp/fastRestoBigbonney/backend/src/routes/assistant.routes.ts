import { Router } from 'express';
import { assistantChat, locationAutocomplete } from '../controllers/assistant.controller';
import { asyncHandler } from '../utils/asyncHandler';
import { assistantVisitorLimiter, assistantDailyLimiter, placesLimiter } from '../middleware/rateLimits';

const router = Router();

// Public (website visitors and guests use them), so cost is bounded by
// shared limits: per visitor, plus a global daily ceiling on Gemini calls.
router.post('/chat', assistantVisitorLimiter, assistantDailyLimiter, asyncHandler(assistantChat));
router.get('/places', placesLimiter, asyncHandler(locationAutocomplete));

export default router;
