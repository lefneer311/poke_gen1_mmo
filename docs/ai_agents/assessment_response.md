# Assessment of proposed MMO architecture ideas

**Status:** Evaluated proposal; not an architecture decision
**Scope:** Evaluation of every proposal in
[`assessment_ideas.md`](assessment_ideas.md)
**Decision authority:** The project charter, accepted architecture decision
records (ADRs), and executable contracts take precedence over this assessment.

## Executive recommendation

The ideas point in the right direction, but they describe several different
delivery horizons. The project should retain the native Lua engine and its
registry/content model, stabilize today's private-session loop, and then move
authority server-side through narrow, testable slices. It should not interpret
the favorable overall assessment as approval to add persistence, modern battle
mechanics, microservices, or large-scale infrastructure during the current
baseline milestone.

The recommended sequence is:

1. Finish the M0/M1 protocol and multiplayer-loop baselines.
2. In M2, replace trusted state reports with semantic commands, validate tile
   movement, and prove a deterministic, headless Gen I battle session.
3. In M3, add durable identity and one transactional progression slice only
   after the server can verify the facts being stored.
4. Treat later-generation mechanics, general scripting, and horizontal scaling
   as separately approved work after that vertical slice succeeds.

This sequence supports the charter's incremental-authority goal while retaining
the bring-your-own-ROM boundary. The server must not receive a player's ROM,
generated cache, save, or client-provided Lua.

## Evaluation criteria

Each idea is evaluated against five questions:

- **Evidence:** Does current source-backed documentation support the premise?
- **Milestone fit:** When does the work belong in the charter?
- **Authority and security:** Does it reduce trust in client-reported valuable
  state without creating a new unsafe boundary?
- **Complexity:** Can it be introduced as a reversible vertical slice?
- **Legal and content boundary:** Does it preserve local ROM import and avoid
  distributing or uploading protected assets?

The labels below mean:

- **Adopt** — use as a planning constraint now.
- **Prototype** — validate the approach before selecting a permanent design.
- **Defer** — plausible, but outside the active milestone or dependent on
  missing evidence.
- **Reject for now** — the proposal creates cost or risk without serving the
  current delivery gate.

## 1. Keep Lua server-side, at least initially

**Assessment: Prototype the simulation boundary; defer the hosting choice.**

Reusing Lua battle mechanics is preferable to immediately maintaining a second
battle implementation. Low-level battle modules accept injected random-number
generation and table-shaped state, but the complete `BattleState` still creates
presentation objects and reads global state. Consequently, the reusable unit is
not yet "the client battle engine running on the server." It is a serializable
battle session that must be extracted and characterized first.

Evaluate the three hosting options only after the same deterministic fixture can
run without graphics or audio:

| Option | Strength | Cost/risk | Recommendation |
| --- | --- | --- | --- |
| Separate Lua worker | Process isolation, preserves the existing Lua runtime, and is easy to replace | RPC schema, supervision, timeouts, deployment packaging, and state-transfer overhead | Preferred first integration experiment, not yet a production commitment |
| Embedded Lua | Lower call overhead and a single deployable process | Native bindings/WASM/runtime compatibility, crash containment, memory limits, and harder upgrades | Compare only after the worker fixture establishes behavior |
| Port simulation to TypeScript or another server language | One server toolchain and potentially simpler operations later | Dual-engine drift during migration and a large unproven rewrite | Defer until authoritative rules and golden transcripts are stable |

Whichever option wins must use server-selected, pinned rulesets. Never execute
Lua or content handlers supplied over the network. Define action schemas,
explicit RNG state, resource limits, deterministic transcripts, and failure
behavior before connecting simulation to rewards. This is M2 work; durable
results are M3 work.

## 2. World simulation is harder than battles

**Assessment: Adopt the bounded-command model, with qualifications.**

A battle is naturally session-oriented, while an overworld includes movement,
warps, encounters, NPC schedules, scripts, reconnects, and concurrent players.
Tile movement makes the first authority step tractable, but does not by itself
solve latency, contention, or content compatibility.

