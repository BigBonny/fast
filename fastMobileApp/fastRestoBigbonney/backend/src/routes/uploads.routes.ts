import { Router } from 'express';
import { authenticate, requireRestaurantAccess } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';
import { mediaUpload, signUpload, uploadMedia } from '../controllers/uploads.controller';

const router = Router();

// Owners and staff can upload dish photos/videos; GUEST staff may not.
router.post(
  '/',
  authenticate,
  requireRestaurantAccess('STAFF'),
  mediaUpload.single('file'),
  asyncHandler(uploadMedia),
);

// Direct upload to storage (files over ~4.5 MB can't go through Vercel).
router.post(
  '/sign',
  authenticate,
  requireRestaurantAccess('STAFF'),
  asyncHandler(signUpload),
);

export default router;
