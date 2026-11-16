import { test } from 'node:test';
import assert from 'node:assert/strict';

process.env.JWT_SECRET = 'test-secret';
process.env.DATABASE_URL = 'postgresql://invalid:invalid@127.0.0.1:1/none';
process.env.FIREBASE_PROJECT_ID = '';

const { restaurantChangeBlocker } = require('../src/controllers/groups.controller');
const { groupCravingSchema, groupRestaurantSchema } = require('../src/utils/validation');

test('the restaurant can change while the group is open and nobody pays', () => {
  assert.equal(restaurantChangeBlocker('OPEN', ['DRAFT', 'DRAFT']), null);
  assert.equal(restaurantChangeBlocker('OPEN', []), null);
});

test('a share being paid or paid freezes the restaurant', () => {
  assert.ok(restaurantChangeBlocker('OPEN', ['DRAFT', 'READY']));
  assert.ok(restaurantChangeBlocker('OPEN', ['PAID']));
});

test('a locked, submitted or cancelled group keeps its restaurant', () => {
  for (const status of ['LOCKED', 'SUBMITTED', 'COMPLETED', 'CANCELLED']) {
    assert.ok(restaurantChangeBlocker(status, ['DRAFT']), status);
  }
});

test('cravings are trimmed, bounded and may be cleared', () => {
  assert.equal(groupCravingSchema.parse({ craving: '  Pizza ' }).craving, 'Pizza');
  assert.equal(groupCravingSchema.parse({ craving: '' }).craving, '');
  assert.ok(!groupCravingSchema.safeParse({ craving: 'x'.repeat(41) }).success);
  assert.ok(!groupCravingSchema.safeParse({}).success);
  assert.ok(!groupRestaurantSchema.safeParse({ restaurantId: '' }).success);
});
