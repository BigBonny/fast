import { test } from 'node:test';
import assert from 'node:assert/strict';
import { toE164 } from '../src/utils/phone';

test('French numbers typed any way become E.164', () => {
  for (const raw of ['0612345678', '06 12 34 56 78', '06.12.34.56.78', '06-12-34-56-78',
    '+33612345678', '+33 6 12 34 56 78', '0033612345678', '+33 0612345678', ' 06 12 34 56 78 ']) {
    assert.equal(toE164(raw), '+33612345678', raw);
  }
});

test('foreign E.164 numbers are kept', () => {
  assert.equal(toE164('+32 470 12 34 56'), '+32470123456');
  assert.equal(toE164('+216 98 123 456'), '+21698123456');
});

test('junk is rejected', () => {
  for (const raw of ['', null, undefined, '123', '0012', 'abcdefghij', '06123456', '+0612345678']) {
    assert.equal(toE164(raw), undefined, String(raw));
  }
});
