import { Request, Response } from 'express';
import { prisma } from '../services/prisma';
import { createReservationSchema, updateReservationStatusSchema } from '../utils/validation';
import { getRestaurantIdForUser } from '../middleware/auth';
import { safeEmitNotificationToUser, notifyRestaurantTeam } from '../services/realtime';

/** "12/11/2026 20:30" in Paris time — the wording used in every message. */
export const reservationWhen = (dateTime: Date): string =>
  dateTime.toLocaleString('fr-FR', { timeZone: 'Europe/Paris', dateStyle: 'short', timeStyle: 'short' });

/**
 * What the restaurant may do with a reservation: answer a pending
 * request, or cancel one it had confirmed. Everything else is final.
 */
export function canRestaurantSetStatus(current: string, next: string): boolean {
  if (current === 'PENDING') return next === 'CONFIRMED' || next === 'DECLINED';
  if (current === 'CONFIRMED') return next === 'CANCELLED';
  return false;
}

/** The client may cancel a request or a confirmed table that hasn't started. */
export function canClientCancel(status: string, dateTime: Date, now = new Date()): boolean {
  return (status === 'PENDING' || status === 'CONFIRMED') && dateTime.getTime() > now.getTime();
}

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

  // The whole team hears about it (owner + staff devices), like a new order.
  const notification = await prisma.notification.create({
    data: {
      userId: restaurant.ownerId,
      title: 'Nouvelle demande de réservation',
      body: `${reservation.userName} — ${reservation.partySize} pers. le ${reservationWhen(dateTime)}`,
      type: 'INFO',
    },
  });
  notifyRestaurantTeam(restaurantId, restaurant.ownerId, notification, {
    reservationId: reservation.id,
  });

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

/** Client cancels a pending request or a confirmed table. */
export const cancelMyReservation = async (req: Request, res: Response): Promise<void> => {
  const reservation = await prisma.reservation.findUnique({ where: { id: req.params.id as string } });
  if (!reservation || reservation.userId !== req.user!.userId) {
    res.status(404).json({ error: 'Réservation introuvable' });
    return;
  }
  if (!canClientCancel(reservation.status, reservation.dateTime)) {
    res.status(409).json({ error: 'Cette réservation ne peut plus être annulée' });
    return;
  }
  // Conditional update: a confirm/decline racing this cancel wins or
  // loses cleanly instead of being overwritten.
  const claimed = await prisma.reservation.updateMany({
    where: { id: reservation.id, status: reservation.status },
    data: { status: 'CANCELLED' },
  });
  if (claimed.count !== 1) {
    res.status(409).json({ error: 'La réservation a changé entre-temps, rafraîchissez' });
    return;
  }
  const updated = await prisma.reservation.findUniqueOrThrow({
    where: { id: reservation.id },
    include: { restaurant: { select: { ownerId: true } } },
  });

  // The restaurant must know the table is free again.
  const notification = await prisma.notification.create({
    data: {
      userId: updated.restaurant.ownerId,
      title: 'Réservation annulée',
      body: `${reservation.userName} a annulé sa table de ${reservation.partySize} pers. du ${reservationWhen(reservation.dateTime)}`,
      type: 'INFO',
    },
  });
  notifyRestaurantTeam(reservation.restaurantId, updated.restaurant.ownerId, notification, {
    reservationId: reservation.id,
  });

  const { restaurant: _restaurant, ...plain } = updated;
  res.json(plain);
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

/**
 * Restaurant staff confirms or declines a request, or cancels a table
 * they had confirmed (not guests). The client is told every time.
 */
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
  if (!canRestaurantSetStatus(reservation.status, data.status)) {
    res.status(409).json({ error: 'Cette réservation a déjà été traitée' });
    return;
  }

  const claimed = await prisma.reservation.updateMany({
    where: { id: reservation.id, status: reservation.status },
    data: { status: data.status },
  });
  if (claimed.count !== 1) {
    res.status(409).json({ error: 'La réservation a changé entre-temps, rafraîchissez' });
    return;
  }
  const updated = await prisma.reservation.findUniqueOrThrow({
    where: { id: reservation.id },
    include: { restaurant: { select: { name: true } } },
  });

  const when = reservationWhen(reservation.dateTime);
  const place = updated.restaurant.name;
  const message =
    data.status === 'CONFIRMED'
      ? {
          title: 'Réservation confirmée',
          body: `${place} : votre table pour ${reservation.partySize} pers. est confirmée le ${when}`,
        }
      : data.status === 'DECLINED'
        ? {
            title: 'Réservation refusée',
            body: `${place} n'a pas pu accepter votre demande du ${when}`,
          }
        : {
            title: 'Réservation annulée par le restaurant',
            body: `${place} a dû annuler votre table du ${when}`,
          };
  // Not 'STATUS': the app's polling only raises a banner for the other
  // types, and a reservation answer must reach the client without FCM.
  const notification = await prisma.notification.create({
    data: {
      userId: reservation.userId,
      ...message,
      type: data.status === 'CONFIRMED' ? 'SUCCESS' : 'INFO',
    },
  });
  safeEmitNotificationToUser(reservation.userId, notification, {
    reservationId: reservation.id,
  });

  const { restaurant: _restaurant, ...plain } = updated;
  res.json(plain);
};
