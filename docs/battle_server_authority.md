# Server-authoritative battle design

**Status:** Design proposal; no runtime behavior is implemented by this document

**Owners:** Battle-engine, coordinator/protocol, persistence, and testing maintainers

**Applies first to:** Two-player Generation I link battles in a bounded pilot
**Project goals:** See the [project charter](project_charter.md) and
[mission and principles](mission_and_principles.md).

## Decision summary

The coordinator should eventually own the complete semantic battle state, accept
only player intent, advance a deterministic simulation, and publish ordered
results for clients to present. The browser and desktop clients should continue
to own menus, animation, audio, text pacing, accessibility, and prediction, but
must not decide whether an action is legal, consume PP, draw randomness, apply
damage or status, choose the winner, or grant a durable reward.

This should **not** be delivered as a single rewrite. First characterize the
current link engine, then extract a headless Lua simulation core, place it behind
a versioned service boundary, shadow current battles, and only then make that
service authoritative. Initially, keep P0's opaque relay available for private,
non-persistent sessions. Durable rewards remain prohibited until the server owns
the participating parties, verifies the whole battle, and commits the result and
reward atomically.

This direction is preferred because it advances the charter's dependable
multiplayer, deliberate-authority, browser-first/shared-core, and maintainability
goals without prematurely coupling progression to client claims. Reusing one Lua
mechanics implementation also avoids maintaining subtly different Generation I
engines in Lua and TypeScript.

## 1. Current system and trust gap

### Current battle trace

1. The coordinator validates that two reported players are available on the same
   reported map, accepts the challenge, creates a battle UUID, chooses a 32-bit
   seed, and assigns host/guest roles.
2. Each client sends its compatibility hello and packed local party through an
   opaque `battle_message`. The server checks only battle membership.
3. Both clients construct mirrored `BattleState` instances and use the same
   Park–Miller random stream. Each sends an action to its peer and independently
   resolves the turn.
4. The link layer exchanges partial state signatures to detect divergence. A
   detected mismatch can end the match, but agreement proves only that both
   clients produced the same claim—not that either party or executable was
   legitimate.
5. Either client may send `battle_end`; the coordinator clears membership without
   receiving a semantic verdict or verifying the final state.

The arrangement is appropriate for a friendly, non-persistent P0 link session.
It preserves the original link-battle feel and keeps the backend small. It is not
a safe basis for accounts, progression, rankings, inventory, or rewards: a
modified client can invent a party, submit otherwise impossible choices, alter
the simulation, or end a battle strategically.

### What can be reused

The battle directory already separates useful mechanics into modules such as
`Damage`, `Status`, `TurnOrder`, `MoveEffects`, `TypeChart`, and rulesets. These
largely operate on tables and accept an injected random function. `LinkBattle`
already supplies a deterministic RNG, canonicalizes parties through pack/unpack,
and demonstrates that two executions can agree.

The top-level `BattleState` is not a suitable server object. It combines model
mutation with LÖVE images, audio, menus, message queues, animation waits, the game
state stack, and presentation-facing battlers. Running it unchanged in NestJS
would import client-only dependencies into the trust boundary and make timing UI
behavior part of server correctness.

## 2. Required authority boundary

| Concern | Proposed authority | Reason tied to project goal |
| --- | --- | --- |
| Account/character and party snapshot | Server | A persistent result is trustworthy only if combatants came from authoritative state; supports controlled authority and future transactional progression. |
| Ruleset, content manifest, and approved mods | Server | All participants must use one rulebook; supports dependable cross-client behavior and maintainability. |
| Legal action set and deadlines | Server | Prevents impossible selections and stalled sessions; supports a dependable complete-battle loop. |
| RNG seed, stream, and draw order | Server simulation | A seed shared with untrusted clients is predictable and mutable; centralized draws make outcomes replayable and verifiable. |
| Turn order, move effects, damage, status, PP, switching, fainting, and verdict | Server simulation | These mutations determine valuable outcomes and therefore cannot remain client assertions. |
| Reward calculation and persistence | Server transaction, after a verified verdict | Enforces the principle that valuable state is not persisted before its cause is validated. |
| Input controls, menu focus, animation, text, sound, camera, and accessibility | Client | Preserves a responsive browser-first experience and keeps presentation out of the simulation core. |
| Cosmetic event timing | Client, within server event order | Network latency should not dictate animation pacing; desktop and browser can share the same semantic contract. |
| Optional local prediction | Client, never committed | Can hide latency while authoritative state remains recoverable through reconciliation. |

