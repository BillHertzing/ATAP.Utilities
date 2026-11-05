# RPRRSBSI V5 AceOutpost and AceCommander Integration

> **V5 revision (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Successor of `Database/Documentation/RPRRSBSI-V4-2-Ace-Outpost-Commander-Integration/README.md`. Requirement and decision IDs keep their V4-2 numbers with the prefix `V5-` (for example `V4-2-CORE-034` is now `V5-CORE-034`); a V4-2 ID that is not repeated here is withdrawn only where the "V5 changes" section says so. The V5 decisions DEC-1 to DEC-6 and the 2026-11-05 training and gamification requirements are summarised in [the V5 overview](RPRRSBSI-V5-00-Specification-Overview.md#v5-decisions); open items are in [HANDOFF-V5.md](HANDOFF-V5.md). **Terminology (DEC-6):** an *Instantiation* is a produced file or row; the run of an executor that produces instantiations is a *Materialization*; the reusable configuration it runs is a *materialization specification*. Where carried-forward V4-2 text uses "Instantiation" for the configured act, read "materialization specification".


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
| [Initial service architecture](../../RPRRSBSI-V5-Ace-Outpost-Commander-Integration/40-Initial-Service-Architecture.puml) | Component boundaries and data flow. |
| [Proxy sequence](../../RPRRSBSI-V5-Ace-Outpost-Commander-Integration/50-Proxy-Sequence.puml) | One request/response capture lifecycle. |
| [Commander views](../../RPRRSBSI-V5-Ace-Outpost-Commander-Integration/60-Commander-Views.puml) | UI-to-query-service relationships. |

The companion [initial capability slice](../RPRRSBSI-V5-55-Initial-Capability-Slice.md) controls ordering and exclusions.
