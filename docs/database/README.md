# PostgreSQL schema draft

These migrations implement the proposed P2 model described in
[`architecture.md`](architecture.md). They are executable schema artifacts; the
current backend does not connect to a database yet.

Create an empty PostgreSQL 16+ database, connect as a role allowed to create
extensions and roles, and run:

```bash
for migration in docs/database/migrations/*.sql; do
  psql -v ON_ERROR_STOP=1 "$DATABASE_URL" -f "$migration"
done
```

The scripts are transactional and record applied versions in
`mmo.schema_migrations`. `001` creates the owner/application roles. Change role
login credentials outside these files (preferably through a secret manager).
Production migration automation should connect as a separately provisioned
login that can assume `mmo_owner`; the game server assumes only `mmo_app`.

No species, move, item, map, quest, sprite, text, or other ROM-derived catalogue
is included. A deployment must separately load reviewed reference identifiers
for one `game_data_versions` row before creating gameplay data.
