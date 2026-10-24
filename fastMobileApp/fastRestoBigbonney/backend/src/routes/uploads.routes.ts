import { Router } from 'express';
import { authenticate, requireRestaurantAccess } from '../middleware/auth';
import { mediaUpload, uploadMedia } from '../controllers/uploads.controller';

const router = Router();

// Owners and staff can upload dish photos/videos; GUEST staff may not.
router.post(
  '/',
  authenticate,
  requireRestaurantAccess('STAFF'),
  mediaUpload.single('file'),
  uploadMedia,
);

export default router;
