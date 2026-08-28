# AI agent orientation and recommended references

## Purpose

This index recommends the project documents an AI agent should read before it
suggests, edits, or commits code. Its goal is to keep proposed work aligned with
the project's mission, current delivery milestone, architectural boundaries,
and legal posture. It is an orientation aid, not permission to treat every note
in `docs/` as an accepted design.

An agent should read the documents in the order below, inspect the affected
source and tests, and state any unresolved assumptions before making a change.
For a documentation-only change, the same rules apply wherever the change makes
claims about runtime behavior or project direction.

## Authority and conflict order

When references disagree, use this order of precedence:

1. The current task and repository-scoped agent instructions, if present.
2. Executable behavior, tests, schemas, build configuration, and CI checks.
3. The project charter and accepted, current design decisions.
4. Maintainer and contributor documentation for the affected subsystem.
5. Source-backed investigations.
6. Proposals, assessments, and exploratory notes.

Do not silently resolve a conflict in favor of the document that best supports
a preferred implementation. Call out the conflict and either update the stale
reference in the same change or keep the proposal narrowly scoped.

## Required pre-edit reading

Read these references for every code change:

| Order | Document | What the agent should take from it |
| ---: | --- | --- |
| 1 | [`README.md`](../../README.md) | The mission, supported user experience, bring-your-own-ROM model, repository map, and primary development commands. |
| 2 | [`DISCLAIMER.md`](../../DISCLAIMER.md) | The non-commercial, non-affiliated legal posture and restrictions around ROMs and derived assets. |
| 3 | [`docs/project_charter.md`](../project_charter.md) | Product goals, milestone boundaries, measurable acceptance gates, explicit non-goals, risks, and expected evidence. |
| 4 | [`docs/ai_agents/source_investigation.md`](source_investigation.md) | A source-backed account of ROM import, engine extensibility, current client/server authority, persistence, and headless battle feasibility. Recheck affected claims against current code. |
| 5 | The README, tests, schemas, package/build files, and contributor guide nearest the files being changed | The actual subsystem contract, local conventions, and supported verification commands. |
| 6 | The implementation and its call sites | The present behavior. Documentation summaries never replace source inspection. |

Before editing, translate the request into a charter goal or milestone. If it
does not serve one, explain why the work is still necessary or recommend that it
be deferred. In particular, do not smuggle P2 persistence or large-scale MMO
scope into a P0/P1 maintenance change.

## Task-specific references

Read the applicable rows in addition to the required set.

| Change area | References and checks |
| --- | --- |
| Mod, loader, registry, hook, or mod API | [`gen1recomp/CONTRIBUTING-mods.md`](../../gen1recomp/CONTRIBUTING-mods.md), the relevant example mod, generated registry documentation, loader tests, and compatibility fixtures. Determine whether the change is contributor Lane A or Lane B before editing. |
| Browser client or packaging | [`web/README.md`](../../web/README.md), `web/package.json`, `web/build-web.sh`, the artifact-safety checks, and browser-facing code paths. Preserve local ROM handling and static-host compatibility. |
| MMO client, coordinator, or protocol | [`docs/client_server_relationship.md`](../client_server_relationship.md), the client and backend message schemas, coordinator tests, transport adapters, and applicable sections of the charter. Where the relationship document is incomplete, derive and document behavior from code rather than guessing. |
| Persistence or database | [`docs/database/tables.md`](../database/tables.md), the individual table notes, migrations, entity definitions, and transactional tests. Verify the work belongs to the active milestone before expanding durable state. |
| Architecture or authority boundaries | [`docs/ai_agents/source_investigation.md`](source_investigation.md), [`docs/proposed_architecture.md`](../proposed_architecture.md), and the authority matrix in the source-backed investigation. Treat the proposed architecture as a proposal, not current behavior. |
| ROM import, cache, or distributable assets | [`DISCLAIMER.md`](../../DISCLAIMER.md), import/cache code, `.gitignore`, build artifact scans, and the charter's hosting and safety requirements. Never add ROM bytes, saves, or ROM-derived generated assets. |
| Imported/upstream project code | The license, README, contribution guide, tests, and style of that subtree. Preserve attribution and distinguish local behavior from upstream behavior. |
| Launch scripts, CI, or operations | Root `README.md`, `Makefile`, the relevant script, workflow definitions, health checks, and deployment documentation. Keep documented one-command workflows working. |