The M2 server should accept an intent such as `move north` with a monotonically
increasing sequence number, then validate session state, movement rate, map
adjacency, collision, and authoritative warps. It should return an accepted
tile/map plus a sequence or a stable rejection and correction. The client may
predict and interpolate, but it must reconcile to the authoritative tile.

This requires a server-readable, versioned collision/warp representation. It
must be legally distributable and must match the client's negotiated content
fingerprint; a map number reported by the client is not sufficient evidence.
NPCs, encounters, and state-changing map scripts should be added in later
vertical slices rather than folded into the first movement change.

## 3. Keep cosmetics client-side and consequences server-side

**Assessment: Adopt as the target authority principle.**

The proposed boundary matches the charter: rendering, animation, interpolation,
audio, camera, menus, and dialogue presentation can remain local, while the
server ultimately owns location, parties, HP/PP, inventory, currency,
progression, encounter outcomes, trades, and durable flags.

Script classification must be based on effects rather than function names:

| Class | Examples | Execution rule |
| --- | --- | --- |
| Presentation | Show text, play sound, animate, change camera | May run on the client; cannot mutate authoritative state |
| Command | Request movement, choose a move, attempt a purchase, answer a dialogue choice | Client sends typed intent; server validates it |
| Authoritative effect | Give/remove item, change money, set quest flag, warp, start encounter, grant experience | Server-owned handler commits or rejects; client renders the result |
| Mixed | Dialogue that opens a shop or conditionally grants an item | Split presentation from a server command and authoritative response |

Do not expose arbitrary remote procedure calls or uploadable scripts. Give every
state-changing command an authorization context, schema, ruleset version, and
idempotency/replay policy. This target is primarily M3, built on M2 movement and
battle verification.

## 4. Use the registry/content system for extensibility

**Assessment: Adopt as a strategic advantage; require an end-to-end proof.**

The engine's registries use string keys and support ordered register, override,
patch, and remove operations. That avoids inheriting many ROM-index ceilings and
makes namespaced identifiers such as `mmo:shopkeeper_pokemon` technically
reasonable. Existing evidence does not prove that every UI, save, trade, link,
or MMO path handles arbitrary custom entries correctly.

Before promising cross-generation or event content, create one original,
legally distributable test species and move, then verify registration, asset
resolution, learnset/evolution, save/reload, compatibility fingerprinting,
battle, trade, and MMO serialization. Define identifier normalization,
namespace ownership, dependency order, removal semantics, and conflicts. The
server and client must negotiate a ruleset/content fingerprint and fail closed
before gameplay when their battle- or world-relevant definitions differ.

Vanilla assets should continue to originate from the player's locally imported
ROM. Project content packs must contain only original or appropriately licensed
material. Registry flexibility is an engine capability, not permission to
redistribute later-generation game data or assets.

## 5. Defer later-generation mechanics

**Assessment: Adopt the deferral.**

Modern mechanics are more than a Pokémon record migration. They affect stat
calculation, damage, move eligibility, switching, item timing, ability hooks,
serialization, database constraints, AI, UI, compatibility fingerprints, and
every consumer of party data. A schema with IVs, EVs, nature, ability, and held
item illustrates the destination but does not specify generation-specific
rules, defaults, migration, or interoperability.

The first authoritative simulation should preserve a named Gen I ruleset and
the four-move/stat model already characterized by the engine. Later mechanics
need a separate ADR and proposal covering ruleset versioning, migrations,
content licensing, UI work, deterministic fixtures, and whether old characters
can cross rulesets. They are explicitly outside M0–M2 and should not block the
M3 Gen I progression slice.

## 6. Treat browser viability as low risk, not no risk

**Assessment: Agree with the premise, but retain browser release gates.**

The browser uses the same Lua game through love.js/WebAssembly, with local ROM
import/storage and WebSocket-backed transport. The project therefore does not
need to invent a separate browser game engine while adding MMO authority.

The remaining risks are operational: asynchronous socket behavior, browser
storage quotas and eviction, mobile input, cross-origin and TLS deployment,
memory/performance differences, build reproducibility, reconnect behavior, and
browser compatibility. M1 must still prove the two-profile multiplayer journey;
M2 must run automated browser smoke tests on the supported matrix. Every future
semantic-protocol change must maintain parity between desktop TCP and browser
WebSocket adapters.

