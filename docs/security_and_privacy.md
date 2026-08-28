# Security and privacy

**Status:** Draft baseline for private sessions; not a public-service security
review
**Owner:** Project maintainers; a future public operator must name a security
owner

## Scope and assets

Protect player-supplied ROMs and saves, endpoint configuration, service
availability, ephemeral identity/presence, battle isolation, build/release
artifacts, and operator credentials. The P0 coordinator is not trusted with ROM
or save content and must not gain an upload endpoint for either.

## Trust model

- Browser, desktop client, installed mods, and all network input are untrusted
  from the coordinator's perspective.
- Coordinates, appearance, name, battle payloads, and battle completion are
  client-reported today. They must never grant durable or valuable state.
- The coordinator owns connection membership, ephemeral UUIDs, challenge and
  battle membership, and the shared battle seed.
- Static hosts serve code only. ROM import, extraction, cache, and save storage
  stay under player control.
- Repository and CI credentials belong in the hosting platform's secret store,
  never source, client bundles, query strings, fixtures, or logs.

## Threats and required controls

| Threat | Current/required response |
| --- | --- |
| ROM/save disclosure | No upload route; ignore rules and artifact scans; inspect release bundles |
| Malformed or cross-session messages | Strict schemas, framing limits, state checks, and isolation tests |
| Impersonation/cheating | Treat guest name and gameplay claims as untrusted; do not award persistent value |
| Flooding/resource exhaustion | P1 must add per-connection/message limits, idle expiry, challenge expiry, and connection caps before a public pilot |
| Dependency or build compromise | Review lockfile changes, use pinned lockfiles, scan dependencies and final artifacts |
| Client-side script/mod execution | Execute only locally installed or server-approved code; never accept executable Lua from a peer |
| Endpoint leakage | Do not log full URLs/query strings; redact credentials and tokens |
| Stale sockets/state | Shutdown hooks and disconnect cleanup; add fault-injection tests and bounded cleanup metrics |

TLS termination and `wss://` are required outside a trusted local network.
Do not describe TLS as authentication: the current service has no accounts,
authorization, or session recovery.

## Data lifecycle

| Data | Location | Lifetime/deletion |
| --- | --- | --- |
| ROM and extracted cache | Player device | Until player changes/removes local browser or filesystem data |
| Save | Player device | Until local deletion/export; never sent to P0 coordinator |
| Name, position, connection/battle IDs | Coordinator memory | Connection/session lifetime; lost on restart |
| Operational logs | Operator environment | Avoid player content; retention is not yet defined, so public operation is blocked pending an explicit policy |

Any P2 identity or persistence proposal requires an ADR, data inventory, lawful
purpose, access/deletion process, retention period, backup treatment, encryption
plan, and incident owner before collection begins.

## Reporting and response

Do not publish exploitable details or personal data in an issue. Until a private
security contact is named, contact the maintainer privately through the hosting
platform profile and disclose only the minimum needed. Maintainers should
acknowledge, reproduce, contain, patch, rotate affected secrets, notify affected
operators/users where appropriate, and record a sanitized retrospective.

This document is engineering guidance, not a claim of complete security or legal
advice.