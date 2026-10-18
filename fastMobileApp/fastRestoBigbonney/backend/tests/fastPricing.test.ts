import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeFastPrice } from '../src/utils/fastPricing';

// Run with: npx tsx --test tests/fastPricing.test.ts
// Before / on / after every grid threshold: 10, 15, 25, 100, 500, 1000.
const cases: Array<[number, number]> = [
  [8, 9.0],
  [9.99, 11.24],
  [10, 11.0],
  [10.01, 11.01],
  [12, 13.2],
  [14.99, 16.49],
  [15, 16.05],
  [15.01, 16.06],
  [20, 21.4],
  [24.99, 26.74],
  [25, 26.75],
  [25.01, 26.26],
  [40, 42.0],
  [99.99, 104.99],
  [100, 105.0],
  [100.01, 102.01],
  [499.99, 509.99],
  [500, 510.0],
  [500.01, 505.01],
  [999.99, 1009.99],
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
