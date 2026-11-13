import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { prisma } from '../services/prisma';
import { env } from '../config/env';
import { registerSchema, loginSchema, updateProfileSchema, changePasswordSchema, phoneRequestSchema, phoneVerifySchema, emailVerifySchema } from '../utils/validation';
import { mailConfigured, sendMail, verificationEmail } from '../services/mailer';
import { toE164 } from '../utils/phone';
import crypto from 'crypto';
import { hitRateLimit, peekRateLimit, resetRateLimit } from '../services/rateLimitStore';

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

  // The phone counts as verified only if a code for it was confirmed during
  // this signup (the last 30 minutes).
  const phoneVerified = data.phone
    ? (await prisma.phoneVerification.count({
        where: {
          phone: toE164(data.phone) ?? data.phone.trim(),
          consumedAt: { gt: new Date(Date.now() - 30 * 60_000) },
        },
      })) > 0
    : false;

  const user = await prisma.user.create({
    data: {
      email: data.email,
      password: hashedPassword,
      name: data.name,
      phone: data.phone,
      role: data.role,
      phoneVerified,
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
    user: { id: user.id, name: user.name, email: user.email, phone: user.phone, role: user.role, points: user.points, emailVerified: user.emailVerified, phoneVerified: user.phoneVerified, driverProfile: user.driverProfile, restaurantId, staffRole },
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

/**
 * Wrong passwords are throttled per IP *and* account, never by locking the
 * account itself: a hard lock lets anyone lock a victim out just by typing
 * their email five times.
 *
 * - same IP + same account: `maxFailedLogins` tries per `lockoutMinutes`;
 * - same account from any IP: a much higher ceiling per hour, which only a
 *   distributed guessing attack reaches.
 */
const ACCOUNT_FAILURE_CEILING = 50;
export function loginThrottleKeys(email: string, ip: string): { ipAccount: string; account: string } {
  const normalized = email.trim().toLowerCase();
  return { ipAccount: `login:${ip}:${normalized}`, account: `login-acct:${normalized}` };
}

export const login = async (req: Request, res: Response): Promise<void> => {
  const data = loginSchema.parse(req.body);
  const keys = loginThrottleKeys(data.email, req.ip ?? '');

  const [ipFailures, accountFailures] = await Promise.all([
    peekRateLimit(keys.ipAccount),
    peekRateLimit(keys.account),
  ]);
  if (ipFailures >= env.maxFailedLogins || accountFailures >= ACCOUNT_FAILURE_CEILING) {
    res.status(429).json({ error: `Trop de tentatives. Réessayez dans ${env.lockoutMinutes} minutes.` });
    return;
  }

  const user = await findUserByEmail(data.email);
  const valid = user ? await bcrypt.compare(data.password, user.password) : false;
  if (!user || !valid) {
    // Unknown emails count too, so the reply never reveals which exist.
    await Promise.all([
      hitRateLimit(keys.ipAccount, env.lockoutMinutes * 60_000),
      hitRateLimit(keys.account, 60 * 60_000),
    ]);
    res.status(401).json({ error: 'Email ou mot de passe incorrect' });
    return;
  }

  await resetRateLimit(keys.ipAccount);

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
    user: { id: user.id, name: user.name, email: user.email, phone: user.phone, role: ctx.role, points: user.points, emailVerified: user.emailVerified, phoneVerified: user.phoneVerified, driverProfile: user.driverProfile, restaurant: user.restaurant, restaurantId, staffRole },
  });
};

// Social sign-up may only self-assign the roles email registration allows
// (registerSchema) — never ADMIN/STAFF/GUEST from a client-supplied body.
// Keep in sync with registerSchema.role. LIVREUR is excluded on purpose.
const SELF_SERVICE_ROLES = ['CLIENT', 'RESTAURANT'] as const;
export function selfServiceRole(role: unknown): (typeof SELF_SERVICE_ROLES)[number] {
  return SELF_SERVICE_ROLES.find((r) => r === role) ?? 'CLIENT';
}

/**
 * Google's tokeninfo returns `email_verified` as the string "true" (and
 * sometimes as a boolean). Without this check, a Google account holding an
 * unverified address could sign in as the existing FAST user who owns it,
 * because accounts are matched by email.
 */
export function isGoogleEmailVerified(payload: { email_verified?: unknown }): boolean {
  return payload.email_verified === true || payload.email_verified === 'true';
}

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
    email_verified?: string | boolean;
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
  if (!isGoogleEmailVerified(payload)) {
    res.status(401).json({ error: 'Adresse email Google non vérifiée' });
    return;
  }

  const googleEmail = payload.email.trim().toLowerCase();
  let user = await findUserByEmail(googleEmail);
  if (!user) {
    user = await prisma.user.create({
      data: {
        email: googleEmail,
        name: payload.name?.trim() || googleEmail.split('@')[0],
        // Unusable random password: Google accounts sign in via Google only.
        password: await bcrypt.hash(crypto.randomBytes(32).toString('hex'), env.bcryptRounds),
        role: selfServiceRole(role),
        // Google only issues tokens for addresses it has verified.
        emailVerified: true,
      },
      include: userWithLinks,
    });
  } else if (!user.emailVerified && user.email.toLowerCase() === googleEmail) {
    user = await prisma.user.update({
      where: { id: user.id },
      data: { emailVerified: true },
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
    user: { id: user.id, name: user.name, email: user.email, phone: user.phone, role: ctx.role, points: user.points, emailVerified: user.emailVerified, phoneVerified: user.phoneVerified, driverProfile: user.driverProfile, restaurant: user.restaurant, restaurantId, staffRole },
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
          // Unusable random password: Apple accounts sign in via Apple only.
          password: await bcrypt.hash(crypto.randomBytes(32).toString('hex'), env.bcryptRounds),
          role: selfServiceRole(role),
          // Apple verifies the address (or relay) it puts in the token.
          emailVerified: Boolean(payload.email),
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
    emailVerified: user.emailVerified,
    phoneVerified: user.phoneVerified,
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
    // Otherwise the phone keeps receiving this account's pushes.
    prisma.deviceToken.deleteMany({ where: { userId } }),
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

  const current = await prisma.user.findUnique({
    where: { id: req.user!.userId },
    select: { email: true, password: true, phone: true },
  });
  if (!current) {
    res.status(404).json({ error: 'Utilisateur introuvable' });
    return;
  }
  // A new address or number has not been proven yet: the badge drops
  // back to "unverified" until a code sent to it is confirmed.
  const emailChanged = Boolean(data.email && data.email !== current.email.toLowerCase());
  // Compared in E.164 so "06 12…" vs "+336 12…" isn't seen as a change.
  const phoneChanged = Boolean(
    data.phone &&
      (toE164(data.phone) ?? data.phone.trim()) !==
        (toE164(current.phone) ?? (current.phone ?? '').trim()),
  );

  // Changing the login email takes the current password, so a stolen or
  // forgotten-open session can't take over the account.
  if (data.email) {
    if (emailChanged) {
      if (!data.currentPassword || !(await bcrypt.compare(data.currentPassword, current.password))) {
        res.status(403).json({ code: 'PASSWORD_REQUIRED', error: "Mot de passe actuel requis pour changer d'email" });
        return;
      }
      const existing = await findUserByEmail(data.email);
      if (existing && existing.id !== req.user!.userId) {
        res.status(409).json({ error: 'Cet email est déjà utilisé' });
        return;
      }
    }
  }

  const user = await prisma.user.update({
    where: { id: req.user!.userId },
    data: {
      ...(data.name && { name: data.name }),
      ...(data.email && { email: data.email }),
      ...(data.phone && { phone: data.phone }),
      ...(emailChanged && { emailVerified: false }),
      ...(phoneChanged && { phoneVerified: false }),
    },
  });

  res.json({ id: user.id, name: user.name, email: user.email, phone: user.phone, role: user.role, points: user.points, emailVerified: user.emailVerified, phoneVerified: user.phoneVerified });
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
  // Bumping tokenVersion signs out every other device (someone who knew the
  // old password). This device gets a fresh token so it stays signed in.
  const updated = await prisma.user.update({
    where: { id: req.user!.userId },
    data: { password: hashedPassword, tokenVersion: { increment: 1 } },
  });
  const token = jwt.sign(
    {
      userId: updated.id,
      role: req.user!.role,
      tokenVersion: updated.tokenVersion,
      restaurantId: req.user!.restaurantId,
      staffRole: req.user!.staffRole,
    },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn as string } as jwt.SignOptions,
  );

  res.json({ message: 'Mot de passe mis à jour', token });
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
  // Twilio only accepts E.164; codes are stored under that form too.
  const phone = toE164(data.phone);
  if (!phone) {
    res.status(400).json({ code: 'INVALID_PHONE', error: 'Numéro de téléphone invalide' });
    return;
  }

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

type CodeCheck = 'OK' | 'EXPIRED' | 'TOO_MANY' | 'INVALID';

/** Checks and consumes the latest SMS code for `phone`. */
async function consumePhoneCode(phone: string, code: string): Promise<CodeCheck> {
  const record = await prisma.phoneVerification.findFirst({
    where: { phone, consumedAt: null, expiresAt: { gt: new Date() } },
    orderBy: { createdAt: 'desc' },
  });
  if (!record) return 'EXPIRED';
  if (record.attempts >= 5) return 'TOO_MANY';
  if (!codesMatch(record.code, code.trim())) {
    await prisma.phoneVerification.update({
      where: { id: record.id },
      data: { attempts: { increment: 1 } },
    });
    return 'INVALID';
  }
  await prisma.phoneVerification.update({
    where: { id: record.id },
    data: { consumedAt: new Date() },
  });
  return 'OK';
}

/** Constant-time comparison of two short codes or hashes. */
export function codesMatch(a: string, b: string): boolean {
  const ba = Buffer.from(a);
  const bb = Buffer.from(b);
  return ba.length === bb.length && crypto.timingSafeEqual(ba, bb);
}

function replyCodeError(res: Response, check: Exclude<CodeCheck, 'OK'>): void {
  if (check === 'EXPIRED') {
    res.status(400).json({ code: 'CODE_EXPIRED', error: 'Code expiré. Demandez-en un nouveau.' });
  } else if (check === 'TOO_MANY') {
    res.status(429).json({ code: 'TOO_MANY_ATTEMPTS', error: 'Trop de tentatives. Demandez un nouveau code.' });
  } else {
    res.status(400).json({ code: 'INVALID_CODE', error: 'Code incorrect' });
  }
}

/** Verify the code — expires after 10 min, 5 attempts max. */
export const verifyPhoneCode = async (req: Request, res: Response): Promise<void> => {
  const data = phoneVerifySchema.parse(req.body);
  const check = await consumePhoneCode(toE164(data.phone) ?? data.phone.trim(), data.code);
  if (check !== 'OK') {
    replyCodeError(res, check);
    return;
  }
  // Not applied to existing accounts here: anyone can type a number, so
  // marking every account that uses it would verify strangers. The signup
  // that follows reads this confirmed code (see register); signed-in users
  // go through confirmAccountPhone instead.
  res.json({ verified: true });
};

/**
 * Signed-in variant: the code proves this user holds the number, so the
 * number becomes the account's phone and is marked verified.
 */
export const confirmAccountPhone = async (req: Request, res: Response): Promise<void> => {
  const data = phoneVerifySchema.parse(req.body);
  // Saved as typed (that's what the profile shows); matched in E.164.
  const phone = data.phone.trim();
  const check = await consumePhoneCode(toE164(phone) ?? phone, data.code);
  if (check !== 'OK') {
    replyCodeError(res, check);
    return;
  }
  const user = await prisma.user.update({
    where: { id: req.user!.userId },
    data: { phone, phoneVerified: true },
  });
  res.json({ verified: true, phone: user.phone, phoneVerified: user.phoneVerified });
};

// ─── Email verification (6-digit code by email) ─────────────

const EMAIL_CODE_TTL_MS = 10 * 60_000;

/** Codes are stored hashed, salted with the account id. */
export function hashEmailCode(userId: string, code: string): string {
  return crypto.createHash('sha256').update(`${userId}:${code}`).digest('hex');
}

/** Send a code to the account's current email. 60 s between sends, 5/hour. */
export const requestEmailCode = async (req: Request, res: Response): Promise<void> => {
  const userId = req.user!.userId;
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { email: true, emailVerified: true },
  });
  if (!user) {
    res.status(404).json({ error: 'Utilisateur introuvable' });
    return;
  }
  if (user.emailVerified) {
    res.json({ alreadyVerified: true });
    return;
  }
  if (user.email.endsWith('.invalid') || user.email.endsWith('privaterelay.appleid.local')) {
    res.status(400).json({ code: 'EMAIL_UNDELIVERABLE', error: 'Cette adresse ne peut pas recevoir d\'email.' });
    return;
  }

  const recent = await prisma.emailVerification.findFirst({
    where: { userId },
    orderBy: { createdAt: 'desc' },
  });
  if (recent && Date.now() - recent.createdAt.getTime() < 60_000) {
    res.status(429).json({ code: 'RESEND_TOO_SOON', error: 'Un code vient d\'être envoyé. Patientez 60 secondes.' });
    return;
  }
  const hourlyCount = await prisma.emailVerification.count({
    where: { userId, createdAt: { gte: new Date(Date.now() - 3600_000) } },
  });
  if (hourlyCount >= 5) {
    res.status(429).json({ code: 'TOO_MANY_CODES', error: 'Trop de codes demandés. Réessayez dans une heure.' });
    return;
  }

  if (!mailConfigured() && env.nodeEnv === 'production') {
    res.status(503).json({ code: 'MAIL_UNAVAILABLE', error: 'Vérification email non configurée' });
    return;
  }

  const code = crypto.randomInt(100000, 1000000).toString();
  await prisma.emailVerification.create({
    data: {
      userId,
      email: user.email,
      codeHash: hashEmailCode(userId, code),
      expiresAt: new Date(Date.now() + EMAIL_CODE_TTL_MS),
    },
  });

  if (mailConfigured()) {
    try {
      const mail = verificationEmail(code);
      await sendMail(user.email, mail.subject, mail.html, mail.text);
    } catch (err) {
      console.error('[requestEmailCode] send failed:', (err as Error).message);
      res.status(502).json({ code: 'MAIL_SEND_FAILED', error: 'Impossible d\'envoyer l\'email. Réessayez.' });
      return;
    }
    res.json({ message: 'Code envoyé', email: user.email });
    return;
  }
  // No provider outside production: hand the code back so dev builds work.
  res.json({ message: 'Code généré (mode développement)', email: user.email, devCode: code });
};

/** Confirm the emailed code — 10 min validity, 5 attempts per code. */
export const verifyEmailCode = async (req: Request, res: Response): Promise<void> => {
  const data = emailVerifySchema.parse(req.body);
  const userId = req.user!.userId;
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { email: true } });
  if (!user) {
    res.status(404).json({ error: 'Utilisateur introuvable' });
    return;
  }
  const record = await prisma.emailVerification.findFirst({
    // A code sent to a previous address no longer proves anything.
    where: { userId, email: user.email, consumedAt: null, expiresAt: { gt: new Date() } },
    orderBy: { createdAt: 'desc' },
  });
  if (!record) {
    replyCodeError(res, 'EXPIRED');
    return;
  }
  if (record.attempts >= 5) {
    replyCodeError(res, 'TOO_MANY');
    return;
  }
  if (!codesMatch(record.codeHash, hashEmailCode(userId, data.code))) {
    await prisma.emailVerification.update({
      where: { id: record.id },
      data: { attempts: { increment: 1 } },
    });
    replyCodeError(res, 'INVALID');
    return;
  }
  await prisma.$transaction([
    prisma.emailVerification.update({ where: { id: record.id }, data: { consumedAt: new Date() } }),
    prisma.user.update({ where: { id: userId }, data: { emailVerified: true } }),
  ]);
  res.json({ verified: true, emailVerified: true });
};
