import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';

// Delivery is off unless FAST_DELIVERY_ENABLED=true. Isolate from .env.
process.env.FAST_DELIVERY_ENABLED = '';
process.env.JWT_SECRET = 'test-secret';
process.env.DATABASE_URL = 'postgresql://invalid:invalid@127.0.0.1:1/none';
process.env.SENTRY_DSN = '';

const { env } = require('../src/config/env');
const app = require('../src/app').default;

const server = app.listen(0);
const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
after(() => server.close());

test('delivery is off by default', () => {
  assert.equal(env.deliveryEnabled, false);
});

test('driver and delivery APIs answer 404 while delivery is off', async () => {
  for (const path of ['/api/deliveries/available', '/api/drivers/me']) {
    const res = await fetch(base + path, { headers: { 'x-forwarded-proto': 'https' }, redirect: 'manual' });
    assert.equal(res.status, 404, path);
  }
});
