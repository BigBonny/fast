import { Router } from 'express';
import { register, login, googleLogin, appleLogin, getMe, updateProfile, changePassword, logout, deleteAccount, phoneVerificationStatus, requestPhoneCode, verifyPhoneCode, confirmAccountPhone, requestEmailCode, verifyEmailCode } from '../controllers/auth.controller';
import { authenticate } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';
import { credentialLimiter } from '../middleware/rateLimits';

const router = Router();

router.post('/register', credentialLimiter, asyncHandler(register));
router.post('/login', credentialLimiter, asyncHandler(login));
router.post('/google', credentialLimiter, asyncHandler(googleLogin));
router.post('/apple', credentialLimiter, asyncHandler(appleLogin));
router.get('/phone/status', asyncHandler(phoneVerificationStatus));
router.post('/phone/request-code', credentialLimiter, asyncHandler(requestPhoneCode));
router.post('/phone/verify', credentialLimiter, asyncHandler(verifyPhoneCode));
// Signed-in verification of the account's own phone / email.
router.post('/phone/confirm', authenticate, credentialLimiter, asyncHandler(confirmAccountPhone));
router.post('/email/request-code', authenticate, credentialLimiter, asyncHandler(requestEmailCode));
router.post('/email/verify', authenticate, credentialLimiter, asyncHandler(verifyEmailCode));
router.get('/me', authenticate, asyncHandler(getMe));
router.patch('/profile', authenticate, asyncHandler(updateProfile));
router.post('/change-password', authenticate, asyncHandler(changePassword));
router.post('/logout', authenticate, asyncHandler(logout));
router.delete('/account', authenticate, asyncHandler(deleteAccount));

export default router;
