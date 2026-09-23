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

export const listRestaurants = async (req: Request, res: Response): Promise<void> => {
  const { category, search, dietary } = req.query;

  const where: Record<string, unknown> = { isActive: true };

  if (category && category !== 'all') where.category = category as string;
  if (search) {
    const kw = (search as string).toLowerCase();
    where.OR = [
      { name: { contains: kw, mode: 'insensitive' } },
      { description: { contains: kw, mode: 'insensitive' } },
      { cuisineType: { contains: kw, mode: 'insensitive' } },
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
      menuItems: { where: { isAvailable: true }, include: { dietaryTags: true } },
      reviews: { orderBy: { createdAt: 'desc' }, take: 5 },
      _count: { select: { reviews: true } },
    },
    orderBy: { rating: 'desc' },
  });

  res.json(restaurants);
};

export const getRestaurant = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  const restaurant = await prisma.restaurant.findUnique({
    where: { id },
    include: {
      dietaryOptions: true,
      menuItems: { where: { isAvailable: true }, include: { dietaryTags: true } },
      reviews: { orderBy: { createdAt: 'desc' }, take: 20, include: { user: { select: { name: true } } } },
      _count: { select: { reviews: true } },
    },
  });

  if (!restaurant) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }

  res.json(restaurant);
};

export const createRestaurant = async (req: Request, res: Response): Promise<void> => {
  const data = createRestaurantSchema.parse(req.body);

  const existing = await prisma.restaurant.findUnique({ where: { ownerId: req.user!.userId } });
  if (existing) {
    res.status(409).json({ error: 'Vous avez déjà un restaurant enregistré' });
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

  const { dietaryOptions, ...restData } = data;

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
    },
    include: { dietaryOptions: true },
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
