import dotenv from 'dotenv';

dotenv.config();

function requireEnv(key: string): string {
  const val = process.env[key];
  if (!val) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return val;
}

const publicBaseUrl = (process.env.PUBLIC_BASE_URL || 'https://backend-six-iota-69.vercel.app').replace(/\/$/, '');

export const env = {
  port: parseInt(process.env.PORT || '3000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  databaseUrl: process.env.DATABASE_URL || '',
  jwtSecret: requireEnv('JWT_SECRET'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '24h',
  corsOrigin: process.env.CORS_ORIGIN || 'http://localhost:3000,http://localhost:5173',
  uploadDir: process.env.UPLOAD_DIR || './uploads',
  serviceFee: parseFloat(process.env.SERVICE_FEE || '1.50'),
  bcryptRounds: parseInt(process.env.BCRYPT_ROUNDS || '12', 10),
  maxFailedLogins: parseInt(process.env.MAX_FAILED_LOGINS || '5', 10),
  lockoutMinutes: parseInt(process.env.LOCKOUT_MINUTES || '15', 10),
  mistralApiKey: process.env.MISTRAL_API_KEY || '',
  geminiApiKey: process.env.GEMINI_API_KEY || '',
  twilioAccountSid: process.env.TWILIO_ACCOUNT_SID || '',
  twilioAuthToken: process.env.TWILIO_AUTH_TOKEN || '',
  twilioFromNumber: process.env.TWILIO_FROM_NUMBER || '',
  stripeSecretKey: process.env.STRIPE_SECRET_KEY || '',
  stripeWebhookSecret: process.env.STRIPE_WEBHOOK_SECRET || '',
  // Optional second secret for a "connected accounts" webhook destination —
  // Stripe signs account.* events of connected accounts with a different key.
  stripeConnectWebhookSecret: process.env.STRIPE_CONNECT_WEBHOOK_SECRET || '',
  stripeCurrency: process.env.STRIPE_CURRENCY || 'eur',
  publicBaseUrl,
  stripeSuccessUrl: process.env.STRIPE_SUCCESS_URL || `${publicBaseUrl}/api/payments/checkout/success?session_id={CHECKOUT_SESSION_ID}`,
  stripeCancelUrl: process.env.STRIPE_CANCEL_URL || `${publicBaseUrl}/api/payments/checkout/cancel`,
  stripeConnectReturnUrl: process.env.STRIPE_CONNECT_RETURN_URL || `${publicBaseUrl}/api/payments/connect/return`,
  stripeConnectRefreshUrl: process.env.STRIPE_CONNECT_REFRESH_URL || `${publicBaseUrl}/api/payments/connect/refresh`,
};
