BEGIN;
SET LOCAL ROLE mmo_owner;
SET LOCAL search_path = mmo, public;

CREATE TYPE sanction_kind AS ENUM ('warning', 'mute', 'suspension', 'ban');

CREATE TABLE account_sanctions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES accounts(id),
  kind sanction_kind NOT NULL,
  reason text NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 1000),
  starts_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  ends_at timestamptz,
  revoked_at timestamptz,
  created_by_account_id uuid REFERENCES accounts(id),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (ends_at IS NULL OR ends_at > starts_at),
  CHECK (revoked_at IS NULL OR revoked_at >= starts_at)
);
CREATE INDEX account_sanctions_active_idx ON account_sanctions(account_id, starts_at, ends_at)
WHERE revoked_at IS NULL;

CREATE TABLE processed_commands (
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  idempotency_key uuid NOT NULL,
  command_type text NOT NULL CHECK (char_length(command_type) BETWEEN 1 AND 64),
  request_digest bytea NOT NULL CHECK (octet_length(request_digest) = 32),
  result jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (pg_column_size(result) <= 16384),
  processed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  expires_at timestamptz NOT NULL,
  PRIMARY KEY (account_id, idempotency_key),
  CHECK (expires_at > processed_at)
);
CREATE INDEX processed_commands_expiry_idx ON processed_commands(expires_at);

CREATE TABLE audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  event_type text NOT NULL CHECK (char_length(event_type) BETWEEN 1 AND 96),
  actor_account_id uuid REFERENCES accounts(id) ON DELETE SET NULL,
  subject_account_id uuid REFERENCES accounts(id) ON DELETE SET NULL,
  subject_character_id uuid REFERENCES characters(id) ON DELETE SET NULL,
  correlation_id uuid NOT NULL,
  source text NOT NULL DEFAULT 'server' CHECK (source IN ('server', 'worker', 'admin')),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (pg_column_size(payload) <= 16384)
);
CREATE INDEX audit_events_subject_account_idx ON audit_events(subject_account_id, occurred_at DESC);
CREATE INDEX audit_events_subject_character_idx ON audit_events(subject_character_id, occurred_at DESC);
CREATE INDEX audit_events_correlation_idx ON audit_events(correlation_id);

CREATE TABLE outbox_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  aggregate_type text NOT NULL CHECK (char_length(aggregate_type) BETWEEN 1 AND 64),
  aggregate_id uuid NOT NULL,
  event_type text NOT NULL CHECK (char_length(event_type) BETWEEN 1 AND 96),
  payload jsonb NOT NULL CHECK (pg_column_size(payload) <= 32768),
  occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  available_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  published_at timestamptz,
  last_error text CHECK (char_length(last_error) <= 1000)
);
CREATE INDEX outbox_events_pending_idx ON outbox_events(available_at, occurred_at)
WHERE published_at IS NULL;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA mmo TO mmo_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA mmo TO mmo_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA mmo TO mmo_app;

-- Append-only evidence: the application may insert and read but cannot rewrite it.
REVOKE UPDATE, DELETE, TRUNCATE ON audit_events, inventory_ledger FROM mmo_app;

INSERT INTO schema_migrations(version) VALUES ('003_operations');
COMMIT;
