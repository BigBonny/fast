import { prisma } from './prisma';
import { env } from '../config/env';
import { isRefundablePaymentStatus, refundPaidOrder } from './stripeRefunds';
import { safeEmitNotificationToUser, notifyRestaurantTeam } from './realtime';

/**
 * Orders the restaurant never accepted are cancelled and fully refunded
 * after `env.acceptTimeoutMin` minutes, so a customer is never left
 * waiting (and charged) at a restaurant that is closed or not looking.
 *
 * There is no scheduler on Vercel's plan, so this runs when the customer
 * or the restaurant fetches orders. Both apps poll while an order is open,
 * which makes the check happen within seconds of the deadline.
 *
 * The clock starts at payment for normal orders, and at submission for
 * group orders (the restaurant doesn't see them before that).
 */

const MIN_INTERVAL_MS = 30_000;
const lastSweep = new Map<string, number>();

export function acceptDeadline(now: Date = new Date()): Date {
  return new Date(now.getTime() - env.acceptTimeoutMin * 60_000);
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
      { groupOrderId: null, createdAt: { lt: deadline } },
      { groupOrder: { status: 'SUBMITTED' as const, submittedAt: { lt: deadline } } },
    ],
  };
}

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
    const stale = await prisma.order.findMany({
      where: staleOrdersWhere(scope),
      include: { restaurant: { select: { ownerId: true } } },
      take: 20,
    });
    let expired = 0;
    for (const order of stale) {
      if (await expireOrder(order)) expired++;
    }
    return expired;
  } catch (err) {
    console.error('expireUnacceptedOrders failed', scope, err);
    return 0;
  }
}

async function expireOrder(order: {
  id: string;
  userId: string;
  restaurantId: string;
  paymentStatus: string;
  stripePaymentIntentId: string | null;
  stripeCheckoutSessionId: string | null;
  total: number;
  serviceFee: number;
  restaurant: { ownerId: string };
}): Promise<boolean> {
  // Claim PLACED → CANCELLED: if the restaurant accepts at the same moment,
  // exactly one side wins.
  const claimed = await prisma.order.updateMany({
    where: { id: order.id, status: 'PLACED' },
    data: { status: 'CANCELLED', refundReason: 'Non acceptée par le restaurant à temps' },
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
      console.error('expireOrder: refund failed', order.id, err);
      return false;
    }
  }

  const ref = order.id.slice(-6).toUpperCase();
  const customer = await prisma.notification.create({
    data: {
      userId: order.userId,
      orderId: order.id,
      title: 'Commande annulée',
      body: refundable
        ? "Le restaurant n'a pas accepté votre commande à temps — vous êtes intégralement remboursé."
        : "Le restaurant n'a pas accepté votre commande à temps.",
      type: 'STATUS',
    },
  });
  safeEmitNotificationToUser(order.userId, customer);

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
  return true;
}

/** Test hook: forget throttling state. */
export function resetStaleOrderThrottle(): void {
  lastSweep.clear();
}
