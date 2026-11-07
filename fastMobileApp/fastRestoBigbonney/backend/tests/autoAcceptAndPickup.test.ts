import { test } from 'node:test';
import assert from 'node:assert/strict';

const { shouldAutoAccept, parisClock, prepMinutesFor } = require('../src/utils/autoAccept');
const {
  generatePickupToken,
  pickupCodeFromToken,
  normalizePickupCode,
  pickupTokenMatches,
} = require('../src/utils/pickupToken');

// 2026-11-09 is a Monday. Paris is UTC+1 in November.
const paris = (hhmm: string, day = '09') => new Date(`2026-11-${day}T${hhmm}:00+01:00`);

test('Paris clock is used, not server UTC', () => {
  const c = parisClock(new Date('2026-11-09T21:45:00Z')); // 22:45 Paris
  assert.equal(c.isoDay, 1);
  assert.equal(c.minutes, 22 * 60 + 45);
});

test('missing / empty / unreadable hours → auto-accept', () => {
  assert.equal(shouldAutoAccept(null, paris('12:00')), true);
  assert.equal(shouldAutoAccept({}, paris('12:00')), true);
  assert.equal(shouldAutoAccept({ '1': '' }, paris('12:00')), true);
  assert.equal(shouldAutoAccept({ '1': 'n/a' }, paris('12:00')), true);
});

test('open well before closing → auto-accept', () => {
  assert.equal(shouldAutoAccept({ '1': '09:00-22:00' }, paris('12:00')), true);
  assert.equal(shouldAutoAccept({ '1': '09:00-22:00' }, paris('21:29')), true);
});

test('within 30 min of closing → manual', () => {
  assert.equal(shouldAutoAccept({ '1': '09:00-22:00' }, paris('21:30')), false);
  assert.equal(shouldAutoAccept({ '1': '09:00-22:00' }, paris('21:55')), false);
});

test('closed day or outside hours → manual', () => {
  assert.equal(shouldAutoAccept({ '1': 'closed' }, paris('12:00')), false);
  assert.equal(shouldAutoAccept({ '1': '09:00-22:00' }, paris('23:00')), false);
  assert.equal(shouldAutoAccept({ '1': '09:00-22:00' }, paris('08:00')), false);
});

test('split shifts', () => {
  const h = { '1': '11:00-14:00,18:00-23:00' };
  assert.equal(shouldAutoAccept(h, paris('12:00')), true);
  assert.equal(shouldAutoAccept(h, paris('13:45')), false);
  assert.equal(shouldAutoAccept(h, paris('16:00')), false);
  assert.equal(shouldAutoAccept(h, paris('19:00')), true);
});

test('overnight hours, including spill-over from the previous day', () => {
  const h = { '1': '18:00-02:00', '2': '18:00-02:00', '7': '18:00-02:00' };
  assert.equal(shouldAutoAccept(h, paris('23:00')), true);
  assert.equal(shouldAutoAccept(h, paris('00:30', '10')), true); // Tue 00:30, Mon's shift
  assert.equal(shouldAutoAccept(h, paris('01:45', '10')), false); // 15 min before 02:00
});

test('prep time = slowest dish, else restaurant default', () => {
  const r = { isRushMode: false, rushPrepTime: 20, normalPrepTime: 12 };
  assert.equal(prepMinutesFor(r, []), 12);
  assert.equal(
    prepMinutesFor(r, [{ menuItem: { prepTime: 8, prepTimeRush: 0 } }, { menuItem: { prepTime: 15, prepTimeRush: 0 } }]),
    15,
  );
  assert.equal(prepMinutesFor({ ...r, isRushMode: true }, [{ menuItem: { prepTime: 0, prepTimeRush: 0 } }]), 20);
});

test('pickup code format and matching', () => {
  const token = generatePickupToken();
  const code = pickupCodeFromToken(token);
  assert.match(code, /^[A-HJKMNP-Z2-9]{4}-FAST$/);
  assert.equal(pickupTokenMatches(token, token), true); // QR
  assert.equal(pickupTokenMatches(token, code), true); // typed
  assert.equal(pickupTokenMatches(token, code.toLowerCase()), true);
  assert.equal(pickupTokenMatches(token, code.slice(0, 4)), true); // suffix omitted
  assert.equal(pickupTokenMatches(token, ` ${code.slice(0, 4)} fast `), true);
  assert.equal(pickupTokenMatches(token, 'ZZZZ-FAST') && code !== 'ZZZZ-FAST', false);
  assert.equal(pickupTokenMatches(null, code), false);
  assert.equal(pickupTokenMatches(token, ''), false);
});

test('"FAST" alone is a valid core, not an empty code', () => {
  assert.equal(normalizePickupCode('FAST'), 'FAST-FAST');
  assert.equal(normalizePickupCode('fast-fast'), 'FAST-FAST');
});

// Must stay byte-identical to lib/models.dart pickupCodeFromToken.
test('known vector shared with the Flutter implementation', () => {
  assert.equal(pickupCodeFromToken('FAST-0123456789abcdef0123456789abcdef'), KNOWN_VECTOR);
});
const KNOWN_VECTOR = 'E2AH-FAST';
