import { env } from '../config/env';

/** True when a mail provider is configured (RESEND_API_KEY + MAIL_FROM). */
export const mailConfigured = (): boolean => Boolean(env.resendApiKey && env.mailFrom);

/** Sends one transactional email through Resend's HTTP API. */
export async function sendMail(to: string, subject: string, html: string, text: string): Promise<void> {
  const resp = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.resendApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ from: env.mailFrom, to: [to], subject, html, text }),
    signal: AbortSignal.timeout(10000),
  });
  if (!resp.ok) {
    const body = await resp.text();
    throw new Error(`Mail provider error: ${resp.status} ${body.slice(0, 200)}`);
  }
}

/** The verification-code email, in the app's brand colours. */
export function verificationEmail(code: string): { subject: string; html: string; text: string } {
  const subject = `Votre code FAST : ${code}`;
  const text = `Votre code de vérification FAST est ${code}. Il est valable 10 minutes.\n\nSi vous n'avez pas demandé ce code, ignorez cet email.`;
  const html = `<!doctype html><html><body style="margin:0;background:#14081f;font-family:Arial,Helvetica,sans-serif">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="padding:32px 16px"><tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:440px;background:#ffffff;border-radius:20px;overflow:hidden">
<tr><td style="background:linear-gradient(135deg,#FF7A00,#FF1F6F,#9B1FE8);background-color:#FF1F6F;padding:20px 24px;color:#ffffff;font-size:24px;font-weight:900;font-style:italic">FAST</td></tr>
<tr><td style="padding:28px 24px;color:#17171B">
<p style="margin:0 0 12px;font-size:16px">Votre code de vérification :</p>
<p style="margin:0 0 20px;font-size:34px;font-weight:900;letter-spacing:8px">${code}</p>
<p style="margin:0;font-size:13px;color:#5b5b66">Valable 10 minutes. Si vous n'avez pas demandé ce code, ignorez cet email.</p>
</td></tr></table>
<p style="color:#b9a9c9;font-size:12px;margin:16px 0 0">FAST — Chaque minute compte</p>
</td></tr></table></body></html>`;
  return { subject, html, text };
}
