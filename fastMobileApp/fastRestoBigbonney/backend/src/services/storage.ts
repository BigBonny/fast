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
