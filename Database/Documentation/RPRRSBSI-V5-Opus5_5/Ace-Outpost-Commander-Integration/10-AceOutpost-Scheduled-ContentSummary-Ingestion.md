# AceOutpost Scheduled Tags and ContentSummary Ingestion

> **V5 revision (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Successor of `Database/Documentation/RPRRSBSI-V4-2-Ace-Outpost-Commander-Integration/10-AceOutpost-Scheduled-ContentSummary-Ingestion.md`. Requirement and decision IDs keep their V4-2 numbers with the prefix `V5-` (for example `V4-2-CORE-034` is now `V5-CORE-034`); a V4-2 ID that is not repeated here is withdrawn only where the "V5 changes" section says so. The V5 decisions DEC-1 to DEC-6 and the 2026-11-05 training and gamification requirements are summarised in [the V5 overview](../RPRRSBSI-V5-00-Specification-Overview.md#v5-decisions); open items are in [HANDOFF-V5.md](../HANDOFF-V5.md). **Terminology (DEC-6):** an *Instantiation* is a produced file or row; the run of an executor that produces instantiations is a *Materialization*; the reusable configuration it runs is a *materialization specification*. Where carried-forward V4-2 text uses "Instantiation" for the configured act, read "materialization specification".

## V5 changes

| Change | Source |
| --- | --- |
| **Built status.** Gather-content capture (`V00060`), AISupervisor telemetry (`V00070`, `V00150`), ContentSummary storage and query (`V00100`–`V00140`) and AceCommander timeline queries exist in source. | SQL |
| **Ownership (DEC-3).** Queries return only rows the caller owns or can see through organization roles, unioned with `ATAPUtilities` template rows; filtering happens before counting, ranking and truncation. | [V5-60](../RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md) |
| **Asserted summaries (DEC-2)** are ingested by hand-entry procedures, not by the scheduler, and are returned by the same queries. | [V5-25](../RPRRSBSI-V5-25-ContentSummary-Data-Contract.md) |
| **New AceCommander surfaces:** theme step in the login workflow and the gamification home page ([40](40-Gamification-Home-And-Login-Theme.md)); DDL Authoring mode and marketplace pages ([V5-15](../RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md)); the diagram viewer must hide `AceAuth` and other users' developer schemas ([V5-65](../RPRRSBSI-V5-65-Protected-Authentication.md)). | 2026-11-04/05 |


## Service boundary

AceOutpost owns a platform scheduler adapter, one host service, repositories, and synchronization. The ingestion plugin supplies parsing and normalization but cannot bypass the host repositories.

- **AO-CS-001:** A schedule definition SHALL name trigger, time zone, minimum interval, resource conditions, priority, cancellation policy, and plugin identity/version.
- **AO-CS-002:** Each run SHALL acquire a bounded lease and create a durable run/checkpoint before processing source records.
- **AO-CS-003:** The input adapter SHALL support the versioned output envelope of both the `Get-ContentSummary` agent and PowerShell function.
- **AO-CS-004:** Parse, classify, hash, normalize, associate Tags, commit locally, enqueue synchronization, and checkpoint SHALL have explicit restart boundaries.
- **AO-CS-005:** Manual high-priority execution uses the same pipeline and idempotency rules as scheduled execution.
- **AO-CS-006:** Cancellation or resource pressure SHALL stop at a safe checkpoint. Emergency interruption SHALL not mark incomplete work successful.

## Rule handling

Tags Rules and ContentSummary Rules produced by the source are persisted as Ace-owned candidates or same-`RuleId` overlays. The task SHALL validate identity, provenance, RuleKind, plugin version, and source hash. It SHALL not create authoritative ATAPUtilities definitions or execute plugin DDL.

## Failure states

Runs distinguish unavailable input, invalid envelope, unauthorized tenant, rejected classification, local-store failure, synchronization pending, synchronization rejected, and success. Diagnostics identify safe remediation without copying sensitive source content.

## Required tests

Duplicate input, reordered input, crash after local commit, crash after central commit before acknowledgment, cancellation, clock change, disk pressure, plugin upgrade, unsupported envelope version, and revoked tenant/device shall each have deterministic fixtures.
