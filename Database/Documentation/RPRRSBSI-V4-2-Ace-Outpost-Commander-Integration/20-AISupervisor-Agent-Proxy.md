# AISupervisor Claude and Codex Proxy

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
