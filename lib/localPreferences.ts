/**
 * Client-side persistence for user preferences that the backend does not expose
 * yet (addresses, notification opt-ins). Kept in one place so it is trivial to
 * swap for real API calls once those endpoints exist.
 */

const ADDRESSES_KEY = "fast_addresses";
const NOTIFICATION_PREFS_KEY = "fast_notification_prefs";

export interface Address {
  id: string;
  label: string;
  line: string;
  isDefault: boolean;
}

export interface NotificationPreferences {
  orderStatus: boolean;
  promotions: boolean;
  news: boolean;
}

export const defaultNotificationPreferences: NotificationPreferences = {
  orderStatus: true,
  promotions: false,
  news: true,
};

function read<T>(key: string, fallback: T): T {
  if (typeof window === "undefined") return fallback;
  try {
    const raw = window.localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch {
    return fallback;
  }
}

function write(key: string, value: unknown) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(key, JSON.stringify(value));
}

export function getAddresses(): Address[] {
  return read<Address[]>(ADDRESSES_KEY, []);
}

export function saveAddresses(addresses: Address[]) {
  write(ADDRESSES_KEY, addresses);
  return addresses;
}

export function addAddress(input: { label: string; line: string }): Address[] {
  const addresses = getAddresses();
  const address: Address = {
    id: `addr-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
    label: input.label.trim(),
    line: input.line.trim(),
    isDefault: addresses.length === 0,
  };
  return saveAddresses([...addresses, address]);
}

export function removeAddress(id: string): Address[] {
  const remaining = getAddresses().filter((a) => a.id !== id);
  // Never leave the list without a default entry.
  if (remaining.length > 0 && !remaining.some((a) => a.isDefault)) {
    remaining[0].isDefault = true;
  }
  return saveAddresses(remaining);
}

export function setDefaultAddress(id: string): Address[] {
  return saveAddresses(getAddresses().map((a) => ({ ...a, isDefault: a.id === id })));
}

export function getNotificationPreferences(): NotificationPreferences {
  return { ...defaultNotificationPreferences, ...read(NOTIFICATION_PREFS_KEY, {}) };
}

export function setNotificationPreference(
  key: keyof NotificationPreferences,
  value: boolean
): NotificationPreferences {
  const next = { ...getNotificationPreferences(), [key]: value };
  write(NOTIFICATION_PREFS_KEY, next);
  return next;
}
