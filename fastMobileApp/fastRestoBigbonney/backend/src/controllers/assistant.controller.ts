import { Request, Response } from 'express';
import { prisma } from '../services/prisma';
import { env } from '../config/env';

// ─── FAST Assistant (Gemini) ────────────────────────────────
// Shared by the Flutter app and the website. Public endpoint —
// it only ever answers questions about FAST itself; restaurant
// data injected as grounding comes from the public catalog.

const SYSTEM_PROMPT = `Tu es l'assistant de FAST, une application de click-and-collect qui permet de commander des repas dans des restaurants locaux et de les retirer sur place (le slogan : "Chaque minute compte").

Règles :
- Réponds dans la langue de l'utilisateur, de façon courte et utile (3-4 phrases max sauf si on te demande une liste).
- Tu aides sur : utiliser l'app (panier, groupes, favoris, points fidélité, codes de retrait), trouver des restaurants/plats, questions sur les commandes, la réservation, le paiement, les remboursements.
- Tu ne dois JAMAIS inventer : des prix, des horaires, des informations de commande précises, des promos, des statuts. Si tu ne sais pas, dis-le.
- Pour les questions techniques de compte ou de paiement précises, renvoie vers le support.
- Pas de contenu offensant, pas de réponses hors-sujet — ramène toujours à FAST poliment.`;

const PRO_SYSTEM_PROMPT = `Tu es l'assistant FAST Pro, l'outil de gestion du restaurant partenaire de l'app FAST (click-and-collect : les clients commandent et viennent retirer).

Règles :
- Réponds dans la langue de l'utilisateur, court et concret (3-4 phrases max sauf liste demandée).
- Tu aides sur : gérer le menu et les photos IA, les commandes (accepter/refuser/rembourser), le tableau cuisine, les réservations, inviter staff/guest, les statistiques, la disponibilité, les retraits QR, les paiements Stripe Connect et les versements.
- Ne JAMAIS inventer de chiffres de vente, statuts de commande ou soldes Stripe. Pour les questions précises de compte Stripe, renvoie vers les paramètres (section Stripe) ou le support.
- Pas de contenu offensant, pas de hors-sujet — ramène à FAST Pro poliment.`;

interface ChatMessage {
  role: 'user' | 'model';
  text: string;
}

export const assistantChat = async (req: Request, res: Response): Promise<void> => {
  const { message, history, audience } = req.body as {
    message?: string;
    history?: ChatMessage[];
    audience?: string;
  };
  const systemPrompt =
    audience === 'pro' ? PRO_SYSTEM_PROMPT : SYSTEM_PROMPT;
  if (!message || typeof message !== 'string' || !message.trim() || message.length > 1000) {
    res.status(400).json({ error: 'Message requis (max 1000 caractères)' });
    return;
  }
  if (!env.geminiApiKey) {
    res.status(503).json({ error: 'Assistant indisponible' });
    return;
  }

  // Ground the answer in real catalog data so the assistant can name
  // actual restaurants/dishes instead of hallucinating.
  let context = '';
  try {
    const restaurants = await prisma.restaurant.findMany({
      where: { isActive: true },
      select: {
        name: true,
        cuisineType: true,
        category: true,
        menuItems: {
          where: { isAvailable: true },
          select: { name: true, category: true },
          take: 15,
        },
      },
      take: 25,
    });
    const lines = restaurants.map((r) => {
      const dishes = r.menuItems.map((m) => m.name).slice(0, 10).join(', ');
      return `- ${r.name} (${r.cuisineType || r.category}): ${dishes}`;
    });
    context = `Catalogue FAST actuel (restaurants et plats disponibles) :\n${lines.join('\n')}`;
  } catch {
    // DB context is a bonus — the assistant still answers generic help.
  }

  const safeHistory = (Array.isArray(history) ? history : [])
    .filter((m) => m && (m.role === 'user' || m.role === 'model') && typeof m.text === 'string')
    .slice(-10)
    .map((m) => ({ role: m.role, parts: [{ text: m.text.slice(0, 1000) }] }));

  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent?key=${env.geminiApiKey}`,
      {
        method: 'POST',
        signal: AbortSignal.timeout(20000),
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: systemPrompt }] },
          contents: [
            ...(context ? [{ role: 'user', parts: [{ text: context }] }, { role: 'model', parts: [{ text: 'Compris, je connais le catalogue FAST.' }] }] : []),
            ...safeHistory,
            { role: 'user', parts: [{ text: message.trim() }] },
          ],
          generationConfig: { temperature: 0.4, maxOutputTokens: 500 },
        }),
      },
    );
    if (!response.ok) {
      res.status(502).json({ error: 'Assistant indisponible pour le moment' });
      return;
    }
    const data = (await response.json()) as {
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    };
    const reply = data.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
    if (!reply) {
      res.status(502).json({ error: 'Réponse vide de l\u2019assistant' });
      return;
    }
    res.json({ reply });
  } catch {
    res.status(502).json({ error: 'Assistant indisponible pour le moment' });
  }
};

// ─── Address autocomplete (OpenStreetMap Nominatim) ─────────
// Free, no API key. We proxy it so the UA/contact policy stays
// server-side and both clients get the same trimmed payload.

interface NominatimHit {
  display_name: string;
  lat: string;
  lon: string;
  address?: { city?: string; town?: string; village?: string };
}

export const locationAutocomplete = async (req: Request, res: Response): Promise<void> => {
  const q = (req.query.q as string | undefined)?.trim() ?? '';
  if (q.length < 3 || q.length > 200) {
    res.json({ suggestions: [] });
    return;
  }
  try {
    const url =
      'https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1' +
      `&limit=6&accept-language=fr&countrycodes=fr&q=${encodeURIComponent(q)}`;
    const response = await fetch(url, {
      headers: { 'User-Agent': 'FAST-App/1.0 (contact: support@fast-eat-now.com)' },
      signal: AbortSignal.timeout(8000),
    });
    if (!response.ok) {
      res.json({ suggestions: [] });
      return;
    }
    const hits = (await response.json()) as NominatimHit[];
    res.json({
      suggestions: hits.map((h) => ({
        label: h.display_name,
        lat: Number(h.lat),
        lng: Number(h.lon),
        city: h.address?.city ?? h.address?.town ?? h.address?.village ?? '',
      })),
    });
  } catch {
    res.json({ suggestions: [] });
  }
};
