import { Request, Response } from 'express';
import { prisma } from '../services/prisma';
import { createReservationSchema, updateReservationStatusSchema } from '../utils/validation';
import { getRestaurantIdForUser } from '../middleware/auth';
import { safeEmitNotificationToUser } from '../services/realtime';

/** Client creates a reservation request (F10). */
export const createReservation = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = req.params.restaurantId as string;
  const data = createReservationSchema.parse(req.body);

  const restaurant = await prisma.restaurant.findUnique({ where: { id: restaurantId } });
  if (!restaurant || !restaurant.isActive) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }
  if (!restaurant.reservationsEnabled) {
    res.status(400).json({ code: 'RESERVATIONS_DISABLED', error: 'Ce restaurant ne propose pas de réservation' });
    return;
  }

  const dateTime = new Date(data.dateTime);
  if (Number.isNaN(dateTime.getTime()) || dateTime.getTime() < Date.now() + 30 * 60 * 1000) {
    res.status(400).json({ error: 'La réservation doit être à au moins 30 minutes dans le futur' });
    return;
  }

  const user = await prisma.user.findUnique({ where: { id: req.user!.userId } });

  const reservation = await prisma.reservation.create({
    data: {
      restaurantId,
      userId: req.user!.userId,
      userName: user?.name ?? '',
      dateTime,
      partySize: data.partySize,
      note: data.note ?? '',
    },
  });

  const notification = await prisma.notification.create({
    data: {
      userId: restaurant.ownerId,
      title: 'Nouvelle demande de réservation',
      body: `${reservation.userName} — ${reservation.partySize} pers. le ${dateTime.toLocaleString('fr-FR')}`,
      type: 'STATUS',
    },
  });
  safeEmitNotificationToUser(restaurant.ownerId, notification);

  res.status(201).json(reservation);
};

/** Client lists their own reservations. */
export const listMyReservations = async (req: Request, res: Response): Promise<void> => {
  const reservations = await prisma.reservation.findMany({
    where: { userId: req.user!.userId },
    include: { restaurant: { select: { name: true, image: true, address: true } } },
    orderBy: { dateTime: 'desc' },
    take: 50,
  });
  res.json(reservations);
};

/** Client cancels a pending reservation. */
export const cancelMyReservation = async (req: Request, res: Response): Promise<void> => {
  const reservation = await prisma.reservation.findUnique({ where: { id: req.params.id as string } });
  if (!reservation || reservation.userId !== req.user!.userId) {
    res.status(404).json({ error: 'Réservation introuvable' });
    return;
  }
  if (reservation.status !== 'PENDING') {
    res.status(409).json({ error: 'Seule une réservation en attente peut être annulée' });
    return;
  }
  const updated = await prisma.reservation.update({
    where: { id: reservation.id },
    data: { status: 'CANCELLED' },
  });
  res.json(updated);
};

/** Restaurant staff lists reservations for their restaurant. */
export const listRestaurantReservations = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }
  const reservations = await prisma.reservation.findMany({
    where: { restaurantId },
    orderBy: [{ status: 'asc' }, { dateTime: 'asc' }],
    take: 200,
  });
  res.json(reservations);
};

/** Restaurant staff confirms or declines a reservation (not guests). */
export const updateReservationStatus = async (req: Request, res: Response): Promise<void> => {
  if (req.user!.role === 'GUEST' || req.user!.staffRole === 'GUEST') {
    res.status(403).json({ error: 'Accès invité : commandes uniquement' });
    return;
  }
  const data = updateReservationStatusSchema.parse(req.body);
  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }

  const reservation = await prisma.reservation.findUnique({ where: { id: req.params.id as string } });
  if (!reservation || reservation.restaurantId !== restaurantId) {
    res.status(404).json({ error: 'Réservation introuvable' });
    return;
  }
  if (reservation.status !== 'PENDING') {
    res.status(409).json({ error: 'Cette réservation a déjà été traitée' });
    return;
  }

  const updated = await prisma.reservation.update({
    where: { id: reservation.id },
    data: { status: data.status },
  });

  const notification = await prisma.notification.create({
    data: {
      userId: reservation.userId,
      title: data.status === 'CONFIRMED' ? 'Réservation confirmée' : 'Réservation refusée',
      body:
        data.status === 'CONFIRMED'
          ? `Votre table pour ${reservation.partySize} pers. est confirmée le ${reservation.dateTime.toLocaleString('fr-FR')}`
          : `Votre demande de réservation du ${reservation.dateTime.toLocaleString('fr-FR')} a été refusée`,
      type: 'STATUS',
    },
  });
  safeEmitNotificationToUser(reservation.userId, notification);

  res.json(updated);
};
