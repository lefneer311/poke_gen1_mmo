# Proposed persistent database architecture

## Decision and scope

Use **PostgreSQL 16+ as the system of record**, accessed only by the NestJS
application server. The browser and desktop clients continue to speak the
versioned game protocol; they never receive database credentials or issue SQL.
This proposal is for the charter's P2 persistent vertical slice, not for the
current guest-only MVP. It deliberately does not make unverified client battle
messages, positions, or save files durable.

PostgreSQL is preferred over a document store because a reward changes several
related facts (battle result, Pokémon experience, inventory, currency and an
audit record) that must commit or roll back together. It also supplies foreign
keys, check constraints, row locking, JSONB for bounded extension data, and
well-understood backup/point-in-time-recovery tooling.

```text
Browser / desktop client
          |
   versioned protocol (TLS)
          |
NestJS application server
  |        |          |
  |  in-memory/Redis  +-- worker reads transactional outbox
  |  ephemeral world
  |  presence
  +---------------- PostgreSQL primary
                         |
                  encrypted backups / PITR
                         |
                    restore staging
```

The primary stores durable identity and gameplay state. Connected presence,
interpolated pixel position, pending challenges and lockstep battle frames stay
in the coordinator (or a future Redis deployment): those values are hot,
short-lived and are already rebuilt on reconnect. Only a server-verified battle
summary is persisted. This keeps the movement latency goal off the database
critical path while preventing transient state from masquerading as trusted
progress.

## Requirements and project-goal justification

| Requirement | Architectural response | Why the project goal requires it |
| --- | --- | --- |
| Durable identity and secure login | `accounts` contains normalized identity and status; `account_credentials` contains only a password hash; `account_sessions` contains a digest of a rotatable token, expiry and revocation time. Recovery tokens use the same digest-only pattern. | P2 calls for accounts, authentication, recovery and deletion. Separating credentials from public character data minimizes exposure and lets operators revoke a compromised session without changing game state. |
| Multiple characters without name ambiguity | `characters` belongs to one account and has a case-insensitive unique name. Soft deletion preserves references while excluding a character from normal play. | The MMO goal needs a stable identity across connections, while the current trainer name is only a connection-scoped guest label. |
| Server-authoritative location and progression | Characters store a validated map/tile/checkpoint, money and play time; `character_flags`, `character_badges`, `character_pokedex` and `quest_progress` store discrete progression. | The goal is to move authority to the server incrementally. Storing tile/checkpoint rather than cosmetic pixel interpolation creates a safe reconnect point and supports validation without uploading a save or ROM. |
| Pokémon ownership, party and storage | `pokemon_instances` stores mechanics required to reconstruct a creature; moves, party slots and box slots are normalized and constrained. Ownership transfer is a single foreign-key update inside a transaction. | Persistent parties, Pokémon and eventual trading are named P2 outputs. Slot uniqueness prevents duplication and makes party-size/storage rules enforceable by the server. |
| Transactional economy | Stackable items, key items, currency checks, immutable `inventory_ledger`, and trade/battle records are updated in one database transaction with explicit row locking. | Durable rewards create cheating and duplication incentives. Atomic writes and a reason ledger make an encounter-through-reward vertical slice reproducible and auditable. |
| Versioned reference data without distributed ROM assets | `game_data_versions` identifies the server ruleset; species, moves, items, maps and quests are referenced by numeric/string keys but their copyrighted names, sprites and map assets are not seeded. | The bring-your-own-ROM mission prohibits shipping ROM-derived assets. The server still needs stable identifiers and a ruleset checksum to validate authoritative actions. Operators must load separately reviewed, legally distributable mechanics data. |
| World partitioning | `worlds` and `world_instances` identify a shard/instance; characters record their last durable instance and tile. | P2 requires partitioned worlds and documented capacity. The indirection permits instances to move between processes without changing every gameplay table. |
| Concurrency and replay safety | Mutable rows carry `version`; commands may claim a unique `(account_id, idempotency_key)` in `processed_commands`; trades use explicit states. Transactions lock affected character/inventory/Pokémon rows in stable ID order. | WebSocket retries and simultaneous trades must not duplicate rewards. Optimistic versions detect stale saves, while idempotency makes retrying a timed-out server command safe. |
| Auditability and moderation | Security/gameplay actions use append-only `audit_events`; account sanctions are time-bounded; structured event payloads are JSONB and must not contain ROM/save content or secrets. | The charter requires moderation, auditability and retention rules before public launch. Audit records link an actor, affected account/character and request correlation ID without becoming a copy of private client data. |
| Reliable side effects | A transactional `outbox_events` row is committed with state changes, then claimed by workers with `FOR UPDATE SKIP LOCKED`. | Notifications and metrics must not be emitted for a transaction that later rolls back, and process crashes must not lose committed trade/battle events. |
| Recovery and operability | UTC `timestamptz`, migration history, health-oriented indexes, least-privilege roles, encrypted daily backups plus WAL archiving, and quarterly restore drills. | The proposed P2 target is restore within four hours with at most 24 hours of loss. A backup is not evidence until it is restored and checked in staging. |

