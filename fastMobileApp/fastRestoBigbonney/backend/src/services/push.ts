import admin from 'firebase-admin';
import { prisma } from './prisma';

// Firebase Admin is configured entirely through env vars so no credentials
// live in the repo:
//   FIREBASE_PROJECT_ID    - Firebase project id
//   FIREBASE_CLIENT_EMAIL  - service account client_email
//   FIREBASE_PRIVATE_KEY   - service account private_key (PEM, \n escaped)
// When they are absent (local dev without a project), all sends no-op.
let app: admin.app.App | null | undefined;

function messaging(): admin.messaging.Messaging | null {
  if (app === undefined) {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKey = process.env.FIREBASE_PRIVATE_KEY;
    app = projectId && clientEmail && privateKey
      ? admin.initializeApp({
          credential: admin.credential.cert({
            projectId,
            clientEmail,
            privateKey: privateKey.replace(/\\n/g, '\n'),
          }),
        })
      : null;
  }
  return app ? admin.messaging(app) : null;
}

const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

export async function sendPushToUser(
  userId: string,
  payload: { title?: string | null; body?: string | null; data?: Record<string, string> },
): Promise<void> {
  const fcm = messaging();
  if (!fcm) return;
  const devices = await prisma.deviceToken.findMany({
    where: { userId },
    select: { id: true, token: true },
  });
  if (!devices.length) return;

  const message = {
    notification: { title: payload.title ?? 'FAST', body: payload.body ?? '' },
    data: payload.data ?? {},
    tokens: devices.map((d) => d.token),
    android: { priority: 'high' as const },
    apns: { payload: { aps: { sound: 'default' } } },
  };

  const result = await fcm.sendEachForMulticast(message);
  const deadIds = result.responses
    .map((r, i) => (!r.success && r.error && DEAD_TOKEN_CODES.has(r.error.code) ? devices[i].id : null))
    .filter((id): id is string => !!id);
  if (deadIds.length) {
    await prisma.deviceToken.deleteMany({ where: { id: { in: deadIds } } });
  }
}
