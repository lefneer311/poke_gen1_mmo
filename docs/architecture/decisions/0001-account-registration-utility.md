# ADR 0001: Account registration utility boundary

- **Status:** Proposed
- **Date:** 2026-08-28
- **Deciders:** Unassigned
- **Supersedes:** None
- **Superseded by:** None

## Context

The current coordinator accepts a guest display name and keeps all identity in
memory. It has no account API, credential store, session recovery, or database
connection. The P2 charter calls for durable identity, but P2 begins only after
the P1 protocol, authority, abuse-control, and observability gates are stable.
This ADR therefore proposes an implementation boundary and acceptance contract;
it does not approve an early public registration service or change the current
guest flow.

The draft PostgreSQL schema already separates `accounts`,
`account_credentials`, and `account_sessions`. Registration must preserve that
separation, keep database credentials out of clients, and never collect a ROM,
save, party, position, or other gameplay data. A command-line interface (CLI)
and a browser portal have different presentation and secret-handling risks, but
they should not implement competing registration rules.

This decision affects the internet trust boundary, authentication credentials,
personally identifiable information (PII), and persistent storage. It requires
a named security and privacy owner before implementation is enabled outside a
private staging environment.

## Decision

### One application service, optional presentation products

Implement registration once as an `accounts` application module in the NestJS
backend. Expose it through a versioned HTTPS JSON API. Build either or both of
the following thin clients against that API:

1. `accountctl`, a separately packaged CLI for users and scripted private-pilot
   setup; and
2. an account portal, a separately deployed browser application for end users.

Neither client may connect to PostgreSQL, hash passwords, decide username
availability, or contain an operator credential. Both submit the same request,
render the same stable problem codes, and treat passwords and session tokens as
write-only secrets. The application service owns normalization, validation,
password hashing, duplicate handling, audit emission, and the transaction.

The first implementation slice is self-service registration only. Login,
recovery, email verification, deletion, character creation, and integration
with `join_world` require follow-up slices and must not be implied by a
successful registration response. If a usable account cannot yet authenticate,
registration remains disabled outside staging.

### Proposed API contract

`POST /api/v1/accounts` accepts `application/json` over HTTPS:

```json
{
  "username": "example-user",
  "password": "correct horse battery staple",
  "email": "optional@example.invalid",
  "locale": "en"
}
```

The server applies an explicitly documented username normalization and policy,
checks UTF-8 byte and character limits before expensive hashing, and validates
the optional email without claiming that an unverified address is owned by the
requester. Password policy should favor length and breached-password screening
over composition rules. Exact limits, Argon2id parameters, and breach-check
behavior must be benchmarked and recorded in the implementing PR rather than
frozen in this architecture proposal.

On success, return `201 Created` with an opaque account ID, normalized username,
status, locale, and creation time. Do not return the credential row or silently
create a login session. Failures use `application/problem+json` with a stable
machine code, a generic user-safe message, and a request ID. The initial codes
are `invalid_request`, `registration_unavailable`, `name_unavailable`,
`rate_limited`, and `internal_error`. Duplicate username and email conflicts
must not reveal which field identifies an existing account; a later recovery
flow may provide a generic out-of-band response.

Requests should carry an `Idempotency-Key`. The service stores a short-lived
digest associated with the normalized request result so retrying after a lost
response does not create a second account. Reusing a key with a different
request is rejected. The exact storage mechanism and retention period must be
specified before implementation; raw passwords and complete request bodies
must never be retained.

### Transaction and persistence

After cheap validation and abuse checks, the backend hashes the password with a
reviewed Argon2id library and a unique salt. In one PostgreSQL transaction it:

1. inserts `accounts` and `account_credentials`;
2. records the idempotent result without the password or email value;
3. appends a bounded audit event containing the account ID, outcome, request ID,
   and coarse source metadata; and
4. commits before sending a response.

Only the encoded password hash is stored. Logs, metrics, traces, problem
details, shell history, process arguments, analytics, and audit JSON must not
contain passwords, tokens, email addresses, or complete registration payloads.
Database uniqueness remains the concurrency authority; a preflight
availability check is advisory and is not part of the initial API.

The CLI reads a password twice from a terminal without echo and may alternatively
read it from standard input only with an explicit `--password-stdin` flag. It
must reject password command-line arguments and avoid saving credentials in a
configuration file. Machine-readable output goes to standard output; prompts
and diagnostics go to standard error. The portal uses a normal password input,
does not persist the password, has accessible labels and error summaries, and
does not load third-party scripts, fonts, telemetry, or password-strength code.

### Abuse, transport, and operational controls

Registration is off by default behind an operator-controlled feature flag.
Outside local development, TLS is mandatory and allowed portal origins use an
explicit Cross-Origin Resource Sharing allowlist. The server enforces request
body limits, timeouts, bounded hashing concurrency, global and per-source rate
limits, and temporary registration closure under load. Proxy-derived client
addresses are trusted only from configured proxies. Responses and timing are
designed to reduce account enumeration; they cannot guarantee that usernames
remain private when those names later become public character identities.

Metrics contain aggregate attempts, outcomes, rejection codes, hash latency,
transaction latency, and queue saturation. Labels must be bounded and exclude
username, email, account ID, address, user agent, and request ID. Alerts cover
rate-limit pressure, hashing saturation, database failures, and anomalous
success volume. An operator runbook must define how to disable registration,
rotate database credentials, investigate abuse without exposing PII, and
recover from a partial deployment.

### Data inventory and lifecycle

