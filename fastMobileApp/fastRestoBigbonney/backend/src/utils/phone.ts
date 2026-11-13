/**
 * Normalises a phone number to E.164 ("+33612345678"), which Twilio
 * requires. French national numbers are the default: "06 12 34 56 78",
 * "06.12.34.56.78" and "0033 6 12 34 56 78" all become "+33612345678".
 * Returns undefined when the input can't be a real number.
 *
 * SMS codes are stored and looked up under this form, so the same number
 * typed two different ways still matches its code.
 */
export function toE164(raw: string | null | undefined): string | undefined {
  let phone = (raw || '').replace(/[\s.\-()]/g, '');
  if (phone.startsWith('00')) phone = `+${phone.slice(2)}`;
  // "+33 0612…" — a national 0 kept after the country code.
  phone = phone.replace(/^\+330/, '+33');
  if (/^\+[1-9]\d{7,14}$/.test(phone)) return phone;
  if (/^0[1-9]\d{8}$/.test(phone)) return `+33${phone.slice(1)}`;
  return undefined;
}
