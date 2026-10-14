# RRSBS ADR-190 — ContentSummary Reconciliation

Status: Frozen implementation plan for Sprint 0015 Tasks 15.60.a-.f on 2026-09-04.
No migration, package, live-system, Ace host, or SharedVSCode change is authorized by
this decision record.

## Decision

ContentSummary is a reusable, versioned `ATAPUtilities` read model derived from an exact
`SourceArtifactVersion`. It is not a second source-identity system, an authorization
grant, an Ace submission log, or a mutable cache row.

The implementation SHALL follow the logical model in
[RDB-260](../Database/Documentation/RRSBS-RDB-260-Context-SourceArtifact-AgentText-ContentSummary-Logical-Model.md),
the source identity contract in [ADR-147](RRSBS-ADR-147-SourceArtifact-and-Path-Identity.md),
the deployed Tags contract in
[RPRRSBSI V4-2 Tags](../Database/Documentation/RPRRSBSI-V4-2-30-Tags-Expert-System.md),
and the exact contract in
[RPRRSBSI V4-2 ContentSummary](../Database/Documentation/RPRRSBSI-V4-2-25-ContentSummary-Data-Contract.md).

## Reconciled ownership planes

| Plane | Authority and permitted responsibility |
| --- | --- |
| `ATAPUtilities` | Durable Repository/SourceArtifact identity, append-only source observations, ContentSummary subjects and versions, dependencies, classification-only Tag assignments, and parameterized as-of query surfaces. |
| `Ace` | V00060 accepted-POST submission provenance, request idempotency, submitted Tag spelling/order, application authorization, transport, and optional application-owned projections. It does not become the authoritative ContentSummary store. |
| AceOutpost local store | Bounded leases, checkpoints, admitted raw-envelope metadata, normalized local projection, outbound synchronization, and retry state. It never publishes authoritative Rules or writes `ATAPUtilities.Tag*` directly. |
| Agent/PowerShell caller | Keeps the existing `Get-ContentSummary` parameter and response-envelope interface. It sends the current structured request and consumes authorized results; it does not fabricate missing summaries. |

This resolves the earlier candidate text that described three `Ace.ContentSummary*`
aggregates as the central model. Ace may retain a projection for application needs, but
the reusable source/version/provenance model belongs to `ATAPUtilities`. V00060 remains
the distinct submission-capture boundary.

## Immutable historical migrations

| Migration | SHA-256 | Disposition |
| --- | --- | --- |
| `V00030__Create_AceOutpostContentSummaryPrototype.sql` | `98C0018A4A92A1A8095CA329D93706A4B426016C1C42B69BC3F7CFB865B38179` | Preserve byte-for-byte and retain `[ATAPUtilities].[AceOutpostContentSummaryPrototype]` as unused historical evidence. Never extend, relabel, backfill, read as the new model, or drop it in this slice. |
| `V00060__Create_Ace_GatherContent_Submission.sql` | `953705FEE9678B532FFF52D780182AA8A7EF3D000DB96873DB9EB58AAAEB46FB` | Preserve byte-for-byte. Continue using its Ace-owned accepted-POST submission, Tag occurrence, and idempotency boundary. Its direct-current-Tag query is transitional and is not the new ContentSummary query. |
| `V00090__Create_ATAPUtilities_Tag_Relations_Assignments_And_Rules.sql` | `34A0EC2A1CE485BECBC0497BD4A726BFEC45CD2DBA7D39E26A753A8A6C594DEB` | Preserve byte-for-byte. Consume its durable Tags, role TVP, as-of edge query, and classification-only assignment constraints through a new forward migration. |

Parked Sprint 0013 drafts, Kind ID 9, stale GUID ranges, and historical migration
numbers remain non-authoritative evidence. They are not allocations.

## V4 naming correction

RDB-260 used `RuleVersion` as a conceptual provenance label. RPRRSBSI V4 reserves
`Version` for external software/package/protocol versions and represents internal Rule
evolution with `RuleVariant` plus `RuleVariantState`. ContentSummary therefore stores an
exact immutable `RuleVariantId` and the applicable state/as-of evidence for prompt,
normalization, classification/redaction, harvesting, freshness, selection, and rendering
Rules. It never stores a mutable “latest Rule” reference.

## Frozen Rules and Instantiation

Task 15.60.c SHALL implement these semantic Rule contracts through normal V4 identity,
variant, and state registration. This ADR allocates stable contract codes, not GUIDs or
rows.

| Code | Pure responsibility |
| --- | --- |
| `CS-R01-source-identity-v1` | Resolve a registered Repository root, validate the ordinal repository-relative path, and produce exact source identity. |
| `CS-R02-content-normalization-v1` | Record byte metadata and produce the normalized LF/BOM-excluded SHA-256 without changing source bytes. |
| `CS-R03-classification-redaction-v1` | Decide admitted, redacted, or excluded before model egress and storage; produce only non-secret evidence. |
| `CS-R04-summary-render-v1` | Generate one safe ContentSummaryVersion from one exact SourceArtifactVersion and exact prompt/generator provenance. |
| `CS-R05-freshness-v1` | Evaluate current, stale, excluded, retired, or unknown from source/dependency/policy watermarks. |
| `CS-R06-query-ranking-v1` | Apply authorization-filtered Tag matching, freshness selection, deterministic rank, limit, and truncation metadata. |

