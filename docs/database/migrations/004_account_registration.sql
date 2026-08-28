BEGIN;
SET LOCAL search_path = mmo, public;

-- Registration idempotency exists before an account ID is known, so it cannot
-- use processed_commands, whose key begins with account_id.
CREATE TABLE account_registration_requests (
  idempotency_key uuid PRIMARY KEY,
  request_digest bytea NOT NULL CHECK (octet_length(request_digest) = 32),
  account_id uuid REFERENCES accounts(id) ON DELETE SET NULL,
  result jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (pg_column_size(result) <= 4096),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  completed_at timestamptz,
  expires_at timestamptz NOT NULL DEFAULT (clock_timestamp() + interval '7 days'),
  CHECK (expires_at > created_at),
  CHECK (completed_at IS NULL OR completed_at >= created_at),
  CHECK ((completed_at IS NULL AND account_id IS NULL) OR completed_at IS NOT NULL)
);
CREATE INDEX account_registration_requests_expiry_idx
ON account_registration_requests(expires_at);

GRANT SELECT, INSERT, UPDATE, DELETE ON account_registration_requests TO mmo_app;

INSERT INTO schema_migrations(version) VALUES ('004_account_registration');
COMMIT;
