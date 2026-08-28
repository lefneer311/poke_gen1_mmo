BEGIN;

DO $roles$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'mmo_owner') THEN
    CREATE ROLE mmo_owner NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'mmo_app') THEN
    CREATE ROLE mmo_app NOLOGIN;
  END IF;
END
$roles$;

CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS mmo AUTHORIZATION mmo_owner;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA mmo TO mmo_app;
SET LOCAL ROLE mmo_owner;

CREATE TABLE IF NOT EXISTS mmo.schema_migrations (
  version text PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  checksum text
);

CREATE OR REPLACE FUNCTION mmo.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END
$function$;

INSERT INTO mmo.schema_migrations(version) VALUES ('001_foundation')
ON CONFLICT (version) DO NOTHING;

ALTER DEFAULT PRIVILEGES FOR ROLE mmo_owner IN SCHEMA mmo
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO mmo_app;
ALTER DEFAULT PRIVILEGES FOR ROLE mmo_owner IN SCHEMA mmo
  GRANT USAGE, SELECT ON SEQUENCES TO mmo_app;
ALTER DEFAULT PRIVILEGES FOR ROLE mmo_owner IN SCHEMA mmo
  GRANT EXECUTE ON FUNCTIONS TO mmo_app;

COMMIT;
