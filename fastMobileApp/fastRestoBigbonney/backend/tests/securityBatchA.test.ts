import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';

process.env.JWT_SECRET ??= 'test-secret';

const {
  RESTAURANT_OWNER_ONLY_FIELDS,
  restaurantPrivateOmit,
  stripOwnerOnlyFields,
} = require('../src/utils/restaurantPrivacy');
const { generateInviteCode, isLegacyInviteCode } = require('../src/controllers/staff.controller');
const { isGoogleEmailVerified } = require('../src/controllers/auth.controller');
const { registerSchema } = require('../src/utils/validation');
const { isValidStatusTransition } = require('../src/utils/orderStatus');

// ─── Owner-only restaurant fields ───────────────────────────

test('owner-only restaurant fields are stripped for non-owners', () => {
  const row = {
    id: 'r1',
    name: 'Chez Test',
    managerIban: 'FR7600000000000000000000000',
    ownerBirthDate: '1990-01-01',
    ownerAddress: '1 rue Privée',
    stripeAccountId: 'acct_123',
    stripeChargesEnabled: true,
    stripePayoutsEnabled: true,
    payoutFrequency: 'daily',
    staffInviteCode: 'FAST-ABCD-EFGH',
  };
  const out = stripOwnerOnlyFields(row);
  assert.deepEqual(out, { id: 'r1', name: 'Chez Test' });
  assert.equal(row.managerIban, 'FR7600000000000000000000000', 'input not mutated');
});

test('Prisma omit clause covers every owner-only field', () => {
  assert.deepEqual(
    Object.keys(restaurantPrivateOmit).sort(),
    [...RESTAURANT_OWNER_ONLY_FIELDS].sort(),
  );
  for (const v of Object.values(restaurantPrivateOmit)) assert.equal(v, true);
});

// ─── Staff invite codes ─────────────────────────────────────

test('invite codes are FAST-XXXX-XXXX from an unambiguous alphabet', () => {
  const seen = new Set<string>();
  for (let i = 0; i < 500; i++) {
    const code = generateInviteCode();
    assert.match(code, /^FAST-[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{4}$/);
    assert.ok(code.length <= 20, 'fits redeemCodeSchema max length');
    seen.add(code);
  }
  assert.ok(seen.size > 495, 'codes are random, not repeating');
});

test('legacy 4-digit invite codes are recognised', () => {
  assert.equal(isLegacyInviteCode('FAST-1234'), true);
  assert.equal(isLegacyInviteCode('FAST-ABCD-EFGH'), false);
  assert.equal(isLegacyInviteCode(null), false);
  assert.equal(isLegacyInviteCode(''), false);
});

// ─── Registration roles ─────────────────────────────────────

test('email registration rejects LIVREUR and privileged roles', () => {
  const base = { email: 'a@b.fr', password: 'Str0ng!Passw0rd', name: 'A' };
  for (const role of ['LIVREUR', 'ADMIN', 'STAFF', 'GUEST']) {
    assert.equal(registerSchema.safeParse({ ...base, role }).success, false, role);
  }
  assert.equal(registerSchema.safeParse({ ...base, role: 'RESTAURANT' }).success, true);
  assert.equal(registerSchema.parse(base).role, 'CLIENT');
});

// ─── Google sign-in ─────────────────────────────────────────

test('Google sign-in requires a verified email', () => {
  assert.equal(isGoogleEmailVerified({ email_verified: 'true' }), true);
  assert.equal(isGoogleEmailVerified({ email_verified: true }), true);
  assert.equal(isGoogleEmailVerified({ email_verified: 'false' }), false);
  assert.equal(isGoogleEmailVerified({ email_verified: false }), false);
  assert.equal(isGoogleEmailVerified({}), false);
});

// ─── Order status transitions ───────────────────────────────

test('same-status transitions are not valid transitions', () => {
  for (const s of ['PLACED', 'PREPARING', 'READY_FOR_PICKUP', 'COMPLETED', 'CANCELLED']) {
    assert.equal(isValidStatusTransition(s, s), false, s);
  }
  assert.equal(isValidStatusTransition('PLACED', 'PREPARING'), true);
  assert.equal(isValidStatusTransition('COMPLETED', 'PREPARING'), false);
});

// ─── Route mounting order ───────────────────────────────────

test('refund routes are mounted before order routes', () => {
  // ordersRoutes has GET /:id, which would swallow GET /refund-requests.
  // Checked on the source so the test doesn't boot the app (and its .env).
  const src = readFileSync(path.join(__dirname, '../src/app.ts'), 'utf8');
  const refunds = src.indexOf("app.use('/api/orders', refundRoutes)");
  const orders = src.indexOf("app.use('/api/orders', ordersRoutes)");
  assert.ok(refunds !== -1 && orders !== -1);
  assert.ok(refunds < orders);
});
