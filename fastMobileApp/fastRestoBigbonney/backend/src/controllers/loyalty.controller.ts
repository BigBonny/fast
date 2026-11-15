import { Request, Response } from 'express';
import { prisma } from '../services/prisma';
import { listLoyaltyCards, redeemLoyaltyReward } from '../services/loyalty';
import { notifyRestaurantTeam } from '../services/realtime';

/** The signed-in client's loyalty cards, closest to the reward first. */
export const getMyLoyaltyCards = async (req: Request, res: Response): Promise<void> => {
  res.json(await listLoyaltyCards(req.user!.userId));
};

/**
 * The client uses a completed card at the counter. The restaurant team is
 * notified so the reward handed over leaves a trace on their side.
 */
export const redeemLoyalty = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = req.params.restaurantId as string;
  const userId = req.user!.userId;

  const result = await redeemLoyaltyReward(userId, restaurantId);
  if (!result.ok) {
    if (result.reason === 'NOT_FOUND') {
      res.status(404).json({ error: 'Restaurant introuvable' });
    } else if (result.reason === 'DISABLED') {
      res.status(409).json({ error: 'Ce restaurant ne propose plus de carte fidélité' });
    } else {
      res.status(409).json({ error: 'Votre carte fidélité n\'est pas encore complète' });
    }
    return;
  }

  const client = await prisma.user.findUnique({
    where: { id: userId },
    select: { name: true },
  });
  const notification = await prisma.notification.create({
    data: {
      userId: result.ownerId,
      title: 'Récompense fidélité utilisée',
      body: `${client?.name || 'Un client'} utilise sa récompense : ${result.reward}.`,
      type: 'INFO',
    },
  });
  notifyRestaurantTeam(restaurantId, result.ownerId, notification);

  res.status(201).json({
    ok: true,
    redemptionId: result.redemptionId,
    reward: result.reward,
    restaurantName: result.restaurantName,
  });
};
