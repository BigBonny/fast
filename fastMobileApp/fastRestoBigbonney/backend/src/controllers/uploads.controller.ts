import { Request, Response } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import os from 'os';
import crypto from 'crypto';
import { env } from '../config/env';
import { createSignedUpload, storeMedia } from '../services/storage';

// On read-only filesystems (Vercel functions), fall back to the only
// writable location — /tmp. Note: /tmp is ephemeral, so durable media
// storage still needs an external bucket (S3/Cloudinary) later.
function ensureUploadDir(): string {
  const candidates = [
    path.resolve(env.uploadDir),
    path.join(os.tmpdir(), 'fast-uploads'),
  ];
  for (const dir of candidates) {
    try {
      fs.mkdirSync(dir, { recursive: true });
      return dir;
    } catch {
      // EROFS / EACCES — try the next candidate
    }
  }
  return candidates[candidates.length - 1];
}

export const uploadDir = ensureUploadDir();

const ALLOWED_MIME = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/heic',
  'image/heif',
  'video/mp4',
  'video/quicktime',
  'video/webm',
  'video/3gpp',
  'video/x-m4v',
]);

const EXT_FOR: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
  'image/heic': '.heic',
  'image/heif': '.heif',
  'video/mp4': '.mp4',
  'video/quicktime': '.mov',
  'video/webm': '.webm',
  'video/3gpp': '.3gp',
  'video/x-m4v': '.m4v',
};

const MAX_UPLOAD_BYTES = 40 * 1024 * 1024;

export const mediaUpload = multer({
  // Buffer in memory, then hand off to durable storage (services/storage).
  storage: multer.memoryStorage(),
  // 40 MB — short dish videos must fit; anything larger should be a link.
  limits: { fileSize: MAX_UPLOAD_BYTES },
  fileFilter: (_req, file, cb) => {
    if (!ALLOWED_MIME.has(file.mimetype)) {
      cb(new Error('Type de fichier non supporté'));
      return;
    }
    cb(null, true);
  },
});

export const uploadMedia = async (req: Request, res: Response): Promise<void> => {
  const file = req.file;
  if (!file) {
    res.status(400).json({ error: 'Aucun fichier reçu' });
    return;
  }
  const ext =
    EXT_FOR[file.mimetype] ?? path.extname(file.originalname).toLowerCase();
  const filename = `${Date.now()}-${crypto.randomBytes(6).toString('hex')}${ext}`;
  try {
    const url = await storeMedia(file.buffer, filename, file.mimetype, uploadDir);
    res.status(201).json({ url });
  } catch (err) {
    console.error('[uploads]', (err as Error).message);
    res
      .status(502)
      .json({ error: 'Stockage du fichier indisponible. Réessayez.' });
  }
};

/**
 * Step one of a direct upload: the client says what it will send and gets
 * a one-time URL to PUT the file to, plus the public URL to save. Answers
 * 501 when storage isn't configured, so the client falls back to POST /.
 */
export const signUpload = async (req: Request, res: Response): Promise<void> => {
  const contentType = String(req.body?.contentType ?? '').toLowerCase();
  const size = Number(req.body?.size);
  if (!ALLOWED_MIME.has(contentType)) {
    res.status(400).json({ error: 'Type de fichier non supporté' });
    return;
  }
  if (!Number.isFinite(size) || size <= 0 || size > MAX_UPLOAD_BYTES) {
    res.status(413).json({ error: 'Fichier trop volumineux (40 Mo maximum)' });
    return;
  }
  const filename = `${Date.now()}-${crypto.randomBytes(6).toString('hex')}${EXT_FOR[contentType]}`;
  try {
    const signed = await createSignedUpload(filename);
    if (!signed) {
      res.status(501).json({ error: 'Envoi direct indisponible' });
      return;
    }
    res.status(201).json(signed);
  } catch (err) {
    console.error('[uploads]', (err as Error).message);
    res.status(502).json({ error: 'Stockage du fichier indisponible. Réessayez.' });
  }
};
