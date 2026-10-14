/**
 * npm run migrate                     Full migration:
 *  1. Creates the database if it does not exist (when the user has the privilege).
 *  2. Runs every database/tables/*.sql file once, in file-name order (tracked in schema_migrations).
 *  3. Re-deploys every stored procedure: DROP PROCEDURE IF EXISTS + the file content.
 *
 * npm run migrate users [bills ...]   Only the named table files, run again even if already applied.
 *  A name is a table file without its number prefix (users -> 025_users.sql) or a table the file
 *  creates (bill_items -> 030_billing.sql). Table files are idempotent (CREATE TABLE IF NOT EXISTS,
 *  INSERT IGNORE), so this adds missing tables and seed rows but never changes existing ones.
 *  Stored procedures are not touched.
 */
import { readFileSync } from 'node:fs';
import { basename } from 'node:path';
import { Connection, RowDataPacket } from 'mysql2/promise';
import { connect, dbEnv, procedureFiles, rel, sqlFiles, TABLES_DIR } from './lib';

const CREATE_TABLE_RE = /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`?([a-z0-9_]+)`?/gi;

/** Table files picked by the command-line names, in file-name order. Unknown names fail before connecting. */
function selectTableFiles(names: string[]): string[] {
  const files = sqlFiles(TABLES_DIR).map((file) => ({
    file,
    key: basename(file, '.sql').replace(/^\d+_/, '').toLowerCase(),
    tables: [...readFileSync(file, 'utf8').matchAll(CREATE_TABLE_RE)].map((m) => m[1].toLowerCase()),
  }));
  const picked = new Set<string>();
  for (const name of names) {
    const wanted = name.toLowerCase();
    const hits = files.filter((f) => f.key === wanted || f.tables.includes(wanted));
    if (!hits.length) {
      throw new Error(
        `No table file matches "${name}". Use a table name or one of: ${files.map((f) => f.key).join(', ')}`,
      );
    }
    hits.forEach((f) => picked.add(f.file));
  }
  return files.map((f) => f.file).filter((file) => picked.has(file));
}

async function applyTableFile(conn: Connection, file: string): Promise<void> {
  process.stdout.write(`  table  ${rel(file)} ... `);
  try {
    await conn.query(readFileSync(file, 'utf8'));
  } catch (e) {
    console.log('failed');
    throw new Error(`Failed to apply ${rel(file)}: ${(e as Error).message}`);
  }
  await conn.query(
    'INSERT INTO schema_migrations (file_name) VALUES (?) ON DUPLICATE KEY UPDATE applied_at = CURRENT_TIMESTAMP',
    [basename(file)],
  );
  console.log('ok');
}

async function main(): Promise<void> {
  const names = process.argv.slice(2);
  const only = names.length ? selectTableFiles(names) : null;

  const env = dbEnv();
  const server = await connect(false);
  try {
    await server.query(
      `CREATE DATABASE IF NOT EXISTS \`${env.database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci`,
    );
  } catch (e) {
    console.warn(`Could not create database ${env.database} (${(e as Error).message}); assuming it exists.`);
  }
  await server.end();

  const conn = await connect(true);
  try {
    await conn.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
      file_name  VARCHAR(150) NOT NULL PRIMARY KEY,
      applied_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);

    if (only) {
      for (const file of only) await applyTableFile(conn, file);
      console.log(`Migration complete: ${only.length} table file(s) applied to ${env.database} (procedures not touched).`);
      return;
    }

    const [appliedRows] = await conn.query<RowDataPacket[]>('SELECT file_name FROM schema_migrations');
    const applied = new Set(appliedRows.map((r) => String(r['file_name'])));

    let tables = 0;
    for (const file of sqlFiles(TABLES_DIR)) {
      if (applied.has(basename(file))) continue;
      await applyTableFile(conn, file);
      tables++;
    }

    const procs = procedureFiles();
    const seen = new Map<string, string>();
    for (const p of procs) {
      const dup = seen.get(p.name);
      if (dup) throw new Error(`Procedure ${p.name} is defined in both ${dup} and ${rel(p.file)}`);
      seen.set(p.name, rel(p.file));
    }
    for (const p of procs) {
      try {
        await conn.query(`DROP PROCEDURE IF EXISTS \`${p.name}\``);
        await conn.query(p.sql);
      } catch (e) {
        throw new Error(`Failed to create ${p.name} (${rel(p.file)}): ${(e as Error).message}`);
      }
    }
    console.log(`Migration complete: ${tables} table file(s) applied, ${procs.length} procedure(s) deployed to ${env.database}.`);
  } finally {
    await conn.end();
  }
}

main().catch((e: unknown) => {
  console.error((e as Error).message);
  process.exit(1);
});