| Data | Purpose and location | Proposed lifecycle |
| --- | --- | --- |
| Username and locale | Identify and localize an account in `accounts` | Retain while active; remove or pseudonymize through the approved deletion flow |
| Optional email | Future verification and recovery in `accounts` | Do not collect until those flows and their lawful purpose are approved; delete with the account unless retention is legally required |
| Encoded password hash | Authenticate in `account_credentials` | Replace on password change; delete on account erasure; never back up plaintext because plaintext is never stored |
| Idempotency digest and result | Make registration retries safe | Short retention to be selected and tested before implementation |
| Security audit event | Detect abuse and support incident response | Proposed 180 days, subject to operator/legal review before collection |
| Aggregate metrics | Operate the service | Retention set by the operator; no account or request identifiers |

Encrypted backups inherit these lifecycles and require a documented expiry and
restore-erasure procedure. Before collection begins, maintainers must document
the lawful purpose, jurisdiction, privacy notice, export/deletion process,
backup treatment, encryption and key rotation plan, incident contact, and
retention owner. The service must not be advertised publicly until those items,
recovery, and deletion are operationally tested.

### Delivery sequence and acceptance

Implementation should use reviewable slices:

1. **Readiness:** accept this ADR, assign security/privacy/operations owners,
   finish the prerequisite P1 gates, approve retention and credential policy,
   and add a migration runner plus restore evidence.
2. **Backend:** add a persistence interface, PostgreSQL adapter, registration
   use case, feature flag, API controller, problem schema, rate limits, audit
   redaction, and metrics. Keep guest play unchanged.
3. **CLI:** add `accountctl register --server URL`, secure interactive input,
   JSON output, documented exit codes, and release provenance. This is the
   smallest UI and should validate the API in a private pilot first.
4. **Portal:** add the browser product only if user research justifies it; meet
   the repository accessibility policy, strict Content Security Policy, origin
   policy, and browser tests. Do not bundle it into the ROM-serving game page.
5. **Authentication:** separately design login, session rotation/revocation,
   recovery, deletion, and game-protocol authorization before accounts own any
   persistent character or gameplay state.

Acceptance evidence for the registration slice includes:

- deterministic unit tests for normalization, policy, error mapping, and
  secret redaction;
- PostgreSQL integration tests for atomic creation, uniqueness races,
  idempotent retry, rollback, and least-privilege access;
- HTTP tests for content types, body limits, disabled mode, generic conflicts,
  rate limits, proxy handling, and response schemas;
- CLI pseudo-terminal tests proving no echo and no password in arguments,
  output, configuration, or diagnostics;
- portal keyboard, screen-reader label, focus, error-summary, Content Security
  Policy, cross-origin, and supported-browser checks if the portal is built;
- load tests that size hashing concurrency without starving health or game
  traffic, plus dependency and secret/log scans; and
- exercised backup restore, account export/deletion, registration-disable, and
  deployment rollback runbooks.

Rollout starts with the feature flag off, then an isolated staging database,
maintainer accounts, and a rate-limited private cohort. Existing guest clients
and game protocol messages remain unchanged. Roll back by disabling the flag
and reverting application clients; do not drop account tables or credential
data in an emergency code rollback. Schema changes remain additive until a
later, tested cleanup migration.

## Alternatives considered

### CLI with direct database access

Rejected. It distributes privileged database credentials, bypasses shared
validation and abuse controls, makes auditing inconsistent, and cannot safely
serve untrusted end users. A narrowly scoped operator-only bootstrap command may
be designed separately, but it is not self-service registration.

### Portal-specific registration implementation

Rejected. Putting business rules or credential hashing in a static portal
duplicates security-sensitive behavior and still requires a trusted backend.
The portal may be a separate product, but it remains an API client.

### CLI only

Viable for a private technical pilot and selected as the first presentation
adapter. It has a smaller browser attack surface and provides an automatable
contract test, but it is less discoverable and accessible to nontechnical
users. It does not eliminate the need for HTTPS, abuse controls, or recovery.

### Portal only

Deferred. A portal provides a familiar registration experience, but adds
cross-origin policy, content security, browser compatibility, accessibility,
deployment, and phishing risks before the underlying service is proven.

### External identity provider

Deferred for explicit privacy, availability, lock-in, account-linking, and
non-commercial terms review. It may reduce password custody but does not remove
authorization, deletion, recovery, abuse, or incident-response obligations.

### Continue guest-only operation

Selected until the P2 prerequisites and named ownership exist. It does not meet
the durable identity goal, but it is safer than collecting credentials before
the system can protect, recover, and delete them.

## Consequences

- Registration rules have one authoritative implementation while CLI and web
  experiences may evolve and deploy independently.
- The backend gains sensitive data, an expensive hashing workload, a public API,
  and operational duties that do not exist in the guest coordinator.
- PostgreSQL and a reviewed password-hashing dependency become runtime-critical;
  dependency review, migrations, backups, monitoring, and incident response are
  required before launch.
- Registration alone is intentionally not a usable authenticated game account.
  Follow-up login and lifecycle work is required, and the UI must communicate
  that limitation during a private implementation phase.
- Guest sessions and both game transports remain compatible because this slice
  neither changes `join_world` nor makes client-reported gameplay durable.
- No new ROM, save, extracted asset, or gameplay data is collected. The portal
  remains separate from local ROM import and storage.

## Verification

This proposed ADR contains no runtime implementation. The implementing pull
requests must link their tests, threat-model review, benchmark results,
accessibility evidence, data-lifecycle approval, restore exercise, rollout, and
rollback record here before maintainers change the status to **Accepted**.