The server is authoritative when its state can be rebuilt from an initial snapshot
and accepted intents without trusting a client's computed damage, random roll,
state hash, or verdict. Encryption, state hashes, and duplicate simulation can
detect transport corruption or accidental desync, but none substitutes for this
ownership boundary.

## 3. Proposed headless battle model

### 3.1 Separate domain state from presentation

Extract a new simulation package from `gen1recomp/src/battle/`, with no reference
to `love`, graphics, audio, input, screens, state stacks, wall-clock time, or
network objects. It should expose a narrow API conceptually equivalent to:

```text
createBattle(initialSnapshot, ruleset, seed) -> BattleState
legalIntents(state, side)                    -> IntentSet
applyIntents(state, intents, rng)            -> State + DomainEvents
canonicalize(state)                          -> StableBytes
```

`BattleState` should become a presentation adapter over this model rather than
the sole home of mechanics. Existing mechanic modules should move only when a
characterization test demonstrates the same result before and after extraction.

**Justification:** a pure boundary lets the same mechanics run in the client,
headless tests, replays, and the authoritative service. That directly serves the
shared-core goal and reduces regression risk compared with a TypeScript rewrite.
It also allows server capacity to be measured independently of rendering.

### 3.2 Serializable state

The authoritative snapshot needs, at minimum:

- battle ID, mode, lifecycle phase, turn number, ruleset/version identifiers;
- canonical host and guest IDs and their ordered party instance IDs;
- each Pokémon's species/content ID, level, current/max HP, persistent status,
  battle stats, known moves and current PP;
- active slots, stat stages, volatile conditions and their counters, disabled or
  locked move state, switch requirements, and escape/forfeit state;
- deterministic RNG algorithm/version and internal state;
- last accepted sequence number per participant; and
- terminal verdict (`host_win`, `guest_win`, `draw`, `cancelled`, or
  `invalidated`) plus a reason.

Use integers and explicitly specified rounding wherever Generation I mechanics
do so. Avoid Lua table iteration as an implicit ordering rule; sort identifiers
or use arrays. Canonical serialization must distinguish missing values from
meaningful zero/false values unless the state schema explicitly normalizes them.

**Justification:** explicit state is necessary for deterministic fixtures,
reconnect, audits, idempotency, and future database transactions. These are all
acceptance evidence for the charter's dependable pilot; hidden UI state cannot
provide that evidence.

### 3.3 Intent protocol instead of opaque peer payloads

Replace authoritative use of `battle_message.payload` with versioned messages
whose fields express player intent, for example:

```json
{
  "type": "battle_intent",
  "battleId": "uuid",
  "turn": 7,
  "intentId": "player-uuid:18",
  "expectedRevision": 24,
  "intent": { "kind": "move", "slot": 2 }
}
```

Supported intents should be a closed tagged union: `move`, `switch`, `forfeit`,
and only those item or special actions enabled by the selected battle mode.
Locked/recharge/forced-switch behavior should usually be inferred by the server,
not asserted as a special client action. Each intent must be checked against the
battle participant, phase, legal action set, revision, slot range, PP, fainted
state, and mode rules.

Submission should be idempotent: retrying the same `intentId` returns the same
acknowledgement; reusing it with different content is an error. A participant may
replace a pending selection only if the rules explicitly permit it and before
the resolution cutoff. The server—not arrival order—defines simultaneous-turn
semantics.

**Justification:** semantic, idempotent intents are small enough to validate,
safe to retry after reconnect, and common to TCP and WebSocket clients. This
supports reliable browser play and the charter requirement that malformed or
state-inappropriate messages fail predictably.

### 3.4 Ordered server output

After accepting both required intents (or applying a documented timeout policy),
the server resolves the turn once and emits:

- `battle_intent_ack` or a stable `battle_error`;
- `battle_update` with battle ID, monotonically increasing revision, turn,
  ordered domain events, visibility-filtered state, and a canonical state hash;
- `battle_waiting` with only non-secret readiness information;
- `battle_resync` containing an authoritative snapshot after a revision gap or
  reconnect; and
- `battle_finished` with verdict, reason, final revision, and reward transaction
  reference when persistence is enabled.

