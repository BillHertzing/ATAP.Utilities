# RPRRSBSI V4 Ace and Mobile Use Cases and Analysis Scenarios

Status: normative behavioral specification; no implementation authority.

## Actors

| Actor | Responsibility |
| --- | --- |
| End user | Owns or receives access to Ace data, grants plugin permissions, reviews analyses, and may author a plugin. |
| AceCommander Client | Presents central and same-device experiences without becoming a database authority. |
| AceCommander Server | Reads published ATAP references, writes user-scoped Ace data, brokers sync, and performs central analyses. |
| Ace Outpost | Collects, normalizes, analyzes, queues, and synchronizes device-local projections. |
| Plugin author | Creates or modifies a plugin definition and requested permissions in an authorized Ace workspace. |
| Plugin host | Verifies trust, mediates permissions and data access, executes analyses, and captures provenance. |
| Publication reviewer | Reviews an immutable candidate and security evidence for the production publication pathway. |
| Publication service | The sole hardened service allowed to move approved DDL/data from Ace to ATAPUtilities. |

## UC-01 - Offline outdoor activity capture

**Preconditions:** the Outpost is enrolled; the user has authorized the source; the local
store and device key are available.

1. Android or iOS Outpost imports or observes an activity from an allowed local or
   app-adjacent source.
2. It stores immutable source metadata and raw evidence according to retention policy.
3. It normalizes timestamps, units, track references, and activity identifiers without
   overwriting the original representation.
4. It records permission denials, missing samples, and sensor uncertainty as findings.
5. It commits the observation and pending-analysis work atomically while offline.

**Postconditions:** no central connectivity is required; source and normalized records
are distinguishable; the item is eligible for local analysis and later sync.

**Failure paths:** insufficient storage pauses acquisition safely; a corrupt source is
quarantined; cancellation leaves no half-committed activity.

## UC-02 - Local expert-system activity analysis

1. The host selects an authorized signed activity-analysis plugin and an edge-approved
   projection of Rules, RuleVariants, Tags, and reference facts.
2. The plugin manifest's permissions and compatibility are checked against current user
   consent and device capability.
3. The host normalizes inputs and resolves effective same-`RuleId` overlays using the
   V4 D-2/D-4 contracts.
4. The plugin derives activity segments, classifications, distance, duration, pace,
   elevation, anomalies, trends, or recommendations within its declared capabilities.
5. The host writes results through its repository, binding source IDs, rule and variant
   IDs, plugin hash, as-of time, assumptions, confidence where approved, and explanation.

**Acceptance:** repeated deterministic execution produces identical canonical output;
missing location or stale facts create findings rather than fabricated certainty.

## UC-03 - Windows file-system sweep and classification

1. A scheduled task invokes Outpost.Windows with an approved scope and resource budget.
2. The host traverses allowed roots and records stable observations without following an
   escaping junction or unauthorized path.
3. Approved plugins classify metadata or content and may emit a sidecar or local record.
4. Changed and unchanged files are distinguished using safe metadata and content-hash
   policy; unreadable files produce bounded diagnostics.
5. Selected observations and results enter the outbound queue.

**Security:** plugin permissions and user consent do not grant access beyond the host's
own allowlist; secrets and excluded files are never placed in analysis DTOs.

## UC-04 - Resumable outbound synchronization

1. Outpost detects usable connectivity and authenticates to AceCommander.
2. It sends registration/capability changes, then an ordered batch of immutable sync
   envelopes with idempotency keys and hashes.
3. The server authenticates device and user/delegation context, validates contract
   versions, rejects cross-user payloads, and commits accepted items transactionally.
4. The server returns per-item acceptance, rejection, conflict, and durable cursor data.
5. Outpost records acknowledgments before deleting or compacting local queue items.
6. Interruption at any point resumes without duplicate central effects.

**Conflict behavior:** raw observations are append-oriented. Mutable Ace states require
an explicit base state/concurrency token and return a conflict instead of last-write-wins
unless the entity contract defines a deterministic merge.

## UC-05 - Same-device local query

1. AceCommander Client authenticates to the local Outpost transport.
2. It requests health, pending-sync counts, recent user-owned activities, or local
   analysis results through a query-only scope.
3. Outpost applies the current user, sharing grants, data classification, and projection
   limits before returning a DTO.

**Negative cases:** loopback origin alone is not identity; another app cannot reuse the
session; hidden users' counts and identifiers are not exposed.

## UC-06 - Same-device command

The client requests a bounded operation such as start sync, re-run an analysis, or
cancel local work. The command uses a separate scope from queries, an idempotency key,
and a resource budget. It cannot install a plugin, expose a secret, change DDL, or widen
data collection unless separately authorized.

