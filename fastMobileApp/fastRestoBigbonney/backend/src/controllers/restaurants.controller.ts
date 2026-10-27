import { Request, Response } from 'express';
import { prisma } from '../services/prisma';
import { createRestaurantSchema, updateRestaurantSchema } from '../utils/validation';
import { geocodeAddress } from '../utils/geocoding';
import { safeEmitNotificationToUser } from '../services/realtime';
import { getRestaurantIdForUser } from '../middleware/auth';

async function applyGeocoding(
  data: { address?: string; city?: string; latitude?: number; longitude?: number },
): Promise<{ latitude?: number; longitude?: number }> {
  if (data.latitude !== undefined && data.longitude !== undefined) {
    return { latitude: data.latitude, longitude: data.longitude };
  }
  if (data.address && data.city) {
    const coords = await geocodeAddress(data.address, data.city);
    if (coords) return coords;
  }
  return {};
}

function publicRestaurant(restaurant: Record<string, unknown>): Record<string, unknown> {
  const result = { ...restaurant };
  result.paymentsReady = Boolean(restaurant.stripeAccountId && restaurant.stripeChargesEnabled);
  for (const key of ['ownerId', 'managerIban', 'stripeAccountId', 'stripeChargesEnabled', 'stripePayoutsEnabled', 'payoutFrequency', 'staffInviteCode']) {
    delete result[key];
  }

  // Food truck: la position affichée est l'arrêt programmé du jour,
  // pour que la distance et la carte pointent au bon endroit.
  const stops = (restaurant.truckStops as Array<Record<string, unknown>> | undefined) ?? [];
  if (restaurant.isFoodTruck && stops.length > 0) {
    const today = new Date().getDay() === 0 ? 7 : new Date().getDay(); // ISO 1-7
    const todayStop = stops.find((s) => s.dayOfWeek === today) ?? null;
    result.todayStop = todayStop;
    if (todayStop) {
      result.latitude = todayStop.latitude;
      result.longitude = todayStop.longitude;
      result.address = todayStop.address;
      result.city = todayStop.city;
    }
  }
  return result;
}

export const listRestaurants = async (req: Request, res: Response): Promise<void> => {
  const { category, search, dietary } = req.query;

  const where: Record<string, unknown> = { isActive: true };

  // `category` is a comma-separated list on the restaurant (incl. custom
  // entries like "Congolais") — match as a substring, not exact equality.
  if (category && category !== 'all') {
    where.category = { contains: category as string, mode: 'insensitive' };
  }
  if (search) {
    const kw = (search as string).toLowerCase();
    where.OR = [
      { name: { contains: kw, mode: 'insensitive' } },
      { description: { contains: kw, mode: 'insensitive' } },
      { cuisineType: { contains: kw, mode: 'insensitive' } },
      { category: { contains: kw, mode: 'insensitive' } },
    ];
  }
  if (dietary) {
    const options = (dietary as string).split(',');
    where.dietaryOptions = {
      some: { option: { in: options } },
    };
  }

  const restaurants = await prisma.restaurant.findMany({
    where,
    include: {
      dietaryOptions: true,
      truckStops: true,
      menuItems: { where: { isAvailable: true }, include: { dietaryTags: true } },
      reviews: { orderBy: { createdAt: 'desc' }, take: 5 },
      _count: { select: { reviews: true } },
    },
    orderBy: { rating: 'desc' },
  });

  res.json(restaurants.map(publicRestaurant));
};

export const getRestaurant = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  const restaurant = await prisma.restaurant.findUnique({
    where: { id },
    include: {
      dietaryOptions: true,
      truckStops: true,
      menuItems: { where: { isAvailable: true }, include: { dietaryTags: true } },
      reviews: { orderBy: { createdAt: 'desc' }, take: 20, include: { user: { select: { name: true } } } },
      _count: { select: { reviews: true } },
    },
  });

  if (!restaurant) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }

  res.json(publicRestaurant(restaurant));
};

export const createRestaurant = async (req: Request, res: Response): Promise<void> => {
  const data = createRestaurantSchema.parse(req.body);

  const existing = await prisma.restaurant.findUnique({ where: { ownerId: req.user!.userId } });
  if (existing) {
    res.status(409).json({ error: 'Vous avez déjà un restaurant enregistré' });
    return;
  }

  // A staff-assigned account can't also own a restaurant — their token may
  // still carry the legacy RESTAURANT role until the next login.
  const staffAssignment = await prisma.restaurantStaff.findUnique({
    where: { userId: req.user!.userId },
    select: { id: true },
  });
  if (staffAssignment) {
    res.status(409).json({ error: 'Ce compte est déjà rattaché à un restaurant en tant que membre du personnel' });
    return;
  }

  const coords = await applyGeocoding(data);

  const restaurant = await prisma.restaurant.create({
    data: {
      ...data,
      ...coords,
      ownerId: req.user!.userId,
      dietaryOptions: data.dietaryOptions
        ? { create: data.dietaryOptions.map((opt) => ({ option: opt as any })) }
        : undefined,
    },
    include: { dietaryOptions: true },
  });

  res.status(201).json(restaurant);
};

