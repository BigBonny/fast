import { Request, Response } from 'express';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { prisma } from '../services/prisma';
import { createMenuItemSchema, updateMenuItemSchema } from '../utils/validation';
import { resolveFastPricing } from '../utils/fastPricing';
import { env } from '../config/env';
import { getRestaurantIdForUser } from '../middleware/auth';
import { parseOcrResponse } from '../utils/menuOcr';
import { uploadDir } from './uploads.controller';

export const listMenuItems = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = req.params.restaurantId as string;

  const items = await prisma.menuItem.findMany({
    where: { restaurantId, isAvailable: true },
    include: { dietaryTags: true, supplements: true },
    orderBy: { category: 'asc' },
  });

  res.json(items);
};

export const listManagedMenuItems = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = req.params.restaurantId as string;
  if (await getRestaurantIdForUser(req.user!) !== restaurantId) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }
  const items = await prisma.menuItem.findMany({
    where: { restaurantId },
    include: { dietaryTags: true, supplements: true },
    orderBy: [{ category: 'asc' }, { name: 'asc' }],
  });
  res.json(items);
};

export const createMenuItem = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = req.params.restaurantId as string;
  const data = createMenuItemSchema.parse(req.body);

  // Verify ownership or staff access
  const userRestaurantId = await getRestaurantIdForUser(req.user!);
  if (userRestaurantId !== restaurantId) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }

  // The restaurateur's price is the BASE price — the stored `price` is the
  // FAST-marked-up customer price. Computed deterministically, never by AI.
  const { price, basePrice } = resolveFastPricing(data);

  const item = await prisma.menuItem.create({
    data: {
      ...data,
      price,
      basePrice,
      restaurantId,
      dietaryTags: data.dietaryTags
        ? { create: data.dietaryTags.map((opt) => ({ option: opt as any })) }
        : undefined,
    },
    include: { dietaryTags: true, supplements: true },
  });

  res.status(201).json(item);
};

export const updateMenuItem = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const data = updateMenuItemSchema.parse(req.body);

  const item = await prisma.menuItem.findUnique({
    where: { id },
    include: { restaurant: true },
  });
  if (!item) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }
  const userRestaurantId = await getRestaurantIdForUser(req.user!);
  if (userRestaurantId !== item.restaurantId) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }

  // Guest staff can ONLY toggle availability (sold out) — every other
  // field is stripped so nothing else can be modified.
  const isGuest = req.user!.role === 'GUEST' || req.user!.staffRole === 'GUEST';
  const patchData: any = isGuest ? { isAvailable: data.isAvailable } : { ...data };
  // Recompute the FAST price only when the base price itself changes.
  if (!isGuest && (data.basePrice != null || data.price != null)) {
    const { price, basePrice } = resolveFastPricing(data);
    patchData.price = price;
    patchData.basePrice = basePrice;
  }
  if (isGuest && typeof data.isAvailable !== 'boolean') {
    res.status(403).json({ error: 'Accès invité : disponibilité uniquement' });
    return;
  }

  const updated = await prisma.menuItem.update({
    where: { id },
    data: {
      ...patchData,
      dietaryTags: !isGuest && data.dietaryTags
        ? {
            deleteMany: {},
            create: data.dietaryTags.map((opt) => ({ option: opt as any })),
          }
        : undefined,
    },
    include: { dietaryTags: true, supplements: true },
  });

  res.json(updated);
};

export const deleteMenuItem = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  const item = await prisma.menuItem.findUnique({
    where: { id },
    include: { restaurant: true },
  });
  if (!item) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }
  const userRestaurantId = await getRestaurantIdForUser(req.user!);
  if (userRestaurantId !== item.restaurantId) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }

  await prisma.menuItem.update({ where: { id }, data: { isAvailable: false } });
  res.json({ message: 'Article supprimé' });
};

// ─── Supplement CRUD ────────────────────────────────────────

