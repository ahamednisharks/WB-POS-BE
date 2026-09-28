import { BadRequestException, Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import { existsSync, mkdirSync, statSync } from 'node:fs';
import { writeFile } from 'node:fs/promises';
import { basename, extname, join } from 'node:path';
import { AppConfig } from '../../config/configuration';

export type UploadKind = 'image' | 'document' | 'invoice';

/** File as the frontend models it (ID proof, invoice copy). `dataUrl` is a data: URL on upload, a link on read. */
export interface UploadedFileInfo {
  name: string;
  type: string;
  size: number;
  dataUrl: string;
}

export interface StoredFile {
  url: string;
  name: string;
}

const MIME_EXT: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'application/pdf': '.pdf',
};

const EXT_MIME: Record<string, string> = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.pdf': 'application/pdf' };

const ALLOWED: Record<UploadKind, string[]> = {
  image: ['image/jpeg', 'image/jpg', 'image/png'],
  document: ['application/pdf', 'image/jpeg', 'image/jpg', 'image/png'],
  invoice: ['application/pdf', 'image/jpeg', 'image/jpg', 'image/png'],
};

const FOLDER: Record<UploadKind, string> = { image: 'images', document: 'documents', invoice: 'documents' };

/**
 * Stores uploads on disk under UPLOAD_DIR and converts between what the DB keeps (a relative
 * `/uploads/...` path) and what clients see (an absolute URL they can load cross-origin).
 */
@Injectable()
export class FileStorageService implements OnModuleInit {
  private readonly dir: string;
  private readonly publicUrl: string;
  private readonly limits: Record<UploadKind, number>;

  constructor(config: ConfigService<AppConfig, true>) {
    const uploads = config.get('uploads', { infer: true });
    this.dir = uploads.dir;
    this.publicUrl = config.get('publicUrl', { infer: true });
    this.limits = { image: uploads.maxImageMb, document: uploads.maxDocMb, invoice: uploads.maxInvoiceMb };
  }

  onModuleInit(): void {
    for (const folder of new Set(Object.values(FOLDER))) mkdirSync(join(this.dir, folder), { recursive: true });
  }

  get uploadDir(): string {
    return this.dir;
  }

  /** Saves raw bytes (multipart upload or decoded data URL) and returns the relative URL. */
  async saveBuffer(buffer: Buffer, mime: string, kind: UploadKind, field = 'file'): Promise<string> {
    const type = mime.toLowerCase();
    if (!ALLOWED[kind].includes(type)) {
      const allowed = kind === 'image' ? 'JPG or PNG' : 'PDF, JPG or PNG';
      throw new BadRequestException({ message: `File must be ${allowed}`, field });
    }
    const maxMb = this.limits[kind];
    if (buffer.length > maxMb * 1024 * 1024) {
      throw new BadRequestException({ message: `File must be ${maxMb} MB or smaller`, field });
    }
    const name = `${randomUUID()}${MIME_EXT[type] ?? ''}`;
    await writeFile(join(this.dir, FOLDER[kind], name), buffer);
    return `/uploads/${FOLDER[kind]}/${name}`;
  }

  /**
   * Normalises an image field from a request body:
   * data: URL -> saved to disk; our own absolute URL -> relative path; '' / null -> null.
   */
  async resolveImage(value: string | null | undefined, field = 'image'): Promise<string | null> {
    return this.resolveUrl(value, 'image', field);
  }

  async resolveFile(file: { name?: string; dataUrl: string } | null | undefined, kind: UploadKind, field: string): Promise<StoredFile | null> {
    if (!file || !file.dataUrl) return null;
    const url = await this.resolveUrl(file.dataUrl, kind, field);
    if (!url) return null;
    return { url, name: (file.name || basename(url)).slice(0, 150) };
  }

  /** Relative DB path -> absolute URL for clients. */
  publicLink(path: string | null | undefined): string | null {
    if (!path) return null;
    return path.startsWith('/uploads/') ? `${this.publicUrl}${path}` : path;
  }

  /** Builds the frontend's UploadedFile shape from what the DB stores. */
  fileInfo(path: string | null | undefined, name: string | null | undefined): UploadedFileInfo | null {
    if (!path) return null;
    const ext = extname(path).toLowerCase();
    let size = 0;
    if (path.startsWith('/uploads/')) {
      const local = join(this.dir, path.slice('/uploads/'.length));
      if (existsSync(local)) size = statSync(local).size;
    }
    return { name: name || basename(path), type: EXT_MIME[ext] ?? 'application/octet-stream', size, dataUrl: this.publicLink(path)! };
  }

  private async resolveUrl(value: string | null | undefined, kind: UploadKind, field: string): Promise<string | null> {
    const v = value?.trim();
    if (!v) return null;
    if (v.startsWith('data:')) {
      const m = /^data:([^;,]+)(;base64)?,(.*)$/s.exec(v);
      if (!m || !m[2]) throw new BadRequestException({ message: 'Invalid file data', field });
      return this.saveBuffer(Buffer.from(m[3], 'base64'), m[1], kind, field);
    }
    if (v.startsWith(`${this.publicUrl}/uploads/`)) return v.slice(this.publicUrl.length);
    if (v.startsWith('/uploads/')) return v;
    if (/^https?:\/\//i.test(v) && v.length <= 255) return v;
    throw new BadRequestException({ message: 'Invalid file reference', field });
  }
}
