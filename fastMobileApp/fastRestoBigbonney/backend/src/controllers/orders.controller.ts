import { Request, Response } from 'express';
import Stripe from 'stripe';
import { OrderStatus } from '@prisma/client';
import { prisma } from '../services/prisma';
import {
  placeOrderSchema,
  updateOrderStatusSchema,
  updateOrderTrackingSchema,
  verifyPickupSchema,
} from '../utils/validation';
import { isValidStatusTransition, STATUS_LABELS } from '../utils/orderStatus';
import { distanceKm } from '../utils/deliveryHelpers';
import { pickupTokenMatches } from '../utils/pickupToken';
import {
  safeEmitNotificationToUser,
  safeEmitOrderStatusToUser,
} from '../services/realtime';
import { env } from '../config/env';
import { getRestaurantIdForUser } from '../middleware/auth';

function stripeClient(): Stripe | null {
  if (!env.stripeSecretKey) return null;
  return new Stripe(env.stripeSecretKey);
}

const orderInclude = {
  items: { include: { menuItem: true } },
  restaurant: { select: { id: true, name: true, image: true, ownerId: true } },
  groupOrder: { select: { code: true, status: true } },
};

async function refundPaidOrder(
  order: {
    id: string;
    paymentStatus: string;
    stripePaymentIntentId: string | null;
    stripeCheckoutSessionId: string | null;
    total: number;
    serviceFee: number;
  },
  // Restaurant declines refund the whole paid amount; client self-cancel
  // keeps the service fee (existing policy).
  options?: { includeServiceFee?: boolean },
): Promise<void> {
  if (order.paymentStatus !== 'PAID') return;

  const stripe = stripeClient();
  if (!stripe) return;

  let paymentIntentId = order.stripePaymentIntentId;
  if (!paymentIntentId && order.stripeCheckoutSessionId) {
    const session = await stripe.checkout.sessions.retrieve(order.stripeCheckoutSessionId);
    paymentIntentId = typeof session.payment_intent === 'string'
      ? session.payment_intent
      : session.payment_intent?.id ?? null;
  }
  if (!paymentIntentId) return;

  const refundAmountCents = Math.round(
    (options?.includeServiceFee ? order.total : order.total - order.serviceFee) * 100,
  );
  if (refundAmountCents <= 0) return;

  // Only reverse a transfer when one exists — charges that went fully
  // to the platform (demo restaurant, or a restaurant without Connect)
  // have no transfer_data and Stripe 400s on reverse_transfer.
  const pi = await stripe.paymentIntents.retrieve(paymentIntentId);
  const hasDestinationTransfer = !!pi.transfer_data?.destination;
  const refundAppFee =
    options?.includeServiceFee === true && hasDestinationTransfer;

  await stripe.refunds.create(
    {
      payment_intent: paymentIntentId,
      amount: refundAmountCents,
      // Destination charge — pull the money back from the connected
      // account rather than paying the refund from the platform balance.
      ...(hasDestinationTransfer ? { reverse_transfer: true } : {}),
      // The platform fee only goes back when the customer is fully
      // refunded AND the charge actually had one (destination charges).
      ...(refundAppFee ? { refund_application_fee: true } : {}),
    },
    // Retries replay the same refund instead of charging a second one.
    // Params go in the key — a key reused with different parameters is
    // rejected outright by Stripe (burned idempotency keys can't recur).
    {
      idempotencyKey: `order-refund-${order.id}-${refundAmountCents}-${hasDestinationTransfer ? 'rt' : 'p'}${refundAppFee ? '-raf' : '-n'}`,
    },
  );

  await prisma.order.update({
    where: { id: order.id },
    data: { paymentStatus: 'REFUNDED' },
  });
}

export const placeOrder = async (req: Request, res: Response): Promise<void> => {
  placeOrderSchema.parse(req.body);
  res.status(402).json({ error: 'Paiement Stripe requis. Utilisez /api/payments/checkout-session.' });
};

