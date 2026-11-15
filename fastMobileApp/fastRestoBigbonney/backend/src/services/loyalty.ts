import { Prisma } from '@prisma/client';
import { prisma } from './prisma';
import { safeEmitNotificationToUser } from './realtime';

/**
 * Loyalty cards.
 *
 * A card's progress is derived, never stored: orders that are both paid
 * and completed at the restaurant since it enabled its programme, minus
 * the stamps already spent on rewards. A cancelled or refunded order
 * simply stops counting, so no point can outlive its order.
 */

export interface LoyaltyCardState {
  /** Stamps shown on the card, capped at the threshold. */
  stamps: number;
  /** Orders still needed before the reward. */
  remaining: number;
  rewardAvailable: boolean;
}

export function loyaltyCardState(
  eligibleOrders: number,
  stampsSpent: number,
  threshold: number,
): LoyaltyCardState {
  const goal = Math.max(1, threshold);
  const progress = Math.max(0, eligibleOrders - stampsSpent);
  return {
    stamps: Math.min(progress, goal),
    remaining: Math.max(0, goal - progress),
    rewardAvailable: progress >= goal,
  };
}

/** Orders that earn a stamp: completed, paid, not refunded. */
export function loyaltyOrdersWhere(
  userId: string,
  restaurantId: string,
  startedAt: Date | null,
): Prisma.OrderWhereInput {
  return {
    userId,
    restaurantId,
    status: 'COMPLETED',
    paymentStatus: { in: ['PAID', 'REFUND_REJECTED'] },
    ...(startedAt ? { createdAt: { gte: startedAt } } : {}),
  };
}

type Db = Prisma.TransactionClient | typeof prisma;

async function rawProgress(
  db: Db,
  userId: string,
  restaurantId: string,
  startedAt: Date | null,
): Promise<{ eligible: number; spent: number }> {
  const [eligible, spent] = await Promise.all([
    db.order.count({ where: loyaltyOrdersWhere(userId, restaurantId, startedAt) }),
    db.loyaltyRedemption.aggregate({
      where: { userId, restaurantId },
      _sum: { stampsUsed: true },
    }),
  ]);
  return { eligible, spent: spent._sum.stampsUsed ?? 0 };
}

export interface LoyaltyCard extends LoyaltyCardState {
  restaurantId: string;
  restaurantName: string;
  restaurantImage: string;
  threshold: number;
  reward: string;
}

/** Every card the user has started (at least one stamp or one reward used). */
export async function listLoyaltyCards(userId: string): Promise<LoyaltyCard[]> {
  const restaurants = await prisma.restaurant.findMany({
    where: {
      loyaltyEnabled: true,
      isActive: true,
      OR: [
        { orders: { some: { userId, status: 'COMPLETED' } } },
        { loyaltyRedemptions: { some: { userId } } },
      ],
    },
    select: {
      id: true,
      name: true,
      image: true,
      loyaltyThreshold: true,
      loyaltyReward: true,
      loyaltyStartedAt: true,
    },
  });
  if (restaurants.length === 0) return [];

  const ids = restaurants.map((r) => r.id);
  const [orders, redemptions] = await Promise.all([
    prisma.order.findMany({
      where: {
        userId,
        restaurantId: { in: ids },
        status: 'COMPLETED',
        paymentStatus: { in: ['PAID', 'REFUND_REJECTED'] },
      },
      select: { restaurantId: true, createdAt: true },
    }),
    prisma.loyaltyRedemption.groupBy({
      by: ['restaurantId'],
      where: { userId, restaurantId: { in: ids } },
      _sum: { stampsUsed: true },
    }),
  ]);
  const spentBy = new Map(redemptions.map((r) => [r.restaurantId, r._sum.stampsUsed ?? 0]));

  const cards: LoyaltyCard[] = [];
  for (const r of restaurants) {
    const eligible = orders.filter(
      (o) =>
        o.restaurantId === r.id &&
        (!r.loyaltyStartedAt || o.createdAt >= r.loyaltyStartedAt),
    ).length;
    const spent = spentBy.get(r.id) ?? 0;
    if (eligible === 0 && spent === 0) continue;
    cards.push({
      restaurantId: r.id,
      restaurantName: r.name,
      restaurantImage: r.image,
      threshold: r.loyaltyThreshold,
      reward: r.loyaltyReward,
      ...loyaltyCardState(eligible, spent, r.loyaltyThreshold),
    });
  }
  // Closest to the reward first.
  cards.sort((a, b) => a.remaining - b.remaining);
  return cards;
}

