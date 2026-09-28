import { config as loadEnv } from 'dotenv';
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';
import { createConnection, Connection } from 'mysql2/promise';

export const DB_DIR = resolve(__dirname, '..');
export const TABLES_DIR = join(DB_DIR, 'tables');
export const PROCEDURES_DIR = join(DB_DIR, 'procedures');
export const SEED_DIR = join(DB_DIR, 'seed');

loadEnv({ path: resolve(DB_DIR, '..', process.env['ENV_FILE'] ?? '.env') });

export interface DbEnv {
  host: string;
  port: number;
  user: string;
  password: string;
  database: string;
  ssl: boolean;
  sslCa: string;
}

export function dbEnv(): DbEnv {
  const e = process.env;
  return {
    host: e['DB_HOST'] ?? 'localhost',
    port: Number(e['DB_PORT'] ?? 3306),
    user: e['DB_USER'] ?? 'root',
    password: e['DB_PASSWORD'] ?? '',
    database: e['DB_NAME'] ?? 'wb_pos',
    ssl: (e['DB_SSL'] ?? '').toLowerCase() === 'true',
    sslCa: e['DB_SSL_CA'] ?? '',
  };
}

/** Admin-style connection used by the scripts (multi statements allowed for table files). */
export async function connect(withDatabase = true): Promise<Connection> {
  const env = dbEnv();
  const conn = await createConnection({
    host: env.host,
    port: env.port,
    user: env.user,
    password: env.password,
    database: withDatabase ? env.database : undefined,
    multipleStatements: true,
    timezone: '+05:30',
    dateStrings: true,
    decimalNumbers: true,
    charset: 'utf8mb4',
    ssl: env.ssl
      ? env.sslCa
        ? { ca: readFileSync(resolve(DB_DIR, '..', env.sslCa), 'utf8') }
        : { rejectUnauthorized: false }
      : undefined,
  });
  await conn.query("SET time_zone = '+05:30'");
  return conn;
}

export function sqlFiles(dir: string): string[] {
  if (!existsSync(dir)) return [];
  const out: string[] = [];
  for (const name of readdirSync(dir).sort()) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) out.push(...sqlFiles(full));
    else if (name.endsWith('.sql')) out.push(full);
  }
  return out;
}

const PROC_RE = /CREATE\s+PROCEDURE\s+`?([a-z0-9_]+)`?/i;

export interface ProcedureFile {
  file: string;
  name: string;
  sql: string;
}

export function procedureFiles(): ProcedureFile[] {
  return sqlFiles(PROCEDURES_DIR).map((file) => {
    const sql = readFileSync(file, 'utf8').trim();
    const match = PROC_RE.exec(sql);
    if (!match) throw new Error(`No CREATE PROCEDURE found in ${rel(file)}`);
    if (/^\s*DELIMITER\b/im.test(sql)) throw new Error(`${rel(file)} must not contain DELIMITER`);
    const count = sql.match(new RegExp(PROC_RE.source, 'gi'))?.length ?? 0;
    if (count !== 1) throw new Error(`${rel(file)} must contain exactly one CREATE PROCEDURE (found ${count})`);
    return { file, name: match[1], sql };
  });
}

export function rel(file: string): string {
  return relative(DB_DIR, file).replace(/\\/g, '/');
}
