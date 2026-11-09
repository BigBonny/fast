import Stripe from 'stripe';
import { prisma } from './prisma';
import { env } from '../config/env';

function stripeClient(): Stripe | null {
  if (!env.stripeSecretKey) return null;
  return new Stripe(env.stripeSecretKey);
}

/** Payment states in which the customer's money is still held and refundable. */
export const REFUNDABLE_PAYMENT_STATUSES = ['PAID', 'REFUND_REQUESTED'] as const;

export function isRefundablePaymentStatus(status: string): boolean {
  return (REFUNDABLE_PAYMENT_STATUSES as readonly string[]).includes(status);
}

/**
 * Builds the Stripe refund parameters for a charge.
 *
 * - Destination charges (restaurant on Stripe Connect) reverse the transfer,
 *   so the refund comes back out of the restaurant's share instead of FAST's
 *   balance.
 * - The platform fee only goes back on a full refund of a destination charge.
 * - The idempotency key encodes every parameter: a retry replays the same
 *   refund instead of creating a second one, and Stripe rejects a reused key
 *   with different parameters.
 */
export function buildRefundRequest(input: {
  keyPrefix: string;
  paymentIntentId: string;
  amountCents: number;
  hasDestinationTransfer: boolean;
  fullRefund: boolean;
}): { params: Stripe.RefundCreateParams; idempotencyKey: string } {
  const refundAppFee = input.fullRefund && input.hasDestinationTransfer;
  return {
    params: {
      payment_intent: input.paymentIntentId,
      amount: input.amountCents,
      ...(input.hasDestinationTransfer ? { reverse_transfer: true } : {}),
      ...(refundAppFee ? { refund_application_fee: true } : {}),
    },
    idempotencyKey:
      `${input.keyPrefix}-${input.amountCents}-${input.hasDestinationTransfer ? 'rt' : 'p'}` +
      `${refundAppFee ? '-raf' : '-n'}`,
  };
}

async function resolvePaymentIntentId(
  stripe: Stripe,
  order: { stripePaymentIntentId: string | null; stripeCheckoutSessionId: string | null },
): Promise<string | null> {
  if (order.stripePaymentIntentId) return order.stripePaymentIntentId;
  if (!order.stripeCheckoutSessionId) return null;
  const session = await stripe.checkout.sessions.retrieve(order.stripeCheckoutSessionId);
  return typeof session.payment_intent === 'string'
    ? session.payment_intent
    : session.payment_intent?.id ?? null;
}

/**
 * Refunds a paid order through Stripe and marks it REFUNDED.
 *
 * Works for orders that are PAID or have a pending refund request
 * (REFUND_REQUESTED): the money is still held in both cases. Returns false
 * when there is nothing to refund (unpaid, already refunded, no Stripe).
 *
 * `includeServiceFee: false` keeps FAST's service fee (client self-cancel and
 * restaurant-approved refund requests); `true` refunds everything
 * (restaurant declines the order).
 */
export async function refundPaidOrder(
  order: {
    id: string;
    paymentStatus: string;
    stripePaymentIntentId: string | null;
    stripeCheckoutSessionId: string | null;
    total: number;
    serviceFee: number;
  },
  options?: { includeServiceFee?: boolean },
): Promise<boolean> {
  if (!isRefundablePaymentStatus(order.paymentStatus)) return false;

  const stripe = stripeClient();
  if (!stripe) return false;

  const paymentIntentId = await resolvePaymentIntentId(stripe, order);
  if (!paymentIntentId) return false;

  const fullRefund = options?.includeServiceFee === true;
  const amountCents = Math.round((fullRefund ? order.total : order.total - order.serviceFee) * 100);
  if (amountCents <= 0) return false;

  // Charges that went fully to the platform (demo restaurant, platform-collect
  // restaurants) have no transfer_data, and Stripe rejects reverse_transfer.
  const pi = await stripe.paymentIntents.retrieve(paymentIntentId);
  const { params, idempotencyKey } = buildRefundRequest({
    keyPrefix: `order-refund-${order.id}`,
    paymentIntentId,
    amountCents,
    hasDestinationTransfer: !!pi.transfer_data?.destination,
    fullRefund,
  });
  await stripe.refunds.create(params, { idempotencyKey });

  await prisma.order.update({
    where: { id: order.id },
    data: { paymentStatus: 'REFUNDED', refundProcessedAt: new Date() },
  });
  return true;
}

/**
 * Fully refunds a payment whose order could not be created (for example a
 * group share paid just as the host submitted or cancelled the group).
 * Safe to call from both the webhook and the client confirm endpoint: the
 * idempotency key makes the second call replay the first refund.
 */
export async function refundRefusedCheckout(
  checkoutId: string,
  paymentIntentId: string | null | undefined,
): Promise<boolean> {
  const stripe = stripeClient();
  if (!stripe || !paymentIntentId) return false;

  const pi = await stripe.paymentIntents.retrieve(paymentIntentId);
  if (pi.status !== 'succeeded' || pi.amount_received <= 0) return false;

  const { params, idempotencyKey } = buildRefundRequest({
    keyPrefix: `checkout-refused-${checkoutId}`,
    paymentIntentId,
    amountCents: pi.amount_received,
    hasDestinationTransfer: !!pi.transfer_data?.destination,
    fullRefund: true,
  });
  await stripe.refunds.create(params, { idempotencyKey });
  return true;
}

/**
 * Thrown inside order creation when a payment succeeded but the order must
 * not be created (the group stopped accepting payments, or the payer left
 * it). Callers refund the payment and answer without retrying.
 */
export class CheckoutRefusedError extends Error {
  readonly code = 'CHECKOUT_REFUSED';
  constructor(message: string, readonly checkoutId: string, readonly userId: string) {
    super(message);
    this.name = 'CheckoutRefusedError';
  }
}