The following files are useful background, but they are not decisions:

- [`initial_investigation.md`](initial_investigation.md) records hypotheses and
  questions that prompted source inspection.
- [`assessment_ideas.md`](assessment_ideas.md) collects suggested directions and
  trade-offs.
- [`proposed_architecture.md`](../proposed_architecture.md) illustrates a target
  architecture without defining a migration plan or current guarantees.

Use these documents to discover questions, then validate answers in the charter,
source-backed documentation, implementation, and tests.

## Documentation set

The following focused documents now have initial drafts. A **draft** describes
current evidence and explicit gaps; it does not imply maintainer approval. Each
policy identifies its owner or records that an owner remains unassigned.

| Proposed document | Recommended contents |
| --- | --- |
| [`docs/mission_and_principles.md`](../mission_and_principles.md) | A short, stable statement of whom the project serves, the bring-your-own-ROM and non-commercial principles, browser-first priorities, accessibility expectations, and the meaning of “MMO” at each milestone. |
| [`docs/roadmap.md`](../roadmap.md) | The active milestone, sequenced outcomes, dependencies, owners, and links to acceptance evidence. It references rather than duplicates the charter. |
| [`docs/architecture/current.md`](../architecture/current.md) | A maintained current-state component diagram, ownership boundaries, data flows, trust boundaries, and links to the implementing modules. |
| [`docs/architecture/decisions/NNNN-short-title.md`](../architecture/decisions/0000-template.md) | Immutable architecture decision records containing context, decision, alternatives, consequences, status, and superseding decision. |
| [`docs/protocol.md`](../protocol.md) | Current client/server messages, directions, schemas, known size limits, state transitions, error codes, and the compatibility policy; versioning and canonical fixtures remain gaps. |
| [`docs/security_and_privacy.md`](../security_and_privacy.md) | Threat model, trust boundaries, accepted client authority, validation and abuse controls, secrets/logging rules, player-data lifecycle, and reporting guidance. |
| [`docs/legal_and_asset_policy.md`](../legal_and_asset_policy.md) | Actionable rules for ROMs, extracted assets, saves, screenshots, original assets, licenses, attribution, and artifact review. It complements rather than weakens the disclaimer. |
| [`CONTRIBUTING.md`](../../CONTRIBUTING.md) | Repository-wide setup, branch and commit expectations, change sizing, issue/PR requirements, review responsibilities, and a map to subsystem guides. |
| [`docs/style_guide.md`](../style_guide.md) | Language-specific formatting and naming rules, Markdown conventions, whitespace and alignment policy, generated-file rules, and available checks. |
| [`docs/testing.md`](../testing.md) | The test pyramid, exact commands by subsystem, required tests by change type, fixtures, deterministic RNG/time guidance, browser checks, and how to report environmental limitations. |
| [`docs/definition_of_done.md`](../definition_of_done.md) | A concise self-review checklist covering scope, behavior, compatibility, security, legal safety, documentation, tests, generated outputs, and rollback. |
| [`docs/release_and_operations.md`](../release_and_operations.md) | Supported environments, build/release steps, artifact scanning, deployment, observability, rollback, backup/restore gaps, and incident procedures appropriate to the active milestone. |
| [`docs/accessibility.md`](../accessibility.md) | Keyboard, focus, labels, color/contrast, motion, touch targets, browser/game-canvas constraints, and manual plus automated checks. |
| [`docs/dependencies_and_upstreams.md`](../dependencies_and_upstreams.md) | Imported trees, known revision gaps, local patch policy, update procedure, retained licenses, and dependency review expectations. |

