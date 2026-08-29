# RPRRSBSI V4 Ace and Mobile Acceptance and Traceability

Status: test and task-authoring contract; no migration or deployment authority.

## Source traceability

| Requirement family | Primary source | V4 relationship |
| --- | --- | --- |
| Offline-first Windows/Android/iOS Outposts | Mobile SQL decision record, pp. 1-2 and 7-8 | Extends V4 into edge projection and execution tiers. |
| Outbound sync and same-device local API | Mobile SQL decision record, pp. 2 and 10-11 | Adds transport/API requirements without changing V4 identity semantics. |
| Encryption and secrets | Mobile SQL decision record, pp. 3-5 | Applies to edge store, DTO, logging, plugin, and sync boundaries. |
| Signed in-process plugins and permissions | Mobile SQL decision record, pp. 5-7 and 11-14 | Extends V4 executor/plugin packaging and trust requirements. |
| Outdoor activity/file analysis | Mobile SQL decision record, pp. 1, 7-8 | Adds domain use cases to generic V4 expert-system execution. |
| Projection rather than full central replica | Mobile SQL decision record, pp. 6-8 | Edge store is distinct from central Ace schema duplication. |
| Separate ATAP and Ace ownership planes | Operator 2026-08-28; V4 D-5/C-04 | Requires separate runtime authority; operator clarification permits coordinated core migrations to create Ace. |
| Ace duplicates all ATAP tables except User | Operator 2026-08-28 | New controlling requirement; parity manifest makes it testable. |
| User-segmented Ace data and Ace-only DDL editing | Operator 2026-08-28 | Closes the basic tenancy goal; detailed policy remains implementation work. |
| Sole production publication pathway | Operator 2026-08-28 | Extends V4 manifestation/publication boundary; detailed design remains pending. |

The mobile record's tentative rejection of a full **device-local** central replica does
not conflict with central SQL Server schema duplication. Outpost keeps a minimal
projection; the central `Ace` schema follows the operator's parity requirement.

## Required conformance suites

### Migration ownership

- **AM-TEST-SCH-001:** Apply the applicable ATAP core migration to a predecessor without
  `Ace`; verify any created Ace schema and objects exactly match the declared manifest,
  parity contract, permissions, and expected hashes.
- **AM-TEST-SCH-002:** Scan migration SQL, loaders, tests, and startup for Ace DDL side
  effects; require every result to be manifest-declared and require zero incidental
  runtime/bootstrap creation paths.
- **AM-TEST-SCH-003:** Prove the migration principal can perform only its declared
  cross-schema change and that ordinary AceCommander/runtime principals cannot alter
  `ATAPUtilities` DDL.
- **AM-TEST-SCH-004:** Compare the parity manifest with live metadata: every ATAP
  application table is mirrored or explicitly excepted, and `User` is absent from Ace.
- **AM-TEST-SCH-005:** Add a synthetic ATAP table without an Ace disposition; the parity
  release gate must fail. Add a manifest-declared Ace counterpart in the same candidate;
  the coordinated migration may then create it and must pass independent parity checks.

### Access and tenancy

- **AM-TEST-ACC-001:** Normal AceCommander can read sanctioned ATAP contracts and cannot
  insert, update, delete, execute unapproved writes, or alter ATAP objects.
- **AM-TEST-ACC-002:** User A cannot observe or mutate User B data through direct
  repositories, joins, counts, search, Tags, sync, logs, errors, or crafted user IDs.
- **AM-TEST-ACC-003:** Child rows cannot be orphaned, assigned to conflicting owners, or
  moved between owners outside an explicit authorized operation.
- **AM-TEST-ACC-004:** Background work without user/delegation/system classification is
  rejected.
- **AM-TEST-ACC-005:** Tags attached to a row never cause access to be granted.

### `ModifyPlugin`

- **AM-TEST-MOD-001:** The normal runtime principal cannot enter or emulate the mode by
  changing a request field.
- **AM-TEST-MOD-002:** Cross-schema, cross-database, permission, ownership, unsafe CLR,
  dynamic SQL, linked-server, external command, secret, and unbounded-trigger attempts
  are rejected before shared mutation.
- **AM-TEST-MOD-003:** User A's workspace cannot read User B fixtures, DDL proposals,
  package bytes, scan findings, or candidates.
- **AM-TEST-MOD-004:** Validation happens in an isolated target; no unapproved DDL reaches
  shared Ace.
- **AM-TEST-MOD-005:** Applying a candidate with the wrong parent schema version or hash
  fails without partial mutation.

### Offline storage and sync

- **AM-TEST-SYNC-001:** Capture, normalize, analyze, and queue representative activity
  and file observations while network access is absent.
- **AM-TEST-SYNC-002:** Kill the process before and after each local/central commit
  boundary; resume without loss or duplicate central effects.
- **AM-TEST-SYNC-003:** Deliver identical envelopes multiple times and require the same
  durable acknowledgment.
- **AM-TEST-SYNC-004:** Reject mismatched user/device identity, payload hash, sequence,
  contract version, revoked credential, and expired projection.
- **AM-TEST-SYNC-005:** Prove local compaction never removes unacknowledged data.
- **AM-TEST-SYNC-006:** Prove sync writes to user-scoped Ace data and cannot invoke the
  ATAP publication path.

### Plugin and analysis

- **AM-TEST-PLG-001:** Reject unsigned, tampered, untrusted, revoked, incompatible, or
  unapproved-permission plugins.