export const addSupplement = async (req: Request, res: Response): Promise<void> => {
  const menuItemId = req.params.menuItemId as string;

  const item = await prisma.menuItem.findUnique({
    where: { id: menuItemId },
    include: { restaurant: true },
  });
  if (!item) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }
  const userRestaurantId = await getRestaurantIdForUser(req.user!);
  if (userRestaurantId !== item.restaurantId) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }

  const { name, price } = req.body as { name: string; price: number };
  if (!name || price == null) {
    res.status(400).json({ error: 'name et price requis' });
    return;
  }

  const supplement = await prisma.menuItemSupplement.create({
    data: { menuItemId, name, price: Number(price) },
  });
  res.status(201).json(supplement);
};

export const updateSupplement = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  const supplement = await prisma.menuItemSupplement.findUnique({
    where: { id },
    include: { menuItem: { include: { restaurant: true } } },
  });
  if (!supplement) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }
  const userRestaurantId = await getRestaurantIdForUser(req.user!);
  if (userRestaurantId !== (supplement as any).menuItem.restaurantId) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }

  const { name, price } = req.body as { name?: string; price?: number };
  const updated = await prisma.menuItemSupplement.update({
    where: { id },
    data: { name: name ?? supplement.name, price: price != null ? Number(price) : supplement.price },
  });
  res.json(updated);
};

export const deleteSupplement = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  const supplement = await prisma.menuItemSupplement.findUnique({
    where: { id },
    include: { menuItem: { include: { restaurant: true } } },
  });
  if (!supplement) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }
  const userRestaurantId = await getRestaurantIdForUser(req.user!);
  if (userRestaurantId !== (supplement as any).menuItem.restaurantId) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }

  await prisma.menuItemSupplement.delete({ where: { id } });
  res.json({ message: 'Supplément supprimé' });
};

// ─── OCR Menu Scanner ──────────────────────────────────────

// Gemini (free tier via Google AI Studio) — preferred when GEMINI_API_KEY is set.
// 'gemini-flash-lite-latest' is the default: it tracks the current lite model,
// has the largest free-tier capacity, and is far less prone to 503 overload
// than the flagship 'gemini-flash-latest' (which is kept as a retry).
const GEMINI_PRIMARY_MODEL = 'gemini-flash-lite-latest';
const GEMINI_RETRY_MODEL = 'gemini-flash-latest';

async function geminiGenerate(
  prompt: string,
  base64Image?: string,
  model: string = GEMINI_PRIMARY_MODEL,
): Promise<string> {
  const apiKey = env.geminiApiKey;
  if (!apiKey) throw new Error('GEMINI_API_KEY non configurée');

  const parts: Record<string, unknown>[] = [{ text: prompt }];
  if (base64Image) {
    const raw = base64Image.startsWith('data:')
      ? base64Image.split(',')[1]
      : base64Image;
    parts.push({
      inline_data: { mime_type: 'image/jpeg', data: raw },
    });
  }

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
    {
      method: 'POST',
      signal: AbortSignal.timeout(15000),
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts }],
        generationConfig: {
          temperature: 0,
          maxOutputTokens: 4000,
          responseMimeType: 'application/json',
        },
      }),
    },
  );

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Gemini ${model} error: ${response.status} ${errText.slice(0, 200)}`);
  }
  const data = (await response.json()) as any;
  // Concatenate all text parts — thinking models may emit several parts.
  const partsArr = data.candidates?.[0]?.content?.parts ?? [];
  return partsArr
    .map((p: any) => (typeof p.text === 'string' ? p.text : ''))
    .join('')
    .trim();
}

const menuPrompt = `
You are an expert menu digitizer.
Read the text from the provided restaurant menu image and extract all the dishes, their prices, and infer their categories (e.g. Entrées, Plats, Desserts, Boissons, Salades, Sandwichs).
If a description is present, extract it as well.

CRITICAL INSTRUCTIONS:
- ONLY extract items that are CLEARLY legible on the menu.
- DO NOT invent, hallucinate, or repeat items.
- If the menu is unreadable, return an empty array.

You MUST return a JSON object with a single key "items" which is an array of objects.
Each object must have exactly these keys:
- "name" (string)
- "price" (number, ignoring currency symbols)
- "category" (string)
- "description" (string, empty string if none)

