import { Request, Response } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import os from 'os';
import crypto from 'crypto';
import { env } from '../config/env';

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

export const mediaUpload = multer({
  storage: multer.diskStorage({
    destination: uploadDir,
    filename: (_req, file, cb) => {
      const ext =
        EXT_FOR[file.mimetype] ?? path.extname(file.originalname).toLowerCase();
      cb(null, `${Date.now()}-${crypto.randomBytes(6).toString('hex')}${ext}`);
    },
  }),
  // 40 MB — short dish videos must fit; anything larger should be a link.
  limits: { fileSize: 40 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!ALLOWED_MIME.has(file.mimetype)) {
      cb(new Error('Type de fichier non supporté'));
      return;
    }
    cb(null, true);
  },
});

export const uploadMedia = (req: Request, res: Response): void => {
  const file = req.file;
  if (!file) {
    res.status(400).json({ error: 'Aucun fichier reçu' });
    return;
  }
  res.status(201).json({ url: `/uploads/${file.filename}` });
};
