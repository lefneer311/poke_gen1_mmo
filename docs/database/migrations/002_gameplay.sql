BEGIN;
SET LOCAL ROLE mmo_owner;
SET LOCAL search_path = mmo, public;

CREATE TYPE account_status AS ENUM ('active', 'locked', 'pending_deletion', 'deleted');
CREATE TYPE character_status AS ENUM ('active', 'retired', 'deleted');
CREATE TYPE pokemon_location AS ENUM ('party', 'box', 'trade', 'none');
CREATE TYPE quest_state AS ENUM ('active', 'completed', 'failed');
CREATE TYPE battle_outcome AS ENUM ('win', 'loss', 'draw', 'abandoned', 'invalid');
CREATE TYPE trade_state AS ENUM ('offered', 'accepted', 'completed', 'cancelled', 'expired');

CREATE TABLE game_data_versions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  version text NOT NULL UNIQUE,
  ruleset_checksum text NOT NULL CHECK (ruleset_checksum ~ '^[0-9a-f]{64}$'),
  activated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username citext NOT NULL UNIQUE CHECK (char_length(username::text) BETWEEN 3 AND 32),
  email citext UNIQUE,
  status account_status NOT NULL DEFAULT 'active',
  locale text NOT NULL DEFAULT 'en' CHECK (char_length(locale) BETWEEN 2 AND 16),
  deletion_requested_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK ((status = 'pending_deletion') = (deletion_requested_at IS NOT NULL) OR status = 'deleted')
);
CREATE TRIGGER accounts_updated_at BEFORE UPDATE ON accounts
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE account_credentials (
  account_id uuid PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  password_hash text NOT NULL CHECK (char_length(password_hash) BETWEEN 20 AND 512),
  password_changed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  failed_attempts integer NOT NULL DEFAULT 0 CHECK (failed_attempts >= 0),
  locked_until timestamptz
);

CREATE TABLE account_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  token_digest bytea NOT NULL UNIQUE CHECK (octet_length(token_digest) = 32),
  user_agent text CHECK (char_length(user_agent) <= 512),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  last_used_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  CHECK (expires_at > created_at),
  CHECK (revoked_at IS NULL OR revoked_at >= created_at)
);
CREATE INDEX account_sessions_active_idx ON account_sessions(account_id, expires_at)
WHERE revoked_at IS NULL;

CREATE TABLE account_recovery_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  token_digest bytea NOT NULL UNIQUE CHECK (octet_length(token_digest) = 32),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  CHECK (expires_at > created_at)
);

CREATE TABLE worlds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9][a-z0-9-]{1,31}$'),
  display_name text NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 64),
  game_data_version_id bigint NOT NULL REFERENCES game_data_versions(id),
  enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE world_instances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  world_id uuid NOT NULL REFERENCES worlds(id),
  instance_key text NOT NULL CHECK (char_length(instance_key) BETWEEN 1 AND 64),
  region text NOT NULL DEFAULT 'local' CHECK (char_length(region) BETWEEN 1 AND 32),
  capacity integer NOT NULL CHECK (capacity BETWEEN 1 AND 10000),
  enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (world_id, instance_key)
);

