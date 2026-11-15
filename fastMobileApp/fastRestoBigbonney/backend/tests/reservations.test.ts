import { test } from 'node:test';
import assert from 'node:assert/strict';

process.env.JWT_SECRET = 'test-secret';
process.env.DATABASE_URL = 'postgresql://invalid:invalid@127.0.0.1:1/none';
process.env.FIREBASE_PROJECT_ID = '';

const {
  canRestaurantSetStatus,
  canClientCancel,
  reservationWhen,
} = require('../src/controllers/reservations.controller');

test('restaurant answers a pending request once', () => {
  assert.ok(canRestaurantSetStatus('PENDING', 'CONFIRMED'));
  assert.ok(canRestaurantSetStatus('PENDING', 'DECLINED'));
  assert.ok(!canRestaurantSetStatus('PENDING', 'CANCELLED'));
  assert.ok(!canRestaurantSetStatus('DECLINED', 'CONFIRMED'));
  assert.ok(!canRestaurantSetStatus('CANCELLED', 'CONFIRMED'));
});

test('restaurant can only cancel a table it confirmed', () => {
  assert.ok(canRestaurantSetStatus('CONFIRMED', 'CANCELLED'));
  assert.ok(!canRestaurantSetStatus('CONFIRMED', 'DECLINED'));
  assert.ok(!canRestaurantSetStatus('CONFIRMED', 'CONFIRMED'));
});

test('client cancels a pending or confirmed table that has not started', () => {
  const now = new Date('2026-11-15T18:00:00Z');
  const later = new Date('2026-11-15T20:00:00Z');
  const earlier = new Date('2026-11-15T12:00:00Z');
  assert.ok(canClientCancel('PENDING', later, now));
  assert.ok(canClientCancel('CONFIRMED', later, now));
  assert.ok(!canClientCancel('CONFIRMED', earlier, now));
  assert.ok(!canClientCancel('DECLINED', later, now));
  assert.ok(!canClientCancel('CANCELLED', later, now));
});

test('messages give the time in Paris, whatever the server timezone', () => {
  // 19:30 UTC in winter is 20:30 in Paris.
  assert.match(reservationWhen(new Date('2026-11-15T19:30:00Z')), /15\/11\/2026.*20:30/);
});
