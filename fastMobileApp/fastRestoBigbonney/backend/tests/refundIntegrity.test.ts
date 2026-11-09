import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

// Isolate from the developer's backend/.env: dotenv never overrides a
// variable that is already set, so these win. No database, Stripe network
// call, push or Sentry event can happen from this file.
process.env.JWT_SECRET = 'test-secret';
process.env.DATABASE_URL = 'postgresql://invalid:invalid@127.0.0.1:1/none';
process.env.STRIPE_SECRET_KEY = 'sk_test_dummy_no_network';
process.env.FIREBASE_PROJECT_ID = '';
process.env.FIREBASE_CLIENT_EMAIL = '';
process.env.FIREBASE_PRIVATE_KEY = '';
process.env.SENTRY_DSN = '';

const { prisma } = require('../src/services/prisma');
const {
  buildRefundRequest,
  isRefundablePaymentStatus,
  CheckoutRefusedError,
} = require('../src/services/stripeRefunds');
const { updateOrderStatus, cancelMyOrder } = require('../src/controllers/orders.controller');
const { approveRefund, rejectRefund } = require('../src/controllers/refunds.controller');

// ─── Fakes ──────────────────────────────────────────────────

type Call = { model: string; method: string; args: unknown };
let calls: Call[] = [];
let handlers: Record<string, (args: any) => unknown> = {};

function model(name: string) {
  return new Proxy(
    {},
    {
      get: (_t, method: string) => async (args: unknown) => {
        calls.push({ model: name, method, args });
        const h = handlers[`${name}.${method}`];
        if (!h) throw new Error(`unexpected prisma call ${name}.${method}`);
        return h(args);
      },
    },
  );
}

for (const name of ['order', 'user', 'notification', 'restaurant', 'deviceToken', 'restaurantStaff']) {
  Object.defineProperty(prisma, name, { value: model(name), configurable: true });
}
Object.defineProperty(prisma, '$transaction', {
  value: async (fn: (tx: unknown) => unknown) => fn(prisma),
  configurable: true,
});

function fakeRes() {
  const res: any = { statusCode: 200, body: undefined };
  res.status = (c: number) => ((res.statusCode = c), res);
  res.json = (b: unknown) => ((res.body = b), res);
  return res;
}

const OWNER = { userId: 'owner1', role: 'RESTAURANT', tokenVersion: 0 };
const CLIENT = { userId: 'client1', role: 'CLIENT', tokenVersion: 0 };

function baseOrder(overrides: Record<string, unknown> = {}) {
  return {
    id: 'order1',
    userId: 'client1',
    restaurantId: 'resto1',
    status: 'PREPARING',
    paymentStatus: 'PAID',
    total: 20,
    serviceFee: 2,
    stripePaymentIntentId: 'pi_123',
    stripeCheckoutSessionId: null,
    refundReason: '',
    restaurant: { id: 'resto1', ownerId: 'owner1', isRushMode: false, rushPrepTime: 25, normalPrepTime: 15 },
    groupOrder: null,
    items: [],
    ...overrides,
  };
}

beforeEach(() => {
  calls = [];
  handlers = {
    'deviceToken.findMany': () => [],
    'notification.create': (a) => ({ id: 'n1', ...a.data }),
    'restaurant.findUnique': () => ({ id: 'resto1' }),
  };
});

const count = (m: string, method: string) =>
  calls.filter((c) => c.model === m && c.method === method).length;

// ─── Refund request building ────────────────────────────────

test('Connect refunds reverse the transfer; full refunds also return the fee', () => {
  const partial = buildRefundRequest({
    keyPrefix: 'order-refund-o1',
    paymentIntentId: 'pi_1',
    amountCents: 1800,
    hasDestinationTransfer: true,
    fullRefund: false,
  });
  assert.deepEqual(partial.params, { payment_intent: 'pi_1', amount: 1800, reverse_transfer: true });
  assert.equal(partial.idempotencyKey, 'order-refund-o1-1800-rt-n');

  const full = buildRefundRequest({
    keyPrefix: 'order-refund-o1',
    paymentIntentId: 'pi_1',
    amountCents: 2000,
    hasDestinationTransfer: true,
    fullRefund: true,
  });
  assert.equal(full.params.reverse_transfer, true);
  assert.equal(full.params.refund_application_fee, true);
  assert.equal(full.idempotencyKey, 'order-refund-o1-2000-rt-raf');
});

