# RPRRSBSI-V4-2 Initial Capability Slice

Status: prioritized implementation handoff. It defines the narrowest planned capability, not executable DDL or authority to deploy it.

## Outcome

The first AceOutpost/AceCommander increment SHALL prove three vertical paths:

1. a scheduled Outpost task ingests `Get-ContentSummary` Tags/ContentSummary output idempotently;
2. an explicit Claude/Codex proxy records safe request/response metadata and token counts in `Ace`; and
3. AceCommander visualizes raw summaries, Tag-set queries, and tokens over time.

## Minimum dependency sequence

| Step | Deliverable | Stop condition |
| ---: | --- | --- |
| 0 | Freeze input/output fixtures from the agent and PowerShell function; classify each field. | No representative fixture or unresolved secret-bearing field. |
| 1 | Provide the minimum durable Tag roots and sanctioned as-of read contract required by item associations. | C-08 through C-15 dependencies affecting the exact slice are not closed. |
| 2 | Add the three ContentSummary Ace aggregates and Outpost-local equivalents behind repository interfaces. | Provider-specific behavior leaks into shared contracts. |
| 3 | Implement one scheduled ingestion job with lease, checkpoint, idempotency, and replay tests. | A retry can duplicate a durable item or assignment. |
| 4 | Add AISupervisor exchange/header/metric aggregates and Claude/Codex adapters with body capture disabled. | Any credential/header secret can reach storage or logs. |
| 5 | Add query APIs and AceCommander views for raw items, Tag `Any`/`All` search, and UTC token buckets by harness/model. | Authorization is applied after aggregation or completeness is hidden. |

## Explicit deferrals

The first slice does not implement arbitrary plugin DDL, production publication, automatic Rule publication, full Ace parity, bidirectional conflict resolution for every entity, prompt/body retention, photo/NFT, outdoor-activity, Git-history, code-to-Rules, or manifestation execution. Those requirements remain architectural consumers, not reasons to widen the first migration.

## Acceptance

- **V4-2-SLICE-001:** Replaying the same ContentSummary fixture produces exactly one ingestion, one logical item per source item, and no duplicate Tag association.
- **V4-2-SLICE-002:** A scheduled task interrupted between local commit, transmission, central commit, and acknowledgment resumes without data loss or duplicate central effect.
- **V4-2-SLICE-003:** Claude and Codex fixtures populate harness, harness version, model, effort, conversation/session, request tokens, response tokens, and supported metadata without persisting secret headers.
- **V4-2-SLICE-004:** Unknown provider metrics persist only when admitted by the controlled metric catalog; otherwise they are recorded as unsupported without failing the exchange.
- **V4-2-SLICE-005:** AceCommander displays authorized raw summaries, returns deterministic `Any`/`All` Tag-set results, and plots token counts over time grouped by harness and model.
- **V4-2-SLICE-006:** Every view exposes provenance and completeness; missing token counts are not graphed as zero.

## Implementation boundary

An implementation task must allocate exact tables, keys, indexes, APIs, DTOs, provider, Flyway versions, fixtures, and tests after the named HITL decisions close. Existing prototype migration `V00030__Create_AceOutpostContentSummaryPrototype.sql` is implementation evidence from another task, not authority for this V4-2 physical design and is not modified here.

See [the initial delivery diagram](RPRRSBSI-V4-2-Initial-Capability-Slice.puml) and the [Ace integration design](RPRRSBSI-V4-2-Ace-Outpost-Commander-Integration/README.md).
