# Architecture decision records

Architecture decision records (ADRs) preserve consequential decisions and the
reasoning available when they were accepted. They do not replace implementation
documentation.

## Process

1. Copy [`0000-template.md`](0000-template.md) to the next unused four-digit
   number and a short kebab-case title.
2. Open it as **Proposed** before implementing a decision that changes a trust
   boundary, public protocol, persistence model, dependency strategy, or shared
   architecture.
3. Record concrete alternatives and consequences. Link the approving pull
   request and implementing changes.
4. After review, set the status to **Accepted** or **Rejected**. Do not rewrite
   accepted history beyond typo/link repair.
5. Replace a decision with a new ADR whose `Supersedes` field links to the old
   record; mark the old one **Superseded** and link forward.

The project maintainers own numbering and acceptance. Draft authors own keeping
their proposed ADR current until a decision is made.