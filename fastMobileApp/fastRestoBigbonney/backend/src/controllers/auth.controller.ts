import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { prisma } from '../services/prisma';
import { env } from '../config/env';
import { registerSchema, loginSchema, updateProfileSchema, changePasswordSchema, phoneRequestSchema, phoneVerifySchema } from '../utils/validation';
import crypto from 'crypto';

const userWithLinks = { driverProfile: true, restaurant: true } as const;

/**
 * Emails are stored as typed historically (mixed case). New accounts are
 * normalised to lowercase by the schemas; lookups try the exact value first
 * (so legacy mixed-case rows keep working), then a case-insensitive match.
 */
async function findUserByEmail(email: string) {
  const exact = await prisma.user.findUnique({ where: { email }, include: userWithLinks });
  if (exact) return exact;
  return prisma.user.findFirst({
    where: { email: { equals: email, mode: 'insensitive' } },
    orderBy: { createdAt: 'asc' },
    include: userWithLinks,
  });
}

export const register = async (req: Request, res: Response): Promise<void> => {
  const data = registerSchema.parse(req.body);

  const existing = await findUserByEmail(data.email);
  if (existing) {
    res.status(409).json({ error: 'Cet email est déjà utilisé' });
    return;
  }

  const hashedPassword = await bcrypt.hash(data.password, env.bcryptRounds);

  const user = await prisma.user.create({
    data: {
      email: data.email,
      password: hashedPassword,
      name: data.name,
      phone: data.phone,
      role: data.role,
      ...(data.role === 'LIVREUR' && data.driverType
        ? { driverProfile: { create: { type: data.driverType } } }
        : {}),
    },
    include: { driverProfile: true },
  });

  // For STAFF/GUEST roles, resolve restaurant assignment
  let restaurantId: string | undefined;
  let staffRole: 'STAFF' | 'GUEST' | undefined;
  if (user.role === 'STAFF' || user.role === 'GUEST') {
    const assignment = await prisma.restaurantStaff.findUnique({
      where: { userId: user.id },
      select: { restaurantId: true, staffRole: true },
    });
    restaurantId = assignment?.restaurantId;
    staffRole = assignment?.staffRole;
  }

  const token = jwt.sign(
    { userId: user.id, role: user.role, tokenVersion: user.tokenVersion, restaurantId, staffRole },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn as string } as jwt.SignOptions,
  );

  res.status(201).json({
    token,
    user: { id: user.id, name: user.name, email: user.email, phone: user.phone, role: user.role, points: user.points, driverProfile: user.driverProfile, restaurantId, staffRole },
  });
};

/**
 * Resolves the staff/guest assignment for a user. Accounts that redeemed an
 * invite code before the role-sync fix keep role RESTAURANT in the DB — if
 * they have an assignment but own no restaurant, heal the role so the app
 * boots into the staff workspace instead of owner onboarding.
 */
async function resolveStaffContext(user: { id: string; role: string }): Promise<{
  role: string;
  restaurantId?: string;
  staffRole?: 'STAFF' | 'GUEST';
}> {
  if (user.role === 'STAFF' || user.role === 'GUEST') {
    const assignment = await prisma.restaurantStaff.findUnique({
      where: { userId: user.id },
      select: { restaurantId: true, staffRole: true },
    });
    return { role: user.role, restaurantId: assignment?.restaurantId, staffRole: assignment?.staffRole };
  }
  if (user.role === 'RESTAURANT') {
    const assignment = await prisma.restaurantStaff.findUnique({
      where: { userId: user.id },
      select: { restaurantId: true, staffRole: true },
    });
    if (assignment) {
      const owned = await prisma.restaurant.findUnique({
        where: { ownerId: user.id },
        select: { id: true },
      });
      if (!owned) {
        await prisma.user.update({
          where: { id: user.id },
          data: { role: assignment.staffRole as 'STAFF' | 'GUEST' },
        });
        return { role: assignment.staffRole, restaurantId: assignment.restaurantId, staffRole: assignment.staffRole };
      }
    }
  }
  return { role: user.role };
}