Return ONLY valid JSON.
`;

async function parseMenuImageWithPixtral(base64Image: string): Promise<Array<{ name: string; price: number; category: string; description: string }>> {
  const apiKey = env.mistralApiKey;
  if (!apiKey) throw new Error('MISTRAL_API_KEY non configurée');

  const prompt = menuPrompt;

  // Use a data URI if not already formatted
  const imageUrl = base64Image.startsWith('data:') ? base64Image : `data:image/jpeg;base64,${base64Image}`;

  const response = await fetch("https://api.mistral.ai/v1/chat/completions", {
    method: "POST",
    signal: AbortSignal.timeout(15000),
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "mistral-small-latest",
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: prompt },
            { type: "image_url", image_url: imageUrl }
          ]
        }
      ],
      response_format: { type: "json_object" },
      temperature: 0.0,
      top_p: 1.0,
      max_tokens: 2000
    })
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Mistral API error: ${response.statusText} - ${errText}`);
  }

  const data = await response.json() as any;
  const content = data.choices[0].message.content;
  return parseOcrResponse(content);
}

export const scanMenu = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = req.params.restaurantId as string;

  // Verify restaurant ownership or staff access
  const userRestaurantId = await getRestaurantIdForUser(req.user!);
  if (userRestaurantId !== restaurantId) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }

  // Single photo (imageBase64) or several video frames (imagesBase64)
  const { imageBase64, imagesBase64 } = req.body as {
    imageBase64?: string;
    imagesBase64?: string[];
  };
  const images =
    Array.isArray(imagesBase64) && imagesBase64.length > 0
      ? imagesBase64.slice(0, 8) // cap payload — Vercel body limit is ~4.5MB
      : imageBase64
        ? [imageBase64]
        : [];
  if (images.length === 0 || images.some(image => typeof image !== 'string' || !image.trim())) {
    res.status(400).json({ error: 'imageBase64 requis' });
    return;
  }
  if (images.reduce((size, image) => size + image.length, 0) > 4000000) {
    res.status(413).json({ code: 'SCAN_IMAGE_TOO_LARGE', error: 'Images trop volumineuses.' });
    return;
  }
  if (!env.geminiApiKey && !env.mistralApiKey) {
    res.status(503).json({ code: 'SCAN_UNAVAILABLE', error: 'Le service de reconnaissance des menus n’est pas configuré.' });
    return;
  }

  // Scan one frame through the provider chain: Gemini lite → Gemini flash → Mistral.
  const scanOne = async (
    img: string,
  ): Promise<Array<{ name: string; price: number; category: string; description: string }>> => {
    if (env.geminiApiKey) {
      try {
        const content = await geminiGenerate(menuPrompt, img);
        const items = parseOcrResponse(content);
        if (items.length > 0) return items;
      } catch (primaryErr) {
        console.log('[scanMenu] primary Gemini failed, retrying');
      }
      // Empty result or provider error — retry once with the flash model.
      try {
        const content = await geminiGenerate(menuPrompt, img, GEMINI_RETRY_MODEL);
        return parseOcrResponse(content);
      } catch (error) {
        if (!env.mistralApiKey) throw error;
      }
    }
    return parseMenuImageWithPixtral(img);
  };

  // Scan every frame; a failed frame doesn't sink the whole batch.
  const results = await Promise.allSettled(images.map(scanOne));
  const allItems = results
    .filter(
      (r): r is PromiseFulfilledResult<
        { name: string; price: number; category: string; description: string }[]
      > => r.status === 'fulfilled',
    )
    .flatMap((r) => r.value);

  if (allItems.length === 0 && results.every((r) => r.status === 'rejected')) {
    // Every frame failed at the provider level (quota/network) — try Mistral
    // once as a last resort on the first frame.
    if (env.mistralApiKey) {
      try {
        const fallback = await parseMenuImageWithPixtral(images[0]);
        allItems.push(...fallback);
        console.log('[scanMenu] Mistral fallback items:', fallback.length);
      } catch {
        res.status(503).json({ code: 'SCAN_UNAVAILABLE', error: 'Le service de reconnaissance des menus est temporairement indisponible.' });
        return;
      }
    } else {
      res.status(503).json({ code: 'SCAN_UNAVAILABLE', error: 'Le service de reconnaissance des menus est temporairement indisponible.' });
      return;
    }
  } else if (allItems.length === 0 && env.mistralApiKey) {
    // Providers responded but found nothing — Mistral gets a second
    // opinion on the middle frame (usually the steadiest shot).
    try {
      const mid = images[Math.floor(images.length / 2)];
      const fallback = await parseMenuImageWithPixtral(mid);
      allItems.push(...fallback);
      console.log('[scanMenu] Mistral second-opinion items:', fallback.length);
    } catch {
      // best effort only
    }
  }

  // Merge frames: dedupe by normalized dish name (first occurrence wins).
  const normalize = (s: string) =>
    s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').trim();

  const seen = new Set<string>();
  const parsedItems = allItems.filter((item) => {
    const key = normalize(item.name ?? '');
    if (!key || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
  console.log('[scanMenu] frames:', images.length, 'merged items:', parsedItems.length);

  if (parsedItems.length === 0) {
    res.status(422).json({ code: 'SCAN_NO_ITEMS', error: 'Aucun plat lisible détecté. Filmez lentement et gardez les noms et prix dans le cadre.' });
    return;
  }

  // Sanitize and bound-check OCR output before writing to DB
  const ocr_item_schema = createMenuItemSchema.pick({ name: true, price: true, category: true, description: true });
  const validItems = parsedItems.reduce<Array<{ name: string; price: number; category: string; description: string }>>((acc, item) => {
    const result = ocr_item_schema.safeParse(item);
    if (result.success) acc.push(result.data as { name: string; price: number; category: string; description: string });
    return acc;
  }, []);

  if (validItems.length === 0) {
    res.status(400).json({ error: 'Les données extraites ne sont pas valides.' });
    return;
  }

  // Insert one-by-one and collect failures — a single bad row
  // shouldn't sink the whole scan.
  const created = [] as unknown[];
  const failed = [] as string[];
  for (const item of validItems) {
    try {
      created.push(await prisma.menuItem.create({
        data: {
          name: item.name,
          // OCR reads the restaurateur's printed (base) price — FAST markup
          // is applied deterministically, never decided by the model.
          price: resolveFastPricing({ price: item.price }).price,
          basePrice: item.price,
          category: item.category || '',
          description: item.description || '',
          restaurantId,
        },
        include: { dietaryTags: true },
      }));
    } catch (dbErr) {
      console.error('[scanMenu] database insert failed', { code: (dbErr as { code?: string }).code ?? 'UNKNOWN', restaurantId });
      failed.push(item.name);
    }
  }

  if (created.length === 0) {
    res.status(500).json({
      code: 'SCAN_SAVE_FAILED',
      error: 'Erreur lors de l\'enregistrement des plats détectés. Réessayez.',
    });
    return;
  }
  console.log('[scanMenu] created:', created.length, 'failed:', failed);

  res.status(201).json(created);
};

/**
 * F06 — propose a customer-facing description for a dish. Strictly
 * forbidden from inventing allergens, ingredients or dietary claims.
 * The owner reviews and edits before saving — nothing is auto-applied.
 */
export const enhanceMenuItem = async (req: Request, res: Response): Promise<void> => {
  const item = await prisma.menuItem.findUnique({ where: { id: req.params.id as string } });
  if (!item) {
    res.status(404).json({ error: 'Plat introuvable' });
    return;
  }
  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (restaurantId !== item.restaurantId || req.user!.staffRole === 'GUEST') {
    res.status(403).json({ error: 'Accès interdit' });
    return;
  }

  if (!env.geminiApiKey && !env.mistralApiKey) {
    res.status(500).json({ error: 'IA non configurée' });
    return;
  }

  const prompt = `You are writing a short, appetizing menu description for a restaurant dish.
Dish name: "${item.name}"
Category: "${item.category || 'Non spécifié'}"
Current description: "${item.description || ''}"

Rules:
- Write in French, one sentence, max 20 words.
- Make it appetizing and generic (style of cuisine, texture, presentation).
- NEVER mention allergens (gluten, nuts, lactose, etc.), specific ingredients not in the name, nutritional or dietary claims (vegan, halal, healthy…).
- If the current description is already good, return it unchanged.

Return ONLY a JSON object: {"description": "<text>"}`;

  try {
    let content: string;
    if (env.geminiApiKey) {
      content = await geminiGenerate(prompt);
    } else {
      const response = await fetch('https://api.mistral.ai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${env.mistralApiKey}`,
        },
        body: JSON.stringify({
          model: 'mistral-small-latest',
          messages: [{ role: 'user', content: prompt }],
          response_format: { type: 'json_object' },
          temperature: 0.5,
          max_tokens: 120,
        }),
      });
      if (!response.ok) {
        throw new Error(`Mistral API error: ${response.statusText}`);
      }
      const data = await response.json() as any;
      content = data.choices[0].message.content;
    }
    const parsed = JSON.parse(content);
    res.json({ description: String(parsed.description || '').slice(0, 300) });
  } catch (err) {
    console.error('[enhanceMenuItem] Error:', (err as Error).message);
    res.status(500).json({ error: 'Erreur lors de la suggestion IA' });
  }
};

