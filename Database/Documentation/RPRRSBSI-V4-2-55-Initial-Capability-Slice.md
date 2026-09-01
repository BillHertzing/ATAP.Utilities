# RPRRSBSI-V4-2 Initial Capability Slice

Status: candidate input to Task 15.140.b and prioritized implementation handoff. It
defines the narrowest planned capability, not executable DDL, a ratified V4 authority,
or authority to configure, deploy, or exercise a live system.

## Outcome

The first AceOutpost/AceCommander increment SHALL prove three vertical paths:

1. `Get-ContentSummary` sends a structured JSON query over HTTPS to the
   `/api/v1/gather-content` resource bound only to IPv4 loopback `127.0.0.1` and IPv6
   loopback `::1`; after authorization and validation, an accepted POST durably records the
   submitted Tags in Task 15.185.b-owned `Ace.Tag*` objects and returns the authorized query
   response;
2. a separately addressed localhost-only HTTPS hybrid metering listener uses a minimum-feature
   Claude/Codex proxy to record approved prompts, tags, safe request/response metadata, and
   provider-reported usage in AISupervisor `Ace` tables; and
3. AceCommander visualizes raw summaries, Tag-set queries, and tokens over time.

The gather-content and metering listeners use different, ATAP-configurable ports in the
`500NN` range. Scheme, host, and port remain configuration values subject to normal ATAP provider
precedence. Exact ports are deliberately not allocated by this document.

## Ratified decision inputs

This slice carries the operator-ratified Task 15.185 D4 through D7 boundaries and the released
U2/U3 designs:

