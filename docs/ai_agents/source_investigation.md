# Link Battle MMO source investigation

> **Status:** Source-backed characterization
> **Scope:** The first documentation phase requested by
> [`initial_investigation.md`](initial_investigation.md). No runtime architecture is
> changed by this document.

## Executive summary

The initial hypothesis is mostly supported, with one important qualification.
The supplied ROM is read by the importer, checked against a known SHA-1, and
expanded into generated Lua data plus graphics and audio assets. Normal play
loads those cached outputs rather than reading ROM bytes. The native Lua engine
owns overworld, scripting, inventory, Pokémon, save, and battle behaviour.

The content model is already substantially more flexible than a ROM index model:
registries use string identifiers, mods can register, override, patch, and remove
records, and the schemas cover species, moves, maps, assets, rulesets, statuses,
effects, evolution methods, growth rates, commands, and more. Limits such as
party size, move count, level cap, and Pokédex size are data constants, although
some engine and UI code still assumes four move slots and the Generation I stat
model.

The qualification is multiplayer authority. The current MMO backend is an
in-memory presence, challenge, and battle-message coordinator. A client reports
its absolute map and coordinates; the server accepts them without collision or
transition validation. A battle receives a server-generated shared seed, but the
server relays an opaque payload and does not own parties, validate actions, or
simulate turns. Consequently, this is deterministic client lockstep rather than
an authoritative MMO simulation.

The engine has reusable, mostly presentation-independent battle modules, but the
top-level `BattleState` combines simulation, menus, timing, audio, and rendering.
A headless server should first extract a turn/session coordinator around the
existing `Damage`, `Status`, `TurnOrder`, `MoveEffects`, and related modules,
rather than attempt to instantiate `BattleState` unchanged.

## 1. Source and module map

| Area | Current responsibility | Representative source |
| --- | --- | --- |
| ROM import | Revision validation, extraction orchestration, cache lifecycle | `src/import/RomImporter.lua`, `Rom.lua`, `RomExtractor.lua`, `CacheFs.lua` |
| Data assembly | Load generated tables, add native defaults, merge mods | `src/core/Data.lua`, `src/mods/Loader.lua`, `Registry.lua`, `Schemas.lua` |
| World | Maps, collision, movement, warps, NPCs, encounters | `src/world/` |
| Scripts | Map scripts, commands, flags, tokens | `src/script/` |
| Pokémon | Instances, party/boxes, stats, growth, evolution | `src/pokemon/` |
| Battle | State machine, mechanics, rulesets, AI, effects, rendering adapter | `src/battle/` |
| Save | Plain-table save model, safe serializer, slots, migrations, validation | `src/core/SaveData.lua`, `SaveSerializer.lua` |
| Link play | Peer handshake, compatibility fingerprint, lockstep battle protocol | `src/link/` |
| MMO client | Persistent transport, presence projection, challenge/battle routing | `src/mmo/` |
| MMO server | TCP/WebSocket adapters, message validation, in-memory coordinator | `backend/src/modules/mmo/` |
| Browser shell | ROM storage/import UI and WebSocket-to-TCP configuration | `web/index.html`, `web/build-web.sh` |

This confirms that `gen1recomp` is the executable game implementation. The ROM
reader is confined to import code; gameplay modules consume `Data` records and
asset paths.

## 2. ROM dependency map

### Import and verification

`RomImporter` holds the selected file temporarily as `romData`, checks it against
the SHA-1 declared by `GameVersion`, constructs `RomExtractor`, and releases the
bytes after extraction. Cache readiness is represented by a format/version marker
containing the expected ROM hash and by the presence of required outputs.

The known output surface includes:

* generated constants, maps, text, field definitions, and battle animations;
* title, font, Pokémon, trainer, field, tileset, UI, and animation images;
* extracted chip-audio programs and version-specific audio data;
* the other decoded tables emitted by `RomExtractor`, including Pokémon, moves,
  items, encounters, trainers, tilesets, sprites, palettes, cries, songs, map
  scripts/pointers, learnsets, evolutions, and type-chart data.

Outputs are a combination of generated Lua definitions, decoded binary audio,
and generated PNG assets. They live in the LÖVE save directory or a portable
cache beside the executable. A developer checkout may provide generated Red data
in the source tree.

