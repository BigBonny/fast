import { test } from 'node:test';
import assert from 'node:assert/strict';

process.env.JWT_SECRET ??= 'test-secret';
const { selfServiceRole } = require('../src/controllers/auth.controller');

test('social sign-up cannot self-assign privileged roles', () => {
  for (const role of ['ADMIN', 'STAFF', 'GUEST', 'admin', '', null, undefined, 42, { role: 'ADMIN' }]) {
    assert.equal(selfServiceRole(role), 'CLIENT');
  }
});

test('social sign-up keeps the roles email registration allows', () => {
  assert.equal(selfServiceRole('CLIENT'), 'CLIENT');
  assert.equal(selfServiceRole('RESTAURANT'), 'RESTAURANT');
  assert.equal(selfServiceRole('LIVREUR'), 'LIVREUR');
});
