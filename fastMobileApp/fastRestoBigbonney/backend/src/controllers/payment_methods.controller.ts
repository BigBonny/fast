import { Request, Response } from 'express';
import Stripe from 'stripe';
import { prisma } from '../services/prisma';
import { env } from '../config/env';

function paymentClient(res: Response): Stripe | null {
  if (!env.stripeSecretKey) {
    res.status(503).json({ code: 'PAYMENT_UNAVAILABLE', error: 'Les paiements ne sont pas configurés.' });
    return null;
  }
  return new Stripe(env.stripeSecretKey);
}

export async function getStripeCustomerId(stripe: Stripe, userId: string, create = false): Promise<string | null> {
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { stripeCustomerId: true, email: true, name: true } });
  if (!user) throw new Error('Utilisateur introuvable');
  if (user.stripeCustomerId) return user.stripeCustomerId;
  if (!create) return null;
  const customer = await stripe.customers.create({ email: user.email, name: user.name, metadata: { userId } }, { idempotencyKey: `fast-customer-${userId}` });
  await prisma.user.update({ where: { id: userId }, data: { stripeCustomerId: customer.id } });
  return customer.id;
}

export const listPaymentMethods = async (req: Request, res: Response): Promise<void> => {
  const stripe = paymentClient(res);
  if (!stripe) return;
  const customer = await getStripeCustomerId(stripe, req.user!.userId);
  if (!customer) {
    res.json([]);
    return;
  }
  const cards = await stripe.paymentMethods.list({ customer, type: 'card', limit: 100 });
  res.json(cards.data.map(method => ({
    id: method.id, brand: method.card?.brand, last4: method.card?.last4,
    expMonth: method.card?.exp_month, expYear: method.card?.exp_year,
  })));
};

export const setupPaymentMethod = async (req: Request, res: Response): Promise<void> => {
  const stripe = paymentClient(res);
  if (!stripe) return;
  const customer = await getStripeCustomerId(stripe, req.user!.userId, true);
  const returnUrl = `${env.publicBaseUrl}/api/payments/methods/return`;
  const session = await stripe.checkout.sessions.create({
    mode: 'setup', customer: customer!, currency: env.stripeCurrency,
    payment_method_types: ['card'],
    client_reference_id: req.user!.userId,
    metadata: { userId: req.user!.userId },
    success_url: returnUrl,
    cancel_url: `${returnUrl}?cancelled=1`,
  });
  res.status(201).json({ url: session.url });
};

export const removePaymentMethod = async (req: Request, res: Response): Promise<void> => {
  const stripe = paymentClient(res);
  if (!stripe) return;
  const id = req.params.id as string;
  if (!/^pm_[A-Za-z0-9]+$/.test(id)) {
    res.status(400).json({ error: 'Carte invalide' });
    return;
  }
  const customer = await getStripeCustomerId(stripe, req.user!.userId);
  if (!customer) {
    res.status(404).json({ error: 'Carte introuvable' });
    return;
  }
  const method = await stripe.paymentMethods.retrieve(id);
  const owner = typeof method.customer === 'string' ? method.customer : method.customer?.id;
  if (owner !== customer) {
    res.status(404).json({ error: 'Carte introuvable' });
    return;
  }
  await stripe.paymentMethods.detach(id);
  res.status(204).end();
};

export const paymentMethodReturnPage = (_req: Request, res: Response): void => {
  res.type('html').send('<!DOCTYPE html><html><head><meta charset="utf-8"><title>FAST</title><meta http-equiv="refresh" content="0;url=fast://cards/return"></head><body><p><a href="fast://cards/return">Retour dans FAST</a></p></body></html>');
};
