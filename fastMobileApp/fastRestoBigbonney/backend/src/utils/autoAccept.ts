// Auto-accept rules for paid orders. Restaurants enter opening hours in
// French local time ({"1": "11:00-14:00,18:00-23:00", "7": "closed"}, ISO
// weekday keys) while the server runs in UTC — always evaluate in Paris time.

const TIME_ZONE = 'Europe/Paris';
export const CLOSING_WINDOW_MIN = 30;
const WEEKDAYS: Record<string, number> = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };

export function parisClock(now: Date): { isoDay: number; minutes: number } {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: TIME_ZONE,
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? '';
  return {
    isoDay: WEEKDAYS[get('weekday')] ?? 1,
    minutes: Number(get('hour')) * 60 + Number(get('minute')),
  };
}

function parseRanges(value: string): Array<[number, number]> {
  const ranges: Array<[number, number]> = [];
  for (const chunk of value.split(',')) {
    const m = chunk.trim().match(/^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$/);
    if (!m) continue;
    const open = Number(m[1]) * 60 + Number(m[2]);
    let close = Number(m[3]) * 60 + Number(m[4]);
    if (close <= open) close += 1440; // overnight, e.g. 18:00-02:00
    ranges.push([open, close]);
  }
  return ranges;
}

/**
 * true  → accept automatically.
 * false → leave PLACED for the restaurant to decide (closed today, outside
 *         opening hours, or within 30 min of closing).
 * Missing or unreadable hours never block: auto-accept is the default.
 */
export function shouldAutoAccept(openingHours: unknown, now: Date = new Date()): boolean {
  if (!openingHours || typeof openingHours !== 'object' || Array.isArray(openingHours)) return true;
  const hours = openingHours as Record<string, unknown>;
  const { isoDay, minutes } = parisClock(now);

  // Yesterday's overnight range still running (e.g. Fri 18:00-02:00 at Sat 01:00).
  const yesterday = hours[String(isoDay === 1 ? 7 : isoDay - 1)];
  if (typeof yesterday === 'string') {
    for (const [, close] of parseRanges(yesterday)) {
      if (close > 1440 && minutes < close - 1440) {
        return close - 1440 - minutes > CLOSING_WINDOW_MIN;
      }
    }
  }

  const today = hours[String(isoDay)];
  if (typeof today !== 'string' || today.trim() === '') return true;
  if (today.trim().toLowerCase() === 'closed') return false;
  const ranges = parseRanges(today);
  if (ranges.length === 0) return true;

  for (const [open, close] of ranges) {
    if (minutes >= open && minutes < close) {
      return close - minutes > CLOSING_WINDOW_MIN;
    }
  }
  return false; // ordering outside opening hours — let a human decide
}

/** Prep time = slowest dish (they cook in parallel), else restaurant default. */
export function prepMinutesFor(
  restaurant: { isRushMode: boolean; rushPrepTime: number; normalPrepTime: number },
  items: Array<{ menuItem: { prepTime: number; prepTimeRush: number } | null }>,
): number {
  const isRush = restaurant.isRushMode;
  const fallback = isRush ? restaurant.rushPrepTime : restaurant.normalPrepTime;
  const times = items
    .map(({ menuItem: mi }) => {
      if (!mi) return 0;
      if (isRush) return mi.prepTimeRush > 0 ? mi.prepTimeRush : mi.prepTime;
      return mi.prepTime;
    })
    .filter((t) => t > 0);
  return times.length > 0 ? Math.max(...times) : fallback;
}
