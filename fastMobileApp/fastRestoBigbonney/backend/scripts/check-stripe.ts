/**
 * Stripe configuration & connectivity check — non-destructive.
 *
 *   npx tsx scripts/check-stripe.ts            full config + API test
 *   npx tsx scripts/check-stripe.ts --accounts also list Connect accounts
 *
 * Verifies everything checkout depends on without creating charges:
 *   - key shape (sk_test vs sk_live) and mode consistency
 *   - authenticated API call (balance) → key actually works
 *   - checkout currency + success/cancel URLs
 *   - webhook signing secrets present
 *   - restaurants' Connect accounts: charges/payouts status vs stored flags
 */

import Stripe from 'stripe';
import { env } from '../src/config/env';
import { prisma } from '../src/services/prisma';

let failures = 0;
const ok = (msg: string) => console.log(`  ✅ ${msg}`);
const warn = (msg: string) => console.log(`  ⚠️  ${msg}`);
const fail = (msg: string) => {
  console.log(`  ❌ ${msg}`);
  failures++;
};

async function main() {
  const withAccounts = process.argv.includes('--accounts');

  console.log('— Key —');
  if (!env.stripeSecretKey) {
    fail('STRIPE_SECRET_KEY is empty');
    return;
  }
  const isLive = env.stripeSecretKey.startsWith('sk_live_');
  const isTest = env.stripeSecretKey.startsWith('sk_test_');
  if (isLive) ok(`live key (sk_live_…)`);
  else if (isTest) warn('test key (sk_test_…) — switch to sk_live_ for production');
  else fail('STRIPE_SECRET_KEY has an unexpected format');

  const stripe = new Stripe(env.stripeSecretKey);

  console.log('— API connectivity —');
  try {
    const balance = await stripe.balance.retrieve();
    const eur = balance.available.find((b) => b.currency === 'eur');
    ok(`authenticated — available balance: ${eur ? eur.amount / 100 : '?'} EUR`);
  } catch (e) {
    fail(`Stripe API call failed: ${(e as Error).message}`);
  }

  console.log('— Checkout —');
  ok(`currency: ${env.stripeCurrency}`);
  const urlOk = (u: string) => u.startsWith('https://') || u.startsWith('http://');
  urlOk(env.stripeSuccessUrl)
    ? ok(`success_url: ${env.stripeSuccessUrl}`)
    : fail(`STRIPE_SUCCESS_URL looks wrong: "${env.stripeSuccessUrl}"`);
  urlOk(env.stripeCancelUrl)
    ? ok(`cancel_url: ${env.stripeCancelUrl}`)
    : fail(`STRIPE_CANCEL_URL looks wrong: "${env.stripeCancelUrl}"`);

  console.log('— Webhooks —');
  env.stripeWebhookSecret?.startsWith('whsec_')
    ? ok('STRIPE_WEBHOOK_SECRET set')
    : warn('STRIPE_WEBHOOK_SECRET missing/malformed — payment confirmation relies on client callback only');
  env.stripeConnectWebhookSecret?.startsWith('whsec_')
    ? ok('STRIPE_CONNECT_WEBHOOK_SECRET set')
    : warn('STRIPE_CONNECT_WEBHOOK_SECRET missing — Connect onboarding status will not auto-refresh');

  console.log('— Restaurants & Stripe Connect —');
  const restaurants = await prisma.restaurant.findMany({
    select: {
      id: true,
      name: true,
      isActive: true,
      stripeAccountId: true,
      stripeChargesEnabled: true,
      stripePayoutsEnabled: true,
    },
  });
  if (restaurants.length === 0) warn('no restaurants in the database');
  for (const r of restaurants) {
    const label = `${r.name} ${r.isActive ? '' : '(inactive) '}`;
    if (!r.stripeAccountId) {
      warn(`${label}— no Connect account → customers CANNOT pay there`);
      continue;
    }
    if (!withAccounts) {
      r.stripeChargesEnabled
        ? ok(`${label}— connected (charges enabled)`)
        : warn(`${label}— account ${r.stripeAccountId} but charges disabled per DB flag`);
      continue;
    }
    try {
      const acct = await stripe.accounts.retrieve(r.stripeAccountId);
      const line = `${label}— ${acct.id}: charges=${acct.charges_enabled} payouts=${acct.payouts_enabled}`;
      acct.charges_enabled ? ok(line) : warn(`${line} (onboarding incomplete)`);
      if (acct.charges_enabled !== r.stripeChargesEnabled) {
        warn(`  ↳ stored flag stale — it self-heals on next checkout`);
      }
    } catch (e) {
      fail(`${label}— account lookup failed: ${(e as Error).message}`);
    }
  }

  console.log(failures === 0 ? '\nAll checks passed.' : `\n${failures} check(s) failed.`);
  process.exitCode = failures === 0 ? 0 : 1;
}

main()
  .catch((e) => {
    console.error('[Fatal]', e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
