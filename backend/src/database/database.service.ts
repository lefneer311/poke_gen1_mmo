import { Injectable, OnApplicationShutdown } from '@nestjs/common';
import postgres, { Sql } from 'postgres';

function requiredDatabaseUrl(): string {
  const value = process.env.DATABASE_URL;
  if (!value) {
    throw new Error('DATABASE_URL is required');
  }
  return value;
}

function applicationRole(): string {
  const role = process.env.DATABASE_ROLE ?? 'mmo_app';
  if (!/^[a-z_][a-z0-9_]*$/.test(role)) throw new Error('DATABASE_ROLE is not a valid PostgreSQL role name');
  return role;
}

@Injectable()
export class DatabaseService implements OnApplicationShutdown {
  private readonly sql = postgres(requiredDatabaseUrl(), {
    max: Number(process.env.DATABASE_POOL_SIZE ?? 10),
    connect_timeout: Number(process.env.DATABASE_CONNECT_TIMEOUT_SECONDS ?? 5),
    idle_timeout: Number(process.env.DATABASE_IDLE_TIMEOUT_SECONDS ?? 30),
    connection: {
      application_name: 'poke_gen1_mmo_backend',
      options: `-c role=${applicationRole()}`,
    },
  });

  query<Row extends Record<string, unknown> = Record<string, unknown>>(
    text: string, values: readonly unknown[] = [],
  ): Promise<readonly Row[]> {
    return this.sql.unsafe<Row[]>(text, [...values]);
  }

  transaction<T>(work: (sql: Sql) => Promise<T>): Promise<T> {
    return this.sql.begin(work) as Promise<T>;
  }

  async assertHealthy(): Promise<void> {
    await this.sql`SELECT 1`;
  }

  async onApplicationShutdown(): Promise<void> {
    await this.sql.end({ timeout: 5 });
  }
}
