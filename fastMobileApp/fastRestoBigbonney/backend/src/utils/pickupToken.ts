import { randomBytes } from 'crypto';

export function generatePickupToken(): string {
  return `FAST-${randomBytes(16).toString('hex')}`;
}

// Short human-readable alternative to the QR token — e.g. "3F9K-FAST".
// Deterministic from the token so no extra column is needed.
export function pickupCodeFromToken(token: string): string {
  let hash = 0;
  for (const c of token) hash = (hash * 31 + c.charCodeAt(0)) >>> 0;
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 4; i++) {
    code += alphabet[(hash >>> (i * 8)) % alphabet.length];
  }
  return `${code}-FAST`;
}

/** Normalise what a cashier types: " 3f9k fast " / "3F9K" → "3F9K-FAST". */
export function normalizePickupCode(input: string): string {
  const raw = input.toUpperCase().replace(/[^A-Z0-9]/g, '');
  // Only strip the suffix when something precedes it — "FAST" alone is a
  // valid 4-letter core.
  const core = raw.length > 4 && raw.endsWith('FAST') ? raw.slice(0, -4) : raw;
  return `${core}-FAST`;
}

/** Matches either the full QR token or the short typed code. */
export function pickupTokenMatches(storedToken: string | null, input: string): boolean {
  if (!storedToken || !input.trim()) return false;
  if (storedToken === input.trim()) return true;
  return pickupCodeFromToken(storedToken) === normalizePickupCode(input);
}