export const login = async (req: Request, res: Response): Promise<void> => {
  const data = loginSchema.parse(req.body);

  const user = await findUserByEmail(data.email);
  if (!user) {
    res.status(401).json({ error: 'Email ou mot de passe incorrect' });
    return;
  }

  // Check account lockout
  if (user.lockedUntil && user.lockedUntil > new Date()) {
    const remaining = Math.ceil((user.lockedUntil.getTime() - Date.now()) / 60000);
    res.status(429).json({ error: `Compte temporairement verrouillé. Réessayez dans ${remaining} minute(s).` });
    return;
  }

  const valid = await bcrypt.compare(data.password, user.password);
  if (!valid) {
    // Increment failed attempts
    const failed = (user.failedLoginAttempts || 0) + 1;
    const updateData: any = { failedLoginAttempts: failed };
    if (failed >= env.maxFailedLogins) {
      updateData.lockedUntil = new Date(Date.now() + env.lockoutMinutes * 60 * 1000);
      updateData.failedLoginAttempts = 0;
    }
    await prisma.user.update({ where: { id: user.id }, data: updateData });

    res.status(401).json({ error: 'Email ou mot de passe incorrect' });
    return;
  }

  // Reset failed attempts on successful login
  if (user.failedLoginAttempts !== 0 || user.lockedUntil) {
    await prisma.user.update({
      where: { id: user.id },
      data: { failedLoginAttempts: 0, lockedUntil: null },
    });
  }

  // Resolve staff assignment (also heals legacy redeemed accounts whose
  // role was never switched from RESTAURANT).
  const ctx = await resolveStaffContext(user);
  const restaurantId = ctx.restaurantId;
  const staffRole = ctx.staffRole;

  const token = jwt.sign(
    { userId: user.id, role: ctx.role, tokenVersion: user.tokenVersion, restaurantId, staffRole },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn as string } as jwt.SignOptions,
  );

  res.json({
    token,
    user: { id: user.id, name: user.name, email: user.email, phone: user.phone, role: ctx.role, points: user.points, driverProfile: user.driverProfile, restaurant: user.restaurant, restaurantId, staffRole },
  });
};

export const googleLogin = async (req: Request, res: Response): Promise<void> => {
  const { idToken, role } = req.body as { idToken?: string; role?: string };
  if (!idToken || typeof idToken !== 'string') {
    res.status(400).json({ error: 'idToken requis' });
    return;
  }

  // Verify the token signature & claims with Google's public endpoint
  const verify = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
  );
  if (!verify.ok) {
    res.status(401).json({ error: 'Token Google invalide ou expiré' });
    return;
  }
  const payload = (await verify.json()) as {
    email?: string;
    name?: string;
    sub?: string;
    aud?: string;
  };
  // The token must have been minted for FAST's own OAuth clients — a
  // Google ID token from any other app must not open a session here.
  const googleClientIds = (
    process.env.GOOGLE_CLIENT_IDS ||
    '792298746020-ssfs311jl0k5qt2cdh32hs66p5uooko9.apps.googleusercontent.com,' +
      '792298746020-61i7cv8gp2cdubrkrim5coqjndfu9tl0.apps.googleusercontent.com'
  ).split(',');
  if (!payload.email || !payload.aud || !googleClientIds.includes(payload.aud)) {
    res.status(401).json({ error: 'Token Google invalide ou expiré' });
    return;
  }

  const googleEmail = payload.email.trim().toLowerCase();
  let user = await findUserByEmail(googleEmail);
  if (!user) {
    user = await prisma.user.create({
      data: {
        email: googleEmail,
        name: payload.name?.trim() || googleEmail.split('@')[0],
        password: await bcrypt.hash(`google-${payload.sub}-${Date.now()}`, env.bcryptRounds),
        role: (role as never) || 'CLIENT',
      },
      include: userWithLinks,
    });
  }

  await issueSession(user, res);
};

/** Shared sign-in tail: staff context → FAST JWT → user payload. */
async function issueSession(
  user: Awaited<ReturnType<typeof findUserByEmail>> & {},
  res: Response,
) {
  if (!user) return;
  const ctx = await resolveStaffContext(user);
  const restaurantId = ctx.restaurantId;
  const staffRole = ctx.staffRole;

  const token = jwt.sign(
    { userId: user.id, role: ctx.role, tokenVersion: user.tokenVersion, restaurantId, staffRole },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn as string } as jwt.SignOptions,
  );

  res.json({
    token,
    user: { id: user.id, name: user.name, email: user.email, phone: user.phone, role: ctx.role, points: user.points, driverProfile: user.driverProfile, restaurant: user.restaurant, restaurantId, staffRole },
  });
}

// Apple's public signing keys for the identity token (RS256).
const appleJwks = createRemoteJWKSet(
  new URL('https://appleid.apple.com/auth/keys'),
);

/**
 * Sign in with Apple (Guideline 4.8). The client sends the identityToken
 * plus the display name Apple returns on the FIRST authorization only.
 */