- [Task 15.185 local HTTPS endpoints and certificate decision](https://github.com/whertzing/_Planning/blob/main/InformationForTheFuture/Sprint0015/Task15.185/LocalHttpsEndpointsAndCertificateDecision.md)
  defines the explicit loopback bindings, remote-rejection posture, separate configurable
  ports, configuration precedence, and the gated UTAT022 certificate boundary.
- [Task 15.185 hybrid metering proxy research](https://github.com/whertzing/_Planning/blob/main/InformationForTheFuture/Sprint0015/Task15.185/HybridMeteringProxyResearch.md)
  preserves the historical proxy research and its current exact-artifact amendment.
  `PROXY-LIBRARY-G01` is reopened after CaptureProxy 1.2.4 was technically rejected.
  The third-party-neutral AceOutpost contract remains the replacement boundary, while
  security and operating choices remain in `AISUPERVISOR-HYBRID-G01`.

Both services use Bitwarden ProjectName `Ace` and provider-neutral VaultGroupingId `Ace` while
retaining distinct ApplicationIds, SecretNames, and exact Secret-ID mappings. This shared
free-tier grouping is configuration metadata; it neither exposes a secret value nor merges the
application security identities. This document authorizes no Bitwarden, token, credential,
certificate, ACL, listener, database, or service action.

## Local HTTPS boundaries

### D4 gather-content POST and submitted-Tag capture

AceOutpost exposes a versioned REST resource over HTTPS on explicit `127.0.0.1` and `::1`
sockets. It SHALL reject non-loopback transport peers, wildcard/LAN bindings, unsupported
methods and content types, oversized requests, and unrecognized contract versions before
query dispatch. `Get-ContentSummary` or another authorized client sends a structured JSON
`POST` to `/api/v1/gather-content` using the configured HTTPS scheme, loopback host, and
ingestion port and receives a response.

REST-D01 previously defined an accepted POST as query-only with no durable write and required a
separate versioned ingestion command. **REST-D02 supersedes that boundary.** After authorization
and request validation, an accepted POST durably records the submitted Tags and returns the
authorized query response. The separate REST02-route premise is superseded. Only POST is mapped;
unsupported methods do not select the route and retain framework method-not-allowed behavior.

`ATAPUtilities.Tag*` remains read-only. Task 15.185.b owns the application-writable,
near-duplicate `Ace.Tag*` objects. The recommended physical direction is Ace-owned append-only
submission provenance plus association or projection into Ace Tag tables. Exact DDL/migration
version, namespace/stewardship, association/projection, upsert/idempotency, constraints, grants,
and failure behavior remain Task 15.185.b design inputs. Missing metadata remains missing; the
receiver does not invent identifiers or silently coerce absence to an empty value.

The current REST JSON contains no prompt, so this slice does not widen the contract or store one.
A future contract revision SHALL store prompt text with submitted Tags for prompt-to-Tag
correlation and ContentSummary candidate/seed generation. Exact prompt security and lifecycle
controls remain pending under `V4-2-H-CS-02`. REST-D02 resolves only the accepted-POST semantic direction of
`V4-2-H-CS-01`; the exact query item DTO and remaining H-CS decisions stay pending.
Authentication/authorization, request limits, and failure semantics remain implementation
allocations behind `INGESTION-HTTPS-G01`.

### D5 hybrid metering proxy

The hybrid path combines a harness-side classified prompt/tag envelope, an explicit local
forward-proxy call, a streaming provider observer, and Ace persistence. The metering listener
uses a second loopback-only HTTPS port, unequal to the ingestion port. Provider destinations are
restricted by server policy; absolute-form request targets and `CONNECT` authority are accepted
only when they match a configured provider rule. `Host`, forwarding headers, request data, and
query parameters cannot widen that allowlist.

CaptureProxy 1.2.4 is not an active engine dependency. Its exact package hash
`368A43ED58F77036D49B7CE5BF6DC186E8DD5F5C2C1EC9B786B404966FDD7C75`,
NuGet.org repository signature, embedded MIT license, zero declared dependencies, and
isolated `net10.0-windows` compatibility remain verified history. The exact-artifact
audit rejected it because of hard-coded `IPAddress.Any`, no local HTTPS
listener-certificate API, unconditional upstream TLS acceptance during captured `CONNECT`,
whole-body or unbounded capture buffering, no authoritative asynchronous drain, and
insufficient pre-forward policy context. The package authorization was not exercised.

D5 hybrid metering remains ratified. The corrected third-party-neutral engine contract and
69 passing focused tests remain partial PROXY01 work. The next candidate must pass that
unchanged conformance suite. The implementation SHALL NOT buffer an entire provider stream,
perform an automatic application retry, become an open proxy, or enable an OS-wide proxy.
`SC-0367` remains a future ATAP-owned-proxy enhancement and is not started by this NO-GO.

Standard `CONNECT` tunneling does not expose provider bodies. Any TLS interception requires
a separately ratified CA, trust, private-key, consent, rotation, and cleanup boundary under
`AISUPERVISOR-HYBRID-G01`; the localhost server certificate is not an interception CA.

The hybrid observer writes approved prompt, tag, exchange, attempt, metric, and usage records to
AISupervisor `Ace` tables. Provider credential values, arbitrary headers, response bodies, tool
payloads, and unclassified request bodies never enter those tables or ordinary logs. Credential
custody, prompt retention/redaction, notice and consent, queue/spool limits, backpressure,
retry/idempotency, bypass, failure policy, recovery, and rollback remain choices in
`AISUPERVISOR-HYBRID-G01`.

### UTAT022 certificate boundary

Both listeners require a UTAT022 server-authentication certificate selected through fail-closed
configuration. The exact client-host form determines whether the certificate needs DNS SAN
`localhost`, IP SAN `127.0.0.1`, IP SAN `::1`, or the approved subset. Later implementation must
prove chain trust, EKU, validity and revocation policy, unambiguous thumbprint resolution,
private-key availability and least-privilege ACL, rotation overlap, rollback, and remote refusal.
It must not disable certificate validation or silently use a development certificate.

The exact ports, certificate issuer/chain, store, binding mechanism, SAN set, private-key ACL,
URL registration/firewall posture, rotation, recovery, and whether both ports use the same
eligible certificate remain subordinate HITL choices. UTAT01 is deferred to D-17 and requires
independent evidence; no UTAT022 port, certificate, SID, ACL, or trust result transfers to it.

## Minimum dependency sequence

| Step | Deliverable | Stop condition |
| ---: | --- | --- |
| 0 | Freeze accepted/rejected gather-content POST and Claude/Codex non-streaming/SSE fixtures; classify each field and synthetic secret canary. | No representative fixture, unclassified field, or unresolved secret-bearing field. |
| 1 | Provide the minimum durable Tag roots and sanctioned as-of read contract required by item associations. | C-08 through C-15 dependencies affecting the exact slice are not closed. |
| 2 | Add the three ContentSummary Ace aggregates, Task 15.185.b-owned `Ace.Tag*` objects, and Outpost-local equivalents behind repository interfaces. | Provider-specific behavior leaks into shared contracts or the application can write `ATAPUtilities.Tag*`. |
| 3 | Implement the D4 loopback HTTPS endpoint and make `Get-ContentSummary` call it, with authorization, durable submitted-Tag capture before query, remote-rejection, TLS, method-selection, cancellation, and replay tests. | A rejected request writes, an accepted request can return without durable Tag capture, idempotency behavior is not yet ratified or a retry violates the later-ratified Task 15.185.b contract, an unsupported method invokes the route, a remote peer can connect, or HTTPS validation is bypassed. |
| 4 | Implement the separate D5 loopback HTTPS hybrid path using the gated forwarding engine, AISupervisor aggregates, and Claude/Codex adapters. | Any credential/header secret can reach storage or logs, the proxy can reach an unconfigured destination, or streaming requires whole-body buffering. |
| 5 | Add query APIs and AceCommander views for raw items, Tag `Any`/`All` search, and UTC token buckets by harness/model. | Authorization is applied after aggregation or completeness is hidden. |
| 6 | Promote passing fixtures to a separately authorized live Claude/Codex acceptance run and prove Ace prompt/tag/usage writes, redaction, both loopback families, remote refusal, and rollback. | A subordinate gate is open, live authority is absent, or evidence could disclose a secret. |

## Explicit deferrals

The first slice does not implement arbitrary plugin DDL, production publication, automatic Rule
publication, full Ace parity, bidirectional conflict resolution for every entity, unrestricted
prompt/body retention, transparent traffic interception, an OS-wide proxy, automatic provider
request replay, photo/NFT, outdoor-activity, Git-history, code-to-Rules, or manifestation
execution. Those requirements remain architectural consumers, not reasons to widen the first
migration or the two local HTTPS boundaries.

## Acceptance

- **V4-2-SLICE-001:** Replaying the same accepted gather-content fixture produces the effect required by the later-ratified Task 15.185.b idempotency contract in `Ace.Tag*` without writing `ATAPUtilities.Tag*`.
- **V4-2-SLICE-002:** `Get-ContentSummary` uses structured JSON POST against `/api/v1/gather-content`; an accepted POST durably records submitted Tags and returns the authorized response; unsupported methods do not invoke the route and retain framework method-not-allowed behavior; both `127.0.0.1` and `::1` succeed with valid TLS, while a remote peer, wildcard binding, wrong scheme, duplicate/out-of-range port, or invalid certificate fails closed.
- **V4-2-SLICE-003:** A gather-content POST interrupted between durable submitted-Tag capture, query execution, and response resumes according to the still-pending Task 15.185.b idempotency/failure contract without unauthorized or duplicate effect.
- **V4-2-SLICE-004:** Claude and Codex non-streaming and SSE fixtures populate harness, harness version, model, effort, conversation/session, exchange/attempt, prompt/tag classification, request tokens, response tokens, and supported metadata without persisting credential or prohibited header values.
- **V4-2-SLICE-005:** The hybrid proxy accepts only configured adapters and destinations, preserves stream ordering and cancellation, performs no automatic application retry, keeps memory bounded under telemetry backpressure, and records missing usage as unavailable rather than zero.
- **V4-2-SLICE-006:** Unknown provider metrics persist only when admitted by the controlled metric catalog; otherwise they are recorded as unsupported without failing the exchange.
- **V4-2-SLICE-007:** AceCommander displays authorized raw summaries, returns deterministic `Any`/`All` Tag-set results, and plots token counts over time grouped by harness and model.
- **V4-2-SLICE-008:** Every view exposes provenance and completeness; missing token counts are not graphed as zero.
- **V4-2-SLICE-009:** After fixture acceptance and fresh live authorization, exact Claude and Codex adapters prove localhost TLS, streaming, redaction, prompt/tag/usage writes to the intended AISupervisor `Ace` tables, remote refusal, and rollback without exposing secrets in evidence.

Fixture success is necessary but not sufficient for live acceptance. The live run is a separate,
operator-directed unit and SHALL use secret-safe evidence.

## Retained subordinate gates

- **`INGESTION-HTTPS-G01`:** exact ingestion port, client-host/SAN form, certificate issuer and
  chain, store/binding, private-key ACL, rotation/recovery, URL/firewall posture,
  authentication/authorization, request limits, and failure behavior.
- **`PROXY-LIBRARY-G01` (reopened):** CaptureProxy 1.2.4 is technically rejected for
  the six binding reasons above. Its exact package facts remain verified history, and no
  AceOutpost product package integration occurred. Select a conforming engine or explicitly
  ratify another bounded approach, then run the unchanged third-party-neutral conformance
  suite. Do not silently fork/vendor CaptureProxy or begin `SC-0367`.
- **`AISUPERVISOR-HYBRID-G01`:** exact metering port and certificate binding, adapter endpoints,
  destination allowlist, provider credential custody, redaction/retention, notice/consent,
  authorized readers, queue/spool and backpressure policy, retry/idempotency, bypass,
  fail-open/fail-closed choices, recovery, alerting, rollback, and live promotion evidence.

No gate is self-ratified by this capability document.

## Implementation boundary

An implementation task must allocate exact tables, keys, indexes, APIs, DTOs, providers,
forward-only Flyway versions, fixtures, and tests after the named HITL decisions close. Existing
prototype migration `V00030__Create_AceOutpostContentSummaryPrototype.sql` and
`[ATAPUtilities].[AceOutpostContentSummaryPrototype]` remain immutable historical evidence from
another task. Applications SHALL NOT write to, extend, reuse, or relabel that table. Its removal
is deferred to a future rewrite of the V00010 core schema; Task 15.185 creates the `Ace` schema
and Ace-owned tables, including the application-writable `Ace.Tag*` model, only through new
forward-only migrations. `ATAPUtilities.Tag*` remains read-only to this application path.

This document is sequencing input. It does not select an active package version, reserve a port,
issue or bind a certificate, grant a private-key ACL, change Bitwarden, configure a listener,
modify a service, apply a migration, write a database, send provider traffic, or authorize
deployment.

See [the initial delivery diagram](RPRRSBSI-V4-2-Initial-Capability-Slice.puml) and the [Ace integration design](RPRRSBSI-V4-2-Ace-Outpost-Commander-Integration/README.md).
