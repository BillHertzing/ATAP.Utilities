# RPRRSBSI V5 Ace Data, Tenancy, and Synchronization Specification

> **V5 revision (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Successor of `Database/Documentation/RPRRSBSI-V4-Ace-Mobile-Integration/40-Data-Tenancy-And-Synchronization.md`. Requirement and decision IDs keep their V4-2 numbers with the prefix `V5-` (for example `V4-2-CORE-034` is now `V5-CORE-034`); a V4-2 ID that is not repeated here is withdrawn only where the "V5 changes" section says so. The V5 decisions DEC-1 to DEC-6 and the 2026-11-05 training and gamification requirements are summarised in [the V5 overview](RPRRSBSI-V5-00-Specification-Overview.md#v5-decisions); open items are in [HANDOFF-V5.md](HANDOFF-V5.md). **Terminology (DEC-6):** an *Instantiation* is a produced file or row; the run of an executor that produces instantiations is a *Materialization*; the reusable configuration it runs is a *materialization specification*. Where carried-forward V4-2 text uses "Instantiation" for the configured act, read "materialization specification".

## V5 changes (applies to the whole Ace and Mobile suite)

| Change | Source |
| --- | --- |
| **Ace copy confirmed and extended (DEC-3).** The 2026-08-28 operator requirement "Ace duplicates all ATAP tables except User" is retained and strengthened: `Ace` holds every `ATAPUtilities` table (same shape) **plus owner columns on every row** (`OwnerUserId` xor `OwnerOrganizationId`, `CreatedByUserId`), enforced by row-level security. The identity registry (`Philote`, `PhiloteValidityPeriod`) stays shared. | [V5-60](../RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md) |
| **Direction reversed (DEC-9).** After a common initial load, changes start in `Ace`; selected changes are promoted to `ATAPUtilities`. The parity manifest becomes the *copy manifest* with disposition `mirrored-with-owner` for every template table and `ace-only` for Ace-only tables; a new `ATAPUtilities` table still fails the gate until its `Ace` twin exists, and the twin is generated, not hand-written. | V5-60 §6 |
| **User table.** "`User` is absent from Ace" is outdated: `ACE.User` and the login tables exist since `V00160`. V5 moves credentials into a protected `AceAuth` schema outside `Ace`. | [V5-65](../RPRRSBSI-V5-65-Protected-Authentication.md) |
| **Publication path replaced (DEC-5).** `productionPublishNewOrModifiedPLugin` (AM-GOAL-005, UC-11, document 50) is replaced by the marketplace bolt-on submission process; its security checks become steps of that process. Developers may author DDL for tables they own (DEC-4); the "Apply an approved change to the shared Ace schema" path (UC-09) remains for core changes. | [V5-15](../RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md) |
| **Tenancy.** "User-segmented data" and "tenant" are implemented by owner columns. | V5-60 |
| **Vocabulary.** Instantiation = produced file or row; Materialization = the run that produces it (DEC-6, DEC-7). | [V5-12](../RPRRSBSI-V5-12-Instantiation-And-Materialization.md) |


Status: normative logical data contract; physical DDL remains future work.

## Schema parity contract

The Ace duplicate is governed by a parity manifest rather than informal naming.

| Manifest field | Requirement |
| --- | --- |
| Source object | Fully qualified ATAPUtilities table and stable object identity. |
| Ace counterpart | Fully qualified Ace table and stable object identity. |
| Disposition | `mirrored`, `excluded-user`, or separately approved exception. |
| Shape evidence | Ordered columns, native types, nullability, computed/default behavior, keys, checks, and referential intent. |
| Ownership delta | Required Ace user ownership root and any permitted lifecycle difference. |
| Version evidence | Source and Ace migration versions plus normalized schema hashes. |
| Security evidence | Principal matrix, row-policy coverage, direct-table denial, and negative tests. |

- **AM-DATA-001:** `User` SHALL have disposition `excluded-user` and no Ace duplicate.
- **AM-DATA-002:** A parity exception SHALL identify the operator decision authorizing
  it; undocumented drift is a release failure.
- **AM-DATA-003:** Parity comparison SHALL be structural and semantic. Matching table
  names alone are insufficient.
- **AM-DATA-004:** An ATAP table addition does not authorize an Ace migration. It creates
  a blocked parity obligation owned by the Ace migration stream.

## User ownership model

The authoritative authentication/user service supplies a durable `UserId`. The exact
physical owner of the `User` table and compatibility with historical cross-schema user
tables require migration inventory, but the target contract has one authoritative user
identity and no Ace duplicate.

Ace tables fall into four categories:

| Category | Segmentation rule |
| --- | --- |
| User-owned aggregate | Carries `OwnerUserId` and is visible to owner plus explicit grants. |
| Aggregate child | Derives ownership through an enforced parent; cannot change owner independently. |
| Shared Ace reference | Has explicit shared/steward policy and cannot be created accidentally by omitting `OwnerUserId`. |
| System operational | Accessible only to bounded service principals and exposed to users through filtered views/DTOs. |

- **AM-DATA-010:** Every Ace table SHALL declare one category in the parity manifest.
- **AM-DATA-011:** A user-owned root SHALL have a non-null durable owner and indexes
  supporting owner-first access paths.
- **AM-DATA-012:** Sharing SHALL be represented as explicit grants with grantor,
  grantee, capability, scope, validity, and revocation history. Tags are not grants.
- **AM-DATA-013:** Application predicates and database enforcement SHALL agree. Where
  SQL row-level security is selected, direct table access remains denied and all session
  context is set by trusted server code, never a client.
- **AM-DATA-014:** Cross-user administrative access SHALL use a separately authorized
  principal and produce immutable audit evidence; it is not an ordinary query option.

## Local projection model

The edge store has logical collections/tables for:

- device and enrollment state;
- cached policy and trust metadata;
- source observations and attachments;
- normalized activity or file facts;
- analysis requests, attempts, results, findings, and provenance;
- minimal expert-system/plugin projection packages;
- outbound synchronization envelopes and items;
- inbound acknowledgments, conflicts, and work-definition deltas;
- cursors and retention/compaction checkpoints; and
- redacted diagnostics and audit events.

The local store SHALL not contain central user directories, complete ATAP/Ace tables,
unneeded other-user data, signing private keys, publication credentials, or unrestricted
DDL.

## Synchronization envelope

Each immutable envelope requires:

| Field | Meaning |
| --- | --- |
| Envelope ID | Canonical durable GUID and idempotency boundary. |
| Device ID | Enrolled source device. |
| Actor/delegation | User or bounded service authority under which data was produced. |
| Sequence and predecessor | Per-device stream ordering without relying on wall-clock order. |
| Contract version | DTO schema and compatibility range. |
| Created/observed times | Device time plus uncertainty/offset evidence where relevant. |
| Data classification | Handling, retention, and redaction class. |
| Payload hash | Integrity and duplicate detection. |
| Items | Typed projections with local and durable semantic identities. |
| Plugin/expert provenance | Package hash, rule/variant identities, facts, and as-of instant. |

- **AM-SYNC-001:** Envelope acceptance SHALL authenticate the device and actor context
  independently from payload IDs.
- **AM-SYNC-002:** The server SHALL validate every item before committing the batch or
  SHALL return explicit per-item atomicity semantics. Ambiguous partial success is
  prohibited.
- **AM-SYNC-003:** Duplicate envelope delivery SHALL return the original durable outcome
  and SHALL not repeat effects.
- **AM-SYNC-004:** Acknowledgments SHALL bind envelope ID, payload hash, accepted item
  identities, server cursor, and result hash.
- **AM-SYNC-005:** Queue deletion or compaction SHALL occur only after durable local
  acknowledgment recording and retention eligibility.
- **AM-SYNC-006:** Sync SHALL write user data to `Ace`, not directly publish it into
  `ATAPUtilities`.

## Inbound projection and work definitions

Inbound data is a signed, bounded projection rather than replication. A projection
manifest identifies authorized user/device, purpose, expiry, package hashes, object IDs,
as-of range, and maximum storage/resource budget. Outpost rejects an unsigned,
overbroad, expired, revoked, or incompatible projection.

Reference updates and plugin updates are distinct from user work/data sync. Trust-policy
and revocation checks precede plugin activation even when data synchronization succeeds.

## Conflict classes

| Class | Required behavior |
| --- | --- |
| Append-only observation | De-duplicate by durable source identity/hash; preserve conflicting source evidence for review. |
| User-editable state | Require base state/concurrency token; return conflict with safe current metadata. |
| Derived analysis | Key by inputs/definition/plugin/as-of hash; coexist if provenance differs. |
| Reference definition | Device never authors it; accept only a signed central projection. |
| Ace overlay/plugin work | Merge only through explicit semantic rules or user review; no blind last-write-wins. |
| ATAP publication | Never resolved by sync; only the production publication pathway may act. |

## Retention and deletion

Retention policies are independently configurable by data class. Deleting an acknowledged
edge cache does not delete central evidence. User deletion requests must account for
legal/regulated retention, immutable audit facts, derived artifacts, sync tombstones, and
other devices. Cryptographic erasure MAY be used where supported, but it must not destroy
keys needed for unrelated users or data.

## Analytical data quality

- raw, normalized, inferred, and recommended data SHALL have separate type/state markers;
- source time, receipt time, analysis time, and server commit time SHALL not be collapsed;
- GPS/location precision and gaps SHALL be preserved or summarized according to policy;
- unit conversions SHALL record original value, normalized value, unit, and algorithm;
- updated rules or plugins SHALL create a new analysis result rather than rewriting the
  provenance of an earlier result; and
- aggregation across users SHALL require a separately approved privacy contract and
  shall not be inferred from the existence of user-segmented data.

## Failure and recovery invariants

- a process crash cannot produce a central effect without a retryable local record;
- a committed server effect cannot be acknowledged with a mismatched payload hash;
- clock reversal cannot reorder the per-device stream;
- a revoked user/device cannot continue syncing because an old cursor exists;
- an ownership mismatch fails the whole affected item before data becomes queryable; and
- schema/DTO incompatibility quarantines the item with bounded diagnostics rather than
  dropping it or coercing fields silently.
