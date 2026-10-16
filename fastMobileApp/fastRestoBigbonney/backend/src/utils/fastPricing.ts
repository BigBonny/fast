/**
 * FAST markup grid (cahier des charges F03 + annexe tarification).
 * Deterministic — the AI never decides the final price; the restaurateur
 * enters the base price and this produces the customer-facing FAST price.
 *
 * Tiers (applied once, on the BASE price only):
 *   [0, 10[      -> +12.5%
 *   [10, 15[     -> +10%
 *   [15, 25]     -> +7%
 *   ]25, 100]    -> +5%
 *   ]100, 500]   -> +2%
 *   ]500, 1000]  -> +1%
 *   >1000        -> +0.5%  (grid defines up to 5000; same rate kept above)
 */
export function computeFastPrice(basePrice: number): number {
  if (!Number.isFinite(basePrice) || basePrice <= 0) return basePrice;
  const rate =
    basePrice < 10 ? 0.125 :
    basePrice < 15 ? 0.10 :
    basePrice <= 25 ? 0.07 :
    basePrice <= 100 ? 0.05 :
    basePrice <= 500 ? 0.02 :
    basePrice <= 1000 ? 0.01 :
    0.005;
  return Math.round(basePrice * (1 + rate) * 100) / 100;
}

/**
 * Resolve the base price and final FAST price for a menu item payload.
 * The incoming `price`/`basePrice` is always treated as the BASE price —
 * never recompute a markup on an already-marked-up price.
 */
export function resolveFastPricing(input: {
  price?: number | null;
  basePrice?: number | null;
}): { basePrice: number; price: number } {
  const base = input.basePrice ?? input.price ?? 0;
  return { basePrice: base, price: computeFastPrice(base) };
}
