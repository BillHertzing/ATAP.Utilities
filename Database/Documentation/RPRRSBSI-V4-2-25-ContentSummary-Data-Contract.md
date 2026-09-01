# RPRRSBSI-V4-2 ContentSummary Data Contract

Status: logical design for the initial Tags and ContentSummary capability; physical DDL and provider selection remain separate work.

## REST-D01 query/write separation — superseded history

**Superseded by REST-D02 2026-08-30.** REST-D01 had defined
`/api/v1/gather-content` as a query-only resource. An authorized
client sent a structured JSON query with `POST` and received the response. An accepted POST
produced no durable write. POST carried the structured query body; it did not imply persistence.

Only POST was mapped for that route. Unsupported methods did not select the query resource and
returned the framework's method-not-allowed behavior. Any durable ContentSummary or provenance
write used a separate explicitly versioned ingestion command endpoint and contract. This ruling
did not select that command's route, DTO, idempotency identity, authorization, admitted fields,
persistence schema, or live values.

REST-D01 remains historical and no longer controls accepted-POST write behavior or requires a
separate REST02 route.

## REST-D02 durable submitted-Tag capture

**Ratified 2026-08-30; supersedes REST-D01.** An authorized client sends the existing structured
JSON POST to `/api/v1/gather-content`. After authorization and request validation, an accepted
POST durably records the submitted Tags and returns the authorized query response. Unsupported
methods still do not select the route and retain framework method-not-allowed behavior.

`ATAPUtilities.Tag*` is read-only to this application path. Task 15.185.b owns the
application-writable, near-duplicate `Ace.Tag*` objects. The recommended physical direction is
Ace-owned append-only submission provenance plus association or projection into Ace Tag tables.
The exact DDL/migration version, namespace/stewardship, association/projection, upsert/idempotency,
constraints, grants, and failure semantics remain Task 15.185.b design inputs.

The current JSON request contains no prompt, so this slice does not add or store one. A future
contract revision SHALL store prompt text with its submitted Tags to preserve prompt-to-Tag
correlation for ContentSummary candidate and seed generation. The exact request field and its
classification, redaction, encryption, access, retention, deletion, and migration controls
remain pending under `V4-2-H-CS-02`.

REST-D02 resolves the accepted-POST semantic direction of `V4-2-H-CS-01`. The exact query item
DTO and every remaining H-CS choice stay pending.

## Capability

- **V4-2-CS-001:** `Get-ContentSummary` SHALL submit one or more Tags and receive the authorized ContentSummary blocks associated with those Tags.
- **V4-2-CS-002:** The return contract SHALL preserve stable item identity, source, text or locator, matched Tags, ranking evidence, asserted and recorded times, producer identity, and content hash.
- **V4-2-CS-003:** The caller MAY rank or reduce returned blocks before prompt construction; the persisted result SHALL distinguish stored rank evidence from caller-side selection.
- **V4-2-CS-004:** A scheduled AceOutpost ingestion task SHALL read the Tags and ContentSummary output produced by the `Get-ContentSummary` agent and PowerShell function.
- **V4-2-CS-005:** Ingestion SHALL be idempotent by source identity plus content hash and SHALL not create duplicate durable effects after retry or process termination.
- **V4-2-CS-006:** Ingestion SHALL preserve the original raw record and a separately queryable normalized projection. Normalization never overwrites raw evidence.

Under REST-D02, the accepted gather-content POST performs the submitted-Tag capture required for
this slice and returns the query response. A separate REST02 route is not required. CS-004
through CS-006 remain logical requirements for the admitted provenance/projection, while their
exact physical realization is pending Task 15.185.b.

## Narrow central Ace projection

The first central slice uses three Ace-owned aggregates after the authoritative Tag root is available:

| Logical table | Minimum purpose |
| --- | --- |
| `Ace.ContentSummaryIngestion` | One source batch/run: tenant, producer, source locator, observed time, payload hash, status, and idempotency key. |
| `Ace.ContentSummaryItem` | One raw/normalized summary unit: ingestion, text or approved locator, source metadata, asserted/recorded times, content hash, and lifecycle state. |
| `Ace.ContentSummaryItemTag` | Application-owned association or projection into the Task 15.185.b `Ace.Tag*` model, including approved origin/as-of data; the exact foreign-key shape remains pending. |

Task 15.185.b also owns the near-duplicate, application-writable `Ace.Tag*` objects needed by
REST-D02. `ATAPUtilities.Tag*` remains a read-only authoritative source; this slice creates no
application write to those objects.

Rules inferred from ingestion are Ace overlays or candidates. Existing semantic Rules use a same-`RuleId` `RuleVariant` selected by an `Override` occurrence. A newly inferred semantic Rule remains an `Ace` candidate until identity registration and the publication workflow approve it; scheduled ingestion SHALL NOT publish it directly.

## Query semantics

- **V4-2-CS-010:** The query API SHALL support Tag-set mode `Any` and `All`, an explicit as-of instant, tenant context, page limit, and deterministic tie-breaking.
- **V4-2-CS-011:** Every returned item SHALL explain which requested Tags matched.
- **V4-2-CS-012:** Ranking SHALL be a named contract with versioned parameters. Until ratified, the initial implementation MAY use deterministic recency then stable identity ordering and SHALL label that behavior as provisional.
- **V4-2-CS-013:** Authorization is evaluated before Tag matching and aggregation so counts and empty results do not disclose unauthorized content.

## Retention and sensitivity

Prompt text, source paths, repository content, and generated summaries may be sensitive. The first slice SHALL default to storing only fields explicitly admitted by classification policy. Secrets and authorization headers are never ContentSummary data.

## HITL decisions

| ID | Status and required decision |
| --- | --- |
| V4-2-H-CS-01 | **Partially resolved by REST-D02, superseding REST-D01:** an accepted gather-content POST durably records submitted Tags in `Ace.Tag*` and returns the authorized query response. The exact query item DTO and remaining input/output/provenance choices are still pending. |
| V4-2-H-CS-02 | **Functional intent partially resolved:** a future request-contract revision stores prompt text with submitted Tags for prompt-to-Tag correlation and ContentSummary candidate/seed generation. The current REST JSON remains unchanged. Exact field shape, classification, redaction, encryption, access, retention, deletion, and migration policy remain pending. |
| V4-2-H-CS-03 | Ranking algorithm, maximum result size, freshness, and stale-result behavior. |
| V4-2-H-CS-04 | Whether source text is stored centrally, locally only, or by content-addressed locator. |

See [the ContentSummary data model](RPRRSBSI-V4-2-ContentSummary-Data-Model.puml).
