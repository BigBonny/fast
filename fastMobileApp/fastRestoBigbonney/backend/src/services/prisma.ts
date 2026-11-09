import { PrismaClient } from '@prisma/client';

function createClient() {
  return new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['error', 'warn'] : ['error'],
    // The restaurateur's base price reveals FAST's hidden markup. It is left
    // out of every query by default (menus, restaurants, order lines);
    // restaurant-side endpoints and price calculation opt back in with
    // `omit: MENU_ITEM_WITH_BASE_PRICE`.
    omit: { menuItem: { basePrice: true } },
  });
}

const globalForPrisma = globalThis as unknown as { prisma: ReturnType<typeof createClient> | undefined };

export const prisma = globalForPrisma.prisma ?? createClient();

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}

/** Prisma `omit` override for queries that need the base price. */
export const MENU_ITEM_WITH_BASE_PRICE = { basePrice: false } as const;