export const getOrder = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  const order = await prisma.order.findUnique({
    where: { id },
    include: orderInclude,
  });
  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }

  const isOwner = order.userId === req.user!.userId;
  const isRestaurantOwner = order.restaurant.ownerId === req.user!.userId;
  const userRestaurantId = await getRestaurantIdForUser(req.user!);
  const isStaff = req.user!.role === 'STAFF' && req.user!.staffRole !== 'GUEST' && userRestaurantId === order.restaurantId;
  if (!isOwner && !isRestaurantOwner && !isStaff) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }

  res.json(order);
};

export const getMyOrders = async (req: Request, res: Response): Promise<void> => {
  const { status } = req.query;

  const where: Record<string, unknown> = { userId: req.user!.userId };
  if (status && typeof status === 'string') {
    where.status = status;
  }

  const orders = await prisma.order.findMany({
    where,
    include: {
      items: { include: { menuItem: true } },
      restaurant: { select: { id: true, name: true, image: true } },
      groupOrder: { select: { code: true, status: true } },
      delivery: { select: { id: true, status: true, driverId: true, destination: true } },
    },
    orderBy: { createdAt: 'desc' },
  });

  res.json(orders);
};

export const getRestaurantOrders = async (req: Request, res: Response): Promise<void> => {
  const { status } = req.query;

  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }

  const where: Record<string, unknown> = {
    restaurantId,
    OR: [
      { groupOrderId: null },
      { groupOrder: { status: 'SUBMITTED' } },
    ],
  };
  if (status && typeof status === 'string') {
    where.status = status;
  }

  const orders = await prisma.order.findMany({
    where,
    include: {
      items: { include: { menuItem: true } },
      user: { select: { id: true, name: true } },
      groupOrder: { select: { code: true, status: true } },
    },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });

  res.json(orders);
};

/** What the client hears when they start walking: prep state vs. their ETA. */
function clientEnRouteMessage(
  order: { status: string; prepStartedAt: Date | null; prepTimerSeconds: number },
  walkMin: number,
): string {
  if (order.status === 'READY_FOR_PICKUP') {
    return `Votre commande est prête — arrivée estimée dans ~${walkMin} min.`;
  }
  if (order.status === 'PREPARING' && order.prepStartedAt) {
    const elapsed = (Date.now() - order.prepStartedAt.getTime()) / 1000;
    const remainingMin = Math.max(0, Math.ceil((order.prepTimerSeconds - elapsed) / 60));
    return remainingMin > 0
      ? `Le restaurant prépare votre commande — prête dans ~${remainingMin} min, vous arrivez dans ~${walkMin} min.`
      : `Votre commande est presque prête — arrivée estimée dans ~${walkMin} min.`;
  }
  return `Le restaurant est prévenu — arrivée estimée dans ~${walkMin} min.`;
}

