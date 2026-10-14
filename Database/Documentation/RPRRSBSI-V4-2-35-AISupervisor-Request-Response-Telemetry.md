# RPRRSBSI-V4-2 AISupervisor Request/Response Telemetry

Status: design contract for an Ace-owned AI-agent proxy. It does not authorize traffic interception, credential capture, or payload retention.

## Proxy boundary

- **V4-2-AIS-001:** The first proxy adapters SHALL support Claude and Codex harness traffic through explicit, configured integration points.
- **V4-2-AIS-002:** Every observed request and terminal response SHALL form one durable exchange with a stable exchange ID, correlation ID, session/conversation ID, start/end UTC times, outcome, and retry/stream sequence information.
- **V4-2-AIS-003:** Agent identity SHALL include harness name and version, provider, model name and reported version when available, and reasoning/effort setting.
- **V4-2-AIS-004:** The exchange SHALL record request-token and response-token counts when reported. Missing counts remain null with a recorded availability reason; they are never estimated as authoritative values.
- **V4-2-AIS-005:** Additional numeric response metadata, including thinking/reasoning, cache-read, cache-write, or tool tokens, SHALL use controlled metric codes so a newly reported metric does not require an immediate table alteration.
- **V4-2-AIS-006:** Headers SHALL be inspected for protocol and correlation metadata but stored only through a classification and redaction policy. Secret, credential, cookie, and bearer values SHALL never be persisted.

## Narrow Ace schema

| Logical table | Minimum purpose |
| --- | --- |
| `Ace.AISupervisorExchange` | Tenant, agent descriptor fields, conversation/session, timestamps, outcome, endpoint classification, and primary request/response token counts. |
| `Ace.AISupervisorHeader` | Direction, normalized header name, disposition, optional safe value or hash, and classification. |
| `Ace.AISupervisorMetric` | Direction, controlled metric code, numeric value, unit, source field, and whether provider-reported or derived. |

Request and response bodies are not required for the initial token visualizer. Body capture defaults off. If later enabled, content belongs in a separately classified payload store with retention, encryption, and access controls; it SHALL NOT be added as an unbounded column to the exchange table.

## Streaming, retries, and failure

- **V4-2-AIS-010:** Streaming chunks belong to one exchange and SHALL not multiply the terminal token count.
- **V4-2-AIS-011:** A network retry SHALL retain attempt identity and link to the logical exchange so totals can be reported either by logical request or physical attempt.
- **V4-2-AIS-012:** Proxy failure SHALL fail open or closed only according to a named policy per endpoint. Telemetry persistence failure SHALL be observable and SHALL never expose secrets in fallback logs.
- **V4-2-AIS-013:** Provider-specific parsing SHALL be isolated behind an adapter; the Ace storage contract remains provider-neutral.

## Query contract

AceCommander SHALL be able to aggregate token counts over explicit UTC buckets by harness, model, effort, tenant-authorized scope, and outcome. A graph point SHALL identify whether counts are complete, partial, missing, or derived.

## HITL decisions

| ID | Required decision |
| --- | --- |
| V4-2-H-AIS-01 | Exact Claude and Codex integration points and supported harness versions. |
| V4-2-H-AIS-02 | Header allowlist, hashing/redaction rules, and retention. |
| V4-2-H-AIS-03 | Whether any body, prompt, response text, or tool payload may be retained. |
| V4-2-H-AIS-04 | Metric-code governance and semantics for thinking/reasoning and cache tokens. |
| V4-2-H-AIS-05 | Fail-open/fail-closed behavior and backpressure when telemetry storage is unavailable. |

See [the AISupervisor data model](RPRRSBSI-V4-2-AISupervisor-Telemetry.puml).
