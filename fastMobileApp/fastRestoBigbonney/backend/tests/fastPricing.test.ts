import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeFastPrice } from '../src/utils/fastPricing';

// Run with: npx tsx --test tests/fastPricing.test.ts
const cases: Array<[number, number]> = [
  [8, 9.0],
  [9.99, 11.24],
  [10, 11.0],
  [12, 13.2],
  [14.99, 16.49],
  [15, 16.05],
  [20, 21.4],
  [25, 26.75],
  [25.01, 26.26],
  [40, 42.0],
  [100, 105.0],
  [100.01, 102.01],
  [500, 510.0],
  [500.01, 505.01],
  [1000, 1010.0],
  [1000.01, 1005.01],
  [5000, 5025.0],
];

for (const [base, expected] of cases) {
  test(`computeFastPrice: base ${base} -> ${expected}`, () => {
    const got = computeFastPrice(base);
    assert.ok(
      Math.abs(got - expected) < 0.005,
      `expected ${expected}, got ${got}`,
    );
  });
}