### Runtime conclusion

The ROM is required for an import or a cache rebuild, not continuously during
normal play. Startup selects the game version, mounts that version's cache, and
then requires generated modules. Map entry, battle, graphics, and audio resolve
those cached files. Swapping the expected ROM hash or bumping the cache format
invalidates the cache and requires re-import.

This means vanilla content remains ROM-derived, while execution is native. It
does **not** mean the ROM can be discarded before first-run import, nor that the
generated copyrighted assets should be distributed by the server.

## 3. Registry and asset model

All registry keys are non-empty strings. Each registry retains an ordered op log
and folds `register`, `override`, `patch`, and `remove` operations over the base
data. Registries freeze after loading, and a failed mod can be rolled back by
dropping its operations. They are not intrinsically limited to eight-bit ROM IDs.

The schema inventory is:

| Domain | Registries/data surfaces |
| --- | --- |
| Core content | `pokemon`, `moves`, `items`, `maps`, `tilesets`, `encounters`, `trainers` |
| Presentation | `sprites`, `text`, `strings`, `screens`, `battle_anims`, `transitions`, `render_pipelines`, `battle_sprite_scales`, `font` |
| Audio/color | songs, SFX, cries, map songs, audio programs, palettes, icons |
| Mechanics | types/type chart, statuses, move effects, item effects, balls, rulesets, AI classes, evolution methods, growth rates |
| Scripting/config | map scripts, commands, tokens, constants, field defaults, text pointers |
| Link extension | link fields and their pack/unpack/revision declarations |

Mods can refer to files within their own directory. Asset merge code resolves
relative mod paths, and example mods already supply external PNG battle sprites.
Therefore a custom string-ID species with non-ROM graphics is supported by the
content architecture in principle. It still needs an end-to-end test covering
every UI, save, trade, and multiplayer path before being treated as proven.

Compatibility is not a ROM hash handshake in MMO mode today. Link play computes a
deterministic fingerprint over battle-relevant merged species, moves, statuses,
effects, types, constants, declared link fields, and link-affecting mod versions.
That mechanism is a useful basis for a future MMO content-manifest hash, but it is
currently part of `src/link`, not the MMO `join_world` exchange.

## 4. Generation I assumptions

### Data-driven or already extensible

* Species and move identifiers are strings and record collections are not capped
  at 151 or 165 by their registries.
* `partyMax`, `moveMax`, `levelCap`, `dexSize`, bag/money limits, badge boosts,
  rulesets, type records, and the type chart are mergeable data.
* Move records can define a category, allowing a physical/special split independent
  of the vanilla type category.
* Statuses, move effects, item effects, balls, evolution methods, and growth rates
  have registries with handler/revision extension points.
* Save records are ordinary Lua tables, support namespaced `modData`, migrations,
  and declared extra link fields.

### Still hardcoded or coupled

* `Pokemon.movesAtLevel` and daycare learning explicitly retain the most recent
  four moves. Code must be audited before changing `moveMax` from four.
* A Pokémon instance stores Generation I DVs, stat experience, and the single
  `special` stat; it has no native nature, ability, held-item, IV, or EV fields.
* Persistent status is represented as a single status ID, even though its
  behaviour is registry-driven.
* The default damage rules faithfully encode Generation I critical hits, badge
  boosts, type-based categories, integer arithmetic, and the 1/256 miss rule.
  Rulesets expose several switches, but do not constitute later-generation
  mechanics by themselves.
* Many menus and render paths assume the Game Boy battle layout and should be
  treated as presentation constraints even when the underlying registry expands.

The effective constraint is thus mixed: numeric ROM ceilings are largely gone,
but data shapes and UI flows still encode Generation I semantics.

## 5. Current MMO protocol

### Transport and framing

Native clients use TCP; the browser's Emscripten socket is carried by WebSocket.
Both expose the same newline-delimited JSON byte stream. The backend offers a TCP
listener and a WebSocket listener/HTTP upgrade endpoint, with a 64 KiB WebSocket
payload ceiling. There is no account authentication or protocol-version/content
compatibility handshake.

### Client-to-server catalog