// ─── AI dish photo ─────────────────────────────────────────
// Realistic "approximate" photo for dishes the owner has not
// photographed. Prefers Gemini's image model when GEMINI_API_KEY
// is configured (the image is written into UPLOAD_DIR so it lives
// under our control). Otherwise falls back to pollinations.ai —
// free, keyless, deterministic per dish name — so every menu item
// can always end up with a plausible photo.

const GEMINI_IMAGE_MODELS = [
  'gemini-2.5-flash-image',
  'gemini-2.0-flash-preview-image-generation',
];

async function geminiGenerateImage(prompt: string): Promise<string | null> {
  const apiKey = env.geminiApiKey;
  if (!apiKey) return null;
  for (const model of GEMINI_IMAGE_MODELS) {
    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
        {
          method: 'POST',
          signal: AbortSignal.timeout(45000),
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: { responseModalities: ['IMAGE'] },
          }),
        },
      );
      if (!response.ok) continue;
      const data = (await response.json()) as {
        candidates?: { content?: { parts?: Record<string, any>[] } }[];
      };
      const parts = data.candidates?.[0]?.content?.parts ?? [];
      const inline = parts.find(
        (p) => p.inlineData?.data || p.inline_data?.data,
      );
      const b64 = (inline?.inlineData?.data ?? inline?.inline_data?.data) as
        | string
        | undefined;
      const mime = (inline?.inlineData?.mimeType ??
        inline?.inline_data?.mime_type ??
        'image/png') as string;
      if (!b64) continue;
      const ext = mime.includes('png') ? '.png' : '.jpg';
      const filename = `ai-${Date.now()}-${crypto
        .randomBytes(4)
        .toString('hex')}${ext}`;
      fs.writeFileSync(
        path.join(uploadDir, filename),
        Buffer.from(b64, 'base64'),
      );
      return `/uploads/${filename}`;
    } catch {
      continue;
    }
  }
  return null;
}