Domain events should describe facts (`move_used`, `pp_changed`, `damage_applied`,
`status_applied`, `pokemon_fainted`, `switch_required`, `battle_finished`) rather
than animation instructions. Events need stable identifiers so replayed delivery
does not repeat sound, text, or other client effects. The client maps them to the
existing presentation queue and acknowledges the latest applied revision.

**Justification:** ordered facts let the original battle presentation evolve
without affecting correctness, permit accessible or alternate interfaces, and
allow both browser and desktop clients to consume one protocol. Resync turns a
brief connection loss into a recoverable state rather than an automatic restart.

### 3.5 Randomness

Use a named, frozen PRNG algorithm with test vectors; store its internal state in
the battle snapshot and route every mechanic draw through the injected RNG. The
server may derive a battle seed from cryptographic randomness, but should not
reveal future RNG state to participants during a valuable match. Record draw
index and purpose in debug/test traces, while avoiding sensitive production-log
volume.

Do not replace Generation I probability rules with cryptographic randomness.
The PRNG needs deterministic replay, while unpredictable seed generation limits
advance knowledge. Changing the algorithm or draw order requires a new simulation
version and must not affect an in-progress battle.

**Justification:** deterministic replay supplies concrete evidence for
maintainability and incident diagnosis; server-only future state prevents clients
from selecting actions with foreknowledge of rolls.

## 4. Runtime shape

### Recommended first deployment: isolated Lua simulation workers

Keep NestJS as the connection/session coordinator and run the extracted Lua core
in bounded worker processes (or a separately deployable internal service). The
coordinator should:

1. authenticate membership and validate the wire schema;
2. create a battle using server-owned party snapshots and manifest versions;
3. route intents to exactly one owning worker/shard;
4. persist/replicate lifecycle metadata needed for recovery;
5. filter and fan out ordered updates; and
6. commit a terminal result through the progression service only after the
   simulation returns a valid final state.

Workers should accept data, not source code, from players. Apply CPU, memory,
turn-count, message-size, and wall-time limits; restart a failed worker; and mark
an unrecoverable battle `invalidated` rather than guessing a winner. Pin one
battle to one worker at a time to avoid concurrent mutation.

**Why not embed arbitrary Lua in NestJS?** Embedding may eventually reduce IPC
cost, but it increases native-module and process-isolation risk before the API is
stable. A process boundary makes resource limits and crashes easier to contain.

**Why not port directly to TypeScript?** TypeScript would integrate naturally
with the backend, but a second implementation creates permanent conformance work
and high risk around integer math, RNG consumption, move effects, and historical
quirks. A port should be reconsidered only if profiling shows the isolated Lua
service cannot meet measured capacity or operational requirements, and then it
must pass the same golden traces.

**Why not keep client lockstep and validate only the final hash?** A malicious
client can coordinate its inputs and hashes around altered initial state or
logic; final validation would need to rerun the complete battle anyway. Running
the trusted simulation as actions arrive gives earlier rejection, simpler
recovery, and one source of truth.

## 5. Content, mods, and ROM boundary

The battle service needs mechanics data but the project's bring-your-own-ROM
policy forbids turning the coordinator into a ROM/save upload destination or
shipping ROM-derived generated assets in server artifacts. Before authority is
enabled, define an operator-provisioned, battle-only content manifest containing
stable IDs and the semantic fields required by the approved ruleset. It must:

- be produced through a separately reviewed setup path, never a player upload;
- omit graphics, audio, text, maps, saves, and unrelated extracted data;
- have a canonical digest included in negotiation and persisted with a battle;
- be allowlisted by the server, with clients required to demonstrate the same
  protocol/engine/ruleset/content/mod compatibility; and
- pass the artifact and legal-policy review before any distribution or public
  hosting decision.

Server mods are trusted operator-installed code, pinned by identifier, version,
and digest. Client-provided Lua must never execute on a server. Initially, permit
only data-only mods or an explicit allowlist of audited handlers; reject a party
that references unknown content or undeclared extension fields.

**Justification:** this supplies the common rulebook authority needs while
preserving the project's core legal/distribution constraint. It also prevents a
client from introducing executable behavior and makes mod compatibility an
explicit contract rather than a best-effort peer check. The exact manifest
contents and provisioning mechanism are a legal and architecture decision gate,
not something this proposal declares safe by itself.

## 6. Lifecycle, failure, and persistence semantics

Use a server-owned state machine:

```text
created -> awaiting_ready -> selecting -> resolving -> selecting
             |                  |             |
             +------------------+-------------+-> finished
             +------------------+-------------+-> invalidated
```

