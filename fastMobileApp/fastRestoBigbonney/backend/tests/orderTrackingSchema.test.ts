import { test } from 'node:test';
import assert from 'node:assert/strict';

const { updateOrderTrackingSchema, verifyPickupSchema } = require('../src/utils/validation');

// The app reports walk progress as a 0-100 percentage — a 0-1 bound here
// silently rejected every real tracking update (restaurant ETA never moved).
test('tracking accepts the percent values the app actually sends', () => {
  for (const pct of [0, 1, 37.5, 92, 100]) {
    const parsed = updateOrderTrackingSchema.parse({ gpsProgress: pct });
    assert.equal(parsed.gpsProgress, pct);
  }
});

test('tracking rejects out-of-range and empty payloads', () => {
  assert.throws(() => updateOrderTrackingSchema.parse({ gpsProgress: 101 }));
  assert.throws(() => updateOrderTrackingSchema.parse({ gpsProgress: -1 }));
  assert.throws(() => updateOrderTrackingSchema.parse({}));
});

// The app sends `pickupToken`; older payloads used `token` — both must
// verify, and neither being present must fail.
test('verify-pickup accepts the app payload (pickupToken)', () => {
  const parsed = verifyPickupSchema.parse({ pickupToken: 'abc123' });
  assert.equal(parsed.pickupToken, 'abc123');
});

test('verify-pickup still accepts token and rejects missing', () => {
  assert.equal(verifyPickupSchema.parse({ token: 'abc' }).token, 'abc');
  assert.throws(() => verifyPickupSchema.parse({}));
  assert.throws(() => verifyPickupSchema.parse({ token: '', pickupToken: '' }));
});