function pollinationsDishPhoto(prompt: string, seedSource: string): string {
  let seed = 7;
  for (const ch of seedSource) {
    seed = (seed * 31 + ch.charCodeAt(0)) % 2147483647;
  }
  const q = new URLSearchParams({
    width: '800',
    height: '600',
    seed: String(Math.abs(seed)),
    nologo: 'true',
    model: 'flux',
  });
  return `https://image.pollinations.ai/prompt/${encodeURIComponent(
    prompt,
  )}?${q.toString()}`;
}

/// Prompt tuned for dish fidelity: the image must actually be *that*
/// dish — name + description carry the semantics, style constraints
/// keep it consistent with the FAST photo style.
function dishPhotoPrompt(name: string, description: string, category: string): string {
  return (
    `Ultra-realistic professional food photography of exactly this dish: "${name}"` +
    (description ? ` — ${description}` : '') +
    '. The photo must clearly show ' + `"${name}"` + ' with its typical' +
    ' ingredients and presentation recognizable at first glance — do not' +
    ' substitute a different dish or generic food item.' +
    (category ? ` Category: ${category}.` : '') +
    ' Served in clean fast-casual restaurant plating, appetizing,' +
    ' soft natural lighting, shallow depth of field, 45-degree angle,' +
    ' photorealistic, high detail, no text, no watermark, no people.'
  );
}