export const updateRestaurant = async (req: Request, res: Response): Promise<void> => {
  const data = updateRestaurantSchema.parse(req.body);

  const restaurant = await prisma.restaurant.findFirst({
    where: { id: req.params.id as string, ownerId: req.user!.userId },
  });
  if (!restaurant) {
    res.status(404).json({ error: 'Restaurant introuvable ou accès refusé' });
    return;
  }

  const addressChanged = (data.address !== undefined && data.address !== restaurant.address)
    || (data.city !== undefined && data.city !== restaurant.city);
  const coords = addressChanged || data.latitude !== undefined || data.longitude !== undefined
    ? await applyGeocoding({
      address: data.address ?? restaurant.address,
      city: data.city ?? restaurant.city,
      latitude: data.latitude,
      longitude: data.longitude,
    })
    : {};

  const { dietaryOptions, truckStops, ...restData } = data;

  // Geocode each declared truck stop (address + city → lat/lng).
  let geocodedStops: Array<Record<string, unknown>> | undefined;
  if (truckStops !== undefined) {
    geocodedStops = [];
    for (const stop of truckStops) {
      const coords = (await geocodeAddress(stop.address, stop.city ?? '')) ?? {
        latitude: restaurant.latitude,
        longitude: restaurant.longitude,
      };
      geocodedStops.push({ ...stop, ...coords });
    }
  }

  const updated = await prisma.restaurant.update({
    where: { id: req.params.id as string },
    data: {
      ...restData,
      ...coords,
      dietaryOptions: dietaryOptions
        ? {
            deleteMany: {},
            create: dietaryOptions.map((opt) => ({ option: opt as any })),
          }
        : undefined,
      truckStops: geocodedStops
        ? {
            deleteMany: {},
            create: geocodedStops as any,
          }
        : undefined,
    },
    include: { dietaryOptions: true, truckStops: true },
  });

  res.json(updated);
};

export const getMyRestaurant = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(404).json({ error: 'Aucun restaurant trouvé pour ce compte' });
    return;
  }

  const restaurant = await prisma.restaurant.findUnique({
    where: { id: restaurantId },
    include: {
      dietaryOptions: true,
      truckStops: true,
      menuItems: { include: { dietaryTags: true } },
      _count: { select: { reviews: true, orders: true } },
    },
  });

  if (!restaurant) {
    res.status(404).json({ error: 'Aucun restaurant trouvé pour ce compte' });
    return;
  }

  res.json(restaurant);
};

async function notifyActiveOrderClients(
  restaurantId: string,
  restaurantName: string,
  title: string,
  body: string,
  type: 'RUSH' | 'FULL' | 'INFO',
): Promise<void> {
  const activeOrders = await prisma.order.findMany({
    where: {
      restaurantId,
      status: { in: ['PLACED', 'PREPARING', 'READY_FOR_PICKUP'] },
    },
    select: { id: true, userId: true },
  });

  const seen = new Set<string>();
  for (const order of activeOrders) {
    if (seen.has(order.userId)) continue;
    seen.add(order.userId);
    const notification = await prisma.notification.create({
      data: {
        userId: order.userId,
        orderId: order.id,
        title,
        body,
        type: type as any,
      },
    });
    safeEmitNotificationToUser(order.userId, notification);
  }
}

export const toggleRushMode = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }
  const restaurant = await prisma.restaurant.findUnique({ where: { id: restaurantId } });
  if (!restaurant) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }

  const updated = await prisma.restaurant.update({
    where: { id: restaurant.id },
    data: { isRushMode: !restaurant.isRushMode },
  });

  if (updated.isRushMode) {
    void notifyActiveOrderClients(
      restaurant.id,
      restaurant.name,
      `🔴 ${restaurant.name} est en RUSH`,
      `Le restaurant est actuellement en période de RUSH. Votre commande Fast est prise en compte, mais un léger délai supplémentaire peut être nécessaire.`,
      'RUSH',
    );
  } else {
    void notifyActiveOrderClients(
      restaurant.id,
      restaurant.name,
      `${restaurant.name} — retour à la normale`,
      `La période de RUSH est terminée. Votre commande sera préparée dans les délais habituels.`,
      'INFO',
    );
  }

  res.json({ isRushMode: updated.isRushMode });
};

