# RPRRSBSI-V4-2 ContentSummary Data Contract

Status: logical design for the initial Tags and ContentSummary capability; physical DDL and provider selection remain separate work.

## Capability

- **V4-2-CS-001:** `Get-ContentSummary` SHALL submit one or more Tags and receive the authorized ContentSummary blocks associated with those Tags.
- **V4-2-CS-002:** The return contract SHALL preserve stable item identity, source, text or locator, matched Tags, ranking evidence, asserted and recorded times, producer identity, and content hash.
- **V4-2-CS-003:** The caller MAY rank or reduce returned blocks before prompt construction; the persisted result SHALL distinguish stored rank evidence from caller-side selection.
- **V4-2-CS-004:** A scheduled AceOutpost ingestion task SHALL read the Tags and ContentSummary output produced by the `Get-ContentSummary` agent and PowerShell function.
- **V4-2-CS-005:** Ingestion SHALL be idempotent by source identity plus content hash and SHALL not create duplicate durable effects after retry or process termination.
- **V4-2-CS-006:** Ingestion SHALL preserve the original raw record and a separately queryable normalized projection. Normalization never overwrites raw evidence.

## Narrow central Ace projection

The first central slice uses three Ace-owned aggregates after the authoritative Tag root is available:

| Logical table | Minimum purpose |
| --- | --- |
| `Ace.ContentSummaryIngestion` | One source batch/run: tenant, producer, source locator, observed time, payload hash, status, and idempotency key. |
| `Ace.ContentSummaryItem` | One raw/normalized summary unit: ingestion, text or approved locator, source metadata, asserted/recorded times, content hash, and lifecycle state. |
| `Ace.ContentSummaryItemTag` | Many-to-many association from an item to durable `ATAPUtilities.Tag.TagId`, including assignment origin and as-of time. |

Rules inferred from ingestion are Ace overlays or candidates. Existing semantic Rules use a same-`RuleId` `RuleVariant` selected by an `Override` occurrence. A newly inferred semantic Rule remains an `Ace` candidate until identity registration and the publication workflow approve it; scheduled ingestion SHALL NOT publish it directly.

## Query semantics

- **V4-2-CS-010:** The query API SHALL support Tag-set mode `Any` and `All`, an explicit as-of instant, tenant context, page limit, and deterministic tie-breaking.
- **V4-2-CS-011:** Every returned item SHALL explain which requested Tags matched.
- **V4-2-CS-012:** Ranking SHALL be a named contract with versioned parameters. Until ratified, the initial implementation MAY use deterministic recency then stable identity ordering and SHALL label that behavior as provisional.
- **V4-2-CS-013:** Authorization is evaluated before Tag matching and aggregation so counts and empty results do not disclose unauthorized content.

## Retention and sensitivity

Prompt text, source paths, repository content, and generated summaries may be sensitive. The first slice SHALL default to storing only fields explicitly admitted by classification policy. Secrets and authorization headers are never ContentSummary data.

## HITL decisions

| ID | Required decision |
| --- | --- |
| V4-2-H-CS-01 | Exact input/output envelope produced by the agent and PowerShell function. |
| V4-2-H-CS-02 | Prompt retention, encryption, redaction, and deletion policy. |
| V4-2-H-CS-03 | Ranking algorithm, maximum result size, freshness, and stale-result behavior. |
| V4-2-H-CS-04 | Whether source text is stored centrally, locally only, or by content-addressed locator. |

See [the ContentSummary data model](RPRRSBSI-V4-2-ContentSummary-Data-Model.puml).
