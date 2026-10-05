import { createMenuItemSchema } from './validation';

export interface ScannedMenuItem {
  name: string;
  price: number;
  category: string;
  description: string;
}

const schema = createMenuItemSchema.pick({ name: true, price: true, category: true, description: true });

export function normalizeOcrItems(raw: unknown): ScannedMenuItem[] {
  if (!Array.isArray(raw)) throw new Error('Invalid OCR item list');
  const seen = new Set<string>();
  const items: ScannedMenuItem[] = [];
  for (const row of raw) {
    if (!row || typeof row !== 'object') continue;
    const data = row as Record<string, unknown>;
    let price = data.price;
    if (typeof price === 'string') {
      const value = price.replace(/\s/g, '').replace(/euros?|eur|€/gi, '');
      price = /^\d+(?:[.,]\d{1,2})?$/.test(value) ? Number(value.replace(',', '.')) : NaN;
    }
    const result = schema.safeParse({
      name: typeof data.name === 'string' ? data.name.trim() : '',
      price,
      category: typeof data.category === 'string' ? data.category.trim() : '',
      description: typeof data.description === 'string' ? data.description.trim() : '',
    });
    if (!result.success) continue;
    const key = result.data.name.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/\s+/g, ' ');
    if (seen.has(key)) continue;
    seen.add(key);
    items.push(result.data as ScannedMenuItem);
  }
  return items;
}

export function parseOcrResponse(content: string): ScannedMenuItem[] {
  const data = JSON.parse(content.trim().replace(/^```(?:json)?\s*|\s*```$/g, ''));
  return normalizeOcrItems(Array.isArray(data) ? data : data?.items);
}
