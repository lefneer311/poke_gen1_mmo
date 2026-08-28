# Testing

**Status:** Draft test policy and command catalogue
**Owner:** Maintainers of each tested subsystem

## Test layers

1. **Static and contract checks:** TypeScript compilation, schema validation,
   framing, serializers, and artifact scans.
2. **Unit/component tests:** Coordinator transitions and isolated Lua modules.
3. **Integration tests:** TCP/WebSocket parity, Lua MMO flows, engine drivers,
   build/package behavior, and disconnect cleanup.
4. **End-to-end/manual checks:** Two browsers complete join → challenge → battle
   → overworld; keyboard/touch/browser compatibility and host shutdown.
5. **Pilot checks:** Reproducible load, latency, recovery, and fault injection;
   these are required by later charter gates but are not yet implemented.

## Commands

| Area | Command | Use |
| --- | --- | --- |
| Backend | `cd backend && npm test` | Protocol, coordinator, and WebSocket framing |
| Backend compile | `cd backend && npm run build` | TypeScript/Nest build |
| MMO Lua | `cd gen1recomp && luajit tests/mmo_world_client_test.lua` | Presence/client behavior |
| MMO battle Lua | `cd gen1recomp && luajit tests/mmo_battle_flow_test.lua` | Challenge/battle flow |
| Engine | `cd gen1recomp && luajit tests/run_engine.lua` | Broad engine regression suite |
| Web | `cd web && npm run build` | Static/WASM bundle and embedded artifact checks |
| Repository | `make test` | Backend build/tests plus selected Lua suites |
| Patch hygiene | `git diff --check` | Whitespace errors |

Use `npm ci` for clean/CI installs when the lockfile and environment permit it;
the existing Makefile uses `npm install`. Web builds can require locally
prepared engine artifacts, so report missing tools/data as a limitation rather
than weakening safety checks.

## Change-to-test mapping

- Protocol/schema/coordinator: valid, malformed, wrong-state, isolation,
  disconnect, and both-transport behavior.
- Lua world/battle: focused MMO test plus affected engine drivers.
- Browser launcher/package: clean build, artifact scan, keyboard check, and a
  supported-browser smoke test; add a screenshot for visible changes.
- Save/import/cache: migration/round-trip and invalid/corrupt input tests. Never
  commit a real save, ROM, or extracted fixture.
- Scripts/CI/release: syntax/usage, failure cleanup, clean checkout build, and
  inspection of the final archive—not only the staging directory.
- Persistence (future): migrations forward/back where supported, transaction
  rollback, concurrency, authorization, backup, and restore.

## Deterministic fixtures

Use synthetic data and fixed seeds. Inject random number generators and clocks;
do not assert against wall-clock timing unless the test controls it. Canonicalize
unordered maps before snapshots. Fixtures must be minimal, reviewable, licensed,
and free of ROM/save-derived content and secrets.

## Reporting

Record the exact command, pass/fail status, relevant environment, and concise
failure reason. A missing dependency or unsupported browser is a warning and
remaining check, not a pass. Do not replace an automated failure with a manual
claim. For milestone evidence, date the run and retain the report or pull-request
link named by the charter.