`CS-I01-contentsummary-initial-v1` is the one initial Instantiation. It binds exact active
variants of CS-R01 through CS-R06, the classification policy, the permitted generator
and model fingerprint, the Tag traversal contract, and the response-envelope version.
Changing any material binding creates a new Instantiation or RuleVariant; it never
rewrites the old binding.

## Security and ordering decision

The mandatory order is:

1. authenticate and authorize the caller;
2. validate version, size, fields, limits, and idempotency identity;
3. durably capture submitted Tags through the V00060 boundary for an accepted POST;
4. resolve only authorized Repository/source scope;
5. classify, exclude, and redact locally before any model egress;
6. verify that redaction output contains no secret canary or prohibited material;
7. harvest and summarize append-only with exact provenance;
8. filter authorized summaries before Tag traversal, matching, ranking, counts, and
   truncation; and
9. return either an explicit authorized-empty envelope or complete authorized items.

Rejected requests write nothing. Unauthorized content never influences match counts,
rank, truncation, or empty/non-empty distinctions. A missing result remains missing; no
caller, harvester, transport, or compatibility agent fabricates content.

## Raw content, redaction, and provenance

The first central slice stores no raw repository bytes and no unredacted source text.
The Outpost may retain only fields admitted by its local classification policy. Central
source observations store identity, hashes, byte/encoding facts, and non-secret
harvester evidence. A summarized version stores approved safe text or a safe locator and
its content hash. An excluded version stores policy/evidence and no excluded text.

“Preserve the original raw record” in the earlier V4-2 text means the admitted immutable
input envelope and its hash, not unrestricted source bytes. Normalized projection never
overwrites that admitted envelope.

## Idempotency and deterministic harvesting

One delivery attempt carries a stable idempotency key. The canonical request hash binds
the ordered admitted envelope. Replaying the same key and hash returns the existing
result; the same key with a different hash is `CS-IDEMP-001` and creates no effect.

The derivation fingerprint binds RepositoryId, ordinal path, exact
SourceArtifactVersion, byte and normalized hashes, all RuleVariant IDs, classification
policy, prompt identity, generator/model/version, dependency fingerprint, and
Instantiation ID. Exact replay creates no duplicate effect. A separate observation or
different provenance remains a distinct append-only fact even when content hashes match.

Candidate paths are processed in `Latin1_General_100_BIN2`/ordinal order after root
resolution. Within a source, dependency ordinal is explicit. Parallel execution may not
change persisted identities, order, hashes, lifecycle outcome, or query results.

## Freshness

A summary is current only when its exact source version, every dependency version,
classification policy, prompt/render RuleVariant, generator/model contract, and
Instantiation binding remain the selected eligible inputs at the query as-of watermark.
Any newer eligible input or a watermark gap yields `stale`; inability to prove freshness
yields `unknown`. Default retrieval returns only `current`. Stale results require an
explicit authorized mode and are labeled; unknown is never silently served as current.

## Tags decision

ContentSummary is the first named consumer after V00090, but it does not demonstrate a
need for assignment confidence/relevance. Deterministic ranking uses Rule evidence,
freshness, traversal evidence, and stable identity, so confidence remains omitted under
C-27.

Task 15.60.c may add one forward-only `content-summary-version` entry to
`TagAssignmentEntityType`, targeting the authoritative ContentSummaryVersion table.
Assignments remain classification-only, use durable TagId endpoints, resolve TagState
as-of, carry required provenance, and never grant capability.

## Forward-only implementation sequence

1. Task 15.60.c reruns collision and predecessor inventory and allocates the next unused
   Flyway version greater than V00090. V00100 is only the expected candidate if still
   unused; this ADR does not reserve it or create a filename.
2. That migration adds the authoritative source/summary/dependency objects, exact Rule/
   Instantiation registrations, `content-summary-version` Tag assignment type, supporting
   constraints, and deterministic fixtures. It must preserve V00030, V00060, and V00090.
3. Task 15.60.d composes V00090 bounded traversal with the parameterized authorized
   ContentSummary query boundary. It does not invent a second traversal algorithm.
4. Task 15.60.e exposes REST and DAB/MCP read-only transports over that one authorized
   query layer. V00060 capture precedes query for accepted REST POSTs.
5. Task 15.60.f removes only the stub behavior behind the current agent and PowerShell
   interfaces and proves real retrieval, explicit empty, and no fabrication.

The synthetic unknown migration fixture is V01000, not a near-head value.

## Consequences and stop conditions

- Append-only provenance costs storage and more joins but makes freshness and replay
  auditable.
- Source bytes stay local unless a later separately ratified classification/retention
  decision admits them.
- Any unresolved identity, RuleVariant, policy, generator, authorization, source-root,
  migration collision, or live-target discrepancy stops implementation.
- Applied migrations are repaired only by a new forward migration.
- This ADR authorizes design and tests only. Package, feed, BuildMaster, database, host,
  service, and higher-tier actions require their own scoped work.
