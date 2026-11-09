import { Request, Response } from 'express';
import { prisma } from '../services/prisma';
import { env } from '../config/env';
import { getRestaurantIdForUser } from '../middleware/auth';
import { notifyRestaurantTeam, safeEmitNotificationToUser } from '../services/realtime';
import { refundPaidOrder } from '../services/stripeRefunds';

// Client requests a refund for a paid order
export const requestRefund = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const rawReason = (req.body as { reason?: unknown })?.reason;
  const reason = typeof rawReason === 'string' ? rawReason.trim().slice(0, 500) : '';

  const order = await prisma.order.findFirst({
    where: { id, userId: req.user!.userId },
    include: {
      restaurant: { select: { id: true, name: true, ownerId: true } },
      groupOrder: { select: { code: true, status: true } },
    },
  });

  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }

  if (order.groupOrder) {
    res.status(409).json({
      error: `Les commandes de groupe (${order.groupOrder.code}) ne peuvent pas être remboursées individuellement`,
    });
    return;
  }

  if (order.paymentStatus !== 'PAID') {
    res.status(409).json({ error: 'Seules les commandes payées peuvent être remboursées' });
    return;
  }

  if (order.status === 'CANCELLED') {
    res.status(409).json({ error: 'Cette commande est déjà annulée' });
    return;
  }

  // Conditional update: a cancel or a second request landing at the same
  // time can't turn an already-refunded order back into a request.
  const claimed = await prisma.order.updateMany({
    where: { id, paymentStatus: 'PAID', status: { not: 'CANCELLED' } },
    data: {
      paymentStatus: 'REFUND_REQUESTED',
      refundReason: reason || '',
      refundRequestedAt: new Date(),
      refundProcessedAt: null,
    },
  });
  if (claimed.count !== 1) {
    res.status(409).json({ error: 'Cette commande a changé entre-temps, rafraîchissez' });
    return;
  }

  // Notify restaurant owner
  const notification = await prisma.notification.create({
    data: {
      userId: order.restaurant.ownerId!,
      orderId: order.id,
      title: 'Demande de remboursement',
      body: `Commande #${order.id.slice(-6)} — ${reason || 'Aucune raison fournie'}`,
      type: 'STATUS',
    },
  });
  notifyRestaurantTeam(order.restaurantId, order.restaurant.ownerId!, notification);

  res.json({ message: 'Demande de remboursement envoyée au restaurant' });
};

// Restaurant approves refund → Stripe refund
export const approveRefund = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }

  const order = await prisma.order.findFirst({
    where: { id, restaurantId },
    include: { user: { select: { id: true, name: true } } },
  });

  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }

  if (order.paymentStatus !== 'REFUND_REQUESTED') {
    res.status(409).json({ error: 'Aucune demande de remboursement en cours' });
    return;
  }

  if (!env.stripeSecretKey) {
    res.status(500).json({ error: 'Stripe non configuré' });
    return;
  }

  // Claim the request before touching Stripe, so a double tap or a second
  // device can't approve it twice (and an approve can't race a reject).
  // refundProcessedAt is null for every open request.
  const claimed = await prisma.order.updateMany({
    where: { id, restaurantId, paymentStatus: 'REFUND_REQUESTED', refundProcessedAt: null },
    data: { refundProcessedAt: new Date() },
  });
  if (claimed.count !== 1) {
    res.status(409).json({ error: 'Cette demande a déjà été traitée' });
    return;
  }

  // Same refund path as cancellations: reverses the restaurant's transfer
  // on Connect charges and uses an idempotency key. Keeps the service fee,
  // as before.
  let refunded: boolean;
  try {
    refunded = await refundPaidOrder(order);
  } catch (err) {
    console.error('approveRefund: Stripe refund failed', order.id, err);
    await prisma.order.updateMany({
      where: { id, paymentStatus: 'REFUND_REQUESTED' },
      data: { refundProcessedAt: null },
    });
    res.status(502).json({ error: 'Échec du remboursement Stripe, réessayez' });
    return;
  }
  if (!refunded) {
    await prisma.order.updateMany({
      where: { id, paymentStatus: 'REFUND_REQUESTED' },
      data: { refundProcessedAt: null },
    });
    res.status(500).json({ error: 'Impossible de trouver le paiement Stripe à rembourser' });
    return;
  }

  await prisma.order.update({
    where: { id },
    data: { status: 'CANCELLED' },
  });

  const notification = await prisma.notification.create({
    data: {
      userId: order.userId,
      orderId: order.id,
      title: 'Remboursement approuvé',
      body: `Commande #${order.id.slice(-6)} — ${(order.total - order.serviceFee).toFixed(2)}€ remboursé`,
      type: 'SUCCESS',
    },
  });
  safeEmitNotificationToUser(order.userId, notification);

  res.json({ message: 'Remboursement approuvé et traité via Stripe' });
};

// Restaurant rejects refund
export const rejectRefund = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const { rejectionReason } = req.body as { rejectionReason?: string };

  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }

  const order = await prisma.order.findFirst({
    where: { id, restaurantId },
    include: { user: { select: { id: true, name: true } } },
  });

  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }

  if (order.paymentStatus !== 'REFUND_REQUESTED') {
    res.status(409).json({ error: 'Aucune demande de remboursement en cours' });
    return;
  }

  const claimed = await prisma.order.updateMany({
    where: { id, restaurantId, paymentStatus: 'REFUND_REQUESTED', refundProcessedAt: null },
    data: {
      paymentStatus: 'REFUND_REJECTED',
      refundProcessedAt: new Date(),
      refundReason: `${order.refundReason} [Refusé: ${(rejectionReason || 'non spécifié').slice(0, 500)}]`,
    },
  });
  if (claimed.count !== 1) {
    res.status(409).json({ error: 'Cette demande a déjà été traitée' });
    return;
  }

  // Notify client
  const notification = await prisma.notification.create({
    data: {
      userId: order.userId,
      orderId: order.id,
      title: 'Remboursement refusé',
      body: `Commande #${order.id.slice(-6)} — ${rejectionReason || 'Le restaurant a refusé votre demande'}`,
      type: 'INFO',
    },
  });
  safeEmitNotificationToUser(order.userId, notification);

  res.json({ message: 'Demande de remboursement refusée' });
};

// Restaurant lists refund requests
export const listRefundRequests = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }

  const orders = await prisma.order.findMany({
    where: {
      restaurantId,
      paymentStatus: { in: ['REFUND_REQUESTED', 'REFUNDED', 'REFUND_REJECTED'] },
    },
    include: {
      items: { include: { menuItem: true } },
      user: { select: { id: true, name: true, phone: true } },
    },
    orderBy: { refundRequestedAt: 'desc' },
  });

  res.json(orders);
};
