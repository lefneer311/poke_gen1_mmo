# Dependencies and upstreams

**Status:** Draft inventory; exact imported revisions remain to be recorded
**Owner:** Project maintainers and the maintainer of each imported subtree

## Imported source trees

| Path | Upstream/project | Local role | License/attribution | Recorded revision |
| --- | --- | --- | --- | --- |
| `gen1recomp/` | `bryanthaboi/gen1recomp` | Native game engine, ROM import, mods, MMO client | `gen1recomp/LICENSE.MD`, subtree README | **Gap: unrecorded** |
| `DramaticShapeVoxelMod/` | DramaticShapeVoxelMod | Optional voxel presentation and browser fixes | `DramaticShapeVoxelMod/LICENSE`, README, changelog | **Gap: unrecorded** |
| `pokered/` | `pret/pokered` | Upstream disassembly used by local build workflow | Subtree README and retained upstream notices | **Gap: unrecorded** |

These directories are copies with local changes, not Git submodules. Before the
next upstream sync, record the upstream URL, immutable commit, import date, and a
list or patch series of local changes in the affected subtree. Do not infer a
revision from a similar current upstream checkout.

## Package dependencies

- `backend/package.json`/`package-lock.json` own NestJS, WebSocket, Zod,
  TypeScript, Jest, and supporting Node packages. Node.js 22 or newer is the
  declared runtime.
- `web/package.json`/`package-lock.json` own `love.js` for the browser build.
- System/build tools include Bash, Python 3, `zip`, RGBDS, LuaJIT, Docker, and
  optionally `cloudflared`; their current setup expectations live in the root
  and subsystem READMEs/scripts.

Lockfiles, not this summary, are the source of exact transitive versions.

## Adding or changing a dependency

Prefer existing facilities and standard libraries. In the pull request, state
purpose, alternatives, direct/transitive footprint, license, maintenance and
security posture, runtime/build-only scope, browser impact, and removal plan.
Update the manifest and lockfile with the ecosystem tool; never hand-edit only
one. Review install scripts, bundled assets, generated code, network behavior,
and published artifact size. Run tests, builds, vulnerability review, license
review, and the final asset scan.

## Updating an imported tree

1. Start from a clean branch and record the current local patch set.
2. Verify upstream URL, immutable before/after revisions, release notes,
   provenance, and license changes.
3. Import without ROMs, generated caches, build output, vendored credentials, or
   irrelevant platform binaries.
4. Reapply local changes as reviewable commits and preserve upstream style and
   attribution; do not mix the sync with unrelated refactoring.
5. Run upstream tests plus this repository's engine, MMO, web build, browser,
   and artifact-safety checks.
6. Update this inventory and describe conflicts, behavior changes, and rollback.

Security updates may be expedited, but still require provenance, compatibility,
artifact, and license review. If an update cannot be made safely, document the
exposure and mitigation rather than silently retaining it.