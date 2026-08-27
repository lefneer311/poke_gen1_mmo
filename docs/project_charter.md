# Link Battle MMO: project charter and expected requirements

## Purpose and status

This document turns the project's current proof of concept into a testable
delivery plan. It is a draft: numbers marked **proposed** are targets to confirm
after baseline load, latency, and browser-compatibility measurements.

The current MVP is a guest-only, in-memory coordinator. It lets players see
one another on the same map, issue and answer challenges, and relay battle
messages through the original client battle engine. The intended product is a
copyright-conscious, browser-first multiplayer experience built around the
Generation I game, not a claim of affiliation with or endorsement by the
rights holders.

## Product goals

1. **Make a private session easy to run.** A host should be able to start one
   command, share one URL, and stop the whole session cleanly.
2. **Deliver a dependable multiplayer loop.** Two players should be able to
   join, see one another, challenge, complete a link battle, and return to the
   overworld without restarting.
3. **Keep protected game data with the player.** Production/static builds must
   contain no ROM, save, or ROM-derived generated assets; a player's ROM must
   not be uploaded to the coordinator.
4. **Move authority to the server in controlled increments.** Establish clear
   contracts for identity, movement, battle outcomes, inventory, and
   progression before adding persistence or large-scale world features.
5. **Preserve maintainability.** Desktop and browser transports should use the
   same protocol and coordinator behavior, with automated contract and
   regression tests.

## Expected users and primary journeys

| User | Expected journey | Successful outcome |
| --- | --- | --- |
| Session host | Install prerequisites, run `make play` or `make play-local`, and share the printed link | Server and client become reachable and shut down together |
| Browser player | Open the page, supply a compatible ROM locally, choose a session identity, and connect | Existing save/cache remains local and the player enters the world |
| Two players | Meet on the same map, face one another, challenge, accept, battle, and exit | Both clients agree on battle start/end and resume presence |
| Developer | Set up the repository, run server and clients independently, and run the test suite | A repeatable local environment and actionable failures |
| Future operator | Deploy static client and TLS-enabled coordinator independently | Health monitoring works and clients connect through `wss://.../ws` |

## Requirements

### P0 — MVP release requirements

These requirements define a releasable private-session proof of concept.

#### Client and session

- The browser client shall import the user-selected ROM and perform extraction
  locally.
- The client shall persist ROM selection, extracted cache, and save data only
  in browser-controlled local storage unless the user explicitly exports it.
- The launcher shall support server selection, distinct local session names,
  fullscreen, diagnostic output, and changing the locally selected ROM.
- Desktop and browser players shall be able to participate in the same world
  through TCP and WebSocket adapters respectively.
- A disconnected client shall fail visibly and be able to reconnect without
  requiring the server process to restart.

#### Presence and movement

- A player shall join with a validated name, map, tile position, facing, and
  movement state and receive both their assigned ID and the current map
  snapshot.
- A player shall receive join, movement, map-change, and leave updates for
  other players on the same map.
- The client shall interpolate remote movement while keeping tile position as
  the gameplay-relevant location.
- The coordinator shall reject malformed, oversized, out-of-order, or
  state-inappropriate messages with a stable error code and without crashing.

#### Challenges and battles

- A player shall only challenge a connected player on the same map.
- A player shall have no more than one pending challenge or active battle.
- The challenged player shall be able to accept or decline; disconnects and
  cancellation shall notify affected peers and clean up server state.
- Accepted challenges shall give both peers the same battle ID and seed, with
  complementary roles.
- The coordinator shall relay battle payloads only to the matching opponent
  and shall reject messages for an unrelated or inactive battle.
- Battle completion or disconnect shall return the remaining player to a
  valid overworld state.

#### Hosting, safety, and operations

- `make play` shall remain the supported one-command hosted-session path and
  `make play-local` the supported no-public-tunnel path.
- The service shall expose a health endpoint and use configurable bind/port
  settings.
- Production deployment shall support TLS WebSockets at `/ws`; static client
  hosting shall require no server-side rendering.