## 7. Change the protocol early

**Assessment: Adopt semantic commands incrementally; retain JSON framing.**

Newline-delimited JSON is adequate for current scale and is shared by native and
browser clients. Changing serialization would add risk without improving the
authority boundary. The important change is from state replacement or opaque
relay toward typed intent and authoritative results.

Do not break the M0 contract in place. First document/version the current
catalogue and add canonical fixtures. Then introduce negotiated semantic
messages alongside current messages, for example:

```json
{
  "type": "battle_action",
  "battleId": "abc",
  "actionId": 17,
  "action": { "type": "move", "slot": 2 }
}
```

```json
{
  "type": "move_intent",
  "sequence": 384,
  "direction": "north"
}
```

Schemas must define lifecycle state, bounds, authorization, ordering,
idempotency, errors, and reconnect behavior. The server should return explicit
accepted/rejected outcomes and authoritative revisions. Opaque
`battle_message` can remain for the non-persistent link-battle path until a
complete server battle session exists; no durable reward may depend on it.

## 8. Use SQL transactions for durable Pokémon state

**Assessment: Adopt for M3 after authority is established.**

Relational transactions and row-level locking fit trades, purchases, and battle
rewards because several ownership and ledger changes must succeed or fail
together. The existing proposed database design also calls for stable lock
ordering, optimistic versions, idempotency keys, ledgers, and a transactional
outbox; these are necessary complements to `BEGIN`/`COMMIT`, not optional
optimizations.

Transactions cannot make an unverified client assertion trustworthy. Persist a
battle reward only from a server-verified battle completion, and derive price,
eligibility, ownership, and reward values inside the transaction from a pinned
ruleset. Specify retry behavior, isolation expectations, unique constraints,
deadlock handling, audit retention, and rollback tests. Select PostgreSQL versus
MariaDB through an ADR based on the implemented schema and operational support;
do not keep a lowest-common-denominator abstraction merely to avoid deciding.

## 9. Do not persist every frame or tile step

**Assessment: Adopt.**

Active coordinates, interpolation, pending challenges, battle turns, and
short-lived NPC state belong in server memory for the initial architecture.
Persist validated checkpoints on meaningful boundaries such as map changes,
graceful logout, a bounded interval, and authoritative transactions. A battle or
reward transaction should record the durable postcondition, not every animation
or network frame.

The design must explicitly define what is lost on a process crash, the maximum
checkpoint age, reconnect placement, safe-location fallback, and how an atomic
economic transaction relates to a location checkpoint. Logout cannot be the
only persistence trigger. Redis or another shared ephemeral store should be
introduced only when a measured multi-process or failover requirement makes
in-memory ownership inadequate.

## 10. Begin with a modular monolith

**Assessment: Adopt; reject premature microservices.**

One deployable NestJS application with explicit gateway, session, world,
battle, character, inventory, content, and persistence module boundaries is the
appropriate initial shape. It keeps local operation, transactions, tracing,
testing, and failure diagnosis manageable. A supervised Lua worker can still be
an implementation detail of the battle module without turning each domain into
an independently deployed service.

Module boundaries should prevent transport handlers from directly mutating
persistence and should make authoritative commands testable without sockets.
Extract a service only after measurements identify an independent scaling or
fault-isolation need, its data ownership is unambiguous, and the team can operate
versioned inter-service contracts. Service names in a diagram are not evidence
for those costs today.

## 11. Keep initial authentication simple

**Assessment: Adopt staged identity, with strict limits on development tokens.**

Authentication should not displace deterministic simulation and protocol work
in M0–M2. A development-only token mapped to a seeded character is sufficient
for local authoritative-slice testing if it is disabled by default outside the
development environment, has narrow scope and expiry, and never becomes an
undocumented production bypass.

M3 authentication needs more than register/login endpoints: password hashing
with a reviewed Argon2id configuration, TLS, session revocation and rotation,
authorization on every character command, rate limits, recovery, deletion,
audit/privacy rules, and protection against account and character enumeration.
Whether the WebSocket uses an opaque session or a signed token should be decided
from deployment and revocation requirements; "JWT" is not itself a security
design.

