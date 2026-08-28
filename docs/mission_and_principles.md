# Mission and principles

**Status:** Draft policy for maintainer review
**Owner:** Project maintainers
**Source of truth:** This document defines stable product principles; the
[project charter](project_charter.md) defines milestone scope and acceptance.

## Mission

Build an extensible, browser-first Generation I multiplayer experience where
friends can meet, challenge one another, and use the original link-battle loop
without the project distributing a ROM or ROM-derived assets.

## Who the project serves

- Players who own a compatible ROM and want a small private session.
- Hosts who need a repeatable one-command setup and clean shutdown.
- Contributors extending the native engine, browser package, or coordinator.
- Future operators evaluating a dependable pilot, not a promised public MMO.

## Principles

1. **Bring your own ROM.** Permanent hosting keeps ROM bytes, saves, and
   extracted assets in player-controlled local storage. The coordinator has no
   upload path for them.
2. **Non-commercial and unaffiliated.** The project is educational, not
   monetized, and not endorsed by the relevant rights holders. Follow
   [`DISCLAIMER.md`](../DISCLAIMER.md) and the
   [legal and asset policy](legal_and_asset_policy.md).
3. **Browser first, shared core.** The browser is the primary player surface.
   Desktop and browser clients should retain one game implementation and one
   coordinator protocol.
4. **Accessible by default.** Launch and connection flows must work without a
   pointer; game-canvas limitations must be documented rather than hidden.
5. **Authority moves deliberately.** Do not persist valuable state until the
   server can validate the action that produced it.
6. **Evidence over aspiration.** Tests, measurements, and current source define
   present behavior. Label targets and proposals clearly.
7. **Small, reversible increments.** Preserve the private-session loop while
   improving contracts, safety, and reliability.

## What “MMO” means by milestone

| Milestone | Meaning |
| --- | --- |
| M0–M1 | A guest-only, in-memory private session with shared presence and two-player link battles. |
| M2 | A bounded pilot with stronger server authority, compatibility negotiation, observability, and abuse controls. |
| M3 | One authenticated, transactional progression slice with tested recovery. |
| M4 | A decision gate for larger scale; not a promise of massive concurrency or a public launch. |