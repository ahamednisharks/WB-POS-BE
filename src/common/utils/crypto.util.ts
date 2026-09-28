import { createCipheriv, createDecipheriv, createHmac, randomBytes } from 'node:crypto';

const ALGO = 'aes-256-gcm';
const VERSION = 'v1';

function keyBuffer(hexKey: string): Buffer {
  const key = Buffer.from(hexKey, 'hex');
  if (key.length !== 32) throw new Error('AES key must be 32 bytes (64 hex characters)');
  return key;
}

/** AES-256-GCM. Output: v1.<iv>.<tag>.<ciphertext> (base64url parts). */
export function encrypt(plain: string, hexKey: string): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv(ALGO, keyBuffer(hexKey), iv);
  const ct = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return [VERSION, iv.toString('base64url'), tag.toString('base64url'), ct.toString('base64url')].join('.');
}

export function decrypt(token: string, hexKey: string): string {
  const [version, iv, tag, ct] = token.split('.');
  if (version !== VERSION || !iv || !tag || ct === undefined) throw new Error('Unsupported ciphertext');
  const decipher = createDecipheriv(ALGO, keyBuffer(hexKey), Buffer.from(iv, 'base64url'));
  decipher.setAuthTag(Buffer.from(tag, 'base64url'));
  return Buffer.concat([decipher.update(Buffer.from(ct, 'base64url')), decipher.final()]).toString('utf8');
}

/** Deterministic keyed hash, used to detect duplicate Aadhaar numbers without decrypting. */
export function keyedHash(plain: string, hexKey: string): string {
  return createHmac('sha256', keyBuffer(hexKey)).update(plain).digest('hex');
}

export function maskTail(value: string | null | undefined, visible = 4): string {
  if (!value) return '';
  const tail = value.slice(-visible);
  return `${'X'.repeat(Math.max(0, value.length - visible))}${tail}`;
}