export type RedeemResult =
  | { ok: true; redemptionId: string; reward: string; restaurantName: string; ownerId: string }
  | { ok: false; reason: 'NOT_FOUND' | 'DISABLED' | 'NOT_READY' };

/**
 * Spends one full card. Serializable so two taps (or two phones) can't
 * both spend the same stamps.
 */
export async function redeemLoyaltyReward(
  userId: string,
  restaurantId: string,
): Promise<RedeemResult> {
  return prisma.$transaction(
    async (tx): Promise<RedeemResult> => {
      const restaurant = await tx.restaurant.findUnique({
        where: { id: restaurantId },
        select: {
          name: true,
          ownerId: true,
          loyaltyEnabled: true,
          loyaltyThreshold: true,
          loyaltyReward: true,
          loyaltyStartedAt: true,
        },
      });
      if (!restaurant) return { ok: false, reason: 'NOT_FOUND' };
      if (!restaurant.loyaltyEnabled) return { ok: false, reason: 'DISABLED' };

      const { eligible, spent } = await rawProgress(
        tx,
        userId,
        restaurantId,
        restaurant.loyaltyStartedAt,
      );
      const state = loyaltyCardState(eligible, spent, restaurant.loyaltyThreshold);
      if (!state.rewardAvailable) return { ok: false, reason: 'NOT_READY' };

      const redemption = await tx.loyaltyRedemption.create({
        data: {
          userId,
          restaurantId,
          stampsUsed: restaurant.loyaltyThreshold,
          reward: restaurant.loyaltyReward,
        },
      });
      return {
        ok: true,
        redemptionId: redemption.id,
        reward: restaurant.loyaltyReward,
        restaurantName: restaurant.name,
        ownerId: restaurant.ownerId,
      };
    },
    { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
  );
}

/**
 * Called once an order has just been completed: tells the client when
 * that order filled their card. Best effort — a loyalty hiccup must
 * never fail the pickup itself.
 */
export async function notifyLoyaltyAfterCompletion(orderId: string): Promise<void> {
  try {
    const order = await prisma.order.findUnique({
      where: { id: orderId },
      select: {
        userId: true,
        restaurantId: true,
        paymentStatus: true,
        createdAt: true,
        restaurant: {
          select: {
            name: true,
            loyaltyEnabled: true,
            loyaltyThreshold: true,
            loyaltyReward: true,
            loyaltyStartedAt: true,
          },
        },
      },
    });
    const rest = order?.restaurant;
    if (!order || !rest?.loyaltyEnabled) return;
    if (order.paymentStatus !== 'PAID' && order.paymentStatus !== 'REFUND_REJECTED') return;
    if (rest.loyaltyStartedAt && order.createdAt < rest.loyaltyStartedAt) return;

    const { eligible, spent } = await rawProgress(
      prisma,
      order.userId,
      order.restaurantId,
      rest.loyaltyStartedAt,
    );
    // Exactly on the threshold: this order is the one that filled the card.
    if (eligible - spent !== rest.loyaltyThreshold) return;

    const notification = await prisma.notification.create({
      data: {
        userId: order.userId,
        orderId,
        title: 'Votre récompense vous attend !',
        body: `Carte fidélité ${rest.name} complète : ${rest.loyaltyReward}. Retrouvez-la dans « Ma fidélité ».`,
        type: 'SUCCESS',
      },
    });
    safeEmitNotificationToUser(order.userId, notification);
  } catch (err) {
    console.error('notifyLoyaltyAfterCompletion failed', orderId, err);
  }
}
