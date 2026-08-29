# RPRRSBSI V4 Ace and Mobile Requirements Catalog

Status: normative requirements companion; implementation is not authorized.

## System goals

- **AM-GOAL-001:** Preserve `ATAPUtilities` as the authoritative source for immutable
  platform references, approved expert-system definitions, and published plugin
  definitions.
- **AM-GOAL-002:** Provide `Ace` as the user-editable and AceCommander-owned plane for
  overlays, plugin work, sessions, analyses, and user-segmented data.
- **AM-GOAL-003:** Support offline-first Windows, Android, and iOS Outposts without
  treating an edge store as a full replica of the central SQL Server database.
- **AM-GOAL-004:** Execute explainable expert-system analyses at the appropriate central
  or edge tier while preserving identity, as-of state, rule provenance, and plugin trust.
- **AM-GOAL-005:** Permit exactly one guarded path to publish reviewed Ace DDL and data
  into `ATAPUtilities`.

## Central schema and migration requirements

- **AM-SCH-001:** `ATAPUtilities` core migrations MAY create the `Ace` schema and MAY
  create or evolve explicitly declared Ace objects. The operator clarified this
  permission on 2026-08-28.
- **AM-SCH-002:** An ATAP.Utilities package that changes `Ace` SHALL declare every Ace
  object and permission effect in its manifest. A hidden Ace side effect in a loader,
  test bootstrap, repair script, or application startup path is prohibited.
- **AM-SCH-003:** The implementation SHALL choose and document either a coordinated
  ATAP/Ace migration lineage or separately identifiable lineages. In either model it
  SHALL provide unambiguous versioning, artifact manifests, deployment authority,
  recovery, and per-schema verification. Ordinary runtime principals remain separate
  from migration authority.
- **AM-SCH-004:** `Ace` SHALL duplicate every application table in `ATAPUtilities`
  except `User`. Views, procedures, functions, triggers, security policies, and
  non-table objects are not automatically included by the word "table" and require an
  explicit parity contract.
- **AM-SCH-005:** The authoritative `User` table SHALL have one owner and SHALL NOT be
  duplicated into `Ace`. Ace rows SHALL carry or derive a durable user ID usable for
  authorization and segmentation without copying user PII.
- **AM-SCH-006:** Schema parity SHALL be recorded in a machine-readable manifest that
  names each source table, Ace counterpart, excluded object, parity version, column and
  constraint hash, ownership rule, and divergence disposition.
- **AM-SCH-007:** A new or changed `ATAPUtilities` table SHALL fail the parity gate until
  the matching Ace change or an approved exception is explicitly present. The same core
  migration package MAY create the Ace counterpart, but the counterpart SHALL be
  manifest-declared, reviewable, and independently verifiable rather than an implicit
  runtime side effect.
- **AM-SCH-008:** Ace and ATAP rows MAY have different lifecycle, ownership, and
  physical keys. Cross-plane equivalence SHALL use explicit durable identity and source
  authority, never table location or coincident row order.
- **AM-SCH-009:** Existing V4 GUID, Philote, temporal, State/Variant, D-2 precedence,
  D-3 material-change, and D-4 overlay contracts remain mandatory in both planes where
  the corresponding tables exist.

## AceCommander access requirements

- **AM-ACC-001:** The normal AceCommander data-access principal SHALL have read-only
  access to approved `ATAPUtilities` views or procedures and read/write access to
  approved `Ace` data paths.
- **AM-ACC-002:** "Predominantly read-only" SHALL be implemented as deny-by-default.
  Any central write exception must be a named pathway with its own principal, procedure,
  authorization policy, audit event, and test; ambient table write permission is
  prohibited.
- **AM-ACC-003:** Ordinary AceCommander runtime, Outpost synchronization, plugins, and
  interactive clients SHALL NOT receive `ALTER`, `CONTROL`, `TAKE OWNERSHIP`, or
  equivalent DDL authority over `ATAPUtilities`.
- **AM-ACC-004:** Every Ace data read and write SHALL be evaluated against the current
  authenticated user ID plus explicit sharing/delegation grants. Client-supplied user IDs
  are filters, not authorization evidence.
- **AM-ACC-005:** Row ownership SHALL be rooted at durable aggregate rows and propagated
  to children by enforced relationships. Orphan rows and conflicting ownership chains
  SHALL be rejected.
