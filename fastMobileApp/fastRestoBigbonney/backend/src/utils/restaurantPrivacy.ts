/**
 * Restaurant fields that only the owner may see: banking, owner identity,
 * Stripe Connect state and the staff invite code. Never send these to
 * customers or to staff accounts.
 */
export const RESTAURANT_OWNER_ONLY_FIELDS = [
  'managerIban',
  'ownerBirthDate',
  'ownerAddress',
  'stripeAccountId',
  'stripeChargesEnabled',
  'stripePayoutsEnabled',
  'payoutFrequency',
  'staffInviteCode',
] as const;

type OwnerOnlyField = (typeof RESTAURANT_OWNER_ONLY_FIELDS)[number];

/** Prisma `omit` clause for including a restaurant in non-owner responses. */
export const restaurantPrivateOmit = Object.fromEntries(
  RESTAURANT_OWNER_ONLY_FIELDS.map((f) => [f, true]),
) as { [K in OwnerOnlyField]: true };

/** Returns a copy of `restaurant` without the owner-only fields. */
export function stripOwnerOnlyFields<T extends Record<string, unknown>>(
  restaurant: T,
): Omit<T, OwnerOnlyField> {
  const result: Record<string, unknown> = { ...restaurant };
  for (const key of RESTAURANT_OWNER_ONLY_FIELDS) delete result[key];
  return result as Omit<T, OwnerOnlyField>;
}