| Message | Meaning | Validation/authority |
| --- | --- | --- |
| `join_world` | Create an ephemeral player with name, map, position, facing, appearance | Shape/range only; client supplies state |
| `move` | Replace map, coordinates, pixel coordinates, facing, moving flag | Shape/range and in-battle gate only |
| `challenge` | Challenge a UUID on the same reported map | Server validates availability |
| `challenge_reply` | Accept or decline a pending challenge | Server validates recipient and availability |
| `battle_message` | Send an opaque link payload to the opponent | Server validates battle membership only |
| `battle_end` | End the shared battle | Either participant may end it |
| `ping` | Liveness echo | Returns `pong` |

### Server-to-client catalog

The coordinator emits `welcome`, `snapshot`, `world_snapshot`, `player_joined`,
`player_moved`, `player_left`, `challenge_sent`, `challenge_received`,
`challenge_declined`, `challenge_cancelled`, `battle_start`, `battle_message`,
`battle_ended`, `pong`, and `error`. `battle_start` assigns host/guest roles and a
cryptographically generated 32-bit seed. Disconnect removes presence and pending
challenges and ends an active battle.

There is no persistence, room abstraction beyond a map ID, reconnect/resume,
timeout for pending challenges, battle action schema, or server world model.

## 6. End-to-end traces

### Movement

1. `WorldClient` reads the local overworld's map, cell/pixel position, facing, and
   motion state.
2. It sends `join_world` once and then sends a `move` whenever that tuple changes.
3. The coordinator directly replaces its in-memory player record. A map change
   causes leave/snapshot/join broadcasts; otherwise it broadcasts `player_moved`.
4. Other clients create passable runtime NPCs and directly update their cells and
   pixels from the reported state.

**Result:** player position is client authoritative. The server does not load map
collision, check speed, validate adjacency, or validate warps, so arbitrary
coordinates and map transitions are accepted.

### Challenge and battle

1. Interacting with a remote-player NPC sends `challenge`.
2. The server verifies same-map availability and creates an in-memory challenge.
3. On acceptance it creates a battle UUID and shared random seed and assigns
   host/guest roles.
4. `BattleFlow` wraps the MMO connection in `BattleNet`; the existing `LinkBattle`
   protocol sees its usual payloads.
5. The coordinator forwards each payload unchanged to the opponent.
6. Both clients simulate and render locally. Either can send `battle_end`.

**Result:** challenge membership and the initial seed are server-owned, while
party state, selections, PP, damage, status, RNG consumption, victory, rewards,
and progression remain client-owned/lockstep.

### Save/load of a Pokémon

Pokémon instances are plain tables nested in the party, boxes, daycare, and other
save structures. `SaveSerializer` writes a deterministic, data-only Lua table and
parses it with a restricted parser rather than executing save text. `SaveData`
uses atomic temporary/backup files, adds format and mod metadata, applies core and
mod migrations, and validates referenced content on load. Unknown mod species and
items can be quarantined into an orphaned/Lost collection rather than crashing.

Arbitrary serializable mod fields can survive in `modData` or Pokémon tables, but
cross-client link transfer requires explicit registered link-field pack/unpack
support. The MMO backend never receives or persists this save state.

## 7. Authority matrix

| System | Current authority | Desired persistent-MMO authority |
| --- | --- | --- |
| Rendering, UI, audio, input | Client | Client |
| Local interpolation | Client | Client |
| Identity/name | Ephemeral server UUID; client name | Authenticated server character |
| Map and position | Client reported, server replicated | Server validated, optional prediction |
| Collision and transitions | Client | Server |
| Party/Pokémon/moves/PP | Local save/client | Server |
| Inventory/money/badges/progression | Local save/client | Server |
| NPCs, encounters, scripts, quests | Local client | Split cosmetic/client and mutating/server |
| Challenge membership | Server memory | Server |
| Battle seed | Server | Server |
| Battle actions and simulation | Client lockstep; opaque relay | Server |
| Battle rewards/evolution | Client | Server transaction |
| Persistence | Client filesystem | Server database; local preferences only |
| Mod/content set | Client install; link fingerprint outside MMO | Server manifest plus client verification |

