import { test } from 'node:test';
import assert from 'node:assert/strict';
import { normalizeOcrItems, parseOcrResponse } from '../src/utils/menuOcr';

test('OCR accepts decimal commas and euro suffixes without inventing prices', () => {
  const items = normalizeOcrItems([
    { name: 'Burger', price: '12,50 euros' },
    { name: 'Pizza', price: '15.00€', category: null },
    { name: 'Unreadable', price: '12 or 15' },
    { name: 'Invalid', price: -1 },
    { name: 123, price: 12 },
    null,
  ]);
  assert.deepEqual(items.map(item => item.price), [12.5, 15]);
  assert.equal(items[1].category, '');
});

test('invalid OCR duplicate does not hide a later valid dish', () => {
  const items = normalizeOcrItems([
    { name: 'Café', price: 'unknown' },
    { name: ' Café ', price: 3 },
    { name: 'cafe', price: 3 },
  ]);
  assert.equal(items.length, 1);
  assert.equal(items[0].price, 3);
});

test('OCR parses fenced JSON and rejects malformed provider output', () => {
  assert.equal(parseOcrResponse('```json\n{"items":[{"name":"Burger","price":12}]}\n```').length, 1);
  assert.equal(parseOcrResponse('[{"name":"Pizza","price":15}]').length, 1);
  assert.throws(() => parseOcrResponse('{"items":"not an array"}'));
});
