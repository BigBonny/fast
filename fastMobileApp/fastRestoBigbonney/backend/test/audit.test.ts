import { before, test } from 'node:test';
import assert from 'node:assert/strict';

const base = process.env.FAST_TEST_URL;
if (base && !/^http:\/\/(127\.0\.0\.1|localhost):\d+\/api$/.test(base)) {
  throw new Error('Audit tests require an isolated localhost API');
}
const tokens: Record<string, string> = {};
let restaurantId = '';

before(async () => {
  if (!base) return;
  for (const role of ['owner', 'guest', 'client']) {
    const response = await fetch(`${base}/auth/login`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: `${role}@audit.test`, password: 'AuditOnly123!' }),
    });
    assert.equal(response.status, 200);
    const body = await response.json() as any;
    tokens[role] = body.token;
    if (role === 'guest') restaurantId = body.user.restaurantId;
  }
});

async function get(path: string, role?: string) {
  return fetch(`${base}${path}`, { headers: role ? { Authorization: `Bearer ${tokens[role]}` } : {} });
}

test('guest cannot read restaurant orders or private account settings', { skip: !base }, async () => {
  for (const path of ['/orders/restaurant', '/restaurants/account/mine', '/stats', '/staff']) {
    assert.equal((await get(path, 'guest')).status, 403, path);
  }
});

test('guest session restore carries its restaurant assignment', { skip: !base }, async () => {
  const response = await get('/auth/me', 'guest');
  assert.equal(response.status, 200);
  const user = await response.json() as any;
  assert.equal(user.restaurantId, restaurantId);
  assert.equal(user.staffRole, 'GUEST');
});

test('managed menu includes sold-out dishes but stays restaurant-scoped', { skip: !base }, async () => {
  for (const role of ['owner', 'guest']) {
    const response = await get(`/menu/restaurant/${restaurantId}/manage`, role);
    assert.equal(response.status, 200);
    const items = await response.json() as any[];
    assert.ok(items.some(item => item.isAvailable === false));
  }
  assert.equal((await get(`/menu/restaurant/${restaurantId}/manage`, 'client')).status, 403);
  assert.equal((await get('/menu/restaurant/not-the-assigned-restaurant/manage', 'guest')).status, 403);
  const publicItems = await (await get(`/menu/restaurant/${restaurantId}`)).json() as any[];
  assert.ok(publicItems.every(item => item.isAvailable));
});

test('public restaurant responses omit bank and Stripe account fields', { skip: !base }, async () => {
  for (const path of ['/restaurants', `/restaurants/${restaurantId}`]) {
    const response = await get(path);
    assert.equal(response.status, 200);
    const body = await response.json() as any;
    for (const restaurant of Array.isArray(body) ? body : [body]) {
      for (const field of ['managerIban', 'stripeAccountId', 'stripePayoutsEnabled', 'payoutFrequency', 'ownerId']) {
        assert.equal(Object.hasOwn(restaurant, field), false, field);
      }
    }
  }
});

test('guest cannot edit dish price or preparation time', { skip: !base }, async () => {
  const items = await (await get(`/menu/restaurant/${restaurantId}`)).json() as any[];
  assert.ok(items.length);
  const response = await fetch(`${base}/menu/${items[0].id}`, {
    method: 'PATCH', headers: { Authorization: `Bearer ${tokens.guest}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ price: 99, prepTime: 99 }),
  });
  assert.equal(response.status, 403);
});