## Transaction boundaries

All state-changing commands run in a database transaction after authentication
and server-side validation. The application sets `SET LOCAL app.account_id`
for correlation, claims an idempotency key, locks affected rows in UUID order,
writes the authoritative state and ledger/audit/outbox records, then commits.
Network calls happen after commit. Serializable isolation is appropriate for
trades; `READ COMMITTED` plus explicit row locks is sufficient for a single
character reward.

Examples:

1. **Verified reward:** lock character and item row; insert the processed
   command; increment inventory/currency; append ledger and battle result;
   increment row versions; add audit/outbox events; commit.
2. **Trade:** lock both characters and all offered Pokémon/item rows in sorted
   order; revalidate ownership, capacity and offer hashes; exchange ownership
   and quantities; mark the trade completed; append both ledgers and an outbox
   event; commit. Never hold a transaction open while waiting for a player.
3. **Location checkpoint:** after movement has been validated in memory, update
   the character's map/tile with `WHERE version = :expected_version`. Cosmetic
   movement remains ephemeral.

## Data lifecycle, security and privacy

- Application connections use `mmo_app`; migrations use the non-login owner
  role. Neither role is exposed to clients. Production credentials come from a
  secret manager, require TLS, and are rotated.
- Passwords are hashed in the application with a reviewed memory-hard password
  hasher and per-password salt. Session and recovery tokens are random and only
  SHA-256 digests are stored. SQL intentionally does not choose application
  hash parameters.
- `accounts.status = 'pending_deletion'` starts a documented grace period.
  After it, a privileged erasure job revokes sessions, deletes credentials and
  either deletes or pseudonymizes legally retained audit/economy references.
- Proposed starting retention: sessions 30 days after expiry/revocation,
  processed command keys 7 days, published outbox rows 7 days, security audit
  events 180 days, and completed trade/battle summaries 365 days. Confirm these
  with the threat model, community policy and applicable law before launch.
- Never put passwords, tokens, ROM bytes, save bytes, raw protocol frames or
  ROM-derived assets into JSONB fields. Apply payload schemas and size limits in
  the application.

## Capacity, scaling and recovery

Start with one primary, a bounded application pool, and migrations performed by
one release job. Indexes favor login, character load, owned Pokémon, inventory,
pending outbox and active sanctions. Measure query latency and table/index size
before adding replicas or partitions. A read replica can later serve moderation
and analytics, but all gameplay decisions read from the primary to avoid stale
authority. Partition high-volume `audit_events` and ledgers by month only when
measurements justify the operational cost.

Take encrypted backups at least daily and continuously archive WAL for a
proposed recovery point objective below 24 hours. Keep copies in a separate
failure domain, restrict restore credentials, test checksums, and restore into
staging quarterly. Record actual recovery point and recovery time; the charter's
four-hour restore target is not met merely by configuring a backup job.

## Migration and rollout plan

1. Run the SQL files in lexical order with `psql -v ON_ERROR_STOP=1` using a
   dedicated database. `001` creates roles/schema/extensions, `002` creates
   durable gameplay tables, and `003` adds audit, idempotency and outbox tables.
2. Load a reviewed reference-data version and its checksum. The repository
   intentionally supplies no copyrighted catalogue or ROM-derived data.
3. Add a persistence adapter behind the existing coordinator and dual-write
   only server-verified checkpoints in a private staging environment.
4. Verify constraints, idempotent reward tests, concurrent trade tests, backup
   restore, account export/deletion and rollback before making SQL authoritative.
5. Roll out the authenticated persistent vertical slice separately from guest
   sessions. Migrations are forward-only; deploy additive schema before code,
   backfill in bounded batches, switch reads, then remove obsolete columns in a
   later release.

The schema is a proposal, not a claim that P1 authority work is complete. No
durable economic reward should be enabled until movement, battle results and
reward calculation are verified by the server as required by the charter.