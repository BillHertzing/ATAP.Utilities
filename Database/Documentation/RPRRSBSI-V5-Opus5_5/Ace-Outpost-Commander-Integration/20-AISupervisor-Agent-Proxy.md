# AISupervisor Claude and Codex Proxy

> **V5 revision (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Successor of `Database/Documentation/RPRRSBSI-V4-2-Ace-Outpost-Commander-Integration/20-AISupervisor-Agent-Proxy.md`. Requirement and decision IDs keep their V4-2 numbers with the prefix `V5-` (for example `V4-2-CORE-034` is now `V5-CORE-034`); a V4-2 ID that is not repeated here is withdrawn only where the "V5 changes" section says so. The V5 decisions DEC-1 to DEC-6 and the 2026-11-05 training and gamification requirements are summarised in [the V5 overview](../RPRRSBSI-V5-00-Specification-Overview.md#v5-decisions); open items are in [HANDOFF-V5.md](../HANDOFF-V5.md). **Terminology (DEC-6):** an *Instantiation* is a produced file or row; the run of an executor that produces instantiations is a *Materialization*; the reusable configuration it runs is a *materialization specification*. Where carried-forward V4-2 text uses "Instantiation" for the configured act, read "materialization specification".

## V5 changes

| Change | Source |
| --- | --- |
| **Built status.** Gather-content capture (`V00060`), AISupervisor telemetry (`V00070`, `V00150`), ContentSummary storage and query (`V00100`–`V00140`) and AceCommander timeline queries exist in source. | SQL |
| **Ownership (DEC-3).** Queries return only rows the caller owns or can see through organization roles, unioned with `ATAPUtilities` template rows; filtering happens before counting, ranking and truncation. | [V5-60](../RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md) |
| **Asserted summaries (DEC-2)** are ingested by hand-entry procedures, not by the scheduler, and are returned by the same queries. | [V5-25](../RPRRSBSI-V5-25-ContentSummary-Data-Contract.md) |
| **New AceCommander surfaces:** theme step in the login workflow and the gamification home page ([40](40-Gamification-Home-And-Login-Theme.md)); DDL Authoring mode and marketplace pages ([V5-15](../RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md)); the diagram viewer must hide `AceAuth` and other users' developer schemas ([V5-65](../RPRRSBSI-V5-65-Protected-Authentication.md)). | 2026-11-04/05 |


## Architecture

The proxy is an explicit local service or harness adapter, not transparent network interception. Each harness adapter translates provider-specific events into a common exchange lifecycle and sends a sanitized record through an Ace-owned repository.

- **AO-AIS-001:** The Claude and Codex adapters SHALL report adapter version, harness version, provider, model, reported model version, effort, conversation/session, request/attempt correlation, timing, outcome, and token metadata availability.
- **AO-AIS-002:** Header inspection SHALL run before forwarding to storage. The redactor uses a denylist for secret-bearing names and an allowlist for safe protocol/correlation values.
- **AO-AIS-003:** Unknown headers default to name-only plus disposition; unknown values are not persisted.
- **AO-AIS-004:** Request and response body capture is disabled in the initial service.
- **AO-AIS-005:** Streaming completion, cancellation, tool errors, retry, and provider error responses SHALL close or explicitly abandon the exchange; no request remains silently open.
- **AO-AIS-006:** Telemetry writes SHALL be buffered durably when Ace is unavailable, subject to bounded retention and an explicit fail-open/fail-closed policy.

## Token semantics

Primary request and response token values are provider-reported. Provider-specific numeric fields map to controlled metric codes with source field and unit. AceCommander must distinguish absent, zero, partial, estimated, and provider-reported values.

## Security review gates

Before real traffic is enabled, HITL must approve adapter integration points, endpoint allowlist, header rules, body policy, retention, user notice/consent where required, and failure behavior. Test fixtures SHALL contain synthetic credentials that prove redaction without using real secrets.
