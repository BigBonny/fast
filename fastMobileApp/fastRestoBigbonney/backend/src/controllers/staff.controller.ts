import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { prisma } from '../services/prisma';
import { env } from '../config/env';
import { getRestaurantIdForUser } from '../middleware/auth';
import { redeemCodeSchema } from '../utils/validation';

// No 0/O or 1/I/L, so codes read aloud or copied by hand stay unambiguous.
const INVITE_ALPHABET = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

/**
 * `FAST-XXXX-XXXX`: 8 random characters from a 31-letter alphabet,
 * about 8.5e11 combinations. The old 4-digit codes (9,000 values) could be
 * brute-forced by any logged-in account in about an hour.
 */
export function generateInviteCode(): string {
  let body = '';
  for (let i = 0; i < 8; i++) body += INVITE_ALPHABET[crypto.randomInt(INVITE_ALPHABET.length)];
  return `FAST-${body.slice(0, 4)}-${body.slice(4)}`;
}

/** True for codes issued before the format change (`FAST-1234`). */
export function isLegacyInviteCode(code: string | null | undefined): boolean {
  return !!code && /^FAST-\d{4}$/.test(code);
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

  // Remove the assignment only. The person keeps their own account (and
  // its order history — deleting the user failed for anyone who had ever
  // ordered); it goes back to a plain professional account, and bumping
  // tokenVersion ends their sessions so the access stops at once.
  await prisma.$transaction([
    prisma.restaurantStaff.delete({ where: { id: staffId } }),
    prisma.user.update({
      where: { id: assignment.userId },
      data: { role: 'RESTAURANT', tokenVersion: { increment: 1 } },
    }),
  ]);

  res.json({ message: "Membre retiré de l'équipe" });
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

  // Also update the user's role, and end their sessions: the old token
  // still carries the previous role, which would otherwise keep working
  // until it expires (24 h).
  await prisma.user.update({
    where: { id: assignment.userId },
    data: { role: newRole as any, tokenVersion: { increment: 1 } },
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
  // Legacy 4-digit codes are guessable: replace them the first time the
  // owner opens the staff screen. Redeem already refuses them.
  if (!restaurant!.staffInviteCode || isLegacyInviteCode(restaurant!.staffInviteCode)) {
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
 * Authenticated — "redeem the code inside FAST Pro". A user who already
 * created a professional account attaches it to a restaurant as a GUEST
 * (limited rights: orders + availability only) using the owner's code.
 */
export const redeemInviteCode = async (req: Request, res: Response): Promise<void> => {
  const { code } = redeemCodeSchema.parse(req.body);

  const normalized = code.trim().toUpperCase();
  const restaurant = isLegacyInviteCode(normalized)
    ? null
    : await prisma.restaurant.findFirst({ where: { staffInviteCode: normalized } });
  if (!restaurant) {
    res.status(403).json({ code: 'INVALID_INVITE_CODE', error: 'Code invalide ou révoqué' });
    return;
  }
  if (restaurant.ownerId === req.user!.userId) {
    res.status(409).json({ error: 'Ce restaurant vous appartient déjà' });
    return;
  }

  // An account that already owns a restaurant can't become a guest
  // elsewhere — the two roles are mutually exclusive in the data model.
  const owned = await prisma.restaurant.findUnique({
    where: { ownerId: req.user!.userId },
    select: { id: true },
  });
  if (owned) {
    res.status(409).json({ error: 'Vous possédez déjà un restaurant — ce compte ne peut pas rejoindre un autre établissement' });
    return;
  }

  await prisma.$transaction([
    prisma.restaurantStaff.upsert({
      where: { userId: req.user!.userId },
      update: { restaurantId: restaurant.id, staffRole: 'GUEST' },
      create: { userId: req.user!.userId, restaurantId: restaurant.id, staffRole: 'GUEST' },
    }),
    // The account role must follow the assignment — otherwise login/getMe
    // never resolve the assignment and the app boots into owner onboarding.
    prisma.user.update({
      where: { id: req.user!.userId },
      data: { role: 'GUEST' },
    }),
  ]);

  const user = await prisma.user.findUnique({ where: { id: req.user!.userId } });
  if (!user) {
    res.status(404).json({ error: 'Compte introuvable' });
    return;
  }

  // Re-issue the token with the new assignment so the app lands in the
  // guest workspace immediately — no logout/login needed.
  const token = signStaffToken({
    userId: user.id,
    role: 'GUEST',
    tokenVersion: user.tokenVersion,
    restaurantId: restaurant.id,
    staffRole: 'GUEST',
  });

  res.json({
    token,
    user: { id: user.id, name: user.name, email: user.email, role: 'GUEST', restaurantId: restaurant.id, staffRole: 'GUEST' },
  });
};
