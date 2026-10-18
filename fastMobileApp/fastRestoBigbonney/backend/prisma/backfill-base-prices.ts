/**
 * One-time data fix: menu items created before the FAST pricing grid have
 * `basePrice = NULL` and their stored `price` IS the restaurant's base
 * price. Customers therefore see the unmarked-up price.
 *
 * For each such item: basePrice <- current price, price <- FAST-marked-up
 * price. Idempotent — items that already have a basePrice are skipped.
 *
 * Run: npx tsx prisma/backfill-base-prices.ts
 */
import { prisma } from '../src/services/prisma';
import { computeFastPrice } from '../src/utils/fastPricing';

async function main() {
  const items = await prisma.menuItem.findMany({
    where: { basePrice: null },
    select: { id: true, name: true, price: true },
  });

  console.log(`Found ${items.length} menu item(s) without basePrice`);

  for (const item of items) {
    const base = item.price;
    const marked = computeFastPrice(base);
    await prisma.menuItem.update({
      where: { id: item.id },
      data: { basePrice: base, price: marked },
    });
    console.log(`  ${item.name}: base ${base.toFixed(2)} -> client ${marked.toFixed(2)}`);
  }

  console.log('Backfill complete.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