export const toggleFullMode = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }
  const restaurant = await prisma.restaurant.findUnique({ where: { id: restaurantId } });
  if (!restaurant) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }

  const updated = await prisma.restaurant.update({
    where: { id: restaurant.id },
    data: { isFull: !restaurant.isFull },
  });

  if (updated.isFull) {
    void notifyActiveOrderClients(
      restaurant.id,
      restaurant.name,
      `⚫ ${restaurant.name} est complet`,
      `Le restaurant est actuellement complet (plus de places disponibles sur place). Les commandes Fast à emporter restent possibles.`,
      'FULL',
    );
  }

  res.json({ isFull: updated.isFull });
};

export const updatePayoutFrequency = async (req: Request, res: Response): Promise<void> => {
  const { frequency } = req.body as { frequency: string };
  const valid = ['daily', 'weekly', 'monthly'];
  if (!valid.includes(frequency)) {
    res.status(400).json({ error: 'Fréquence invalide (daily, weekly, monthly)' });
    return;
  }

  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }

  const updated = await prisma.restaurant.update({
    where: { id: restaurantId },
    data: { payoutFrequency: frequency },
  });

  res.json({ payoutFrequency: updated.payoutFrequency });
};

// ─── Restaurant requests (client → FAST) ─────────────────────
// A client suggests a restaurant that isn't on FAST yet. Ops calls the
// restaurant and onboards it — the request keeps the client's contact
// info so they can be told when it goes live.

const cleanField = (v: unknown, max = 160): string =>
  typeof v === 'string' ? v.trim().slice(0, max) : '';

export const createRestaurantRequest = async (req: Request, res: Response): Promise<void> => {
  const body = req.body as Record<string, unknown>;
  const name = cleanField(body.name, 120);
  if (name.length < 2) {
    res.status(400).json({ error: 'Nom du restaurant requis' });
    return;
  }

  const user = await prisma.user.findUnique({
    where: { id: req.user!.userId },
    select: { name: true, email: true },
  });

  const request = await prisma.restaurantRequest.create({
    data: {
      name,
      city: cleanField(body.city, 120),
      address: cleanField(body.address, 200),
      phone: cleanField(body.phone, 30),
      note: cleanField(body.note, 500),
      userId: req.user!.userId,
      userName: user?.name ?? '',
      userEmail: user?.email ?? '',
    },
  });

  res.status(201).json({ ok: true, request: { id: request.id, name: request.name, createdAt: request.createdAt } });
};

export const listMyRestaurantRequests = async (req: Request, res: Response): Promise<void> => {
  const requests = await prisma.restaurantRequest.findMany({
    where: { userId: req.user!.userId },
    orderBy: { createdAt: 'desc' },
    take: 20,
    select: { id: true, name: true, city: true, status: true, createdAt: true },
  });
  res.json(requests);
};

// Admin: full pipeline view + status updates so the FAST team can call
// the requested restaurants and track onboarding progress.
const REQUEST_STATUSES = ['NEW', 'CONTACTED', 'ONBOARDED', 'DECLINED'];

export const listRestaurantRequests = async (req: Request, res: Response): Promise<void> => {
  const status = cleanField(req.query.status, 20).toUpperCase();
  const requests = await prisma.restaurantRequest.findMany({
    where: REQUEST_STATUSES.includes(status) ? { status } : undefined,
    orderBy: { createdAt: 'desc' },
    take: 200,
  });
  res.json(requests);
};

export const updateRestaurantRequestStatus = async (req: Request, res: Response): Promise<void> => {
  const status = cleanField((req.body as Record<string, unknown>).status, 20).toUpperCase();
  if (!REQUEST_STATUSES.includes(status)) {
    res.status(400).json({ error: 'Statut invalide' });
    return;
  }
  const request = await prisma.restaurantRequest.update({
    where: { id: String(req.params.requestId) },
    data: { status },
  });

  // Keep the requesting client in the loop — the big win is ONBOARDED,
  // which turns their suggestion into a place they can actually order from.
  if (request.userId && (status === 'CONTACTED' || status === 'ONBOARDED')) {
    const notification = await prisma.notification.create({
      data: {
        userId: request.userId,
        title: status === 'ONBOARDED' ? `${request.name} est sur FAST !` : 'Bonne nouvelle !',
        body: status === 'ONBOARDED'
          ? 'Le restaurant que vous attendiez vient de nous rejoindre — bon appétit !'
          : `Nous avons contacté ${request.name} pour le faire rejoindre FAST.`,
        type: 'SUCCESS',
      },
    });
    safeEmitNotificationToUser(request.userId, notification);
  }

  res.json({ ok: true, request });
};
