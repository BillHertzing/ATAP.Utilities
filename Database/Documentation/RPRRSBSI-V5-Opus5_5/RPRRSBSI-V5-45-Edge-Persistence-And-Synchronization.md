# RPRRSBSI-V5 Edge Persistence and Synchronization

> **V5 revision (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Successor of `Database/Documentation/RPRRSBSI-V4-2-45-Edge-Persistence-And-Synchronization.md`. Requirement and decision IDs keep their V4-2 numbers with the prefix `V5-` (for example `V4-2-CORE-034` is now `V5-CORE-034`); a V4-2 ID that is not repeated here is withdrawn only where the "V5 changes" section says so. The V5 decisions DEC-1 to DEC-6 and the 2026-11-05 training and gamification requirements are summarised in [the V5 overview](RPRRSBSI-V5-00-Specification-Overview.md#v5-decisions); open items are in [HANDOFF-V5.md](HANDOFF-V5.md). **Terminology (DEC-6):** an *Instantiation* is a produced file or row; the run of an executor that produces instantiations is a *Materialization*; the reusable configuration it runs is a *materialization specification*. Where carried-forward V4-2 text uses "Instantiation" for the configured act, read "materialization specification".

## V5 changes

| Change | Source |
| --- | --- |
| **Not built.** | SQL |
| **Ownership defines sync scope (DEC-3):** an Outpost projection contains the device user's owned `Ace` rows, the visible rows of the user's organizations, and the `ATAPUtilities` template rows it needs. Owner columns replace "tenant" in the synchronization envelope. | [V5-60](RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md) |
| **Developer schemas** ([V5-15](RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md)) are not synchronized to Outposts until a bolt-on is published. | DEC-4 |
| Decisions V5-H-EDGE-01…04 remain open. | HANDOFF-V5 |


Status: provider-neutral architecture and selection criteria; no embedded database is selected.

## Logical boundaries

AceOutpost maintains a selective local projection, scheduled-work state, raw ingestion evidence, normalized ContentSummary items, Tag associations, and a durable outbound queue. It is not a full copy of `ATAPUtilities` or `Ace`.

- **V5-EDGE-001:** Local work SHALL continue while disconnected and survive process or device restart.
- **V5-EDGE-002:** Every outbound mutation SHALL have a stable operation ID, tenant, device, plugin, idempotency key, payload hash, created time, attempt state, and acknowledgment state.
- **V5-EDGE-003:** The server SHALL acknowledge only a durably committed effect; Outpost retains an item until that acknowledgment is durably recorded.
- **V5-EDGE-004:** Projection refresh, eviction, revocation, and deletion SHALL be explicit states. Absence from a batch is not deletion.
- **V5-EDGE-005:** Concurrent changes SHALL be detected. Last-write-wins is prohibited unless approved for a named data class.
- **V5-EDGE-006:** Sensitive and non-sensitive local data SHALL have an enforceable boundary, with sensitive data encrypted at rest and keys held by platform secure storage or an approved provider shim.

## Provider selection scorecard

The decision shall compare candidates across Windows, Android, and iOS first, while documenting portability to approved later hosts.

| Category | Required evidence |
| --- | --- |
| Integrity | Transactions or equivalent atomicity, crash recovery, corruption detection, backup/restore, and idempotent retry. |
| Platform | Packaging, footprint, CPU, memory, battery, storage, AOT compatibility, and supported OS lifecycle. |
| Security | Encryption, key bootstrap/rotation/revocation, secure temporary files and journals, and least-privilege repository access. |
| Query | Tag-set lookup, ContentSummary retrieval, task queue, telemetry/time-series aggregation, and batch ingestion. |
| Evolution | Forward migrations, compatibility windows, downgrade behavior, and exit/export path. |
| Scale/cost | Redistribution license, tooling, operations, and viability across millions of devices. |
| Testability | Deterministic fixtures, disposable stores, fault injection, schema inspection, and parity with shared repository contracts. |

SQLite, SQLCipher, and non-relational candidates remain candidates only. A weighted score requires an approved phase-one device matrix and threat model.

## Synchronization envelope

The transport contract carries contract version, operation ID, tenant, source device, plugin identity/version, entity type and identity, source authority, payload hash, asserted/recorded times, classification, and causal predecessor or cursor. Payload schemas are versioned independently from transport.

## HITL decisions

| ID | Required decision |
| --- | --- |
| V5-H-EDGE-01 | Phase-one device and operating-system matrix. |
| V5-H-EDGE-02 | Edge persistence provider and sensitive/non-sensitive store arrangement. |
| V5-H-EDGE-03 | Projection algorithm, conflict policy, deletion semantics, retention, and compaction by entity type. |
| V5-H-EDGE-04 | Transport, authentication, cursor, batching, compression, and retry protocol. |

See [the edge synchronization diagram](../RPRRSBSI-V4-2-Edge-Synchronization.puml).
