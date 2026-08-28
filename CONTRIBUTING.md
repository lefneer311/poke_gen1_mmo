# Contributing

Thank you for improving Link Battle MMO. The active goal is a dependable,
copyright-conscious private-session loop; read the
[project charter](docs/project_charter.md) before expanding scope.

## Start here

1. Read [`README.md`](README.md), [`DISCLAIMER.md`](DISCLAIMER.md), the
   [AI/contributor orientation](docs/ai_agents/README.md), and the nearest
   subsystem README.
2. Use Node.js 22 or newer. Run `make setup`, or install subsystem dependencies
   directly when making a narrow change.
3. For mod work, follow
   [`gen1recomp/CONTRIBUTING-mods.md`](gen1recomp/CONTRIBUTING-mods.md) and state
   whether the change uses contributor Lane A or Lane B.

## Branches, commits, and change size

- Work on a topic branch. Keep commits cohesive, imperative, and reviewable.
- Separate refactors from behavior changes. Avoid drive-by formatting and
  generated outputs not intended for version control.
- Preserve public behavior unless the issue and pull request identify a breaking
  change, compatibility plan, migration, and rollback.
- Never commit ROMs, saves, extracted assets, credentials, personal data, or
  debug logs.

## Issues and pull requests

For material changes, describe the problem, milestone, current evidence, scope,
alternatives, and acceptance test before implementation. A pull request should
include:

- a concise outcome-focused title and summary;
- linked issue/roadmap outcome when one exists;
- user-visible and protocol/architecture/security/legal impact;
- exact test commands and results, including environmental limitations;
- screenshots for perceptible web changes and compatibility notes for protocol
  or public API changes;
- migration and rollback instructions when relevant.

Authors own scope, tests, documentation, and responding to review. Reviewers own
checking correctness, failure paths, compatibility, trust boundaries, asset
safety, and milestone fit. Maintainers own policy/ADR acceptance, releases, and
merges. Self-review with the [definition of done](docs/definition_of_done.md).

## Verification

Run narrow tests first. The normal repository check is:

```bash
make test
git diff --check
```

See [`docs/testing.md`](docs/testing.md) for subsystem commands. Do not claim an
unrun check passed. Changes to protocol messages need backend schema/coordinator
tests and Lua client coverage; web changes need a clean build and browser check;
release changes need a complete artifact scan.