- **AM-ACC-006:** Background work SHALL run with an explicit initiating user, delegated
  service grant, or system-owned classification. An unscoped background principal SHALL
  not bypass segmentation.
- **AM-ACC-007:** Read paths SHALL prevent inference through counts, joins, errors,
  search, tags, sync status, logs, and timing where practical, not merely filter the
  final result set.

## `ModifyPlugin` requirements

- **AM-MOD-001:** `ModifyPlugin` SHALL be an explicit restricted mode with a short-lived,
  purpose-bound authorization separate from normal AceCommander operation.
- **AM-MOD-002:** The mode SHALL permit DDL only for Ace-owned plugin objects and SHALL
  reject any reference resolving outside the allowed Ace change boundary.
- **AM-MOD-003:** A user SHALL see only the DDL proposal, validation evidence, and Ace
  objects for plugins the user owns or is authorized to co-edit.
- **AM-MOD-004:** Because SQL DDL is shared rather than row-scoped, unreviewed DDL SHALL
  be compiled and exercised first in a per-user or per-change isolated database/schema
  workspace. The shared `Ace` schema SHALL receive only a validated immutable change
  package through an Ace-owned apply gate.
- **AM-MOD-005:** The DDL parser and validator SHALL reject dynamic SQL, cross-database
  references, linked-server access, unsafe CLR, external commands, privilege changes,
  ownership changes, unbounded triggers, secret access, and references to unapproved
  schemas unless a later policy explicitly allows a bounded case.
- **AM-MOD-006:** DDL changes SHALL be forward-only and append-only in history. An
  already applied migration SHALL never be edited.
- **AM-MOD-007:** Every proposal SHALL bind user, plugin, source commit/package, parent
  schema version, normalized DDL hash, dependency graph, requested permissions,
  validation results, and timestamps.

## Edge persistence and connectivity requirements

- **AM-EDGE-001:** Ace Outpost.Windows, Ace Outpost.Android, and Ace Outpost.iOS SHALL
  continue required local work while disconnected.
- **AM-EDGE-002:** Each Outpost SHALL maintain a transactional local store for
  observations, normalized records, analysis results, outbound envelopes, cursors,
  acknowledgments, failures, and retry state.
- **AM-EDGE-003:** The local store SHALL be a projection and work queue, not a full
  mirror of `ATAPUtilities` or `Ace`.
- **AM-EDGE-004:** Network synchronization SHALL be initiated by Outpost. Central
  server-initiated inbound connectivity SHALL not be required.
- **AM-EDGE-005:** A same-device AceCommander Client MAY call a loopback or platform IPC
  Outpost API for authorized command and query scenarios.
- **AM-EDGE-006:** Synchronization SHALL be resumable, idempotent, bandwidth-conscious,
  order-aware, and safe across process termination, duplicate delivery, and intermittent
  connectivity.
- **AM-EDGE-007:** The central service SHALL acknowledge only durably committed items.
  An Outpost SHALL retain an outbound item until acknowledgment is durably recorded.
- **AM-EDGE-008:** The architecture SHALL define retention and compaction independently
  for raw observations, normalized facts, analysis outputs, diagnostics, and acknowledged
  envelopes.
- **AM-EDGE-009:** Local database technology remains a bounded implementation decision.
  Selection SHALL be based on target devices, transactional integrity, encryption,
  footprint, .NET/platform support, schema migration, backup/recovery, and testability.

## API and DTO requirements

- **AM-API-001:** Shared contracts SHALL cover device identity and registration,
  capabilities, health, work definitions, observation batches, analysis requests and
  results, sync envelopes, cursors, acknowledgments, local queries, and errors.
- **AM-API-002:** Every contract SHALL carry a contract version and compatibility range.
  Unknown required fields or unsupported major versions SHALL fail closed.
- **AM-API-003:** Every mutation request SHALL carry an idempotency key, actor/device
  identity, correlation ID, created time, and payload hash.
- **AM-API-004:** DTOs SHALL use canonical lowercase dashed GUID text and preserve the
  V4 rule that database equality compares native GUID values.
- **AM-API-005:** DTOs SHALL minimize sensitive fields and support selective projection;
  a complete database row or secret value SHALL not be transferred merely for
  convenience.
- **AM-API-006:** Same-device query and command APIs SHALL have separate authorization
  scopes and rate/resource limits.

## Plugin and expert-system requirements

