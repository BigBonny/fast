import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { prisma } from '../services/prisma';
import { env } from '../config/env';
import { getRestaurantIdForUser } from '../middleware/auth';
import { joinStaffSchema, guestLoginSchema, redeemCodeSchema } from '../utils/validation';

function generateInviteCode(): string {
  return `FAST-${crypto.randomInt(1000, 9999)}`;
}

function signStaffToken(payload: {
  userId: string;
  role: string;
  tokenVersion: number;
  restaurantId?: string;
  staffRole?: string;
}): string {
  return jwt.sign(payload, env.jwtSecret, { expiresIn: env.jwtExpiresIn } as jwt.SignOptions);
}

/** List all staff members for the current user's restaurant */
export const listStaff = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(404).json({ error: 'Aucun restaurant trouvé' });
    return;
  }

  const staff = await prisma.restaurantStaff.findMany({
    where: { restaurantId },
    include: {
      user: { select: { id: true, name: true, email: true, phone: true } },
    },
    orderBy: { createdAt: 'desc' },
  });

  res.json(staff);
};

/** Create a new staff/guest account and assign it to the current user's restaurant */
export const createStaff = async (req: Request, res: Response): Promise<void> => {
  const { email, password, name, phone, staffRole } = req.body;

  if (!email || !password || !name) {
    res.status(400).json({ error: 'Email, mot de passe et nom requis' });
    return;
  }

  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(404).json({ error: 'Aucun restaurant trouvé' });
    return;
  }

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    res.status(409).json({ error: 'Cet email est déjà utilisé' });
    return;
  }

  const hashedPassword = await bcrypt.hash(password, env.bcryptRounds);
  const role = staffRole === 'GUEST' ? 'GUEST' : 'STAFF';

  const user = await prisma.user.create({
    data: {
      email,
      password: hashedPassword,
      name,
      phone: phone || null,
      role: role as any,
      staffAssignments: {
        create: {
          restaurantId,
          staffRole: role as any,
        },
      },
    },
    select: { id: true, name: true, email: true, phone: true, role: true },
  });

  res.status(201).json(user);
};

/** Delete a staff member (removes assignment + user account) */
export const deleteStaff = async (req: Request, res: Response): Promise<void> => {
  const staffId = req.params.id as string;
  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(404).json({ error: 'Aucun restaurant trouvé' });
    return;
  }

  const assignment = await prisma.restaurantStaff.findFirst({
    where: { id: staffId, restaurantId },
  });
  if (!assignment) {
    res.status(404).json({ error: 'Membre du personnel introuvable' });
    return;
  }

  // Delete both the assignment and the user account
  await prisma.restaurantStaff.delete({ where: { id: staffId } });
  await prisma.user.delete({ where: { id: assignment.userId } });

  res.json({ message: 'Membre supprimé' });
};

/** Update staff role (promote/demote between STAFF and GUEST) */
export const updateStaffRole = async (req: Request, res: Response): Promise<void> => {
  const staffId = req.params.id as string;
  const { staffRole } = req.body;
  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(404).json({ error: 'Aucun restaurant trouvé' });
    return;
  }

  const assignment = await prisma.restaurantStaff.findFirst({
    where: { id: staffId, restaurantId },
  });
  if (!assignment) {
    res.status(404).json({ error: 'Membre du personnel introuvable' });
    return;
  }

  const newRole = staffRole === 'GUEST' ? 'GUEST' : 'STAFF';

  const updated = await prisma.restaurantStaff.update({
    where: { id: staffId },
    data: { staffRole: newRole as any },
    include: { user: { select: { id: true, name: true, email: true, phone: true } } },
  });

  // Also update the user's role
  await prisma.user.update({
    where: { id: assignment.userId },
    data: { role: newRole as any },
  });

  res.json(updated);
};

// ─── Invite codes (F13) ─────────────────────────────────────
// Owner shares a code; kitchen staff self-register with first/last name.
// Rotating or revoking the code immediately stops new joins AND future
// guest logins — active sessions still expire naturally via JWT expiry.

/** Get the current invite code, generating one on first use. */
export const getInviteCode = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(404).json({ error: 'Aucun restaurant trouvé' });
    return;
  }
  let restaurant = await prisma.restaurant.findUnique({ where: { id: restaurantId } });
  if (!restaurant!.staffInviteCode) {
    restaurant = await prisma.restaurant.update({
      where: { id: restaurantId },
      data: { staffInviteCode: generateInviteCode() },
    });
  }
  res.json({ code: restaurant!.staffInviteCode });
};

/** Rotate the code — revokes the old one (stops joins and guest logins). */
export const rotateInviteCode = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(404).json({ error: 'Aucun restaurant trouvé' });
    return;
  }
  const restaurant = await prisma.restaurant.update({
    where: { id: restaurantId },
    data: { staffInviteCode: generateInviteCode() },
  });
  res.json({ code: restaurant.staffInviteCode });
};

/** Revoke the code entirely. */
export const revokeInviteCode = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = await getRestaurantIdForUser(req.user!);
  if (!restaurantId) {
    res.status(404).json({ error: 'Aucun restaurant trouvé' });
    return;
  }
  await prisma.restaurant.update({
    where: { id: restaurantId },
    data: { staffInviteCode: null },
  });
  res.json({ message: 'Code révoqué' });
};