## 8. Headless feasibility and determinism

Low-level battle modules accept injected RNG functions and operate on tables.
This is promising for server reuse. The link fingerprint deliberately sorts keys,
and link battle uses a shared seed to keep simulations aligned.

However, `BattleState` itself is not headless: it constructs and draws images,
owns menu/prompt sequencing and animation waits, calls audio/presentation code,
and defaults to `love.math.random`. Simulation and presentation are separated at
the module level but recombined in the top-level state machine. Overworld state is
similarly tied to LÖVE update/state-stack and rendering-facing objects.

The practical experiment is therefore not “run the existing screen on NestJS.”
It is:

1. define a serializable battle-session state and action schema;
2. extract a pure turn resolver that calls the existing mechanic modules with an
   explicit deterministic RNG;
3. run Lua headlessly in the current test harness first;
4. replay the same fixture twice and compare canonical state/event output;
5. only then choose embedded server Lua, a separate Lua simulation service, or a
   TypeScript port.

Server execution must load only the server-approved mod set. The mod runtime can
execute Lua handlers, so accepting client-provided scripts would be unsafe.

## 9. Risks and prioritized next work

1. **Add characterization tests, not a rewrite.** Capture join/movement rejection
   gaps, the full challenge lifecycle, deterministic battle traces, and save
   round-trips.
2. **Version the MMO handshake.** Add protocol, engine, ruleset, merged-content,
   and approved-mod fingerprints before persistent state is introduced.
3. **Prototype a custom species.** Use a namespaced string ID, external sprites,
   custom learnset/evolution, save/reload, link fingerprint, trade, and MMO battle.
4. **Prototype a headless turn.** Start with two fixed parties, an explicit seed,
   one selected move each, and a canonical result/event log.
5. **Define server state before storage.** Model character, Pokémon instance,
   inventory, progression, battle, and version fields independently of a database.
6. **Move authority incrementally.** Identity/content handshake, then Pokémon and
   inventory, then battle actions/simulation, then movement/world validation.

Do not add authentication, a production database, later-generation mechanics, or
server-side arbitrary scripts until the two prototypes establish the content and
simulation boundaries.

## 10. Answers to the initial checklist

| Question | Finding |
| --- | --- |
| ROM used after extraction? | No direct runtime byte reads found; cached generated data/assets are used. |
| What is extracted? | Lua data, PNG graphics, and binary/decoded audio across the vanilla content categories listed above. |
| Native systems? | World, scripts, Pokémon, inventory, battle, UI, saves, mods, link, and MMO client. |
| Hardcoded Gen I assumptions? | Four moves and Gen I Pokémon/stat/status shapes remain; many numeric limits and mechanics are data/registry driven. |
| Identifier model? | String keys in namespaced-capable registries; vanilla uses symbolic uppercase IDs. |
| Non-ROM species/moves? | Structurally supported; end-to-end proof remains required. |
| Arbitrary graphics/audio? | Mod-local assets and registries support them; examples prove PNG override, broader end-to-end proof remains. |
| Mod compatibility? | Save metadata/migrations and a deterministic link-surface fingerprint; no MMO handshake yet. |
| MMO server state? | Ephemeral players, challenges, and battle memberships only. |
| Movement authority? | Client coordinates accepted and replicated without world validation. |
| Battle authority/RNG? | Clients simulate with a server-issued common seed; server relays opaque messages. |
| Headless battle? | Mechanic modules are promising; the complete `BattleState` is presentation-coupled. |
| Save model? | Deterministically serialized Lua tables, migrations, mod data, content validation, local filesystem authority. |
| Script security? | Lua handlers are trusted installed/server-selected code, not suitable for client upload. |
| Web difference? | Same Lua game; love.js/WASM uses an asynchronous WebSocket-backed TCP connection and browser ROM storage/import shell. |

## Conclusion

The ROM is a bootstrap source for vanilla data and assets, not the executable
authority or the primary extensibility ceiling. The registry and save designs
already support substantial original content. The immediate architectural barrier
is that MMO movement, character state, and battle outcomes originate on clients.
The least disruptive path is to preserve the native engine and registries while
extracting deterministic simulation boundaries and moving trust to the server in
small, tested phases.