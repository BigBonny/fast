import { test } from 'node:test';
import assert from 'node:assert/strict';

process.env.JWT_SECRET ??= 'test-secret';
const { codesMatch, hashEmailCode } = require('../src/controllers/auth.controller');
const { emailVerifySchema } = require('../src/utils/validation');
const { verificationEmail } = require('../src/services/mailer');

test('email codes are hashed per account', () => {
  const a = hashEmailCode('user-a', '123456');
  assert.equal(a, hashEmailCode('user-a', '123456'));
  assert.notEqual(a, hashEmailCode('user-b', '123456'));
  assert.notEqual(a, hashEmailCode('user-a', '123457'));
  assert.doesNotMatch(a, /123456/);
});

test('codesMatch compares exactly, including different lengths', () => {
  assert.equal(codesMatch('123456', '123456'), true);
  assert.equal(codesMatch('123456', '123457'), false);
  assert.equal(codesMatch('123456', '12345'), false);
  assert.equal(codesMatch('', ''), true);
});

test('email verify schema only accepts 6 digits', () => {
  assert.equal(emailVerifySchema.safeParse({ code: ' 123456 ' }).success, true);
  for (const code of ['12345', '1234567', 'abcdef', '12 456', '']) {
    assert.equal(emailVerifySchema.safeParse({ code }).success, false, code);
  }
});

test('verification email carries the code in both parts', () => {
  const mail = verificationEmail('482913');
  assert.match(mail.subject, /482913/);
  assert.match(mail.html, /482913/);
  assert.match(mail.text, /482913/);
});
