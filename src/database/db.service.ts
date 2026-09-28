/* eslint-disable @typescript-eslint/no-explicit-any */
import { Inject, Injectable, Logger, OnApplicationBootstrap, OnModuleDestroy } from '@nestjs/common';
import { Pool } from 'mysql2/promise';
import { MYSQL_POOL } from './db.constants';

/** Error thrown by mysql2, tagged with the procedure that raised it (for logs only). */
export interface SpError extends Error {
  code?: string;
  errno?: number;
  sqlState?: string;
  sqlMessage?: string;
  procName?: string;
}

/** The only class in src/ that talks to MySQL. Everything goes through stored procedures. */
@Injectable()
export class DbService implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly logger = new Logger('Database');

  constructor(@Inject(MYSQL_POOL) private readonly pool: Pool) {}

  /** Pings MySQL once at startup so the console shows whether the DB is reachable. */
  async onApplicationBootstrap(): Promise<void> {
    try {
      const conn = await this.pool.getConnection();
      const { host, port, database } = conn.config;
      await conn.ping();
      conn.release();
      this.logger.log(`DB connected successfully (${host}:${port}/${database})`);
    } catch (err) {
      this.logger.error(`DB connection failed: ${(err as Error).message}`);
    }
  }

  /** Calls a stored procedure and returns ONLY the result sets (arrays), in order. */
  async call<T = any>(procName: string, params: unknown[] = []): Promise<T[][]> {
    if (!/^sp_[a-z0-9_]+$/.test(procName)) throw new Error(`Invalid procedure name: ${procName}`);
    const placeholders = params.map(() => '?').join(',');
    try {
      const [results] = await this.pool.query(`CALL ${procName}(${placeholders})`, params);
      return (results as any[]).filter(Array.isArray) as T[][];
    } catch (err) {
      (err as SpError).procName = procName;
      throw err;
    }
  }

  /** Convenience: first row of first result set. */
  async callOne<T = any>(procName: string, params: unknown[] = []): Promise<T | null> {
    const sets = await this.call<T>(procName, params);
    return sets[0]?.[0] ?? null;
  }

  async onModuleDestroy(): Promise<void> {
    await this.pool.end();
  }
}
