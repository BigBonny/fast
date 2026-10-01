import { Request, Response } from 'express';
import { prisma } from '../services/prisma';
import { createMenuItemSchema, updateMenuItemSchema } from '../utils/validation';
import { env } from '../config/env';
import { getRestaurantIdForUser } from '../middleware/auth';

export const listMenuItems = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = req.params.restaurantId as string;

  const items = await prisma.menuItem.findMany({
    where: { restaurantId, isAvailable: true },
    include: { dietaryTags: true, supplements: true },
    orderBy: { category: 'asc' },
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

  const item = await prisma.menuItem.create({
    data: {
      ...data,
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

  const updated = await prisma.menuItem.update({
    where: { id },
    data: {
      ...data,
      dietaryTags: data.dietaryTags
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
  console.log('[scanMenu] Mistral output:', content);
  const parsed = JSON.parse(content);
  return parsed.items || [];
}

export const scanMenu = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = req.params.restaurantId as string;

  // Verify restaurant ownership or staff access
  const userRestaurantId = await getRestaurantIdForUser(req.user!);
  if (userRestaurantId !== restaurantId) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }

  const { imageBase64 } = req.body as { imageBase64?: string };
  if (!imageBase64) {
    res.status(400).json({ error: 'imageBase64 requis' });
    return;
  }

  let parsedItems: Array<{ name: string; price: number; category: string; description: string }> = [];

  try {
    if (env.geminiApiKey) {
      try {
        const content = await geminiGenerate(menuPrompt, imageBase64);
        parsedItems = (JSON.parse(content).items || []) as typeof parsedItems;
        console.log('[scanMenu] Gemini returned items count:', parsedItems.length);
      } catch (primaryErr) {
        // Lite model can still hit demand spikes — retry on the flagship alias.
        console.log('[scanMenu] primary Gemini failed, retrying:', (primaryErr as Error).message);
        const content = await geminiGenerate(menuPrompt, imageBase64, GEMINI_RETRY_MODEL);
        parsedItems = (JSON.parse(content).items || []) as typeof parsedItems;
        console.log('[scanMenu] Gemini retry items count:', parsedItems.length);
      }
    } else {
      parsedItems = await parseMenuImageWithPixtral(imageBase64);
      console.log('[scanMenu] Mistral returned items count:', parsedItems.length);
    }
  } catch (err) {
    console.error('[scanMenu] OCR failed:', (err as Error).message);
    // Fallback to the other provider if the primary one failed
    try {
      if (env.geminiApiKey && env.mistralApiKey) {
        parsedItems = await parseMenuImageWithPixtral(imageBase64);
        console.log('[scanMenu] Mistral fallback items:', parsedItems.length);
      } else {
        throw err;
      }
    } catch (fallbackErr) {
      res.status(500).json({ error: 'Échec de la reconnaissance OCR. Veuillez réessayer avec une image plus nette.' });
      return;
    }
  }

  if (parsedItems.length === 0) {
    res.status(400).json({ error: 'Aucun plat détecté. Assurez-vous que les prix sont bien lisibles (ex: 12.50€).' });
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

  const created = await Promise.all(
    validItems.map(item =>
      prisma.menuItem.create({
        data: {
          name: item.name,
          price: item.price,
          category: item.category || '',
          description: item.description || '',
          restaurantId,
        },
        include: { dietaryTags: true },
      })
    )
  );

  res.status(201).json(created);
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
