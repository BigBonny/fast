import { OrderStatus } from '@prisma/client';

const VALID_TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  PLACED: ['PREPARING', 'CANCELLED'],
  PREPARING: ['READY_FOR_PICKUP', 'CANCELLED'],
  READY_FOR_PICKUP: ['COMPLETED', 'CANCELLED'],
  COMPLETED: [],
  CANCELLED: [],
};

/**
 * A status may only move forward along the table above. Same-status
 * "transitions" are NOT valid: re-applying COMPLETED used to grant loyalty
 * points and send notifications again each time. Callers that want
 * idempotent retries should short-circuit on `from === to` themselves.
 */
export function isValidStatusTransition(from: OrderStatus, to: OrderStatus): boolean {
  return VALID_TRANSITIONS[from]?.includes(to) ?? false;
}

export const STATUS_LABELS: Record<string, string> = {
  PREPARING: 'Préparation commencée',
  READY_FOR_PICKUP: 'Repas prêt !',
  COMPLETED: 'Commande récupérée',
  CANCELLED: 'Commande annulée',
};
