import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { prisma } from '../services/prisma';
import { env } from '../config/env';

export interface AuthPayload {
  userId: string;
  role: 'CLIENT' | 'RESTAURANT' | 'LIVREUR' | 'ADMIN' | 'STAFF' | 'GUEST';
  tokenVersion: number;
  restaurantId?: string;
  staffRole?: 'STAFF' | 'GUEST';
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthPayload;
    }
  }
}

export const authenticate = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  const header = req.headers.authorization;

  if (!header || !header.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Authentification requise' });
    return;
  }

  const token = header.split(' ')[1];

  try {
    const decoded = jwt.verify(token, env.jwtSecret) as AuthPayload;

    // Validate tokenVersion to enforce logout invalidation
    const user = await prisma.user.findUnique({ where: { id: decoded.userId }, select: { tokenVersion: true } });
    if (!user || user.tokenVersion !== decoded.tokenVersion) {
      res.status(401).json({ error: 'Session expirée. Veuillez vous reconnecter.' });
      return;
    }

    req.user = decoded;
    next();
  } catch {
    res.status(401).json({ error: 'Token invalide ou expiré' });
  }
};

export const requireRole = (...roles: string[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user || !roles.includes(req.user.role)) {
      res.status(403).json({ error: 'Accès interdit' });
      return;
    }
    next();
  };
};

/** Middleware: allow RESTAURANT owners OR STAFF/GUEST assigned to a restaurant */
export const requireRestaurantAccess = (minRole: 'STAFF' | 'GUEST' = 'GUEST') => {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    if (!req.user) {
      res.status(401).json({ error: 'Authentification requise' });
      return;
    }

    const role = req.user.role;

    // Owner: full access
    if (role === 'RESTAURANT' || role === 'ADMIN') {
      next();
      return;
    }

    // Staff/Guest: check assignment and role level
    if (role === 'STAFF' || role === 'GUEST') {
      if (minRole === 'STAFF' && role === 'GUEST') {
        res.status(403).json({ error: 'Accès réservé au personnel' });
        return;
      }

      // Resolve restaurantId from JWT or DB
      if (!req.user.restaurantId) {
        const assignment = await prisma.restaurantStaff.findUnique({
          where: { userId: req.user.userId },
          select: { restaurantId: true, staffRole: true },
        });
        if (!assignment) {
          res.status(403).json({ error: 'Aucun restaurant assigné' });
          return;
        }
        req.user.restaurantId = assignment.restaurantId;
        req.user.staffRole = assignment.staffRole;
      }

      if (minRole === 'STAFF' && req.user.staffRole === 'GUEST') {
        res.status(403).json({ error: 'Accès réservé au personnel' });
        return;
      }

      next();
      return;
    }

    res.status(403).json({ error: 'Accès interdit' });
  };
};

/** Helper: get the restaurant ID for the current user (owner or staff) */
export async function getRestaurantIdForUser(user: AuthPayload): Promise<string | null> {
  if (user.role === 'RESTAURANT' || user.role === 'ADMIN') {
 const restaurant = await prisma.restaurant.findUnique({ where: { ownerId: user.userId } });
    return restaurant?.id ?? null;
  }
  if (user.role === 'STAFF' || user.role === 'GUEST') {
    if (user.restaurantId) return user.restaurantId;
    const assignment = await prisma.restaurantStaff.findUnique({
      where: { userId: user.userId },
      select: { restaurantId: true },
    });
    return assignment?.restaurantId ?? null;
  }
  return null;
}
