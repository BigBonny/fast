import { test } from 'node:test';
import assert from 'node:assert/strict';

const { createMenuItemSchema, updateMenuItemSchema } = require('../src/utils/validation');

// The app sends the restaurateur's BASE price as `basePrice` — create
// must not require the `price` key.
test('create accepts the exact app payload (basePrice, no price)', () => {
  const parsed = createMenuItemSchema.parse({
    name: 'Burger test',
    description: 'desc',
    basePrice: 12.5,
    image: '',
    category: 'Burgers',
    prepTime: 0,
    prepTimeRush: 0,
    videoUrl: '',
    isAvailable: true,
    dietaryTags: [],
  });
  assert.equal(parsed.basePrice, 12.5);
  assert.equal(parsed.isAvailable, true);
});

test('create still accepts a price-only payload', () => {
  const parsed = createMenuItemSchema.parse({ name: 'X', price: 9.9 });
  assert.equal(parsed.price, 9.9);
});

test('create rejects when neither price nor basePrice is sent', () => {
  assert.throws(() => createMenuItemSchema.parse({ name: 'X' }));
});

test('all six dietary enum values are accepted', () => {
  const parsed = createMenuItemSchema.parse({
    name: 'X',
    basePrice: 5,
    dietaryTags: ['VEGAN', 'VEGETARIAN', 'GLUTEN_FREE', 'HALAL', 'KETO', 'DAIRY_FREE'],
  });
  assert.equal(parsed.dietaryTags.length, 6);
});

test('update stays fully partial — no price required on edit', () => {
  assert.doesNotThrow(() => updateMenuItemSchema.parse({ isAvailable: false }));
  assert.doesNotThrow(() => updateMenuItemSchema.parse({ name: 'Renamed' }));
});