CREATE TABLE characters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES accounts(id),
  world_id uuid NOT NULL REFERENCES worlds(id),
  name citext NOT NULL CHECK (char_length(name::text) BETWEEN 1 AND 16),
  status character_status NOT NULL DEFAULT 'active',
  instance_id uuid REFERENCES world_instances(id),
  map_key text NOT NULL CHECK (char_length(map_key) BETWEEN 1 AND 64),
  tile_x smallint NOT NULL,
  tile_y smallint NOT NULL,
  facing text NOT NULL DEFAULT 'down' CHECK (facing IN ('up', 'down', 'left', 'right')),
  checkpoint_key text CHECK (char_length(checkpoint_key) <= 64),
  money integer NOT NULL DEFAULT 0 CHECK (money BETWEEN 0 AND 999999999),
  play_seconds bigint NOT NULL DEFAULT 0 CHECK (play_seconds >= 0),
  version bigint NOT NULL DEFAULT 1 CHECK (version > 0),
  last_seen_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  UNIQUE (world_id, name),
  CHECK ((status = 'deleted') = (deleted_at IS NOT NULL))
);
CREATE INDEX characters_account_idx ON characters(account_id) WHERE status <> 'deleted';
CREATE TRIGGER characters_updated_at BEFORE UPDATE ON characters
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE pokemon_instances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id uuid NOT NULL REFERENCES characters(id),
  species_id smallint NOT NULL CHECK (species_id > 0),
  nickname text CHECK (char_length(nickname) BETWEEN 1 AND 16),
  level smallint NOT NULL CHECK (level BETWEEN 1 AND 100),
  experience integer NOT NULL CHECK (experience >= 0),
  current_hp smallint NOT NULL CHECK (current_hp >= 0),
  status_condition text NOT NULL DEFAULT 'none'
    CHECK (status_condition IN ('none', 'sleep', 'poison', 'burn', 'freeze', 'paralysis')),
  attack_ev integer NOT NULL DEFAULT 0 CHECK (attack_ev BETWEEN 0 AND 65535),
  defense_ev integer NOT NULL DEFAULT 0 CHECK (defense_ev BETWEEN 0 AND 65535),
  speed_ev integer NOT NULL DEFAULT 0 CHECK (speed_ev BETWEEN 0 AND 65535),
  special_ev integer NOT NULL DEFAULT 0 CHECK (special_ev BETWEEN 0 AND 65535),
  hp_ev integer NOT NULL DEFAULT 0 CHECK (hp_ev BETWEEN 0 AND 65535),
  attack_iv smallint NOT NULL CHECK (attack_iv BETWEEN 0 AND 15),
  defense_iv smallint NOT NULL CHECK (defense_iv BETWEEN 0 AND 15),
  speed_iv smallint NOT NULL CHECK (speed_iv BETWEEN 0 AND 15),
  special_iv smallint NOT NULL CHECK (special_iv BETWEEN 0 AND 15),
  original_trainer_name text NOT NULL CHECK (char_length(original_trainer_name) BETWEEN 1 AND 16),
  original_trainer_number integer NOT NULL CHECK (original_trainer_number BETWEEN 0 AND 65535),
  location pokemon_location NOT NULL DEFAULT 'none',
  version bigint NOT NULL DEFAULT 1 CHECK (version > 0),
  caught_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX pokemon_instances_owner_idx ON pokemon_instances(character_id);
CREATE TRIGGER pokemon_instances_updated_at BEFORE UPDATE ON pokemon_instances
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE pokemon_moves (
  pokemon_id uuid NOT NULL REFERENCES pokemon_instances(id) ON DELETE CASCADE,
  slot smallint NOT NULL CHECK (slot BETWEEN 1 AND 4),
  move_id smallint NOT NULL CHECK (move_id > 0),
  current_pp smallint NOT NULL CHECK (current_pp >= 0),
  pp_ups smallint NOT NULL DEFAULT 0 CHECK (pp_ups BETWEEN 0 AND 3),
  PRIMARY KEY (pokemon_id, slot)
);

CREATE TABLE party_slots (
  character_id uuid NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  slot smallint NOT NULL CHECK (slot BETWEEN 1 AND 6),
  pokemon_id uuid NOT NULL UNIQUE REFERENCES pokemon_instances(id),
  PRIMARY KEY (character_id, slot)
);

CREATE TABLE storage_boxes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id uuid NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  box_number smallint NOT NULL CHECK (box_number BETWEEN 1 AND 255),
  name text CHECK (char_length(name) BETWEEN 1 AND 32),
  capacity smallint NOT NULL DEFAULT 20 CHECK (capacity BETWEEN 1 AND 255),
  UNIQUE (character_id, box_number)
);

CREATE TABLE storage_box_slots (
  box_id uuid NOT NULL REFERENCES storage_boxes(id) ON DELETE CASCADE,
  slot smallint NOT NULL CHECK (slot BETWEEN 1 AND 255),
  pokemon_id uuid NOT NULL UNIQUE REFERENCES pokemon_instances(id),
  PRIMARY KEY (box_id, slot)
);