export const generateDishPhoto = async (
  req: Request,
  res: Response,
): Promise<void> => {
  const { name, description, category } = (req.body ?? {}) as {
    name?: string;
    description?: string;
    category?: string;
  };
  if (typeof name !== 'string' || name.trim().length < 2) {
    res.status(400).json({ error: 'Le nom du plat est requis' });
    return;
  }
  const safeName = name.trim().slice(0, 120);
  const safeDesc = (description ?? '').trim().slice(0, 200);
  const safeCat = (category ?? '').trim().slice(0, 60);
  const prompt = dishPhotoPrompt(safeName, safeDesc, safeCat);

  if (env.geminiApiKey) {
    const url = await geminiGenerateImage(prompt);
    if (url) {
      res.json({ imageUrl: url, source: 'gemini' });
      return;
    }
  }
  res.json({ imageUrl: pollinationsDishPhoto(prompt, safeName), source: 'pollinations' });
};

/// Batch fill — generates a photo for every menu item that still lacks
/// one, so the whole menu gets visuals in one tap. Gemini is used for
/// the first few (bounded cost/latency), Pollinations for the rest.
export const generateMenuPhotos = async (
  req: Request,
  res: Response,
): Promise<void> => {
  const restaurantId = String(req.params.restaurantId);
  if (await getRestaurantIdForUser(req.user!) !== restaurantId) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }

  const items = await prisma.menuItem.findMany({
    where: { restaurantId, image: '' },
    select: { id: true, name: true, description: true, category: true },
    take: 100,
  });
  if (items.length === 0) {
    res.json({ updated: 0, items: [] });
    return;
  }

  const geminiBudget = env.geminiApiKey ? 4 : 0;
  const results: { id: string; imageUrl: string; source: string }[] = [];

  for (const [index, item] of items.entries()) {
    const prompt = dishPhotoPrompt(
      item.name.slice(0, 120),
      (item.description ?? '').slice(0, 200),
      (item.category ?? '').slice(0, 60),
    );
    let imageUrl: string | null = null;
    let source = 'pollinations';
    if (index < geminiBudget) {
      imageUrl = await geminiGenerateImage(prompt);
      if (imageUrl) source = 'gemini';
    }
    imageUrl ??= pollinationsDishPhoto(prompt, item.name);

    await prisma.menuItem.update({
      where: { id: item.id },
      data: { image: imageUrl },
    });
    results.push({ id: item.id, imageUrl, source });
  }

  res.json({ updated: results.length, items: results });
};

export const suggestPrepTime = async (req: Request, res: Response): Promise<void> => {
  const { name, category, description } = req.body as { name: string; category?: string; description?: string };

  if (!name) {
    res.status(400).json({ error: 'name requis' });
    return;
  }

  const aiPrompt = `You are a restaurant kitchen expert. Estimate the preparation time in minutes for a dish.
Dish name: "${name}"
Category: "${category || 'Non spécifié'}"
Description: "${description || ''}"

Consider typical cooking times for this type of dish in a fast-food/casual restaurant context.
Return ONLY a JSON object: {"prepTime": <number_in_minutes>, "reasoning": "<short explanation in French>"}
The prepTime should be between 1 and 60 minutes.`;

  if (!env.geminiApiKey && !env.mistralApiKey) {
    res.status(500).json({ error: 'IA non configurée' });
    return;
  }

  try {
    let content: string;
    if (env.geminiApiKey) {
      content = await geminiGenerate(aiPrompt);
    } else {
      const response = await fetch('https://api.mistral.ai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${env.mistralApiKey}`,
        },
        body: JSON.stringify({
          model: 'mistral-small-latest',
          messages: [{ role: 'user', content: aiPrompt }],
          response_format: { type: 'json_object' },
          temperature: 0.3,
          max_tokens: 200,
        }),
      });

      if (!response.ok) {
        throw new Error(`Mistral API error: ${response.statusText}`);
      }
      const data = await response.json() as any;
      content = data.choices[0].message.content;
    }
    const parsed = JSON.parse(content);

    const prepTime = Math.max(1, Math.min(60, Math.round(parsed.prepTime || 8)));
    res.json({ prepTime, reasoning: parsed.reasoning || '' });
  } catch (err) {
    console.error('[suggestPrepTime] Error:', (err as Error).message);
    res.status(500).json({ error: 'Erreur lors de la suggestion IA' });
  }
};
