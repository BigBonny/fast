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
