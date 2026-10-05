import { Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../services/prisma';

const addressSchema = z.object({
  label: z.string().trim().min(1).max(80),
  address: z.string().trim().min(3).max(300),
  city: z.string().trim().max(100).default(''),
  isDefault: z.boolean().default(false),
});

export const listAddresses = async (req: Request, res: Response): Promise<void> => {
  const addresses = await prisma.savedAddress.findMany({
    where: { userId: req.user!.userId },
    orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
  });
  res.json(addresses);
};

export const createAddress = async (req: Request, res: Response): Promise<void> => {
  const data = addressSchema.parse(req.body);
  const userId = req.user!.userId;
  const address = await prisma.$transaction(async tx => {
    const isDefault = data.isDefault || await tx.savedAddress.count({ where: { userId } }) === 0;
    if (isDefault) await tx.savedAddress.updateMany({ where: { userId, isDefault: true }, data: { isDefault: false } });
    return tx.savedAddress.create({ data: { ...data, userId, isDefault } });
  }, { isolationLevel: 'Serializable' });
  res.status(201).json(address);
};

export const updateAddress = async (req: Request, res: Response): Promise<void> => {
  const data = addressSchema.partial().parse(req.body);
  const userId = req.user!.userId;
  const id = req.params.id as string;
  const address = await prisma.$transaction(async tx => {
    if (!await tx.savedAddress.findFirst({ where: { id, userId } })) return null;
    if (data.isDefault) await tx.savedAddress.updateMany({ where: { userId, isDefault: true }, data: { isDefault: false } });
    return tx.savedAddress.update({ where: { id }, data });
  }, { isolationLevel: 'Serializable' });
  if (!address) {
    res.status(404).json({ error: 'Adresse introuvable' });
    return;
  }
  res.json(address);
};

export const deleteAddress = async (req: Request, res: Response): Promise<void> => {
  const userId = req.user!.userId;
  const id = req.params.id as string;
  const deleted = await prisma.$transaction(async tx => {
    const address = await tx.savedAddress.findFirst({ where: { id, userId } });
    if (!address) return false;
    await tx.savedAddress.delete({ where: { id } });
    if (address.isDefault) {
      const next = await tx.savedAddress.findFirst({ where: { userId }, orderBy: { createdAt: 'desc' } });
      if (next) await tx.savedAddress.update({ where: { id: next.id }, data: { isDefault: true } });
    }
    return true;
  }, { isolationLevel: 'Serializable' });
  if (!deleted) {
    res.status(404).json({ error: 'Adresse introuvable' });
    return;
  }
  res.status(204).end();
};