export const updateOrderTracking = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const data = updateOrderTrackingSchema.parse(req.body);

  const order = await prisma.order.findFirst({
    where: { id, userId: req.user!.userId },
    include: {
      restaurant: {
        select: {
          latitude: true,
          longitude: true,
          ownerId: true,
        },
      },
    },
  });
  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }

  // Terminal orders must not regress — a late in-flight patch could
  // otherwise clear isReadyAtEntrance set by verify-pickup.
  if (order.status === 'COMPLETED' || order.status === 'CANCELLED') {
    res.json(order);
    return;
  }

  const updateData: Record<string, unknown> = {};
  if (data.gpsProgress !== undefined) {
    // Once the client is en route the order stays en route — a later
    // jittery 0 must not flip the Pro card back (and re-fire the push).
    updateData.gpsProgress =
      order.gpsProgress > 0 ? Math.max(1, data.gpsProgress) : data.gpsProgress;
  }
  if (data.isReadyAtEntrance !== undefined) updateData.isReadyAtEntrance = data.isReadyAtEntrance;

  // Live walking ETA for the restaurant: client position → straight-line
  // km ÷ 5 km/h walk ≈ minutes. Stored in clientDelayMin — the same field
  // the Pro card's "client ETA" chip displays.
  if (
    data.latitude !== undefined &&
    data.longitude !== undefined &&
    order.fulfillmentType === 'PICKUP'
  ) {
    const km = distanceKm(
      order.restaurant.latitude,
      order.restaurant.longitude,
      data.latitude,
      data.longitude,
    );
    const walkMin = Math.min(60, Math.max(1, Math.ceil(km * 12)));
    updateData.clientDelayMin = walkMin;

    // Client just started moving (first nonzero progress patch) — tell
    // the restaurant they're en route and let the client know the prep
    // window. Fires once: gpsProgress only crosses 0→>0 a single time.
    if (order.gpsProgress === 0 && (data.gpsProgress ?? 0) > 0) {
      const enRoute = await prisma.notification.create({
        data: {
          userId: order.restaurant.ownerId!,
          orderId: order.id,
          title: 'Client en route',
          body: `Commande #${order.id.slice(-6)} — arrivée estimée dans ~${walkMin} min`,
          type: 'STATUS',
        },
      });
      safeEmitNotificationToUser(order.restaurant.ownerId!, enRoute);

      const prep = await prisma.notification.create({
        data: {
          userId: order.userId,
          orderId: order.id,
          title: 'Vous êtes en route',
          body: clientEnRouteMessage(order, walkMin),
          type: 'INFO',
        },
      });
      safeEmitNotificationToUser(order.userId, prep);
    }
  }

  const updated = await prisma.order.update({
    where: { id },
    data: updateData,
    include: orderInclude,
  });

  res.json(updated);
};

export const verifyPickup = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const parsed = verifyPickupSchema.parse(req.body);
  const token = (parsed.token ?? parsed.pickupToken ?? parsed.code)!;

  const order = await prisma.order.findUnique({
    where: { id },
    include: { restaurant: true },
  });
  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }

  if (order.restaurant.ownerId !== req.user!.userId) {
    const userRestaurantId = await getRestaurantIdForUser(req.user!);
    if (userRestaurantId !== order.restaurantId) {
      res.status(403).json({ error: 'Accès refusé' });
      return;
    }
  }

  // The client can show up while the kitchen is still finishing — handing
  // the bag over completes the order either way.
  if (order.status !== 'READY_FOR_PICKUP' && order.status !== 'PREPARING') {
    res.status(409).json({ error: 'Cette commande ne peut pas être remise' });
    return;
  }

  // Accepts the full QR token OR the short "XXXX-FAST" code shown
  // alongside it — both derive from the same stored token.
  if (!pickupTokenMatches(order.pickupToken, token)) {
    res.status(400).json({ error: 'Token de retrait invalide' });
    return;
  }

  res.json(await completePickup(order.id, order.userId));
};

/**
 * Restaurant types/scans a code without picking the order first: find the
 * matching active pickup order among this restaurant's orders.
 */
export const redeemPickupCode = async (req: Request, res: Response): Promise<void> => {
  const parsed = verifyPickupSchema.parse(req.body);
  const input = (parsed.code ?? parsed.pickupToken ?? parsed.token)!;

  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }

  const candidates = await prisma.order.findMany({
    where: {
      restaurantId,
      fulfillmentType: 'PICKUP',
      status: { in: ['PREPARING', 'READY_FOR_PICKUP'] },
      pickupToken: { not: null },
    },
    select: { id: true, userId: true, pickupToken: true },
  });
  const match = candidates.find((o) => pickupTokenMatches(o.pickupToken, input));
  if (!match) {
    res.status(404).json({ error: 'Aucune commande active ne correspond à ce code' });
    return;
  }

  res.json(await completePickup(match.id, match.userId));
};

