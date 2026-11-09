import type { Options, Store, ClientRateLimitInfo } from 'express-rate-limit';
import { prisma } from './prisma';

/**
 * Rate-limit counters kept in Postgres (table "RateLimit"), so a limit
 * holds across every Vercel instance. An in-memory counter only sees the
 * requests that land on its own instance, which makes it nearly useless
 * on serverless.
 *
 * Used for the sensitive limits only (login, sign-up, AI assistant, invite
 * codes): each check costs one small database round trip.
 */

type HitResult = { hits: number; resetAt: Date };

/** Counts one hit for `key` in a fixed window; returns the window's total. */
export async function hitRateLimit(key: string, windowMs: number): Promise<HitResult> {
  const now = new Date();
  const resetAt = new Date(now.getTime() + windowMs);
  const rows = await prisma.$queryRaw<Array<{ hits: number; resetAt: Date }>>`
    INSERT INTO "RateLimit" ("key", "hits", "resetAt")
    VALUES (${key}, 1, ${resetAt})
    ON CONFLICT ("key") DO UPDATE SET
      "hits" = CASE WHEN "RateLimit"."resetAt" <= ${now} THEN 1 ELSE "RateLimit"."hits" + 1 END,
      "resetAt" = CASE WHEN "RateLimit"."resetAt" <= ${now} THEN ${resetAt} ELSE "RateLimit"."resetAt" END
    RETURNING "hits", "resetAt"`;
  maybeCleanUp(now);
  return { hits: Number(rows[0].hits), resetAt: rows[0].resetAt };
}

/** Current count for `key` without adding a hit (0 once the window ended). */
export async function peekRateLimit(key: string): Promise<number> {
  const row = await prisma.rateLimit.findUnique({ where: { key } });
  if (!row || row.resetAt <= new Date()) return 0;
  return row.hits;
}

export async function resetRateLimit(key: string): Promise<void> {
  await prisma.rateLimit.deleteMany({ where: { key } });
}

// Expired rows are harmless (the next hit resets them) but would pile up.
let lastCleanup = 0;
function maybeCleanUp(now: Date): void {
  if (now.getTime() - lastCleanup < 60 * 60_000) return;
  lastCleanup = now.getTime();
  prisma.rateLimit
    .deleteMany({ where: { resetAt: { lt: new Date(now.getTime() - 60 * 60_000) } } })
    .catch((err) => console.error('[rateLimit] cleanup failed', err));
}

/** express-rate-limit store backed by the RateLimit table. */
export class PostgresRateLimitStore implements Store {
  private windowMs = 60_000;
  prefix: string;
  // Counters are shared by every instance, unlike the default memory store.
  localKeys = false;

  constructor(prefix: string) {
    this.prefix = prefix;
  }

  init(options: Options): void {
    this.windowMs = options.windowMs;
  }

  async get(key: string): Promise<ClientRateLimitInfo | undefined> {
    const row = await prisma.rateLimit.findUnique({ where: { key: this.prefix + key } });
    if (!row || row.resetAt <= new Date()) return undefined;
    return { totalHits: row.hits, resetTime: row.resetAt };
  }

  async increment(key: string): Promise<ClientRateLimitInfo> {
    const { hits, resetAt } = await hitRateLimit(this.prefix + key, this.windowMs);
    return { totalHits: hits, resetTime: resetAt };
  }

  async decrement(key: string): Promise<void> {
    await prisma.rateLimit.updateMany({
      where: { key: this.prefix + key, hits: { gt: 0 } },
      data: { hits: { decrement: 1 } },
    });
  }

  async resetKey(key: string): Promise<void> {
    await resetRateLimit(this.prefix + key);
  }
}