CREATE TABLE character_inventory (
  character_id uuid NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  item_id smallint NOT NULL CHECK (item_id > 0),
  quantity integer NOT NULL CHECK (quantity BETWEEN 0 AND 999999),
  version bigint NOT NULL DEFAULT 1 CHECK (version > 0),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (character_id, item_id)
);

CREATE TABLE inventory_ledger (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  character_id uuid NOT NULL REFERENCES characters(id),
  item_id smallint NOT NULL CHECK (item_id > 0),
  quantity_delta integer NOT NULL CHECK (quantity_delta <> 0),
  balance_after integer NOT NULL CHECK (balance_after >= 0),
  reason text NOT NULL CHECK (reason IN ('encounter', 'battle', 'trade', 'shop', 'script', 'admin')),
  correlation_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX inventory_ledger_character_idx ON inventory_ledger(character_id, created_at DESC);

CREATE TABLE character_flags (
  character_id uuid NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  flag_key text NOT NULL CHECK (char_length(flag_key) BETWEEN 1 AND 96),
  value jsonb NOT NULL DEFAULT 'true'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (character_id, flag_key),
  CHECK (pg_column_size(value) <= 4096)
);

CREATE TABLE character_badges (
  character_id uuid NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  badge_id smallint NOT NULL CHECK (badge_id > 0),
  earned_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (character_id, badge_id)
);

CREATE TABLE character_pokedex (
  character_id uuid NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  species_id smallint NOT NULL CHECK (species_id > 0),
  seen_at timestamptz NOT NULL,
  caught_at timestamptz,
  PRIMARY KEY (character_id, species_id),
  CHECK (caught_at IS NULL OR caught_at >= seen_at)
);

CREATE TABLE quest_progress (
  character_id uuid NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  quest_key text NOT NULL CHECK (char_length(quest_key) BETWEEN 1 AND 96),
  state quest_state NOT NULL DEFAULT 'active',
  step smallint NOT NULL DEFAULT 0 CHECK (step >= 0),
  progress jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (pg_column_size(progress) <= 16384),
  started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  completed_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (character_id, quest_key),
  CHECK ((state = 'completed') = (completed_at IS NOT NULL))
);

CREATE TABLE battle_results (
  id uuid PRIMARY KEY,
  world_id uuid NOT NULL REFERENCES worlds(id),
  ruleset_version_id bigint NOT NULL REFERENCES game_data_versions(id),
  started_at timestamptz NOT NULL,
  ended_at timestamptz NOT NULL,
  seed bigint NOT NULL,
  transcript_digest bytea NOT NULL CHECK (octet_length(transcript_digest) = 32),
  verified boolean NOT NULL,
  invalid_reason text CHECK (char_length(invalid_reason) <= 256),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (ended_at >= started_at),
  CHECK (verified OR invalid_reason IS NOT NULL)
);

CREATE TABLE battle_participants (
  battle_id uuid NOT NULL REFERENCES battle_results(id) ON DELETE CASCADE,
  character_id uuid NOT NULL REFERENCES characters(id),
  outcome battle_outcome NOT NULL,
  rating_before integer,
  rating_after integer,
  PRIMARY KEY (battle_id, character_id)
);

CREATE TABLE trades (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  world_id uuid NOT NULL REFERENCES worlds(id),
  initiator_character_id uuid NOT NULL REFERENCES characters(id),
  recipient_character_id uuid NOT NULL REFERENCES characters(id),
  state trade_state NOT NULL DEFAULT 'offered',
  offer_digest bytea NOT NULL CHECK (octet_length(offer_digest) = 32),
  expires_at timestamptz NOT NULL,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (initiator_character_id <> recipient_character_id),
  CHECK ((state = 'completed') = (completed_at IS NOT NULL)),
  CHECK (expires_at > created_at)
);
CREATE INDEX trades_participants_idx ON trades(initiator_character_id, recipient_character_id, created_at DESC);
CREATE TRIGGER trades_updated_at BEFORE UPDATE ON trades
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

INSERT INTO schema_migrations(version) VALUES ('002_gameplay');
COMMIT;
