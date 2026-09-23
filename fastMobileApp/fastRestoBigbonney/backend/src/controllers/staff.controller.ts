import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { prisma } from '../services/prisma';
import { env } from '../config/env';
import { getRestaurantIdForUser } from '../middleware/auth';

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