- **Ready:** bind immutable participant, party, ruleset, simulation, and content
  versions before showing the first action menu.
- **Selection timeout:** use a documented pilot limit. A timeout can forfeit in a
  competitive mode or cancel/draw in a friendly mode; it must never silently
  choose a move unless that is an explicit mode rule.
- **Disconnect:** retain the battle for a bounded resume window. The character is
  still in battle and cannot start another. On resume, verify identity and send a
  snapshot from the last committed revision.
- **Duplicate/stale input:** acknowledge exact duplicates; reject conflicts and
  stale revisions without mutating state.
- **Worker failure:** rebuild from initial snapshot plus the accepted-intent log,
  and verify the last canonical hash. If replay differs, invalidate the battle
  and grant no reward.
- **Forfeit:** an authenticated semantic intent yields a server verdict; it is
  distinct from network loss and from administrative invalidation.
- **Completion:** freeze the final battle state, calculate allowed rewards, and
  commit battle verdict, Pokémon/inventory mutations, and reward ledger in one
  database transaction. An idempotency key prevents double grants.

For P1, battles may remain ephemeral and reward-free while these semantics are
tested. For P2, do not mutate the durable party at battle start and later append
an unverified result; either lock/version the relevant records or use a battle
snapshot with an optimistic version check at atomic completion.

**Justification:** explicit failures prevent disconnect exploits and duplicated
rewards, while bounded resume supports the charter's dependable loop. Atomic
completion is the minimum safe bridge from battle authority to persistent MMO
progression.

## 7. Information visibility and spectators

Build one complete internal state, then project it per recipient. A participant
receives its own legal choices and all information the rules make observable,
not private opponent selections or unrevealed data. A spectator receives only a
separately defined public projection, preferably delayed for competitive modes.
Logs and metrics should use instance IDs and result codes rather than dumping
complete parties.

The current link battle exchanges full parties, so strict information hiding may
not be necessary for the first faithful private mode. Even then, projection must
be an explicit policy so later matchmaking or expanded rules do not accidentally
leak selections, hidden moves, or server RNG state.

**Justification:** a visibility layer is cheap to define at the new boundary and
avoids protocol redesign when the project grows beyond trusted friends, while
data-minimized logs support the privacy principle.

## 8. Incremental migration

### Phase 0 — Freeze and characterize current behavior

- Catalogue every link action, battle result, forced switch, disconnect, and
  desync path.
- Add golden fixtures for damage rounding, critical hits, accuracy, speed ties,
  status, multi-turn moves, faint/switch, PP, and representative move effects.
- Replay identical party/seed/action inputs twice and assert byte-identical
  canonical state and event streams.

**Exit gate:** existing P0 battle tests remain green and the chosen mechanics
matrix has named coverage. This protects the current private-session goal before
structural work begins.

### Phase 1 — Extract a headless single-turn core

- Define schemas for initial state, intent, state, event, ruleset, and RNG.
- Resolve one fixed two-action turn under plain Lua/LuaJIT without LÖVE stubs.
- Grow conformance coverage until a complete link battle can run headlessly.
- Keep `BattleState` using the same core locally, so extraction does not fork
  mechanics.

**Exit gate:** client and headless adapters produce identical golden traces and
the core contains no presentation or transport dependency. This validates the
shared-core hypothesis before server infrastructure is committed.

### Phase 2 — Version and provision the server rulebook

- Add protocol, simulation, ruleset, content-manifest, and approved-mod digests
  to a versioned join/battle handshake.
- Define the operator provisioning path and complete the legal/artifact review.
- Reject incompatible parties before creating a battle.

**Exit gate:** compatibility failures are stable and actionable, and deployed
server artifacts pass the no-ROM/save/generated-asset scan. This preserves
browser interoperability and the bring-your-own-ROM goal.

### Phase 3 — Shadow validation

- Run the headless server simulation from copies of current party/action traffic
  while clients remain authoritative for the visible P0 match.
- Compare per-turn canonical states; record counters and redacted diagnostics,
  but never grant rewards from shadow results.
- Exercise worker crash, delayed/duplicate packet, reconnect, and version-skew
  scenarios.

**Exit gate:** the agreed test corpus and pilot sessions meet a defined zero-
unexplained-divergence target. Shadowing is reversible and obtains operational
evidence without breaking the private-session loop.

### Phase 4 — Server-authoritative, reward-free link battles

