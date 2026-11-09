import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

process.env.JWT_SECRET = 'test-secret';
process.env.DATABASE_URL = 'postgresql://invalid:invalid@127.0.0.1:1/none';
process.env.STRIPE_SECRET_KEY = ''; // no Stripe: refunds become no-ops
process.env.FIREBASE_PROJECT_ID = '';
process.env.SENTRY_DSN = '';
process.env.FAST_ACCEPT_TIMEOUT_MIN = '15';

const { prisma } = require('../src/services/prisma');
const {
  expireUnacceptedOrders,
  staleOrdersWhere,
  resetStaleOrderThrottle,
} = require('../src/services/staleOrders');

type Call = { model: string; method: string; args: any };
let calls: Call[] = [];
let handlers: Record<string, (args: any) => unknown> = {};
for (const name of ['order', 'notification', 'deviceToken', 'restaurantStaff']) {
  Object.defineProperty(prisma, name, {
    configurable: true,
    value: new Proxy({}, {
      get: (_t, method: string) => async (args: unknown) => {
        calls.push({ model: name, method, args });
        const h = handlers[`${name}.${method}`];
        if (!h) throw new Error(`unexpected prisma call ${name}.${method}`);
        return h(args);
      },
    }),
  });
}

const staleOrder = {
  id: 'order_abc123',
  userId: 'client1',
  restaurantId: 'resto1',
  paymentStatus: 'PAID',
  stripePaymentIntentId: 'pi_1',
  stripeCheckoutSessionId: null,
  total: 12,
  serviceFee: 1,
  restaurant: { ownerId: 'owner1' },
};

beforeEach(() => {
  calls = [];
  resetStaleOrderThrottle();
  handlers = {
    'order.findMany': () => [staleOrder],
    'notification.create': (a) => ({ id: 'n', ...a.data }),
    'deviceToken.findMany': () => [],
    'restaurantStaff.findMany': () => [],
  };
});

test('deadline query: 15 min after payment, or after group submission', () => {
  const now = new Date('2026-11-09T12:00:00Z');
  const where = staleOrdersWhere({ restaurantId: 'r1' }, now) as any;
  assert.equal(where.status, 'PLACED');
  assert.equal(where.restaurantId, 'r1');
  const deadline = new Date('2026-11-09T11:45:00Z').getTime();
  assert.equal(where.OR[0].groupOrderId, null);
  assert.equal(where.OR[0].createdAt.lt.getTime(), deadline);
  assert.equal(where.OR[1].groupOrder.status, 'SUBMITTED');
  assert.equal(where.OR[1].groupOrder.submittedAt.lt.getTime(), deadline);
});

test('an expired order is cancelled and both sides are notified', async () => {
  handlers['order.updateMany'] = () => ({ count: 1 });
  const n = await expireUnacceptedOrders({ restaurantId: 'resto1' });
  assert.equal(n, 1);
  const claim = calls.find((c) => c.method === 'updateMany')!.args;
  assert.deepEqual(claim.where, { id: 'order_abc123', status: 'PLACED' });
  assert.equal(claim.data.status, 'CANCELLED');
  const notified = calls.filter((c) => c.model === 'notification').map((c) => c.args.data.userId);
  assert.deepEqual(notified, ['client1', 'owner1']);
});

test('if the restaurant accepted first, nothing is cancelled or sent', async () => {
  handlers['order.updateMany'] = () => ({ count: 0 });
  const n = await expireUnacceptedOrders({ userId: 'client1' });
  assert.equal(n, 0);
  assert.equal(calls.filter((c) => c.model === 'notification').length, 0);
});

test('sweeps are throttled per restaurant or customer', async () => {
  handlers['order.updateMany'] = () => ({ count: 1 });
  await expireUnacceptedOrders({ restaurantId: 'resto1' });
  calls = [];
  assert.equal(await expireUnacceptedOrders({ restaurantId: 'resto1' }), 0);
  assert.equal(calls.length, 0);
});

test('a database error never breaks the order list', async () => {
  handlers['order.findMany'] = () => { throw new Error('db down'); };
  assert.equal(await expireUnacceptedOrders({ userId: 'client2' }), 0);
});
