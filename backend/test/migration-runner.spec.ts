import { mkdtemp, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import * as path from 'node:path';
import { loadMigrations } from '../src/database/migration-runner';

describe('migration loader', () => {
  it('loads only named SQL migrations in lexical order with stable checksums', async () => {
    const directory = await mkdtemp(path.join(tmpdir(), 'mmo-migrations-'));
    await Promise.all([
      writeFile(path.join(directory, '002_second.sql'), 'SELECT 2;'),
      writeFile(path.join(directory, '001_first.sql'), 'SELECT 1;'),
      writeFile(path.join(directory, 'notes.txt'), 'ignored'),
    ]);

    const migrations = await loadMigrations(directory);

    expect(migrations.map(({ version }) => version)).toEqual(['001_first', '002_second']);
    expect(migrations[0].checksum).toMatch(/^[0-9a-f]{64}$/);
    expect(migrations[0].checksum).not.toBe(migrations[1].checksum);
  });
});