test('platform charges never send reverse_transfer (Stripe would reject it)', () => {
  const r = buildRefundRequest({
    keyPrefix: 'k',
    paymentIntentId: 'pi_1',
    amountCents: 500,
    hasDestinationTransfer: false,
    fullRefund: true,
  });
  assert.deepEqual(r.params, { payment_intent: 'pi_1', amount: 500 });
});

test('pending refund requests still count as refundable money', () => {
  assert.equal(isRefundablePaymentStatus('PAID'), true);
  assert.equal(isRefundablePaymentStatus('REFUND_REQUESTED'), true);
  for (const s of ['PENDING', 'FAILED', 'REFUNDED', 'REFUND_REJECTED']) {
    assert.equal(isRefundablePaymentStatus(s), false, s);
  }
});

test('CheckoutRefusedError carries what the refund handler needs', () => {
  const e = new CheckoutRefusedError('closed', 'chk1', 'u1');
  assert.ok(e instanceof Error);
  assert.equal(e.code, 'CHECKOUT_REFUSED');
  assert.equal(e.checkoutId, 'chk1');
  assert.equal(e.userId, 'u1');
});

// ─── Status update races ────────────────────────────────────

test('status update that lost a race returns 409 and grants nothing', async () => {
  handlers['order.findUnique'] = () => baseOrder({ status: 'READY_FOR_PICKUP' });
  handlers['order.updateMany'] = () => ({ count: 0 }); // someone else moved it
  const res = fakeRes();
  await updateOrderStatus(
    { params: { id: 'order1' }, body: { status: 'COMPLETED' }, user: OWNER },
    res,
  );
  assert.equal(res.statusCode, 409);
  assert.equal(count('user', 'update'), 0, 'no loyalty points');
  assert.equal(count('notification', 'create'), 0, 'no notification');
});

test('status update that wins grants points exactly once', async () => {
  handlers['order.findUnique'] = () => baseOrder({ status: 'READY_FOR_PICKUP' });
  handlers['order.updateMany'] = () => ({ count: 1 });
  handlers['user.update'] = () => ({});
  const res = fakeRes();
  await updateOrderStatus(
    { params: { id: 'order1' }, body: { status: 'COMPLETED' }, user: OWNER },
    res,
  );
  assert.equal(res.statusCode, 200);
  assert.equal(count('user', 'update'), 1);
  const claim = calls.find((c) => c.method === 'updateMany')!.args as any;
  assert.deepEqual(claim.where, { id: 'order1', status: 'READY_FOR_PICKUP' });
});

// ─── Client cancel ──────────────────────────────────────────

test('client cancel racing a restaurant accept returns 409 without refunding', async () => {
  handlers['order.findFirst'] = () => baseOrder({ status: 'PLACED' });
  handlers['order.updateMany'] = () => ({ count: 0 }); // restaurant accepted first
  const res = fakeRes();
  await cancelMyOrder({ params: { id: 'order1' }, user: CLIENT }, res);
  assert.equal(res.statusCode, 409);
  assert.equal(count('order', 'update'), 0, 'never marked REFUNDED');
});

// ─── Restaurant refund approval ─────────────────────────────

test('approving an already-processed refund request returns 409 before Stripe', async () => {
  handlers['order.findFirst'] = () => baseOrder({ paymentStatus: 'REFUND_REQUESTED' });
  handlers['order.updateMany'] = () => ({ count: 0 }); // double tap / other device
  const res = fakeRes();
  await approveRefund({ params: { id: 'order1' }, user: OWNER }, res);
  assert.equal(res.statusCode, 409);
  const claim = calls.find((c) => c.method === 'updateMany')!.args as any;
  assert.deepEqual(claim.where, {
    id: 'order1',
    restaurantId: 'resto1',
    paymentStatus: 'REFUND_REQUESTED',
    refundProcessedAt: null,
  });
});

test('rejecting a request that was already approved returns 409', async () => {
  handlers['order.findFirst'] = () => baseOrder({ paymentStatus: 'REFUND_REQUESTED' });
  handlers['order.updateMany'] = () => ({ count: 0 });
  const res = fakeRes();
  await rejectRefund({ params: { id: 'order1' }, body: {}, user: OWNER }, res);
  assert.equal(res.statusCode, 409);
  assert.equal(count('notification', 'create'), 0);
});
