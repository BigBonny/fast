import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';
import { listAddresses, createAddress, updateAddress, deleteAddress } from '../controllers/addresses.controller';

const router = Router();
router.use(authenticate, requireRole('CLIENT', 'RESTAURANT', 'LIVREUR'));
router.get('/', asyncHandler(listAddresses));
router.post('/', asyncHandler(createAddress));
router.patch('/:id', asyncHandler(updateAddress));
router.delete('/:id', asyncHandler(deleteAddress));
export default router;