/**
 * Public — "Créer un compte invité" at FAST Pro signup.
 * The member enters first/last name + the code from the admin and is
 * logged in directly. Guest rights are enforced server-side elsewhere
 * (orders + availability toggling only).
 */
export const joinWithCode = async (req: Request, res: Response): Promise<void> => {
  const data = joinStaffSchema.parse(req.body);
  const code = data.code.trim().toUpperCase();
  const name = `${data.firstName.trim()} ${data.lastName.trim()}`.trim();

  const restaurant = await prisma.restaurant.findFirst({ where: { staffInviteCode: code } });
  if (!restaurant) {
    res.status(403).json({ code: 'INVALID_INVITE_CODE', error: 'Code invalide ou révoqué' });
    return;
  }

  // Same name + same restaurant already joined? Treat as login instead of
  // creating a duplicate — keeps repeated onboarding taps harmless.
  const existing = await prisma.user.findFirst({
    where: {
      role: 'GUEST',
      name: { equals: name, mode: 'insensitive' },
      staffAssignments: { some: { restaurantId: restaurant.id, staffRole: 'GUEST' } },
    },
  });
  if (existing) {
    const token = signStaffToken({
      userId: existing.id,
      role: 'GUEST',
      tokenVersion: existing.tokenVersion,
      restaurantId: restaurant.id,
      staffRole: 'GUEST',
    });
    res.json({ token, user: { id: existing.id, name: existing.name, role: 'GUEST', restaurantId: restaurant.id, staffRole: 'GUEST' } });
    return;
  }

  const syntheticEmail = `guest-${crypto.randomUUID()}@invite.fast.local`;
  const user = await prisma.user.create({
    data: {
      email: syntheticEmail,
      password: await bcrypt.hash(crypto.randomBytes(16).toString('hex'), env.bcryptRounds),
      name,
      role: 'GUEST' as any,
      staffAssignments: {
        create: { restaurantId: restaurant.id, staffRole: 'GUEST' as any },
      },
    },
  });

  const token = signStaffToken({
    userId: user.id,
    role: 'GUEST',
    tokenVersion: user.tokenVersion,
    restaurantId: restaurant.id,
    staffRole: 'GUEST',
  });

  res.status(201).json({ token, user: { id: user.id, name: user.name, role: 'GUEST', restaurantId: restaurant.id, staffRole: 'GUEST' } });
};

/**
 * Public — guest re-login with code + name. The code acts as the shared
 * secret; rotating it locks out every guest that hasn't an active session.
 */
export const guestLogin = async (req: Request, res: Response): Promise<void> => {
  const data = guestLoginSchema.parse(req.body);
  const code = data.code.trim().toUpperCase();
  const name = `${data.firstName.trim()} ${data.lastName.trim()}`.trim();

  const restaurant = await prisma.restaurant.findFirst({ where: { staffInviteCode: code } });
  const user = restaurant
    ? await prisma.user.findFirst({
        where: {
          role: 'GUEST',
          name: { equals: name, mode: 'insensitive' },
          staffAssignments: { some: { restaurantId: restaurant.id, staffRole: 'GUEST' } },
        },
      })
    : null;

  if (!restaurant || !user) {
    res.status(401).json({ error: 'Code ou nom invalide' });
    return;
  }

  const token = signStaffToken({
    userId: user.id,
    role: 'GUEST',
    tokenVersion: user.tokenVersion,
    restaurantId: restaurant.id,
    staffRole: 'GUEST',
  });

  res.json({ token, user: { id: user.id, name: user.name, role: 'GUEST', restaurantId: restaurant.id, staffRole: 'GUEST' } });
};

/**
 * Authenticated — "redeem the code inside FAST Pro". A user who already
 * created a professional account attaches it to a restaurant as a GUEST
 * (limited rights: orders + availability only) using the owner's code.
 */
export const redeemInviteCode = async (req: Request, res: Response): Promise<void> => {
  const { code } = redeemCodeSchema.parse(req.body);

  const restaurant = await prisma.restaurant.findFirst({
    where: { staffInviteCode: code.trim().toUpperCase() },
  });
  if (!restaurant) {
    res.status(403).json({ code: 'INVALID_INVITE_CODE', error: 'Code invalide ou révoqué' });
    return;
  }
  if (restaurant.ownerId === req.user!.userId) {
    res.status(409).json({ error: 'Ce restaurant vous appartient déjà' });
    return;
  }

  await prisma.restaurantStaff.upsert({
    where: { userId: req.user!.userId },
    update: { restaurantId: restaurant.id, staffRole: 'GUEST' },
    create: { userId: req.user!.userId, restaurantId: restaurant.id, staffRole: 'GUEST' },
  });

  const user = await prisma.user.findUnique({ where: { id: req.user!.userId } });
  if (!user) {
    res.status(404).json({ error: 'Compte introuvable' });
    return;
  }

  // Re-issue the token with the new assignment so the app lands in the
  // guest workspace immediately — no logout/login needed.
  const token = signStaffToken({
    userId: user.id,
    role: user.role,
    tokenVersion: user.tokenVersion,
    restaurantId: restaurant.id,
    staffRole: 'GUEST',
  });

  res.json({
    token,
    user: { id: user.id, name: user.name, email: user.email, role: user.role, restaurantId: restaurant.id, staffRole: 'GUEST' },
  });
};
