import { test } from 'node:test';
import assert from 'node:assert/strict';

process.env.JWT_SECRET = 'test-secret';
process.env.DATABASE_URL = 'postgresql://invalid:invalid@127.0.0.1:1/none';

const { loyaltyCardState, loyaltyOrdersWhere } = require('../src/services/loyalty');
const { updateRestaurantSchema } = require('../src/utils/validation');

test('card progress counts orders towards the threshold', () => {
  assert.deepEqual(loyaltyCardState(7, 0, 10), {
    stamps: 7,
    remaining: 3,
    rewardAvailable: false,
  });
});

test('reward becomes available at the threshold and stamps stay capped', () => {
  assert.deepEqual(loyaltyCardState(10, 0, 10), {
    stamps: 10,
    remaining: 0,
    rewardAvailable: true,
  });
  assert.equal(loyaltyCardState(13, 0, 10).stamps, 10);
});

test('a new card starts after the reward is used, keeping extra orders', () => {
  assert.deepEqual(loyaltyCardState(12, 10, 10), {
    stamps: 2,
    remaining: 8,
    rewardAvailable: false,
  });
});

test('refunds after a redemption never produce negative progress', () => {
  // 10 orders redeemed, then one of them refunded: 9 eligible, 10 spent.
  assert.deepEqual(loyaltyCardState(9, 10, 10), {
    stamps: 0,
    remaining: 10,
    rewardAvailable: false,
  });
});

test('only paid, completed orders since activation earn a stamp', () => {
  const since = new Date('2026-11-01T00:00:00Z');
  const where = loyaltyOrdersWhere('u1', 'r1', since);
  assert.equal(where.status, 'COMPLETED');
  assert.deepEqual(where.paymentStatus, { in: ['PAID', 'REFUND_REJECTED'] });
  assert.deepEqual(where.createdAt, { gte: since });
  assert.equal(loyaltyOrdersWhere('u1', 'r1', null).createdAt, undefined);
});

test('loyalty settings are validated', () => {
  assert.ok(updateRestaurantSchema.safeParse({ loyaltyEnabled: true, loyaltyThreshold: 10, loyaltyReward: 'Un menu offert' }).success);
  assert.ok(!updateRestaurantSchema.safeParse({ loyaltyThreshold: 1 }).success);
  assert.ok(!updateRestaurantSchema.safeParse({ loyaltyThreshold: 51 }).success);
  assert.ok(!updateRestaurantSchema.safeParse({ loyaltyReward: 'x'.repeat(81) }).success);
});