- Switch negotiated clients from opaque relay to intent/update messages.
- Render only server events, support snapshot resync, and enforce deadlines.
- Keep an explicitly labeled legacy P0 mode only if maintainers can test both;
  never allow legacy battles to affect durable state.

**Exit gate:** two browser profiles and a browser/desktop pair repeatedly complete
challenge → battle → overworld, including reconnect and forced-switch cases, with
one authoritative verdict. This delivers the M2 battle-integrity goal.

### Phase 5 — Transactional progression slice

- Source parties from authenticated server records.
- Add an idempotent finalization transaction and audit record.
- Enable one deliberately bounded reward/progression outcome, then test rollback,
  retry, disconnect, restore, and concurrent-session conflicts.

**Exit gate:** the M3 vertical slice survives reconnect and backup restore with no
duplicate or client-invented reward. Trading, broad PvE, rankings, and economies
remain separate scope.

## 9. Testing and operational evidence

The change is complete only with evidence at several layers:

| Layer | Required evidence |
| --- | --- |
| Pure mechanics | Table-driven unit tests and golden vectors for rules, RNG, integer/overflow behavior, and every extracted effect family |
| Determinism | Same input log produces the same canonical snapshot/events across repeated runs, worker restarts, and supported platforms |
| Conformance | Current client adapter and headless core agree during extraction; any intentional divergence is versioned and documented |
| Protocol | Valid/invalid schemas, ownership, phase, revision, idempotency, size, ordering, and visibility projection tests over TCP and WebSocket |
| Lifecycle | Challenge, ready, timeout, forfeit, disconnect/resume, duplicate intent, worker crash/replay, and cleanup integration tests |
| Persistence | Atomic verdict/reward, optimistic conflict, retry, rollback, backup/restore, and no-double-grant tests before M3 |
| Security | Fuzzed intent decoder, rate/resource limits, no client Lua execution, manifest allowlist, and redacted logs |
| Capacity | Measured simultaneous battles, turn-resolution latency, worker saturation, queue depth, memory, and replay recovery time against pilot targets |
| Browser UX | Server-delay simulation, animation queue catch-up, resync, keyboard/touch operation, and accessible status announcements |

At minimum expose counts of battles by phase/result, intent rejection code,
timeouts, reconnects, simulation duration, queue delay, resyncs, replay failures,
and version incompatibilities. Use battle IDs for correlation, but do not log ROM
bytes, save payloads, full parties, secret RNG state, or authentication tokens.

## 10. Alternatives and explicit non-goals

### Alternatives rejected for the first implementation

- **Trust client verdict plus two matching signatures:** both clients and their
  inputs remain untrusted, and collusion or identical modified code wins.
- **Send all random rolls from the server but simulate on clients:** improves RNG
  control but leaves action legality and state mutation client-owned.
- **Rerun only completed battles:** delays cheat detection, complicates user
  experience and rewards, and still requires the full authoritative engine.
- **Rewrite every mechanic in TypeScript immediately:** maximizes scope and
  creates two sources of truth before headless feasibility is measured.
- **Move the entire LÖVE `BattleState` to the server:** couples correctness and
  capacity to presentation and imports unnecessary asset dependencies.

### Non-goals of this proposal

- Rebalancing or modernizing Generation I mechanics.
- Adding doubles, raids, broad PvE encounters, matchmaking, rankings, or public
  spectator infrastructure.
- Uploading player ROMs, saves, extracted assets, or Lua mods to the coordinator.
- Promising seamless failover or massive concurrency before pilot measurements.
- Granting persistent rewards from legacy opaque-relay battles.

## 11. Open decisions before implementation

1. Which exact link rules and intentional divergences define simulation version
   1, and who approves changes?
2. What battle-only data is legally and technically acceptable in an operator-
   provisioned manifest, and how is it generated without a player upload path?
3. Does the first worker use standalone Lua, LuaJIT, or another sandboxed runtime,
   and what are its measured resource limits?
4. Which resume window and timeout outcome best fit friendly versus competitive
   modes?
5. What party/version locking model will the M3 transaction use?
6. Which state is observable to an opponent or spectator in the faithful private
   mode?
7. What measured divergence, latency, and capacity thresholds are required to
   leave shadow mode?

These are release-gate decisions, not reasons to keep valuable outcomes client-
authoritative. Resolve them using fixtures, pilot measurements, and legal review,
consistent with the project's evidence-over-aspiration principle.