async function completePickup(orderId: string, userId: string) {
  const updated = await prisma.$transaction(async (tx) => {
    const result = await tx.order.update({
      where: { id: orderId },
      data: { status: 'COMPLETED', isReadyAtEntrance: true },
      include: orderInclude,
    });

    await tx.user.update({
      where: { id: userId },
      data: { points: { increment: 10 } },
    });

    const statusNotification = await tx.notification.create({
      data: {
        userId,
        orderId,
        title: STATUS_LABELS.COMPLETED,
        body: 'Votre commande a été récupérée avec succès.',
        type: 'SUCCESS',
      },
    });

    const ratingNotification = await tx.notification.create({
      data: {
        userId,
        orderId,
        title: 'Notez votre commande',
        body: 'Comment s\'est passée votre expérience ? Laissez un avis.',
        type: 'RATING',
      },
    });

    return { order: result, statusNotification, ratingNotification };
  });

  safeEmitOrderStatusToUser(userId, { orderId, status: 'COMPLETED' });
  safeEmitNotificationToUser(userId, updated.statusNotification);
  safeEmitNotificationToUser(userId, updated.ratingNotification);
  return updated.order;
}

export const updateOrderStatus = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const data = updateOrderStatusSchema.parse(req.body);

  const order = await prisma.order.findUnique({
    where: { id },
    include: {
      restaurant: true,
      groupOrder: { select: { status: true } },
      items: { include: { menuItem: true } },
    },
  });
  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }

  const rest = order.restaurant;
  if (rest.ownerId !== req.user!.userId) {
    const userRestaurantId = await getRestaurantIdForUser(req.user!);
    if (userRestaurantId !== order.restaurantId) {
      res.status(403).json({ error: 'Accès refusé' });
      return;
    }
  }
  if (order.groupOrder && order.groupOrder.status !== 'SUBMITTED') {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }

  if (!isValidStatusTransition(order.status, data.status as OrderStatus)) {
    res.status(400).json({
      error: `Transition de statut invalide : ${order.status} → ${data.status}`,
    });
    return;
  }

  const updateData: Record<string, unknown> = { status: data.status };
  if (data.status === 'PREPARING') {
    updateData.prepStartedAt = new Date();
    const isRush = rest.isRushMode;
    const fallback = isRush ? rest.rushPrepTime : rest.normalPrepTime;
    // Per-dish prep times: dishes cook in parallel, so the order's prep
    // time is the longest dish time. Items without a time fall back to
    // the restaurant default.
    const itemTimes = order.items
      .map((it) => {
        const mi = it.menuItem;
        if (!mi) return 0;
        if (isRush) return mi.prepTimeRush > 0 ? mi.prepTimeRush : mi.prepTime;
        return mi.prepTime;
      })
      .filter((t) => t > 0);
    const prepTime =
      data.prepTimeMinutes ??
      (itemTimes.length > 0 ? Math.max(...itemTimes) : fallback);
    updateData.prepTimerSeconds = prepTime * 60;
  }
  if (data.status === 'CANCELLED' && data.isBilledAnyway) {
    updateData.isBilledAnyway = true;
  }
  // A restaurant cancelling a paid order refunds the customer — same
  // rule as client self-cancel. Only 'billed anyway' cancellations keep
  // the money (preparation already started).
  if (
    data.status === 'CANCELLED' &&
    !data.isBilledAnyway &&
    order.paymentStatus === 'PAID'
  ) {
    await refundPaidOrder(order, { includeServiceFee: true });
  }
  if (data.status === 'COMPLETED') {
    updateData.isReadyAtEntrance = true;
    await prisma.user.update({
      where: { id: order.userId },
      data: { points: { increment: 10 } },
    });
  }

  const updated = await prisma.order.update({
    where: { id },
    data: updateData,
    include: {
      items: { include: { menuItem: true } },
      restaurant: true,
      groupOrder: { select: { code: true, status: true } },
    },
  });

  const label = STATUS_LABELS[data.status] || data.status;
  const notification = await prisma.notification.create({
    data: {
      userId: order.userId,
      orderId: order.id,
      title: label,
      body: data.status === 'PREPARING'
        ? 'Le restaurant prépare votre commande.'
        : data.status === 'READY_FOR_PICKUP'
          ? 'Votre repas est chaud et prêt à être récupéré !'
          : data.status === 'CANCELLED'
            ? (data.isBilledAnyway
                ? 'Commande annulée — la préparation était déjà commencée, elle reste facturée.'
                : order.paymentStatus === 'PAID'
                  ? 'Le restaurant n\'a pas pu honorer votre commande — remboursement en cours.'
                  : 'Le restaurant n\'a pas pu honorer votre commande.')
            : `Statut mis à jour : ${label}`,
      type: data.status === 'COMPLETED' ? 'SUCCESS' : 'STATUS',
    },
  });

  safeEmitOrderStatusToUser(order.userId, {
    orderId: order.id,
    status: data.status,
  });
  safeEmitNotificationToUser(order.userId, notification);

  if (data.status === 'COMPLETED') {
    const ratingNotification = await prisma.notification.create({
      data: {
        userId: order.userId,
        orderId: order.id,
        title: 'Notez votre commande',
        body: 'Comment s\'est passée votre expérience ? Laissez un avis.',
        type: 'RATING',
      },
    });
    safeEmitNotificationToUser(order.userId, ratingNotification);
  }

  res.json(updated);
};

