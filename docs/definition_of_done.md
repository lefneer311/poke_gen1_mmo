# Definition of done

A change is done only when every applicable item below is satisfied. Mark an
item not applicable with a short reason; do not silently skip it.

## Scope and behavior

- [ ] The change advances a named charter/roadmap outcome or explains why it is
      necessary now.
- [ ] Acceptance behavior and important failure, disconnect, reconnect, and
      cleanup paths are implemented and tested.
- [ ] The patch contains no unrelated refactor, formatting churn, debug output,
      temporary file, or accidental generated output.
- [ ] Current behavior and proposals are clearly distinguished.

## Compatibility and authority

- [ ] Desktop/browser and TCP/WebSocket behavior remain aligned where relevant.
- [ ] Existing saves, mods, messages, public APIs, and deployments remain
      compatible, or an approved migration, rollout, and rollback is included.
- [ ] The server does not newly trust client-reported data for durable or
      valuable state.
- [ ] Architecture/protocol changes have an ADR when required and update the
      current-state documentation after implementation.

## Security, privacy, and assets

- [ ] Inputs, limits, authorization/state checks, logs, secrets, dependencies,
      and new network/storage behavior were reviewed at their trust boundary.
- [ ] No ROM, save, extracted asset, credential, private log, or sensitive
      player content exists in source, fixtures, history, or distributables.
- [ ] Third-party material has recorded provenance, compatible licensing, and
      retained attribution.
- [ ] The final release artifact—not only source—passes the safety scan.

## Quality and evidence

- [ ] Tests cover user-visible outcomes and failure paths, use deterministic
      synthetic fixtures, and pass at the narrowest and broadest feasible scope.
- [ ] Format/compiler/linter commands configured for each touched language pass.
- [ ] `git diff --check` passes and the staged diff contains only intended work.
- [ ] Generated files came from their generator and required generated outputs
      are included.
- [ ] Documentation, setup, accessibility, operations, and screenshots are
      updated when affected.
- [ ] The pull request reports exact commands, honest limitations, remaining
      risks, reviewers/owners, migration steps, and rollback.