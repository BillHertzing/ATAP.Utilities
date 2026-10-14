# AceOutpost Scheduled Tags and ContentSummary Ingestion

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
