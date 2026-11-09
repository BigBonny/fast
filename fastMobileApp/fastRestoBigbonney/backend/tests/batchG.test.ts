import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

process.env.JWT_SECRET = 'test-secret';
process.env.DATABASE_URL = 'postgresql://invalid:invalid@127.0.0.1:1/none';
process.env.STRIPE_SECRET_KEY = ''; // no Stripe: refunds become no-ops
process.env.FIREBASE_PROJECT_ID = '';
process.env.SENTRY_DSN = '';
process.env.SUPABASE_URL = '';
process.env.SUPABASE_SERVICE_ROLE_KEY = '';
process.env.FAST_ACCEPT_TIMEOUT_MIN = '15';
process.env.FAST_GROUP_ABANDON_MIN = '120';

const { prisma } = require('../src/services/prisma');
const {
  expireUnacceptedOrders,
  staleOrdersWhere,
  resetStaleOrderThrottle,
} = require('../src/services/staleOrders');
const { reportReview, REVIEW_HIDE_THRESHOLD } = require('../src/controllers/reviews.controller');
const { restaurantRevenue, parisDayKey } = require('../src/controllers/stats.controller');
const { loginThrottleKeys } = require('../src/controllers/auth.controller');
const { signUpload } = require('../src/controllers/uploads.controller');
const { supplementSchema } = require('../src/utils/validation');
const { PostgresRateLimitStore } = require('../src/services/rateLimitStore');

