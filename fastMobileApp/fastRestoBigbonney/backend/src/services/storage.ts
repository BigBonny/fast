import fs from 'fs';
import path from 'path';
import { env } from '../config/env';

/**
 * Durable media storage. Vercel functions only have an ephemeral /tmp, so
 * anything written to disk there vanishes on the next cold start. When
 * SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY are set, files go to the public
 * Supabase Storage bucket and an absolute https URL is returned. Without
 * them (local dev) we fall back to the upload directory + `/uploads/…`.
 */
export const storageConfigured = (): boolean =>
  Boolean(env.supabaseUrl && env.supabaseServiceRoleKey);

export async function storeMedia(
  buffer: Buffer,
  filename: string,
  mimeType: string,
  localDir: string,
): Promise<string> {
  if (storageConfigured()) {
    const base = env.supabaseUrl.replace(/\/$/, '');
    const objectPath = `${env.supabaseBucket}/${filename}`;
    const resp = await fetch(`${base}/storage/v1/object/${objectPath}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.supabaseServiceRoleKey}`,
        apikey: env.supabaseServiceRoleKey,
        'Content-Type': mimeType,
        'x-upsert': 'false',
        'cache-control': '31536000',
      },
      body: new Uint8Array(buffer),
    });
    if (!resp.ok) {
      const text = await resp.text();
      throw new Error(`Storage upload failed: ${resp.status} ${text.slice(0, 200)}`);
    }
    return `${base}/storage/v1/object/public/${objectPath}`;
  }

  fs.mkdirSync(localDir, { recursive: true });
  fs.writeFileSync(path.join(localDir, filename), buffer);
  return `/uploads/${filename}`;
}

/**
 * Signed upload URL for Supabase Storage, so the app sends the file
 * straight to the bucket. Files can't pass through the API on Vercel:
 * a function request body is capped at about 4.5 MB, far below a short
 * dish video. Returns null when storage isn't configured (local dev).
 */
export async function createSignedUpload(
  filename: string,
): Promise<{ uploadUrl: string; publicUrl: string } | null> {
  if (!storageConfigured()) return null;
  const base = env.supabaseUrl.replace(/\/$/, '');
  const objectPath = `${env.supabaseBucket}/${filename}`;
  const resp = await fetch(`${base}/storage/v1/object/upload/sign/${objectPath}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.supabaseServiceRoleKey}`,
      apikey: env.supabaseServiceRoleKey,
      'Content-Type': 'application/json',
    },
    body: '{}',
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Storage sign failed: ${resp.status} ${text.slice(0, 200)}`);
  }
  const { url } = (await resp.json()) as { url?: string };
  if (!url) throw new Error('Storage sign failed: no url');
  return {
    uploadUrl: `${base}/storage/v1${url.startsWith('/') ? url : `/${url}`}`,
    publicUrl: `${base}/storage/v1/object/public/${objectPath}`,
  };
}
