import { Request, Response } from 'express';
import { prisma } from '../services/prisma';
import { createReviewSchema } from '../utils/validation';

export const createReview = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = req.params.restaurantId as string;
  const data = createReviewSchema.parse(req.body);

  const restaurant = await prisma.restaurant.findUnique({ where: { id: restaurantId } });
  if (!restaurant) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }

  const user = await prisma.user.findUnique({ where: { id: req.user!.userId } });
  if (!user) {
    res.status(404).json({ error: 'Utilisateur introuvable' });
    return;
  }

  // Every review belongs to one completed order: one review per order.
  // Without an explicit order (older app versions), the most recent
  // completed order not yet reviewed is used. Before, a missing orderId
  // allowed unlimited reviews (NULLs bypass the unique index).
  const requestedOrderId =
    data.orderId ?? (typeof req.query.orderId === 'string' ? req.query.orderId : undefined);
  const order = await prisma.order.findFirst({
    where: {
      ...(requestedOrderId ? { id: requestedOrderId } : {}),
      userId: req.user!.userId,
      restaurantId,
      status: 'COMPLETED',
      reviews: { none: { userId: req.user!.userId } },
    },
    orderBy: { createdAt: 'desc' },
    select: { id: true },
  });
  if (!order) {
    res.status(409).json({
      error: requestedOrderId
        ? 'Commande invalide, non récupérée ou déjà notée'
        : 'Vous avez déjà noté toutes vos commandes récupérées dans ce restaurant',
    });
    return;
  }

  const review = await prisma.review.create({
    data: {
      restaurantId,
      userId: req.user!.userId,
      orderId: order.id,
      userName: user.name,
      rating: data.rating,
      comment: data.comment || '',
    },
  });

  const aggregations = await prisma.review.aggregate({
    where: { restaurantId, isReported: false },
    _avg: { rating: true },
    _count: true,
  });

  await prisma.restaurant.update({
    where: { id: restaurantId },
    data: {
      rating: Math.round((aggregations._avg.rating || 0) * 10) / 10,
      reviewsCount: aggregations._count,
    },
  });

  await prisma.order.update({
    where: { id: order.id },
    data: { ratingSubmitted: true },
  });

  res.status(201).json(review);
};

export const listReviews = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = req.params.restaurantId as string;

  const reviews = await prisma.review.findMany({
    where: { restaurantId, isReported: false },
    include: { user: { select: { name: true } } },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });

  res.json(reviews);
};

/** Distinct users who must report a review before it is hidden. */
export const REVIEW_HIDE_THRESHOLD = 3;

/** F09 — signalement d'un avis. One report per user; the review is hidden
 *  (and left out of the average) only once several different people have
 *  reported it, so nobody — a competitor or the restaurant itself — can
 *  hide a review alone. */
export const reportReview = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  const review = await prisma.review.findUnique({ where: { id } });
  if (!review) {
    res.status(404).json({ error: 'Avis introuvable' });
    return;
  }
  if (review.userId === req.user!.userId) {
    res.status(400).json({ error: 'Vous ne pouvez pas signaler votre propre avis' });
    return;
  }

  await prisma.reviewReport.upsert({
    where: { reviewId_userId: { reviewId: id, userId: req.user!.userId } },
    create: { reviewId: id, userId: req.user!.userId },
    update: {},
  });
  const reporters = await prisma.reviewReport.count({ where: { reviewId: id } });
  if (reporters < REVIEW_HIDE_THRESHOLD || review.isReported) {
    res.json({ message: 'Avis signalé pour modération' });
    return;
  }
  await prisma.review.update({ where: { id }, data: { isReported: true } });

  const aggregations = await prisma.review.aggregate({
    where: { restaurantId: review.restaurantId, isReported: false },
    _avg: { rating: true },
    _count: true,
  });
  await prisma.restaurant.update({
    where: { id: review.restaurantId },
    data: {
      rating: Math.round((aggregations._avg.rating || 0) * 10) / 10,
      reviewsCount: aggregations._count,
    },
  });

  res.json({ message: 'Avis signalé pour modération' });
};