Keep each policy close to the code it governs when a repository-wide document
would become vague. A subsystem guide may override a general recommendation,
but it should link back to the common policy and explain the exception.

## Writing and formatting recommendations

Until a repository-wide style guide is adopted, agents should follow the
surrounding file and these conservative defaults:

- Use clear US English, active voice, and concrete nouns. Define acronyms on
  first use and use the project's established terms consistently.
- Describe current behavior in the present tense. Label future behavior as
  **proposed**, milestone-bound, or exploratory; do not turn aspirations into
  guarantees through wording alone.
- Keep code identifiers, message names, commands, paths, ports, and configuration
  values exact and in backticks.
- Preserve the local language's formatter output. Do not manually align code
  with runs of spaces when an automated formatter would undo it.
- Use spaces rather than tabs in Markdown, remove trailing whitespace, keep one
  final newline, and avoid unrelated whitespace-only churn.
- Wrap prose consistently with the surrounding document (prefer approximately
  80 characters in new Markdown files). Do not wrap tables or code where doing
  so harms readability or correctness.
- Use headings in a logical hierarchy, descriptive link text, fenced code blocks
  with language tags, and tables only when readers need to compare consistent
  fields.
- Update comments and documentation with behavior. Comments should explain
  constraints and intent, not restate the next line of code.
- Preserve public compatibility by default. Name intentional breaking changes,
  migration steps, and rollback paths explicitly.
- Keep commits cohesive. Exclude debug output, temporary files, generated
  artifacts not meant for version control, secrets, ROMs, saves, and unrelated
  cleanup.

## Agent self-check before suggesting or committing changes

An agent should be able to answer **yes** to each applicable item:

### Orientation and scope

- [ ] I can name the project goal and active milestone this change serves.
- [ ] I read the required references and the nearest subsystem guidance.
- [ ] I inspected current source, call sites, tests, and configuration rather
      than relying only on investigation notes.
- [ ] I separated current facts, inferences, and proposals in my reasoning and
      documentation.
- [ ] The patch is the smallest coherent change that satisfies the request and
      does not introduce deferred milestone scope accidentally.

### Correctness and compatibility

- [ ] Input, output, error, lifecycle, reconnect, and cleanup behavior remain
      correct or are intentionally changed and documented.
- [ ] Desktop/browser and TCP/WebSocket parity remains intact where applicable.
- [ ] Existing saves, mods, protocol peers, and public APIs remain compatible,
      or the change includes an approved migration and compatibility note.
- [ ] Client-reported data is not newly trusted for durable or valuable state.
- [ ] Tests cover the user-visible effect and important failure paths, not only
      implementation details.

### Language, style, and patch hygiene

- [ ] Names and prose match project terminology and do not overstate current
      capabilities or legal assurances.
- [ ] The formatter and linter for every touched language pass.
- [ ] Indentation, whitespace, imports, line endings, and file layout match the
      surrounding code; no unrelated formatting churn is present.
- [ ] Generated files were produced by their generator rather than hand-edited,
      and all required generated outputs are included.
- [ ] `git diff --check` passes and the staged diff contains only intended work.

### Safety and evidence

- [ ] No ROM, save, extracted copyrighted asset, credential, or sensitive player
      content is added to source, logs, fixtures, or distributable artifacts.
- [ ] New dependencies, inputs, network behavior, and persistence have been
      reviewed at the appropriate security and privacy boundary.
- [ ] I ran the narrow tests first and the broadest feasible repository checks
      afterward, and reported exact commands and honest results.
- [ ] User-facing behavior, architecture, protocol, setup, and operational docs
      are updated when affected.
- [ ] The commit message describes the outcome and the final summary identifies
      remaining risks or checks that could not run.

If a check is not applicable, omit it from the change report. If a required
check cannot run, report the limitation; do not imply it passed.