type Call = { model: string; method: string; args: any };
let calls: Call[] = [];
let handlers: Record<string, (args: any) => unknown> = {};
const MODELS = [
  'order', 'notification', 'deviceToken', 'restaurantStaff', 'groupOrder',
  'paymentCheckout', 'review', 'reviewReport', 'restaurant', 'rateLimit',
];
for (const name of MODELS) {
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
Object.defineProperty(prisma, '$queryRaw', {
  configurable: true,
  value: async (strings: TemplateStringsArray, ...values: unknown[]) => {
    calls.push({ model: '$queryRaw', method: 'raw', args: values });
    return handlers['$queryRaw'](values) as unknown;
  },
});

function mockRes() {
  const res: any = { statusCode: 200, body: undefined };
  res.status = (c: number) => { res.statusCode = c; return res; };
  res.json = (b: unknown) => { res.body = b; return res; };
  return res;
}

beforeEach(() => {
  calls = [];
  resetStaleOrderThrottle();
  handlers = {
    'notification.create': (a) => ({ id: 'n', ...a.data }),
    'deviceToken.findMany': () => [],
    'restaurantStaff.findMany': () => [],
  };
});

// ── Unsent group orders ────────────────────────────────────────────────

const groupOrder = {
  id: 'order_grp001',
  userId: 'member1',
  restaurantId: 'resto1',
  paymentStatus: 'PAID',
  stripePaymentIntentId: 'pi_g',
  stripeCheckoutSessionId: null,
  total: 9,
  serviceFee: 1,
  restaurant: { ownerId: 'owner1' },
  groupOrder: { id: 'grp1', code: 'FAST-X', status: 'OPEN' },
};

test('sweep also covers groups never sent, after the group deadline', () => {
  const now = new Date('2026-11-09T12:00:00Z');
  const where = staleOrdersWhere({ userId: 'u' }, now) as any;
  const branch = where.OR[2];
  assert.deepEqual(branch.groupOrder.status.in, ['OPEN', 'LOCKED', 'CANCELLED']);
  assert.equal(branch.createdAt.lt.getTime(), new Date('2026-11-09T10:00:00Z').getTime());
});

test('an unsent group is closed, its paid share refunded, only the customer told', async () => {
  handlers['order.findMany'] = () => [groupOrder];
  handlers['groupOrder.updateMany'] = () => ({ count: 1 });
  handlers['order.updateMany'] = () => ({ count: 1 });
  assert.equal(await expireUnacceptedOrders({ userId: 'member1' }), 1);
  const close = calls.find((c) => c.model === 'groupOrder')!.args;
  assert.deepEqual(close.where.status, { in: ['OPEN', 'LOCKED'] });
  assert.equal(close.data.status, 'CANCELLED');
  const notified = calls.filter((c) => c.model === 'notification').map((c) => c.args.data.userId);
  assert.deepEqual(notified, ['member1']);
});

test('a group the host submitted meanwhile is left alone', async () => {
  handlers['order.findMany'] = () => [groupOrder];
  handlers['groupOrder.updateMany'] = () => ({ count: 0 });
  handlers['groupOrder.findUnique'] = () => ({ status: 'SUBMITTED' });
  assert.equal(await expireUnacceptedOrders({ userId: 'member1' }), 0);
  assert.equal(calls.filter((c) => c.model === 'order' && c.method === 'updateMany').length, 0);
});

// ── Review reports ─────────────────────────────────────────────────────

test('one report does not hide a review; the third distinct reporter does', async () => {
  let count = 1;
  handlers['review.findUnique'] = () => ({ id: 'rv', userId: 'author', restaurantId: 'r', isReported: false });
  handlers['reviewReport.upsert'] = () => ({});
  handlers['reviewReport.count'] = () => count;
  handlers['review.update'] = () => ({});
  handlers['review.aggregate'] = () => ({ _avg: { rating: 4 }, _count: 2 });
  handlers['restaurant.update'] = () => ({});

  const req: any = { params: { id: 'rv' }, user: { userId: 'reporter' } };
  await reportReview(req, mockRes());
  assert.equal(calls.filter((c) => c.model === 'review' && c.method === 'update').length, 0);

  count = REVIEW_HIDE_THRESHOLD;
  await reportReview(req, mockRes());
  const hide = calls.find((c) => c.model === 'review' && c.method === 'update')!;
  assert.equal(hide.args.data.isReported, true);
});

test('authors cannot report their own review', async () => {
  handlers['review.findUnique'] = () => ({ id: 'rv', userId: 'me', restaurantId: 'r', isReported: false });
  const res = mockRes();
  await reportReview({ params: { id: 'rv' }, user: { userId: 'me' } } as any, res);
  assert.equal(res.statusCode, 400);
});

// ── Stats ──────────────────────────────────────────────────────────────

test('restaurant revenue excludes FAST markup', () => {
  assert.equal(restaurantRevenue({ subtotal: 12, serviceFee: 1.5 }), 10.5);
  assert.equal(restaurantRevenue({ subtotal: 1, serviceFee: 3 }), 0);
});

test('days are counted in Paris time, not server time', () => {
  // 23:30 UTC on 9 Nov is already 10 Nov in Paris (UTC+1).
  assert.equal(parisDayKey(new Date('2026-11-09T23:30:00Z')), '2026-11-10');
  assert.equal(parisDayKey(new Date('2026-07-09T21:30:00Z')), '2026-07-09');
});

// ── Login throttle, supplements ───────────────────────────────────────

test('login throttle keys are per IP+account and per account, case-insensitive', () => {
  const a = loginThrottleKeys('Bob@Mail.com ', '1.2.3.4');
  const b = loginThrottleKeys('bob@mail.com', '1.2.3.4');
  assert.deepEqual(a, b);
  assert.notEqual(a.ipAccount, a.account);
  assert.notEqual(loginThrottleKeys('bob@mail.com', '5.6.7.8').ipAccount, a.ipAccount);
});

test('supplements need a name and a sane price', () => {
  assert.equal(supplementSchema.safeParse({ name: 'Fromage', price: '1.5' }).success, true);
  assert.equal(supplementSchema.safeParse({ name: '', price: 1 }).success, false);
  assert.equal(supplementSchema.safeParse({ name: 'X', price: -1 }).success, false);
  assert.equal(supplementSchema.safeParse({ name: 'X', price: 5000 }).success, false);
  assert.equal(supplementSchema.partial().safeParse({ price: 2 }).success, true);
});

// ── Direct uploads ─────────────────────────────────────────────────────

test('upload signing checks type and size, and says when storage is off', async () => {
  let res = mockRes();
  await signUpload({ body: { contentType: 'application/pdf', size: 10 } } as any, res);
  assert.equal(res.statusCode, 400);

  res = mockRes();
  await signUpload({ body: { contentType: 'video/mp4', size: 41 * 1024 * 1024 } } as any, res);
  assert.equal(res.statusCode, 413);

  res = mockRes();
  await signUpload({ body: { contentType: 'video/mp4', size: 20 * 1024 * 1024 } } as any, res);
  assert.equal(res.statusCode, 501); // no Supabase in tests → client falls back
});

// ── Shared rate-limit store ───────────────────────────────────────────

test('rate-limit store counts in Postgres under its prefix', async () => {
  handlers['$queryRaw'] = () => [{ hits: 3, resetAt: new Date('2030-01-01') }];
  handlers['rateLimit.deleteMany'] = () => ({ count: 0 });
  const store = new PostgresRateLimitStore('cred:');
  store.init({ windowMs: 60_000 } as any);
  const info = await store.increment('1.2.3.4');
  assert.equal(info.totalHits, 3);
  const raw = calls.find((c) => c.model === '$queryRaw')!;
  assert.equal(raw.args[0], 'cred:1.2.3.4');
  assert.equal(store.localKeys, false);
});
