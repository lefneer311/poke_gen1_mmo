# Release and operations

**Status:** Draft P0 private-session runbook; public/persistent operation is not
approved
**Owner:** Release owner and service operator must be named per release

## Supported shapes

- `make play`: development/private convenience path that builds and serves a
  ROM through a temporary shared URL. It is explicitly not the copyright-safe
  permanent-hosting model; stop it when the private session ends.
- `make play-local`: the same combined flow without a public tunnel.
- Permanent hosting: static `web/dist/` without ROM/cache/save material plus a
  separately deployed backend accepting TLS WebSockets at `/ws`.
- Backend container: configurable `PORT`/`HTTP_PORT` and `HOST`, with TCP and
  development WebSocket ports configured separately. `GET /health` is the
  current liveness signal.

Node.js 22 or newer is supported by package metadata. The current README lists
macOS as the primary one-command environment and Linux with manually installed
dependencies. A dated browser matrix is still required before the M1 gate.

## Pre-release checklist

1. Name the release owner, target environment, commit, rollback owner, and
   maintenance window.
2. From a clean checkout, install locked dependencies and run the commands in
   [`testing.md`](testing.md).
3. Build the web client. Inspect `web/dist/` and any containing archive for ROM,
   save, extracted/cache output, secrets, source-map leakage, unexpected binary
   files, and third-party notices.
4. Smoke-test local ROM import, join, presence, challenge, battle, return,
   disconnect, health, and clean shutdown in the target browsers/transports.
5. Record image digests/artifact checksums, configuration (without secrets),
   protocol compatibility, known issues, test evidence, and rollback command.
6. Keep the disclaimer and bring-your-own-ROM instructions on launch surfaces.

GitHub Pages builds on pushes to `main` affecting web/game sources and may also
be dispatched with a default `wss://` server. Treat a baked endpoint as public
configuration, never a secret.

## Deployment and verification

Deploy the backend before a client that requires it, verify `/health`, then
publish the immutable static artifact. Confirm the served artifact checksum and
connect through the externally terminated TLS route. Do not log full query
strings because `?server=` can contain sensitive endpoint details.

Minimum P0 observation is process/container state, health probes, startup and
shutdown errors, and manual connection/battle verification. Structured metrics,
alerts, latency histograms, rate limits, and dashboards are P1 requirements; do
not claim production service levels until they exist and have named responders.

## Rollback and incidents

Keep the previous known-good client artifact and backend image. On regression,
stop rollout, restore the compatible backend/client pair, verify health and the
primary loop, and communicate protocol incompatibility. If protected assets or
secrets are published, unpublish immediately, revoke/rotate credentials, remove
cached artifacts where the host permits, preserve minimal incident evidence,
and follow the disclaimer/takedown process.

The P0 backend is in-memory: restarting it is the state-reset and recovery
mechanism, and disconnects all players. There is no database, backup, or restore
procedure. Any persistent release is blocked until migrations, automated
backups, retention, encrypted storage, restore into staging, recovery objectives,
and a successful restore exercise are documented and tested.