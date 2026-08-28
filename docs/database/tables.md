# Database tables

The earlier table sketch has been superseded by the reviewed PostgreSQL
proposal in [`architecture.md`](architecture.md). The executable definitions
are split into ordered migrations:

1. [`001_foundations.sql`](migrations/001_foundations.sql) — roles,
   schema, extensions and migration tracking;
2. [`002_gameplay.sql`](migrations/002_gameplay.sql) — accounts,
   sessions, worlds, characters, Pokémon, inventory, progression, verified
   battle summaries and trades; and
3. [`003_operations.sql`](migrations/003_operations.sql) — sanctions, retry
   safety, audit events and the transactional outbox; and
4. [`004_account_registration.sql`](migrations/004_account_registration.sql) —
   pre-account registration idempotency and bounded retry results.

The schema intentionally contains no ROM-derived reference catalogue. See the
architecture document for trust boundaries, transaction semantics, retention,
backup expectations and the justification for each requirement.
