# Roadmap

**Status:** Draft; owners and dates are unassigned
**Owner:** Project maintainers
**Source of truth:** Milestone definitions and gates remain in the
[project charter](project_charter.md). This document sequences work without
duplicating every requirement.

## Active milestone

**M0: Baseline** is the active milestone until maintainers record evidence that
the current protocol catalogue matches implementation and the existing suites
pass. A milestone changes only through a reviewed update to this file and the
charter; elapsed time does not advance it.

## Sequence

| Order | Outcome | Depends on | Owner | Acceptance evidence |
| ---: | --- | --- | --- | --- |
| 1 | Freeze the implemented wire contract and known gaps | None | Unassigned | [`protocol.md`](protocol.md), schema/coordinator tests |
| 2 | Record supported build and browser baselines | Clean protocol baseline | Unassigned | Dated test and compatibility report |
| 3 | Make join → challenge → battle → return repeatable | Baselines | Unassigned | Three successful runs in two fresh browser profiles |
| 4 | Exercise disconnect cleanup and artifact safety | Repeatable loop | Unassigned | Fault tests and clean distributable scan |
| 5 | Negotiate protocol/content compatibility | M1 exit | Unassigned | Fixtures and cross-version rejection tests |
| 6 | Validate movement and define verifiable battle state | Compatibility contract | Unassigned | Conformance tests and deterministic battle fixture |
| 7 | Add observability and bounded abuse controls | Stable server contracts | Unassigned | Load report, dashboards, and runbook exercise |
| 8 | Design one persistent progression slice | M2 exit and approved ADRs | Unassigned | Threat model, data model, migration/restore plan |

## Gate discipline

- Work on M1 may begin while M0 gaps are being closed, but M1 cannot be called
  complete without M0 evidence.
- Authentication, durable characters, inventory, and progression are M3 work.
- Massive concurrency, public matchmaking, and public-launch operations remain
  outside M0–M2.
- Link issues and pull requests to the row they advance. Put dated evidence in
  the pull request or a focused report rather than marking an unsupported pass.