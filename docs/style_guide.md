# Style guide

**Status:** Draft repository defaults
**Owner:** Project maintainers; subsystem conventions override this document
when explicitly documented

## General rules

- Prefer the smallest clear change and match surrounding structure.
- Use US English and active voice. Define acronyms once. Name current behavior
  in present tense and label proposals explicitly.
- Use UTF-8, LF line endings, spaces, no trailing whitespace, and one final
  newline. Do not align code manually with runs of spaces.
- Keep identifiers, paths, commands, message names, configuration, and ports
  exact and formatted as code.
- Explain constraints and intent in comments; do not narrate the next line.
- Never wrap imports in `try`/`catch` to hide missing dependencies.

## TypeScript (`backend/`)

Use the existing TypeScript compiler configuration and nearby NestJS patterns:
two-space indentation, semicolons, single-quoted strings, explicit return types
on exported and lifecycle functions, and `camelCase` values/`PascalCase` types.
Keep transport framing separate from coordinator behavior. Validate untrusted
wire data at the boundary and test rejection paths. Run:

```bash
cd backend && npm test && npm run build
```

No standalone linter/formatter is configured; do not claim one ran.

## Lua (`gen1recomp/`, mods)

Follow the nearest module and upstream subtree conventions. Keep engine,
presentation, transport, and mod extension boundaries intact. Avoid global
state, inject deterministic random/time behavior in tests, and use registered
extension points instead of patching generated data. Mod code additionally
follows `gen1recomp/CONTRIBUTING-mods.md`.

## Shell and Python

Shell scripts use Bash when they rely on Bash features and should begin with
`set -euo pipefail`. Quote expansions, clean up temporary resources with traps,
and return actionable errors. Python uses four spaces, standard-library
facilities where practical, and `snake_case`; scripts should expose a useful
`--help` when they accept options.

## Markdown

Wrap new prose near 80 characters, except tables, URLs, and code. Use one `#`
title, logical heading levels, descriptive links, language-tagged fences, and
tables only for comparable fields. Use relative links within the repository.
Avoid raw HTML unless Markdown cannot express the requirement.

## Generated and imported files

Do not hand-edit generated ROM/cache/build output. Change its generator and
include only outputs the repository intentionally tracks. In imported trees,
preserve attribution and local style; document local patches and do not apply a
repository-wide reformat during a functional change.