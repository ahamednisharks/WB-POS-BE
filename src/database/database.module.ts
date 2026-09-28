import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createPool, Pool } from 'mysql2/promise';
import { AppConfig } from '../config/configuration';
import { MYSQL_POOL } from './db.constants';
import { DbService } from './db.service';

@Global()
@Module({
  providers: [
    {
      provide: MYSQL_POOL,
      inject: [ConfigService],
      useFactory: (config: ConfigService<AppConfig, true>): Pool => {
        const db = config.get('db', { infer: true });
        const pool = createPool({
          host: db.host,
          port: db.port,
          user: db.user,
          password: db.password,
          database: db.database,
          connectionLimit: db.poolLimit,
          waitForConnections: true,
          timezone: '+05:30',
          dateStrings: true,
          decimalNumbers: true,
          namedPlaceholders: false,
          multipleStatements: false,
          charset: 'utf8mb4',
          // With a CA file the server certificate is verified; without one the link is encrypted only.
          ssl: db.ssl ? (db.sslCa ? { ca: readFileSync(resolve(db.sslCa), 'utf8') } : { rejectUnauthorized: false }) : undefined,
        });
        // The promise pool wraps a callback pool; its 'connection' event hands us the raw connection.
        pool.pool.on('connection', (conn) => {
          conn.query("SET time_zone = '+05:30'");
        });
        return pool;
      },
    },
    DbService,
  ],
  exports: [DbService],
})
export class DatabaseModule {}