- **AM-PLG-001:** Only signed, integrity-verified, trusted-publisher plugins present in
  the applicable allowlist SHALL be eligible to load.
- **AM-PLG-002:** The initial signing layer MAY use Authenticode where supported, but the
  package model SHALL permit platform-appropriate and multi-layer signature evolution.
- **AM-PLG-003:** Plugins SHALL declare capabilities, permissions, data classes,
  supported hosts, contract versions, resource limits, and dependencies in a signed
  manifest.
- **AM-PLG-004:** Permission availability and authenticated user consent SHALL be
  validated before activation. Signature trust does not imply permission grant.
- **AM-PLG-005:** Plugins are initially in-process as accepted by the mobile decision
  record. The host SHALL compensate with deny-by-default permissions, resource budgets,
  cancellation, watchdogs, auditable loading, and rapid revocation. Out-of-process or
  platform sandboxing remains a future hardening option.
- **AM-PLG-006:** An edge expert-system package SHALL contain only the authorized,
  signed projection of definitions and facts needed for its declared analysis.
- **AM-PLG-007:** Analysis results SHALL bind the plugin package hash, effective
  RuleVariants, as-of instant, normalized inputs, source observations, device identity,
  and explanation/provenance.
- **AM-PLG-008:** A plugin SHALL write only through host-mediated repositories and sync
  APIs. Direct central database access and unrestricted local database access are
  prohibited.

## Outdoor activity and file analysis requirements

- **AM-ANA-001:** The mobile domain SHALL support activity source, activity type,
  timestamps, time zone/offset evidence, route/track references, samples or summaries,
  attachments, classifications, findings, and sync state.
- **AM-ANA-002:** Analyses MAY include normalization, segmentation, distance/duration/
  pace/elevation derivation, anomaly detection, activity classification, comparison,
  trend analysis, and recommendations, provided each output is explainable and
  provenance-bound.
- **AM-ANA-003:** Raw source evidence SHALL remain distinguishable from normalized facts,
  inferred classifications, and recommendations.
- **AM-ANA-004:** Windows file analysis SHALL support scheduled traversal, stable file
  observation, content/metadata classification, sidecar output, local records, change
  detection, and selective synchronization.
- **AM-ANA-005:** An analysis SHALL record incomplete or degraded inputs rather than
  silently manufacture precision. Location gaps, sensor drift, denied permissions, and
  stale reference facts become findings.
- **AM-ANA-006:** Tags may classify analysis artifacts under the V4 Tags model but SHALL
  not be treated as authorization grants.

## Security and privacy requirements

- **AM-SEC-001:** PII, PCI, regulated, confidential, and user-designated sensitive data
  SHALL be classified and encrypted at rest and in transit.
- **AM-SEC-002:** Secrets SHALL not appear in plugin packages, DDL, static configuration,
  DTO logs, command lines, crash artifacts, telemetry, or general-purpose database rows.
- **AM-SEC-003:** Platform keystores SHALL protect device identity and bootstrap key
  material. A Bitwarden-compatible provider SHOULD govern higher-level secrets where
  available; encrypted local custody is a fallback whose key is not stored beside the
  ciphertext.
- **AM-SEC-004:** Enrollment, key rotation, revocation, and recovery SHALL account for
  prolonged offline periods and clock uncertainty.
- **AM-SEC-005:** Logs and diagnostics SHALL be structured, correlated, redacted, and
  separately retained according to data classification.
- **AM-SEC-006:** Publication and DDL validation SHALL be treated as hostile-input and
  software-supply-chain boundaries, including malware scanning, static analysis,
  dependency review, signature verification, provenance, and sandbox tests.

## Quality requirements

- **AM-QLT-001:** Identical normalized input, definitions, facts, as-of instant, and
  plugin bytes SHALL produce canonically identical deterministic analysis output.
- **AM-QLT-002:** Local writes and sync state transitions SHALL survive process death
  without acknowledged-data loss or duplicate central effects.
- **AM-QLT-003:** Normal application, `ModifyPlugin`, synchronization, and production
  publication SHALL use distinct principals and auditable capability sets.
- **AM-QLT-004:** Schema parity, user isolation, API compatibility, offline recovery,
  malware resistance, and publication rollback SHALL have automated negative tests.
- **AM-QLT-005:** "Done" requires deployment evidence at the actual consuming tier; a
  generated migration or passing local test is not deploy-state completion.
