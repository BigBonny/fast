import { waitUntil } from '@vercel/functions';
import { prisma } from './prisma';
import { sendPushToUser } from './push';

/**
 * How users hear about changes: Firebase Cloud Messaging push, plus the
 * app's own polling. There is no WebSocket channel — Socket.IO was removed
 * because a Vercel serverless function can't hold a persistent connection,
 * so it never ran in production.
 *
 * Pushes are sent after the HTTP response. `waitUntil` tells Vercel to keep
 * the function alive until they finish; without it the function can be
 * frozen as soon as the response is sent and the push is lost. Outside
 * Vercel (local dev, tests) the promise simply runs on its own.
 */
function runAfterResponse(task: Promise<unknown>): void {
  waitUntil(task.catch((err) => console.error('[FCM] send failed:', err)));
}

type PushableNotification = {
  title?: string | null;
  body?: string | null;
  type?: string | null;
  orderId?: string | null;
} | null;

function pushPayload(notification: unknown) {
  const n = notification as PushableNotification;
  return {
    title: n?.title,
    body: n?.body,
    data: {
      type: n?.type ?? '',
      ...(n?.orderId ? { orderId: n.orderId } : {}),
    },
  };
}

/** Push a stored notification to one user's devices. */
export function safeEmitNotificationToUser(userId: string, notification: unknown): void {
  runAfterResponse(sendPushToUser(userId, pushPayload(notification)));
}

/**
 * Push a restaurant-side notification to the owner AND every staff/guest
 * account assigned to the restaurant. The stored Notification row stays on
 * the owner (their inbox); staff devices get the push so the kitchen hears
 * about new orders, en-route clients and cancellations.
 */
export function notifyRestaurantTeam(
  restaurantId: string,
  ownerId: string,
  notification: unknown,
): void {
  const payload = pushPayload(notification);
  runAfterResponse(
    (async () => {
      const staff = await prisma.restaurantStaff.findMany({
        where: { restaurantId },
        select: { userId: true },
      });
      const recipients = new Set([ownerId, ...staff.map((s) => s.userId)]);
      await Promise.all([...recipients].map((id) => sendPushToUser(id, payload)));
    })(),
  );
}
