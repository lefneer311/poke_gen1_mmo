import * as path from 'node:path';
import { runMigrations } from './migration-runner';

const connectionString = process.env.DATABASE_MIGRATION_URL ?? process.env.DATABASE_URL;
if (!connectionString) {
  throw new Error('DATABASE_MIGRATION_URL or DATABASE_URL is required');
}

const migrations = process.env.DATABASE_MIGRATIONS_DIR
  ?? path.resolve(__dirname, '../../../docs/database/migrations');
runMigrations(connectionString, migrations)
  .then(() => process.stdout.write('Database migrations are up to date.\n'))
  .catch((error: unknown) => {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  });