export const signalClientDelay = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const { delayMin } = req.body as { delayMin: number };

  if (typeof delayMin !== 'number' || delayMin < 1 || delayMin > 60) {
    res.status(400).json({ error: 'Délai invalide (1-60 min)' });
    return;
  }

  const order = await prisma.order.findFirst({
    where: { id, userId: req.user!.userId },
    include: { restaurant: { select: { id: true, ownerId: true } } },
  });
  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }

  if (order.status === 'COMPLETED' || order.status === 'CANCELLED') {
    res.status(409).json({ error: 'Commande terminée' });
    return;
  }

  await prisma.order.update({
    where: { id },
    data: { clientDelayMin: delayMin },
  });

  const notification = await prisma.notification.create({
    data: {
      userId: order.restaurant.ownerId!,
      orderId: order.id,
      title: 'Arrivée du client',
      body: `Commande #${order.id.slice(-6)} — Le client arrive dans ~${delayMin} min`,
      type: 'INFO',
    },
  });
  safeEmitNotificationToUser(order.restaurant.ownerId!, notification);

  res.json({ message: `Retard de ${delayMin} min signalé au restaurant` });
};

export const setFastFeedback = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const { feedback } = req.body as { feedback: string };

  if (feedback !== 'LIKE' && feedback !== 'DISLIKE') {
    res.status(400).json({ error: 'Feedback invalide (LIKE ou DISLIKE)' });
    return;
  }

  const order = await prisma.order.findFirst({
    where: { id, userId: req.user!.userId },
  });
  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }

  if (order.status !== 'COMPLETED') {
    res.status(409).json({ error: 'Commande non terminée' });
    return;
  }

  await prisma.order.update({
    where: { id },
    data: { fastFeedback: feedback },
  });

  res.json({ message: 'Feedback enregistré', fastFeedback: feedback });
};

export const cancelMyOrder = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  const order = await prisma.order.findFirst({
    where: { id, userId: req.user!.userId },
    include: { groupOrder: { select: { code: true, status: true } } },
  });
  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }
  if (order.groupOrder) {
    res.status(409).json({
      error: `La part payée du groupe ${order.groupOrder.code} ne peut pas être annulée individuellement`,
    });
    return;
  }

  if (order.status === 'CANCELLED' || order.status === 'COMPLETED') {
    res.status(409).json({ error: 'Cette commande ne peut plus être annulée' });
    return;
  }

  if (order.status !== 'PLACED') {
    await prisma.order.update({
      where: { id },
      data: { status: 'CANCELLED', isBilledAnyway: true },
    });
    res.json({ message: 'Commande annulée. La préparation avait commencé, le montant est facturé.' });
    return;
  }

  if (order.paymentStatus === 'PAID') {
    try {
      await refundPaidOrder(order);
    } catch (err) {
      res.status(500).json({ error: `Échec du remboursement : ${(err as Error).message}` });
      return;
    }
  }

  await prisma.order.update({
    where: { id },
    data: { status: 'CANCELLED' },
  });

  res.json({ message: 'Commande annulée. Remboursement effectué (hors frais de service).' });
};