export const appleLogin = async (req: Request, res: Response): Promise<void> => {
  try {
    const { identityToken, name, role } = req.body as {
      identityToken?: string;
      name?: string;
      role?: string;
    };
    if (!identityToken || typeof identityToken !== 'string') {
      res.status(400).json({ error: 'identityToken requis' });
      return;
    }

    const appleClientIds = (
      process.env.APPLE_CLIENT_IDS || 'com.fast.resto.fastRestoBigbonney'
    ).split(',');
    const { payload } = await jwtVerify(identityToken, appleJwks, {
      issuer: 'https://appleid.apple.com',
      audience: appleClientIds,
    });
    if (!payload.email && !payload.sub) {
      res.status(401).json({ error: 'Token Apple invalide ou expiré' });
      return;
    }

    // Users may hide their real email — the relay address is stable per
    // sub, so prefer the email but fall back to a deterministic synthetic
    // one keyed on the Apple user id.
    const appleEmail = String(
      payload.email ?? `apple-${payload.sub}@privaterelay.appleid.local`,
    )
      .trim()
      .toLowerCase();
    let user = await findUserByEmail(appleEmail);
    if (!user) {
      user = await prisma.user.create({
        data: {
          email: appleEmail,
          name: (typeof name === 'string' ? name.trim() : '') || appleEmail.split('@')[0],
          password: await bcrypt.hash(
            `apple-${payload.sub}-${Date.now()}`,
            env.bcryptRounds,
          ),
          role: (role as never) || 'CLIENT',
        },
        include: userWithLinks,
      });
    }

    await issueSession(user, res);
  } catch {
    res.status(401).json({ error: 'Token Apple invalide ou expiré' });
  }
};

export const getMe = async (req: Request, res: Response): Promise<void> => {
  const user = await prisma.user.findUnique({
    where: { id: req.user!.userId },
    include: { restaurant: true, driverProfile: { include: { schedules: true } } },
  });

  if (!user) {
    res.status(404).json({ error: 'Utilisateur introuvable' });
    return;
  }

  // Include staff assignment if applicable — heals legacy redeemed
  // accounts whose role was never switched from RESTAURANT.
  const ctx = await resolveStaffContext(user);
  const staffAssignment = ctx.restaurantId != null
    ? { restaurantId: ctx.restaurantId, staffRole: ctx.staffRole ?? 'GUEST' }
    : null;

  res.json({
    id: user.id,
    name: user.name,
    email: user.email,
    phone: user.phone,
    role: ctx.role,
    points: user.points,
    restaurant: user.restaurant,
    driverProfile: user.driverProfile,
    staffAssignment,
    restaurantId: staffAssignment?.restaurantId,
    staffRole: staffAssignment?.staffRole,
  });
};

export const logout = async (req: Request, res: Response): Promise<void> => {
  // Increment tokenVersion to invalidate all existing tokens
  await prisma.user.update({
    where: { id: req.user!.userId },
    data: { tokenVersion: { increment: 1 } },
  });
  res.json({ message: 'Déconnexion réussie' });
};

export const deleteAccount = async (req: Request, res: Response): Promise<void> => {
  const userId = req.user!.userId;
  await prisma.$transaction([
    prisma.notification.deleteMany({ where: { userId } }),
    prisma.restaurant.updateMany({ where: { ownerId: userId }, data: { isActive: false } }),
    prisma.user.update({
      where: { id: userId },
      data: {
        email: `deleted-${userId}@deleted.invalid`,
        name: 'Compte supprimé',
        phone: null,
        password: await bcrypt.hash(`${userId}-${Date.now()}`, env.bcryptRounds),
        points: 0,
        tokenVersion: { increment: 1 },
      },
    }),
  ]);
  res.json({ message: 'Compte supprimé' });
};

export const updateProfile = async (req: Request, res: Response): Promise<void> => {
  const data = updateProfileSchema.parse(req.body);

  // If email is being changed, ensure it's not already in use.
  if (data.email) {
    const existing = await findUserByEmail(data.email);
    if (existing && existing.id !== req.user!.userId) {
      res.status(409).json({ error: 'Cet email est déjà utilisé' });
      return;
    }
  }

  const user = await prisma.user.update({
    where: { id: req.user!.userId },
    data: {
      ...(data.name && { name: data.name }),
      ...(data.email && { email: data.email }),
      ...(data.phone && { phone: data.phone }),
    },
  });

  res.json({ id: user.id, name: user.name, email: user.email, phone: user.phone, role: user.role, points: user.points });
};

