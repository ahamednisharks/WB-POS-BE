import { resolve } from 'node:path';

export interface AppConfig {
  port: number;
  nodeEnv: string;
  corsOrigins: string[];
  publicUrl: string;
  db: {
    host: string;
    port: number;
    user: string;
    password: string;
    database: string;
    poolLimit: number;
    /** TLS to the DB server (required by cloud hosts like Aiven). */
    ssl: boolean;
    /** Path to the server's CA certificate; when set, the certificate is verified. */
    sslCa: string;
  };
  jwt: {
    secret: string;
    expires: string;
    rememberExpires: string;
  };
  aesKey: string;
  uploads: {
    dir: string;
    maxImageMb: number;
    maxDocMb: number;
    maxInvoiceMb: number;
  };
}

export default (): AppConfig => {
  const e = process.env;
  const port = Number(e['PORT'] ?? 3000);
  return {
    port,
    nodeEnv: e['NODE_ENV'] ?? 'development',
    corsOrigins: (e['CORS_ORIGINS'] ?? '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
    publicUrl: (e['PUBLIC_URL'] ?? `http://localhost:${port}`).replace(/\/$/, ''),
    db: {
      host: e['DB_HOST'] ?? 'localhost',
      port: Number(e['DB_PORT'] ?? 3306),
      user: e['DB_USER'] ?? '',
      password: e['DB_PASSWORD'] ?? '',
      database: e['DB_NAME'] ?? 'wb_pos',
      poolLimit: Number(e['DB_POOL_LIMIT'] ?? 10),
      ssl: (e['DB_SSL'] ?? '').toLowerCase() === 'true',
      sslCa: e['DB_SSL_CA'] ?? '',
    },
    jwt: {
      secret: e['JWT_SECRET'] ?? '',
      expires: e['JWT_EXPIRES'] ?? '8h',
      rememberExpires: e['JWT_REMEMBER_EXPIRES'] ?? '7d',
    },
    aesKey: e['AES_KEY'] ?? '',
    uploads: {
      dir: resolve(e['UPLOAD_DIR'] ?? './uploads'),
      maxImageMb: Number(e['MAX_IMAGE_MB'] ?? 1),
      maxDocMb: Number(e['MAX_DOC_MB'] ?? 2),
      maxInvoiceMb: Number(e['MAX_INVOICE_MB'] ?? 5),
    },
  };
};
