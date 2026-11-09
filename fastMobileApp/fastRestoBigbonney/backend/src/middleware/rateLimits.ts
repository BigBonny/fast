import rateLimit, { ipKeyGenerator } from 'express-rate-limit';
import { PostgresRateLimitStore } from '../services/rateLimitStore';

/**
 * Limits that must hold across every serverless instance, so their
 * counters live in Postgres. If the database can't be reached the request
 * goes through (`passOnStoreError`): an outage must not lock everyone out.
 */
const shared = {
  standardHeaders: true,
  legacyHeaders: false,
  passOnStoreError: true,
} as const;

const ipKey = (req: { ip?: string }) => ipKeyGenerator(req.ip ?? '');

/** Login, sign-up, social sign-in and phone codes: per IP. */
export const credentialLimiter = rateLimit({
  ...shared,
  windowMs: 15 * 60_000,
  // Generous because mobile carriers put many people behind one IP; the
  // login itself also limits wrong passwords per IP and account.
  limit: 60,
  keyGenerator: ipKey,
  store: new PostgresRateLimitStore('cred:'),
  message: { error: 'Trop de tentatives. Réessayez dans 15 minutes.' },
});

/** Staff invite codes: per account, so one account can't spray guesses. */
export const redeemLimiter = rateLimit({
  ...shared,
  windowMs: 15 * 60_000,
  limit: 10,
  keyGenerator: (req) => req.user?.userId ?? ipKey(req),
  store: new PostgresRateLimitStore('redeem:'),
  message: { error: 'Trop de tentatives. Réessayez dans quelques minutes.' },
});

/**
 * AI assistant. It stays usable without an account (website visitors,
 * guests), so the cost is bounded by a per-visitor limit plus a global
 * daily ceiling on Gemini calls.
 */
export const assistantVisitorLimiter = rateLimit({
  ...shared,
  windowMs: 60 * 60_000,
  limit: 30,
  keyGenerator: (req) => (req.user?.userId ? `u:${req.user.userId}` : `ip:${ipKey(req)}`),
  store: new PostgresRateLimitStore('assistant:'),
  message: { error: "Limite de messages atteinte. Réessayez dans une heure." },
});

export const assistantDailyLimiter = rateLimit({
  ...shared,
  windowMs: 24 * 60 * 60_000,
  limit: Number(process.env.FAST_ASSISTANT_DAILY_LIMIT) || 3000,
  keyGenerator: () => 'global',
  store: new PostgresRateLimitStore('assistant-day:'),
  message: { error: "L'assistant est très sollicité aujourd'hui. Réessayez demain." },
});

/** Address suggestions (calls the free French BAN API): per IP. */
export const placesLimiter = rateLimit({
  ...shared,
  windowMs: 60 * 60_000,
  limit: 300,
  keyGenerator: ipKey,
  store: new PostgresRateLimitStore('places:'),
  message: { error: 'Trop de recherches. Réessayez plus tard.' },
});
