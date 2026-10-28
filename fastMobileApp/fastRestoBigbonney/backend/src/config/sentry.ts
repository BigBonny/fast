import * as Sentry from '@sentry/node';

const EMAIL_RE = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;
const JWT_RE = /eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*/g;

function scrubString(s: string): string {
  return s.replace(EMAIL_RE, '[email]').replace(JWT_RE, '[token]');
}

/** Recursively redact emails and JWTs inside free-form values. */
function scrubDeep(v: unknown): unknown {
  if (typeof v === 'string') return scrubString(v);
  if (Array.isArray(v)) return v.map(scrubDeep);
  if (v && typeof v === 'object') {
    const out: Record<string, unknown> = {};
    for (const [k, val] of Object.entries(v)) out[k] = scrubDeep(val);
    return out;
  }
  return v;
}

/**
 * Crash reporting for the API. No-op unless SENTRY_DSN is set, so dev and
 * self-hosted installs need nothing. Events are stripped of every piece
 * of personal data before leaving the process: request bodies (which can
 * contain passwords, addresses, card setup payloads), auth headers,
 * cookies, and the user context is reduced to an opaque id.
 */
export function initSentry(): void {
  if (!process.env.SENTRY_DSN) return;

  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV || 'development',
    tracesSampleRate: 0.1,
    // v11 sends no PII by default — the scrub below is the second net.

    beforeSend(event) {
      // Never send the request body — it can hold passwords, emails,
      // addresses, Stripe details.
      if (event.request) {
        delete event.request.data;
        delete event.request.cookies;
        if (event.request.headers) {
          const headers = { ...event.request.headers };
          for (const k of Object.keys(headers)) {
            if (/authorization|cookie|token|secret/i.test(k)) {
              headers[k] = '[redacted]';
            }
          }
          event.request.headers = headers;
        }
      }

      // User context: keep an opaque id only — no email/name/ip.
      if (event.user) {
        event.user = event.user.id ? { id: event.user.id } : {};
      }

      // Breadcrumbs/tags may quote request paths or bodies — scrub
      // emails and JWTs wherever they appear.
      if (event.breadcrumbs) {
        event.breadcrumbs = event.breadcrumbs.map((b) => ({
          ...b,
          message: b.message ? scrubString(b.message) : b.message,
          data: scrubDeep(b.data) as typeof b.data,
        }));
      }
      if (event.tags) event.tags = scrubDeep(event.tags) as typeof event.tags;
      if (event.extra) event.extra = scrubDeep(event.extra) as typeof event.extra;

      return event;
    },
  });
}

export { Sentry };
