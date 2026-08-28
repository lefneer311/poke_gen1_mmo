import { createHash } from 'node:crypto';
import { promises as fs } from 'node:fs';
import * as path from 'node:path';
import postgres from 'postgres';

export interface Migration {
  version: string;
  sql: string;
  checksum: string;
}

export async function loadMigrations(directory: string): Promise<Migration[]> {
  const names = (await fs.readdir(directory))
    .filter((name) => /^\d{3}_[a-z0-9_]+\.sql$/.test(name))
    .sort();

  return Promise.all(names.map(async (name) => {
    const sql = await fs.readFile(path.join(directory, name), 'utf8');
    return {
      version: name.slice(0, -4),
      sql,
      checksum: createHash('sha256').update(sql).digest('hex'),
    };
  }));
}

export async function runMigrations(connectionString: string, directory: string): Promise<void> {
  const sql = postgres(connectionString, { max: 1 });
  try {
    await sql`SELECT pg_advisory_lock(hashtext('poke_gen1_mmo_migrations'))`;
    for (const migration of await loadMigrations(directory)) {
      const result = await sql<{ checksum: string | null }[]>`
        SELECT checksum FROM mmo.schema_migrations WHERE version = ${migration.version}
      `.catch((error: unknown) => {
        if (migration.version === '001_foundation') return [];
        throw error;
      });
      if (result[0]) {
        if (result[0].checksum !== migration.checksum) {
          throw new Error(`Migration ${migration.version} has changed after being applied`);
        }
        continue;
      }
      await sql.unsafe(migration.sql);
      await sql`UPDATE mmo.schema_migrations SET checksum = ${migration.checksum} WHERE version = ${migration.version}`;
    }
  } finally {
    await sql`SELECT pg_advisory_unlock(hashtext('poke_gen1_mmo_migrations'))`.catch(() => undefined);
    await sql.end({ timeout: 5 });
  }
}
