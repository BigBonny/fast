import { prisma } from './prisma';
import { env } from '../config/env';
import { isRefundablePaymentStatus, refundPaidOrder } from './stripeRefunds';
import { safeEmitNotificationToUser, notifyRestaurantTeam } from './realtime';

/**
 * Paid orders that will never be prepared are cancelled and fully refunded,
 * so no customer is left charged for nothing:
 *
 * - the restaurant didn't accept within `env.acceptTimeoutMin` minutes
 *   (counted from payment, or from submission for group orders);
 * - the group was never sent to the restaurant: the host didn't submit
 *   within `env.groupAbandonMin` minutes of the share being paid;
 * - the host cancelled the group after some members had paid.
 *
 * There is no scheduler on Vercel's plan, so the sweep runs when the
 * customer or the restaurant fetches orders. Both apps poll while an order
 * is open, so the deadline is applied within seconds.
 */

const MIN_INTERVAL_MS = 30_000;
const CHECKOUT_CLEANUP_INTERVAL_MS = 60 * 60_000;
// Well past Stripe's 3-day webhook retry window, so a late payment still finds its row.
const ABANDONED_CHECKOUT_AGE_MS = 7 * 24 * 60 * 60_000;
const lastSweep = new Map<string, number>();
let lastCheckoutCleanup = 0;

export type ExpiryReason = 'NOT_ACCEPTED' | 'GROUP_NOT_SENT' | 'GROUP_CANCELLED';

export function acceptDeadline(now: Date = new Date()): Date {
  return new Date(now.getTime() - env.acceptTimeoutMin * 60_000);
}

export function groupDeadline(now: Date = new Date()): Date {
  return new Date(now.getTime() - env.groupAbandonMin * 60_000);
}

export function staleOrdersWhere(
  scope: { restaurantId?: string; userId?: string },
  now: Date = new Date(),
) {
  const deadline = acceptDeadline(now);
  return {
    ...scope,
    status: 'PLACED' as const,
    OR: [
      // Normal order the restaurant never accepted.
      { groupOrderId: null, createdAt: { lt: deadline } },
      // Group sent to the restaurant, never accepted.
      { groupOrder: { status: 'SUBMITTED' as const, submittedAt: { lt: deadline } } },
      // Group the host never sent (or cancelled): the restaurant can't
      // even see these orders.
      {
        groupOrder: { status: { in: ['OPEN' as const, 'LOCKED' as const, 'CANCELLED' as const] } },
        createdAt: { lt: groupDeadline(now) },
      },
    ],
  };
}

const staleOrderInclude = {
  restaurant: { select: { ownerId: true } },
  groupOrder: { select: { id: true, code: true, status: true } },
};

/**
 * Cancels and refunds this scope's expired orders. Throttled per scope, and
 * never throws: a failure here must not break the order list it runs before.
 */
export async function expireUnacceptedOrders(
  scope: { restaurantId: string } | { userId: string },
): Promise<number> {
  const key = 'restaurantId' in scope ? `r:${scope.restaurantId}` : `u:${scope.userId}`;
  const now = Date.now();
  if (now - (lastSweep.get(key) ?? 0) < MIN_INTERVAL_MS) return 0;
  lastSweep.set(key, now);

  try {
    await cleanUpAbandonedCheckouts(now);
    const stale = await prisma.order.findMany({
      where: staleOrdersWhere(scope),
      include: staleOrderInclude,
      take: 20,
    });
    let expired = 0;
    for (const order of stale) {
      const reason: ExpiryReason =
        order.groupOrder && order.groupOrder.status !== 'SUBMITTED'
          ? order.groupOrder.status === 'CANCELLED' ? 'GROUP_CANCELLED' : 'GROUP_NOT_SENT'
          : 'NOT_ACCEPTED';
      if (await cancelAndRefundOrder(order, reason)) expired++;
    }
    return expired;
  } catch (err) {
    console.error('expireUnacceptedOrders failed', scope, err);
    return 0;
  }
}

/**
 * The host cancels a group: every paid share still waiting is refunded.
 * Returns the number of orders refunded. The group must already be marked
 * CANCELLED by the caller (so no member can pay or submit meanwhile).
 */
