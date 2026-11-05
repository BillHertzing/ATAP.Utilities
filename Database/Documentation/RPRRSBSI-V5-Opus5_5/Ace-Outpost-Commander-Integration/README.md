# RPRRSBSI V5 AceOutpost and AceCommander Integration

> **V5 revision (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Successor of `Database/Documentation/RPRRSBSI-V4-2-Ace-Outpost-Commander-Integration/README.md`. Requirement and decision IDs keep their V4-2 numbers with the prefix `V5-` (for example `V4-2-CORE-034` is now `V5-CORE-034`); a V4-2 ID that is not repeated here is withdrawn only where the "V5 changes" section says so. The V5 decisions DEC-1 to DEC-6 and the 2026-11-05 training and gamification requirements are summarised in [the V5 overview](../RPRRSBSI-V5-00-Specification-Overview.md#v5-decisions); open items are in [HANDOFF-V5.md](../HANDOFF-V5.md). **Terminology (DEC-6):** an *Instantiation* is a produced file or row; the run of an executor that produces instantiations is a *Materialization*; the reusable configuration it runs is a *materialization specification*. Where carried-forward V4-2 text uses "Instantiation" for the configured act, read "materialization specification".

## V5 changes

| Change | Source |
| --- | --- |
| **Built status.** Gather-content capture (`V00060`), AISupervisor telemetry (`V00070`, `V00150`), ContentSummary storage and query (`V00100`–`V00140`) and AceCommander timeline queries exist in source. | SQL |
| **Ownership (DEC-3).** Queries return only rows the caller owns or can see through organization roles, unioned with `ATAPUtilities` template rows; filtering happens before counting, ranking and truncation. | [V5-60](../RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md) |
| **Asserted summaries (DEC-2)** are ingested by hand-entry procedures, not by the scheduler, and are returned by the same queries. | [V5-25](../RPRRSBSI-V5-25-ContentSummary-Data-Contract.md) |
| **New AceCommander surfaces:** theme step in the login workflow and the gamification home page ([40](40-Gamification-Home-And-Login-Theme.md)); DDL Authoring mode and marketplace pages ([V5-15](../RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md)); the diagram viewer must hide `AceAuth` and other users' developer schemas ([V5-65](../RPRRSBSI-V5-65-Protected-Authentication.md)). | 2026-11-04/05 |


Status: application architecture companion to the V4-2 database design.

## Priority

The first service increment joins three user-visible capabilities:

1. scheduled ingestion of Tags and ContentSummary output produced by `Get-ContentSummary`;
2. safe Claude/Codex request-response telemetry through AISupervisor; and
3. AceCommander views for raw content, Tag-set retrieval, and token use over time.

## Documents

| Document | Purpose |
| --- | --- |
| [AceOutpost scheduled ingestion](10-AceOutpost-Scheduled-ContentSummary-Ingestion.md) | Scheduling, idempotency, local persistence, and synchronization. |
| [AISupervisor agent proxy](20-AISupervisor-Agent-Proxy.md) | Adapter, redaction, exchange, header, and metric behavior. |
| [AceCommander visualization](30-AceCommander-Visualization.md) | Query contracts and initial user experiences. |
| [Initial service architecture](../../RPRRSBSI-V4-2-Ace-Outpost-Commander-Integration/40-Initial-Service-Architecture.puml) | Component boundaries and data flow. |
| [Proxy sequence](../../RPRRSBSI-V4-2-Ace-Outpost-Commander-Integration/50-Proxy-Sequence.puml) | One request/response capture lifecycle. |
| [Commander views](../../RPRRSBSI-V4-2-Ace-Outpost-Commander-Integration/60-Commander-Views.puml) | UI-to-query-service relationships. |
| [Gamification home page and login theme step](40-Gamification-Home-And-Login-Theme.md) | **New in V5.** Theme selection during login, gamification home page, training wizard surfaces. |

The companion [initial capability slice](../RPRRSBSI-V5-55-Initial-Capability-Slice.md) controls ordering and exclusions.