## UC-07 - Central analysis over synchronized data

AceCommander Server selects user-authorized Ace observations and published ATAP
reference definitions. It resolves effective ATAP baseline plus Ace overlays once through
the topology-neutral union contract, runs the expert system, and writes the result only
to the user's Ace plane. It may read `ATAPUtilities`; it may not modify the published
definition as part of analysis.

## UC-08 - Create or modify a plugin in `ModifyPlugin` mode

1. The authenticated user enters `ModifyPlugin` using a purpose-bound elevated session.
2. AceCommander creates an isolated change workspace bound to user, plugin, base schema,
   and expiry.
3. The user can inspect only authorized Ace/plugin DDL and user-owned or shared Ace test
   data.
4. Edits create a normalized DDL and seed/data proposal; direct `ATAPUtilities` objects,
   cross-database references, privilege changes, and unsafe features are rejected.
5. The proposal is compiled and migrated into a disposable database or schema clone.
6. Static, migration, security, tenancy, performance-budget, rollback-by-forward-fix,
   and malware tests execute against synthetic and user-authorized fixtures.
7. A passing proposal becomes an immutable signed candidate. It remains Ace-only until
   a separate publication process approves it.

**Key invariant:** shared Ace DDL is never made user-private by a row filter. Isolation
occurs in the change workspace; row segmentation governs test and application data.

## UC-09 - Apply an approved change to the shared Ace schema

An Ace-owned deployment principal verifies the candidate hash, parent schema version,
signature, dependency closure, and evidence. It applies the next forward-only Ace
migration, records the result, and runs parity plus cross-user-isolation tests. Failure
stops and requires a new forward-fix candidate; an applied migration is not edited.

## UC-10 - Read ATAP reference and write Ace overlay

1. AceCommander reads an immutable ATAP Rule and baseline RuleVariant through a sanctioned
   read contract.
2. It writes a user-owned Ace RuleVariant that retains the same `RuleId` and a user-owned
   `Override` occurrence.
3. Resolution unions authorized ATAP and Ace candidates, sorts explicit ordinals, and
   records selected, shadowed, and source-authority provenance.
4. Neither the ATAP Rule nor baseline variant is copied or modified.

## UC-11 - Publish a plugin to ATAPUtilities

1. A reviewer selects an immutable Ace candidate and invokes only
   `productionPublishNewOrModifiedPLugin`.
2. The pathway revalidates provenance, signatures, dependencies, licenses, data
   classification, malware scans, sandbox behavior, tenancy, DDL allowlist, and migration
   compatibility against the exact target predecessor.
3. A separate authorized approval binds the exact bytes and expected ATAP changes.
4. The publication service translates only approved Ace-owned candidate objects into a
   new forward-only ATAP migration/data package.
5. The same immutable package is promoted through required tiers; publication records
   source and destination identities without granting Ace runtime write access to ATAP.

**Current gate:** steps 2-5 are architectural requirements, not an implemented workflow.
The detailed authorization, review quorum, malware tooling, transformation rules,
rollback, and production deployment contract remain `HITL-PENDING`.

## UC-12 - Reject attempted alternate publication

Any direct insert, merge, DDL execution, linked-server copy, bulk import, admin script,
plugin action, Outpost sync, or ordinary AceCommander call that attempts to move Ace
content into `ATAPUtilities` is denied and audited because it did not traverse
`productionPublishNewOrModifiedPLugin`.

## UC-13 - Revoke a plugin while devices are offline

The central service publishes a signed revocation/trust-policy update. Connected devices
apply it before accepting new work. An offline device may continue only under a defined
maximum-offline and cached-policy rule; otherwise the affected plugin is disabled pending
fresh policy. Results produced under later-revoked bytes remain provenance-bound and are
quarantined or re-evaluated according to policy rather than silently deleted.

## UC-14 - User separation adversarial scenario

User A and User B own similar plugin and activity identifiers. User A attempts direct
queries, crafted DTO user IDs, joins, search, Tags, sync cursors, error probing, and
`ModifyPlugin` fixtures referencing User B. Every path returns only authorized data,
produces no cross-user count or identifier leak, and records the denied attempt without
including User B's sensitive payload.

## UC-15 - Device loss and recovery

The user revokes the device. Central services reject further credentials and mark pending
device-originated work accordingly. A replacement device enrolls with new device identity,
receives only minimum authorized projections, and never restores raw secrets from an
ordinary sync payload. Locally encrypted data on the lost device remains protected by
platform-backed key material and retention policy.