export async function refundCancelledGroup(groupId: string): Promise<number> {
  const orders = await prisma.order.findMany({
    where: { groupOrderId: groupId, status: 'PLACED' },
    include: staleOrderInclude,
  });
  let refunded = 0;
  for (const order of orders) {
    if (await cancelAndRefundOrder(order, 'GROUP_CANCELLED')) refunded++;
  }
  return refunded;
}

type StaleOrder = {
  id: string;
  userId: string;
  restaurantId: string;
  paymentStatus: string;
  stripePaymentIntentId: string | null;
  stripeCheckoutSessionId: string | null;
  total: number;
  serviceFee: number;
  restaurant: { ownerId: string };
  groupOrder: { id: string; code: string; status: string } | null;
};

const CUSTOMER_MESSAGES: Record<ExpiryReason, string> = {
  NOT_ACCEPTED: "Le restaurant n'a pas accepté votre commande à temps",
  GROUP_NOT_SENT: "La commande de groupe n'a pas été envoyée au restaurant à temps",
  GROUP_CANCELLED: "L'hôte a annulé la commande de groupe",
};

async function cancelAndRefundOrder(order: StaleOrder, reason: ExpiryReason): Promise<boolean> {
  // An unsent group is closed first, so the host can't submit it while its
  // orders are being refunded. If the host submitted in the meantime, the
  // orders follow the normal acceptance deadline instead.
  if (reason === 'GROUP_NOT_SENT' && order.groupOrder) {
    const closed = await prisma.groupOrder.updateMany({
      where: { id: order.groupOrder.id, status: { in: ['OPEN', 'LOCKED'] } },
      data: { status: 'CANCELLED' },
    });
    if (closed.count === 0) {
      const current = await prisma.groupOrder.findUnique({
        where: { id: order.groupOrder.id },
        select: { status: true },
      });
      if (current?.status !== 'CANCELLED') return false;
    }
  }

  // Claim PLACED → CANCELLED: if the restaurant accepts at the same moment,
  // exactly one side wins.
  const claimed = await prisma.order.updateMany({
    where: { id: order.id, status: 'PLACED' },
    data: { status: 'CANCELLED', refundReason: CUSTOMER_MESSAGES[reason] },
  });
  if (claimed.count !== 1) return false;

  const refundable = isRefundablePaymentStatus(order.paymentStatus);
  if (refundable) {
    try {
      // The customer got nothing: refund everything, service fee included.
      await refundPaidOrder(order, { includeServiceFee: true });
    } catch (err) {
      // Put it back so the next sweep retries, rather than leaving a
      // cancelled-but-charged order.
      await prisma.order.updateMany({
        where: { id: order.id, status: 'CANCELLED' },
        data: { status: 'PLACED', refundReason: '' },
      });
      console.error('cancelAndRefundOrder: refund failed', order.id, err);
      return false;
    }
  }

  const customer = await prisma.notification.create({
    data: {
      userId: order.userId,
      orderId: order.id,
      title: 'Commande annulée',
      body: `${CUSTOMER_MESSAGES[reason]}${refundable ? ' — vous êtes intégralement remboursé.' : '.'}`,
      type: 'STATUS',
    },
  });
  safeEmitNotificationToUser(order.userId, customer);

  // The restaurant only hears about orders it could see.
  if (reason === 'NOT_ACCEPTED') {
    const ref = order.id.slice(-6).toUpperCase();
    const team = await prisma.notification.create({
      data: {
        userId: order.restaurant.ownerId,
        orderId: order.id,
        title: 'Commande expirée',
        body: `Commande #${ref} annulée et remboursée : elle n'a pas été acceptée dans les ${env.acceptTimeoutMin} minutes.`,
        type: 'INFO',
      },
    });
    notifyRestaurantTeam(order.restaurantId, order.restaurant.ownerId, team);
  }
  return true;
}

/**
 * Checkout rows are created when payment starts. One that never became an
 * order within a week was abandoned (or refused and already refunded).
 */
async function cleanUpAbandonedCheckouts(now: number): Promise<void> {
  if (now - lastCheckoutCleanup < CHECKOUT_CLEANUP_INTERVAL_MS) return;
  lastCheckoutCleanup = now;
  await prisma.paymentCheckout.deleteMany({
    where: { createdOrderId: null, createdAt: { lt: new Date(now - ABANDONED_CHECKOUT_AGE_MS) } },
  });
}

/** Test hook: forget throttling state. */
export function resetStaleOrderThrottle(): void {
  lastSweep.clear();
  lastCheckoutCleanup = Date.now();
}