export const changePassword = async (req: Request, res: Response): Promise<void> => {
  const data = changePasswordSchema.parse(req.body);

  const user = await prisma.user.findUnique({ where: { id: req.user!.userId } });
  if (!user) {
    res.status(404).json({ error: 'Utilisateur introuvable' });
    return;
  }

  const valid = await bcrypt.compare(data.currentPassword, user.password);
  if (!valid) {
    res.status(401).json({ error: 'Mot de passe actuel incorrect' });
    return;
  }

  const hashedPassword = await bcrypt.hash(data.newPassword, env.bcryptRounds);
  await prisma.user.update({
    where: { id: req.user!.userId },
    data: { password: hashedPassword },
  });

  res.json({ message: 'Mot de passe mis à jour' });
};

// ─── Phone verification (SMS OTP, F11) ──────────────────────

const smsConfigured = () =>
  Boolean(env.twilioAccountSid && env.twilioAuthToken && env.twilioFromNumber);

/** Whether the app must require SMS verification at signup. */
export const phoneVerificationStatus = async (_req: Request, res: Response): Promise<void> => {
  res.json({ enabled: smsConfigured() });
};

async function sendSms(to: string, body: string): Promise<void> {
  const creds = Buffer.from(`${env.twilioAccountSid}:${env.twilioAuthToken}`).toString('base64');
  const resp = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${env.twilioAccountSid}/Messages.json`,
    {
      method: 'POST',
      headers: {
        Authorization: `Basic ${creds}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({ To: to, From: env.twilioFromNumber, Body: body }),
      signal: AbortSignal.timeout(10000),
    },
  );
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`SMS provider error: ${resp.status} ${text.slice(0, 200)}`);
  }
}

/** Request a one-time SMS code. Rate-limited: 60 s between resends, 3/hour. */
export const requestPhoneCode = async (req: Request, res: Response): Promise<void> => {
  const data = phoneRequestSchema.parse(req.body);
  const phone = data.phone.trim();

  const recent = await prisma.phoneVerification.findFirst({
    where: { phone },
    orderBy: { createdAt: 'desc' },
  });
  if (recent && Date.now() - recent.createdAt.getTime() < 60_000) {
    res.status(429).json({ error: 'Un code vient d\'être envoyé. Patientez 60 secondes.' });
    return;
  }
  const hourlyCount = await prisma.phoneVerification.count({
    where: { phone, createdAt: { gte: new Date(Date.now() - 3600_000) } },
  });
  if (hourlyCount >= 3) {
    res.status(429).json({ error: 'Trop de codes demandés. Réessayez dans une heure.' });
    return;
  }

  const code = crypto.randomInt(100000, 999999).toString();
  await prisma.phoneVerification.create({
    data: { phone, code, expiresAt: new Date(Date.now() + 10 * 60_000) },
  });

  if (smsConfigured()) {
    try {
      await sendSms(phone, `Votre code FAST : ${code} (valide 10 min)`);
    } catch (err) {
      console.error('[requestPhoneCode] SMS send failed:', (err as Error).message);
      res.status(502).json({ code: 'SMS_SEND_FAILED', error: 'Impossible d\'envoyer le SMS. Réessayez.' });
      return;
    }
    res.json({ message: 'Code envoyé' });
    return;
  }

  // No SMS provider: fail safe in production, expose the code in dev/test.
  if (env.nodeEnv === 'production') {
    res.status(503).json({ code: 'SMS_UNAVAILABLE', error: 'Vérification SMS non configurée' });
    return;
  }
  res.json({ message: 'Code généré (mode développement)', devCode: code });
};

/** Verify the code — expires after 10 min, 5 attempts max. */
export const verifyPhoneCode = async (req: Request, res: Response): Promise<void> => {
  const data = phoneVerifySchema.parse(req.body);
  const phone = data.phone.trim();

  const record = await prisma.phoneVerification.findFirst({
    where: { phone, consumedAt: null, expiresAt: { gt: new Date() } },
    orderBy: { createdAt: 'desc' },
  });
  if (!record) {
    res.status(400).json({ code: 'CODE_EXPIRED', error: 'Code expiré. Demandez-en un nouveau.' });
    return;
  }
  if (record.attempts >= 5) {
    res.status(429).json({ error: 'Trop de tentatives. Demandez un nouveau code.' });
    return;
  }
  if (record.code !== data.code.trim()) {
    await prisma.phoneVerification.update({
      where: { id: record.id },
      data: { attempts: { increment: 1 } },
    });
    res.status(400).json({ code: 'INVALID_CODE', error: 'Code incorrect' });
    return;
  }

  await prisma.phoneVerification.update({
    where: { id: record.id },
    data: { consumedAt: new Date() },
  });
  await prisma.user.updateMany({ where: { phone }, data: { phoneVerified: true } });

  res.json({ verified: true });
};