- **AM-TEST-PLG-002:** Prove a signed plugin still cannot access undeclared files, data,
  network endpoints, secrets, or another user.
- **AM-TEST-PLG-003:** Enforce time, memory, I/O, cancellation, and output budgets for a
  non-terminating or abusive in-process plugin.
- **AM-TEST-ANA-001:** Identical activity input and exact package/rule/fact/as-of inputs
  produce canonically identical deterministic results.
- **AM-TEST-ANA-002:** Missing track segments, stale facts, denied location, corrupted
  files, or partial activity sources produce explicit findings.
- **AM-TEST-ANA-003:** Results retain source, plugin hash, effective RuleVariant,
  normalization, as-of, and explanation provenance.

### Publication

- **AM-TEST-PUB-001:** Every alternate Ace-to-ATAP data/DDL route is denied.
- **AM-TEST-PUB-002:** Intake by mutable path, changed digest, missing provenance,
  unresolved finding, secret, malware indicator, prohibited DDL, or unapproved dependency
  fails closed.
- **AM-TEST-PUB-003:** Publication reconstitutes an ATAP-owned forward-only package and
  never executes Ace DDL verbatim merely because it passed Ace validation.
- **AM-TEST-PUB-004:** Approval binds exact bytes and predecessor; changes after approval
  invalidate the approval.
- **AM-TEST-PUB-005:** Identical package hashes move through tiers; a rebuild is a new
  candidate.
- **AM-TEST-PUB-006:** Recovery and revocation drills prove affected publications and
  edge devices can be identified from immutable provenance.

## Adversarial close variants

Reviewers SHALL explicitly test these near-misses:

- a helper migration or test bootstrap creates `Ace` even though the core migration does
  not;
- `UserInformation` or `UserSettings` is mirrored while claiming only `User` is excluded,
  without a decision on whether those are part of the authoritative user aggregate;
- a view filters by caller-provided `UserId` but the base table remains directly readable;
- DDL is described as "user-scoped" even though it changes a shared schema;
- an Ace table omits owner data and is accidentally treated as globally shared;
- a central analysis writes its output into ATAP because it used ATAP rules;
- Outpost sync is repurposed as a publication shortcut;
- a signed plugin brings a malicious dependency or requests a newly added permission;
- a device accepts stale trust policy indefinitely while offline;
- raw activity evidence is overwritten by normalization or later analysis;
- a local full replica is introduced under the name "cache"; and
- a publication approval applies to a semantically similar but byte-different package.

## Open decision register

| ID | Decision required before implementation/release |
| --- | --- |
| AM-PEND-001 | Exact physical owner/location of the single authoritative `User` aggregate and disposition of historical `AceCommander.User*` objects. |
| AM-PEND-002 | Whether `Ace` is the exact SQL schema name or the target logical name replacing historical `AceCommander`. |
| AM-PEND-003 | Exact list of "application tables" and treatment of views, procedures, functions, triggers, policies, and user-child tables in parity. |
| AM-PEND-004 | Row-segmentation mechanism, sharing model, administrative access, service-owned rows, and SQL Server edition support. |
| AM-PEND-005 | Local database engine and platform matrix, including SQLCipher/provider availability and migration support. |
| AM-PEND-006 | Same-device transport and authentication on Windows, Android, and iOS. |
| AM-PEND-007 | DTO compatibility window, sync batch limits, conflict policy per entity, and local retention periods. |
| AM-PEND-008 | Device bootstrap, offline credential lifetime, secret-provider availability, key rotation, and lost-device recovery. |
| AM-PEND-009 | Plugin permission taxonomy, platform signing layers, resource budgets, revocation/offline grace, and user-consent UX. |
| AM-PEND-010 | Allowed `ModifyPlugin` DDL subset, isolated workspace technology, validation toolchain, and shared-Ace apply approval. |
| AM-PEND-011 | Full `productionPublishNewOrModifiedPLugin` design: ownership, canonical identifier, eligibility, transformations, reviewers, malware gates, credentials, promotion, recovery, and incident response. |
| AM-PEND-012 | Outdoor activity sources, licenses/terms, canonical model, location privacy, algorithms, confidence, and aggregation policy. |

Existing Task 15.140.b pending items, including D-3 edge cases, C-16 through C-27,
FU-4, and FU-6, remain pending unless the operator's 2026-08-28 direction explicitly
settles the same question. This suite closes the high-level separate-schema and
user-segmentation requirements but does not silently invent their physical details.

## Recommended implementation slices

1. Ratify AM-PEND-001 through AM-PEND-004 and inventory historical schemas.
2. Build the parity manifest/analyzer without DDL execution.
3. Ratify coordinated-versus-separate migration topology and prove manifest-declared
   cross-schema migrations plus separated runtime principals in disposable databases.
4. Implement Ace row ownership and negative isolation tests.
5. Ratify and implement the edge database/DTO/sync foundation.
6. Implement one Windows file and one mobile activity vertical slice offline.
7. Implement signed projection packages and one deterministic analysis plugin.
8. Implement isolated `ModifyPlugin` candidate authoring and validation.
9. Ratify the production publication ADR/threat model and build its non-production
   validation pipeline.
10. Promote immutable increments through the required tiers with deploy-state evidence.

Every slice SHALL cite the exact AM requirement IDs, applicable V4 IDs, closed pending
decisions, commands/tests, and `_generated/` evidence paths. No slice may combine an
unresolved architecture choice with a live migration or publication action.
