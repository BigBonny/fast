import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { authenticate } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';
import { prisma } from '../services/prisma';

const router = Router();
router.use(authenticate);

const fcmTokenSchema = z.object({
  token: z.string().min(10).max(512),
  platform: z.string().min(1).max(32),
});

// POST /api/users/me/fcm-token — register/refresh the device's FCM token.
router.post('/me/fcm-token', asyncHandler(async (req: Request, res: Response) => {
  const { token, platform } = fcmTokenSchema.parse(req.body);
  const userId = req.user!.userId;
  await prisma.deviceToken.upsert({
    where: { token },
    update: { userId, platform },
    create: { userId, token, platform },
  });
  res.status(204).end();
}));

// DELETE /api/users/me/fcm-token — drop a token (logout/uninstall).
router.delete('/me/fcm-token', asyncHandler(async (req: Request, res: Response) => {
  const { token } = z.object({ token: z.string().min(10).max(512) }).parse(req.body);
  await prisma.deviceToken.deleteMany({ where: { token, userId: req.user!.userId } });
  res.status(204).end();
}));

export default router;
