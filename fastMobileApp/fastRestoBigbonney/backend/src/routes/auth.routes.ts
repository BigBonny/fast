import { Router } from 'express';
import { register, login, googleLogin, getMe, updateProfile, changePassword, logout, deleteAccount } from '../controllers/auth.controller';
import { authenticate } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

router.post('/register', asyncHandler(register));
router.post('/login', asyncHandler(login));
router.post('/google', asyncHandler(googleLogin));
router.get('/me', authenticate, asyncHandler(getMe));
router.patch('/profile', authenticate, asyncHandler(updateProfile));
router.post('/change-password', authenticate, asyncHandler(changePassword));
router.post('/logout', authenticate, asyncHandler(logout));
router.delete('/account', authenticate, asyncHandler(deleteAccount));

export default router;
