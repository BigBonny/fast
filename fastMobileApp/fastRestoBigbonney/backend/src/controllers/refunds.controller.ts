import { Request, Response } from 'express';
import Stripe from 'stripe';
import { prisma } from '../services/prisma';
import { env } from '../config/env';
import { getRestaurantIdForUser } from '../middleware/auth';
import { safeEmitNotificationToUser } from '../services/realtime';

function stripeClient(): Stripe | null {
  if (!env.stripeSecretKey) return null;
  return new Stripe(env.stripeSecretKey);
}

// Client requests a refund for a paid order
export const requestRefund = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const { reason } = req.body as { reason?: string };

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

  await prisma.order.update({
    where: { id },
    data: {
      paymentStatus: 'REFUND_REQUESTED',
      refundReason: reason || '',
      refundRequestedAt: new Date(),
    },
  });

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
  safeEmitNotificationToUser(order.restaurant.ownerId!, notification);

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

  // Process Stripe refund
  const stripe = stripeClient();
  if (!stripe) {
    res.status(500).json({ error: 'Stripe non configuré' });
    return;
  }

  let paymentIntentId = order.stripePaymentIntentId;
  if (!paymentIntentId && order.stripeCheckoutSessionId) {
    const session = await stripe.checkout.sessions.retrieve(order.stripeCheckoutSessionId);
    paymentIntentId = typeof session.payment_intent === 'string'
      ? session.payment_intent
      : session.payment_intent?.id ?? null;
  }

  if (!paymentIntentId) {
    res.status(500).json({ error: 'Impossible de trouver le paiement Stripe' });
    return;
  }

  const refundAmountCents = Math.round((order.total - order.serviceFee) * 100);
  if (refundAmountCents <= 0) {
    res.status(400).json({ error: 'Montant à rembourser invalide' });
    return;
  }

  try {
    await stripe.refunds.create({
      payment_intent: paymentIntentId,
      amount: refundAmountCents,
    });

    await prisma.order.update({
      where: { id },
      data: {
        paymentStatus: 'REFUNDED',
        status: 'CANCELLED',
        refundProcessedAt: new Date(),
      },
    });

    // Notify client
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
  } catch (err) {
    res.status(500).json({ error: `Échec du remboursement Stripe : ${(err as Error).message}` });
  }
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

  await prisma.order.update({
    where: { id },
    data: {
      paymentStatus: 'REFUND_REJECTED',
      refundProcessedAt: new Date(),
      refundReason: `${order.refundReason} [Refusé: ${rejectionReason || 'non spécifié'}]`,
    },
  });

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