- Build and CI checks shall fail if a ROM, save, or generated ROM-derived asset
  is detected in distributable output.
- Documentation and user-visible launch surfaces shall carry the
  non-affiliation, non-commercial, bring-your-own-ROM position.
- Logs shall not contain ROM/save content and should avoid full query strings,
  because a server endpoint may be supplied there.

### P1 — dependable pilot requirements

These requirements follow the MVP and should not silently expand P0 scope.

- Add explicit protocol version negotiation and compatibility errors.
- Add reconnect/session-resume behavior with bounded timeouts and documented
  cleanup semantics.
- Make movement server-authoritative: validate map adjacency, traversability,
  warp destinations, and plausible movement rate.
- Define a battle transcript/state contract and make battle results
  server-verifiable before rewards or progression depend on them.
- Add structured logs, connection/battle gauges, error counters, latency
  histograms, and operational runbooks.
- Add abuse controls: message-rate limits, connection limits, name policy, and
  maximum idle/session lifetimes.
- Run automated browser smoke tests against the built WebAssembly client on the
  supported browser matrix.

### P2 — persistent MMO requirements

P2 begins only after P1 contracts and measurements are stable.

- Add accounts or another durable identity model, secure authentication,
  authorization, recovery, and deletion flows.
- Store characters, parties, Pokémon, inventory, currency, progression, and
  world state in a transactional database with migrations and backups.
- Make the server authoritative for state-changing scripts, encounters,
  rewards, trades, inventory, and progression; retain animation, audio,
  interpolation, menus, and other cosmetic behavior on the client.
- Partition worlds/instances and document capacity, consistency, deployment,
  rollback, and disaster-recovery expectations.
- Add moderation, auditability, data-retention rules, and a reviewed legal/IP
  distribution policy before any public launch.

## Non-functional objectives and measurables

Targets below are **proposed pilot service-level objectives**, measured at the
server boundary over a rolling seven-day pilot. Local development and planned
maintenance are excluded. Baselines must be recorded before the targets become
release gates.

| Quality | Proposed measurable | Measurement / release evidence |
| --- | --- | --- |
| Availability | Health endpoint succeeds for >= 99.0% of pilot minutes | External probe report |
| Join reliability | >= 99% of valid join attempts receive a welcome and snapshot within 5 seconds | Server counters plus end-to-end test |
| Presence latency | p95 accepted movement-to-peer-send latency <= 150 ms, excluding internet transit | Timestamped server histogram |
| Battle setup | >= 99% of accepted challenges emit valid starts to both connected peers within 2 seconds | Coordinator metric and integration test |
| Battle integrity | 0 cross-battle or cross-map message deliveries in automated isolation tests | Protocol/integration suite |
| Cleanup | 100% of tested disconnect paths remove presence, challenge, and battle state within 5 seconds | Fault-injection tests |
| Capacity | 50 concurrent connections and 10 concurrent battles for 30 minutes with < 1% server errors (**initial target**) | Reproducible load-test report |
| Build safety | 0 ROM/save/generated-asset signatures in every published artifact | Artifact scan in CI |
| Compatibility | Latest stable Chrome, Firefox, and Safari desktop complete launch/join smoke test; one current iOS Safari and Android Chrome device complete touch smoke test | Dated compatibility matrix |
| Accessibility | Launcher usable by keyboard, controls have accessible names, visible focus, and no critical automated accessibility findings | Automated scan plus manual checklist |
| Maintainability | All protocol changes include schema validation, coordinator tests, and client compatibility notes | Pull-request checklist |
| Recoverability (P2) | Restore a backup into staging within 4 hours with no more than 24 hours of data loss | Quarterly restore exercise |

Privacy/security measurements for P0 are binary gates: no distributable ROM or
save data; no coordinator endpoint capable of receiving ROM/save uploads; input
schema and 64 KiB message limit covered by tests; dependency vulnerabilities
reviewed before release. A public service requires a separate threat model and
legal review.

## Expected outputs

### P0 outputs

- Reproducible desktop and browser client builds.
- NestJS coordinator exposing health, TCP, and WebSocket interfaces.
- Versioned/documented JSON message catalogue, validation rules, lifecycle,
  and error codes.
