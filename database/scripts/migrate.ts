/**
 * npm run db:migrate
 *  1. Creates the database if it does not exist (when the user has the privilege).
 *  2. Runs every database/tables/*.sql file once, in file-name order (tracked in schema_migrations).
 *  3. Re-deploys every stored procedure: DROP PROCEDURE IF EXISTS + the file content.
 */
import { readFileSync } from 'node:fs';
import { basename } from 'node:path';
import { RowDataPacket } from 'mysql2/promise';
import { connect, dbEnv, procedureFiles, rel, sqlFiles, TABLES_DIR } from './lib';

async function main(): Promise<void> {
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

    const [appliedRows] = await conn.query<RowDataPacket[]>('SELECT file_name FROM schema_migrations');
    const applied = new Set(appliedRows.map((r) => String(r['file_name'])));

    let tables = 0;
    for (const file of sqlFiles(TABLES_DIR)) {
      const name = basename(file);
      if (applied.has(name)) continue;
      process.stdout.write(`  table  ${rel(file)} ... `);
      await conn.query(readFileSync(file, 'utf8'));
      await conn.query('INSERT INTO schema_migrations (file_name) VALUES (?)', [name]);
      tables++;
      console.log('ok');
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
