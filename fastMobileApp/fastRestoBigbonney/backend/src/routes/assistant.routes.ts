import { Router } from 'express';
import { assistantChat, locationAutocomplete } from '../controllers/assistant.controller';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

// Public — help chat and address suggestions carry no sensitive data.
router.post('/chat', asyncHandler(assistantChat));
router.get('/places', asyncHandler(locationAutocomplete));

export default router;