## 12. Risk ratings and overall suitability

**Assessment: Directionally agree with the 8/10 conclusion; do not treat the
number as measured evidence.**

The framework has unusually useful foundations: a native engine, local ROM
import, extensible registries, ordinary save structures, shared browser/desktop
game code, deterministic components, headless test infrastructure, and an
existing multiplayer transport. Forking and evolving it is more credible than
discarding those capabilities and starting over.

The original qualitative ratings understate several dependencies. A revised
planning view is:

| Area | Planning risk | Reason / required evidence |
| --- | --- | --- |
| Browser client viability | Low–Medium | Runtime exists; browser matrix, storage, performance, and reconnect gates remain |
| Local ROM/content import | Low technically, High legal/product sensitivity | Proven local flow; distribution policy and legal review remain mandatory |
| Registry extensibility | Medium | String registries exist; one end-to-end custom-content fixture is still needed |
| SQL persistence mechanics | Low–Medium | Conventional technology; migrations, backups, idempotency, and recovery add work |
| Accounts/authentication | Medium | Standard patterns, but recovery, privacy, abuse, and operations are product-critical |
| Inventory/progression authority | Medium | Straightforward domain logic only after commands and rulesets are trusted |
| Battle simulation extraction | Medium–High | Useful deterministic modules exist; full state remains presentation-coupled |
| Server-authoritative movement | Medium–High | Discrete movement helps; content parity, correction, warps, and scripts remain |
| Shared NPC/script world | High | Concurrency, scheduling, mixed effects, and recovery need new contracts |
| Later-generation mechanics | High | Cross-cutting schema, rules, UI, migration, testing, and content work |
| Generic MMO scripting | High | Capability, determinism, sandboxing, versioning, and authority are difficult |
| Large-scale infrastructure | High and deferred | No current milestone or measurement justifies it |

The encouraging headless tests reduce uncertainty about extracting simulation,
but they do not demonstrate a production server loop, hostile-input isolation,
or deterministic parity across runtimes. The conclusion should therefore be
read as **pursue through gated prototypes**, not "the architecture is already
MMO-ready."

## Decisions to record before implementation

The following work should produce reviewed ADRs or equivalent contracts rather
than relying on this assessment:

1. Authoritative command envelope, protocol negotiation, and compatibility
   policy.
2. Server-readable world/content package and fingerprint, including its legal
   provenance.
3. Serializable battle-session API, deterministic RNG contract, and golden
   transcript format.
4. Lua worker versus embedded runtime after both can be compared against the
   same fixture.
5. Durable identity/session model and selected relational database before M3.
6. Checkpoint, crash-recovery, transaction, and idempotency guarantees for the
   first persistent progression slice.

## Proposed validation gates

The assessment becomes actionable only through evidence:

- **M0/M1:** freeze protocol fixtures and repeatedly complete join, presence,
  challenge, battle, and overworld return in two fresh browser profiles.
- **Movement prototype:** replay valid and invalid tile commands against a
  versioned map fixture, including collisions, warps, rate limits, duplicates,
  reordering, correction, and reconnect.
- **Battle prototype:** run fixed parties, actions, ruleset, and seed headlessly;
  compare final state and transcript across repeated runs and supported Lua
  runtimes.
- **Content prototype:** exercise one original custom species and move through
  registry, assets, save, fingerprint, battle, trade, and MMO serialization.
- **Persistent slice:** complete an authenticated, server-verified encounter and
  reward, reconnect to the same state, retry commands without duplication, and
  restore the database backup.
- **Scale decision:** measure first. Add shared ephemeral infrastructure or
  split services only when capacity, availability, or isolation results show a
  concrete need.

## Final position

Proceed with the existing framework and preserve the client engine, local ROM
boundary, registries, and Lua mechanics. Treat the current coordinator as useful
MVP scaffolding rather than the future source of authority. The principal work
is to define deterministic simulation and semantic command boundaries, then
move one consequence at a time to a modular server. This recommendation is
conditional on the validation gates above and does not expand the active
milestone or approve later-generation content, public operation, or large-scale
MMO infrastructure.