- Private-session launch scripts and static-client/standalone-server deployment
  instructions.
- Automated coordinator, protocol, WebSocket framing, Lua MMO flow, and engine
  regression tests.
- Copyright-safety artifact scan, disclaimer, troubleshooting guide, and
  compatibility report.
- Baseline load/latency report against the proposed SLOs above.

### P1 outputs

- Authoritative movement/map-data service and conformance tests.
- Battle verification design, deterministic fixtures, and disconnect/recovery
  test suite.
- Observability dashboard, alerts, abuse controls, and operator runbook.
- Automated cross-browser smoke test and release checklist.

### P2 outputs

- Reviewed data model, migrations, persistence service, backups, and restore
  evidence.
- Authentication/authorization and player data lifecycle documentation.
- Server-authoritative progression vertical slice (encounter through durable
  reward), then trading and additional world systems.
- Capacity model, staged rollout plan, moderation tools, and public-launch
  readiness review.

## Milestones and acceptance gates

| Milestone | Objective | Exit gate |
| --- | --- | --- |
| M0: Baseline | Freeze and document the current protocol and supported environments | Existing automated suites pass; protocol catalogue matches implementation; known gaps are logged |
| M1: Private-session MVP | Make the complete two-player journey repeatable | Two fresh browser profiles complete join -> presence -> challenge -> battle -> overworld three consecutive times; artifact scan is clean |
| M2: Dependable pilot | Establish authority, observability, and bounded operation | P1 requirements implemented; proposed SLO load run passes; browser matrix and disconnect fault tests pass |
| M3: Persistent vertical slice | Persist one end-to-end progression outcome safely | Authenticated player completes encounter/reward, reconnects, and sees the same transactional state; backup restore succeeds |
| M4: MMO readiness decision | Determine whether to scale scope and operations | Security, legal/IP, moderation, recovery, cost, and capacity reviews have named owners and approval |

## Explicit non-goals for P0/P1

- Massive concurrency, seamless global worlds, public matchmaking, or a
  production uptime guarantee.
- Accounts, database persistence, cross-device save synchronization, economies,
  trading, quests, or authoritative rewards.
- Reimplementing or modernizing all Pokémon mechanics, adding later-generation
  content, or guaranteeing compatibility with arbitrary ROM revisions.
- Distributing a commercial ROM, extracted copyrighted assets, or user saves.
- Treating client-reported movement or relayed battle messages as sufficiently
  trustworthy for a persistent economy.

## Assumptions, dependencies, and risks

| Item | Response / decision needed |
| --- | --- |
| Rights and distribution | Continue bring-your-own-ROM and non-commercial posture; obtain qualified legal review before public availability or monetization |
| Client authority and cheating | Keep P0 social/non-persistent; do not attach durable value until movement, battle results, and rewards are verified server-side |
| Browser/LÖVE compatibility | Pin build dependencies, retain compatibility build by default, and publish a dated browser/device matrix |
| In-memory state loss | Document that a restart ends the session; persistence belongs to P2, not an implicit MVP promise |
| Protocol drift | Introduce protocol versions and contract fixtures before independently deployed clients/servers become common |
| Upstream/licensing changes | Track retained third-party licenses and document local modifications when updating imported projects |
| Operational abuse | Keep private pilots bounded; implement P1 rate/connection limits before widening access |
| Scope growth | Require milestone ownership and acceptance evidence; later-generation mechanics and broad MMO systems remain separate proposals |

## Ownership and reporting template

Before scheduling a milestone, assign one accountable owner for client,
coordinator/protocol, infrastructure/operations, testing/release, and legal/IP.
At each milestone review, publish:

1. requirement status (`met`, `not met`, `deferred`, or `changed`);
2. links to test, artifact-scan, load, and compatibility evidence;
3. actual values for every applicable measurable;
4. open defects and risks, each with an owner and target date; and
5. a go/no-go decision for the next milestone.

Changes to a target should record the baseline, rationale, approver, and date so
that success criteria are not weakened after results are known.