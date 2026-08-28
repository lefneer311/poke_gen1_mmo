# Legal and asset policy

**Status:** Draft contributor policy
**Owner:** Project maintainers
**Controlling notice:** [`DISCLAIMER.md`](../DISCLAIMER.md). This policy adds
workflow rules and does not weaken that notice or provide legal advice.

## Non-negotiable rules

Do not commit, publish, attach to issues, place in fixtures, or include in a
release any commercial-game ROM, save, extracted sprite, music, map, text,
generated cache, or other ROM-derived artifact. Do not add download links or
automation that obtains a commercial ROM. Each player supplies a compatible ROM
and permanent deployments perform import locally.

The repository is non-commercial and unaffiliated. Do not add ads, donations,
paid access/features, sponsorship claims, or language implying endorsement by
Nintendo, The Pokémon Company, Game Freak, or Creatures.

## Asset decision table

| Material | Allowed? | Conditions |
| --- | --- | --- |
| Player-owned ROM/save | Local use only | Ignored by Git; never uploaded or distributed |
| Locally extracted cache | Local use only | Ignored; delete before packaging |
| Original code | Yes | Contributor has rights; compatible project license/terms |
| Original art/audio/fonts | By review | Record author, source, license, and attribution; no imitation passed off as official |
| Third-party open assets/code | By review | License permits intended distribution/modification; retain notices and source/revision |
| Screenshots containing protected game assets | Documentation-only exception review | Use the minimum necessary, no asset sheets, record provenance, and obtain maintainer approval before commit/release |
| Upstream disassembly/source representations | Existing imported trees only unless approved | Preserve upstream license/attribution and document revision/update method |
| Secrets, personal data, private server logs | No | Use synthetic/redacted examples |

Names and trademarks may be used only to describe compatibility or project
subject matter accurately, with the non-affiliation notice nearby on primary
launch and distribution surfaces.

## Review checklist

Before commit and before publication:

1. Inspect staged file names and types for ROM/save/cache outputs.
2. Build into a clean output directory and scan the complete artifact, including
   archives, source maps, caches, screenshots, and copied test data.
3. Review every new binary and its provenance. A changed extension is not a safe
   transformation of protected data.
4. Verify third-party license text and attribution remain present.
5. Confirm the client still imports locally and the coordinator has no ROM/save
   upload path.
6. Keep the disclaimer and non-commercial language visible.

At minimum run `git status --short`, `git diff --cached --check`, and the
artifact scan in `web/build-web.sh`/the Pages workflow. Stop publication and ask
a maintainer when provenance or permission is unclear. Honor takedown requests
as described in the disclaimer.