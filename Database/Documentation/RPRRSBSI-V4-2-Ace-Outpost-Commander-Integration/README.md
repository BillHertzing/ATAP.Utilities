# RPRRSBSI V4-2 AceOutpost and AceCommander Integration

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
| [Initial service architecture](40-Initial-Service-Architecture.puml) | Component boundaries and data flow. |
| [Proxy sequence](50-Proxy-Sequence.puml) | One request/response capture lifecycle. |
| [Commander views](60-Commander-Views.puml) | UI-to-query-service relationships. |

The companion [initial capability slice](../RPRRSBSI-V4-2-55-Initial-Capability-Slice.md) controls ordering and exclusions.
