# RPRRSBSI-V4-2 ContentSummary Data Contract

Status: Frozen logical and interface contract for Sprint 0015 Tasks 15.60.b-.f.
Physical DDL, GUIDs, the next Flyway number, package version, deployment, and live values
remain Task 15.60.c or later work.

## Authority and precedence

This contract implements, in descending precedence:

1. the ratified RPRRSBSI V4 identity, RuleVariant, ownership, history, and Tags decisions;
2. REST-D02 and Decision Register D-19 for the existing gather-content POST and public
   PowerShell ownership;
3. [ADR-190](../../SolutionDocumentation/RRSBS-ADR-190-ContentSummary-Reconciliation.md);
4. [RDB-260](RRSBS-RDB-260-Context-SourceArtifact-AgentText-ContentSummary-Logical-Model.md);
5. the deployed [V4-2 Tags contract](RPRRSBSI-V4-2-30-Tags-Expert-System.md) and frozen
   traversal contract.

The two non-migration authority inputs were reviewed at these exact SHA-256 values:

| Authority input | SHA-256 |
| --- | --- |
| `RPRRSBSI-V4-2-30-Tags-Expert-System.md` | `DC3D40115FCB6A33DC01177E39C5E677177BE72AC1D3083FD21B0D91829AF10F` |
| `RRSBS-RDB-260-Context-SourceArtifact-AgentText-ContentSummary-Logical-Model.md` | `7E0DFB088195BC03D8F6219E43F3D85B1B257305FBBE058BE53ADEC2C0F6C86C` |

Where older text conflicts, this contract controls Task 15.60 implementation. In
particular:

- REST-D02 supersedes REST-D01: an accepted authorized POST first records submitted Tags
  through the V00060 Ace boundary and then returns the authorized query response.
- `ATAPUtilities` owns the reusable ContentSummary source/version/provenance model. Ace
  owns submission provenance and may own a projection, not the authoritative summary.
- conceptual RDB-260 `RuleVersion` references are exact V4 `RuleVariantId` plus applicable
  `RuleVariantState`/as-of evidence.
- raw-record preservation means the admitted immutable envelope, not unrestricted source
  bytes.

## Historical and deployed boundaries

| Boundary | Frozen behavior |
| --- | --- |
| V00030 | SHA-256 `98C0018A4A92A1A8095CA329D93706A4B426016C1C42B69BC3F7CFB865B38179`; historical prototype only. Do not read, extend, rename, backfill, or delete its table. |
| V00060 | SHA-256 `953705FEE9678B532FFF52D780182AA8A7EF3D000DB96873DB9EB58AAAEB46FB`; preserve accepted-POST Tag capture, ordered spelling, request hash, and idempotency. Its direct current-Tag query is transitional. |
| V00090 | SHA-256 `34A0EC2A1CE485BECBC0497BD4A726BFEC45CD2DBA7D39E26A753A8A6C594DEB`; consume durable Tags, as-of states, typed traversal edges, and classification-only assignments without editing the migration. |

The current migration head is V00090. Task 15.60.c allocates the next unused version
greater than V00090 after a fresh collision inventory. V00100 is an expectation only if
still unused; it is not reserved here. V01000 is the synthetic unknown-version fixture.

## Existing public request and response envelope

Task 15.60.f SHALL preserve the public PowerShell parameters:

`Tags`, `Depth`, `Width`, `Instance`, `Scheme`, `HostName`, `Port`, `Path`, `AgentName`,
`WorktreeRoot`, `TaskId`, and `Prompt`.

The REST request body remains exactly:

```json
{
  "tags": ["schema", "migration"],
  "depth": 3,
  "width": 2,
  "instance": "production"
}
```

`Idempotency-Key` is one canonical lowercase dashed GUID in the header. The current body
contains no prompt and SHALL NOT be widened in Tasks 15.60.c-.f. `Prompt` remains local
recorder input behind its existing redaction boundary.

The public response envelope remains:

```text
agent, status, query, items, truncated, error
```

`status=ok` with `items=[]`, `truncated=false`, and `error=null` is the only successful
empty result. Transport failure uses `status=Error`, no items, and a stable safe error.
No layer substitutes fixture, cached, guessed, or generated text for an empty result.

## Frozen Rules and Instantiation

Task 15.60.c SHALL register semantic identities for these codes and implement exact
immutable variants. GUID allocation occurs only in that implementation task.

| Rule contract code | Required inputs | Required output and effect |
| --- | --- | --- |
| `CS-R01-source-identity-v1` | registered root, RepositoryId, candidate locator | one canonical ordinal repository-relative path or a controlled error; no implicit Repository |
| `CS-R02-content-normalization-v1` | exact bytes, encoding/BOM facts | byte hash, normalized LF/BOM-excluded hash, byte count, encoding and line-ending facts; no byte rewrite |
| `CS-R03-classification-redaction-v1` | source identity/version, classification policy, local content | `admitted`, `redacted`, or `excluded` plus non-secret evidence; model egress is permitted only for admitted/redacted output |
| `CS-R04-summary-render-v1` | exact source version, safe content/locator, exact prompt RuleVariant, generator/model identity | one complete safe summary derivation or one controlled failure; never partial success |
| `CS-R05-freshness-v1` | source/dependency/policy/prompt/generator/Instantiation watermarks at as-of | `current`, `stale`, `excluded`, `retired`, or `unknown` with non-secret reason |
| `CS-R06-query-ranking-v1` | authorized candidate set, requested/resolved Tags, freshness mode, limit | deterministic authorized order, rank evidence, authorized counts, and truncation |

`CS-I01-contentsummary-initial-v1` binds exact active variants of CS-R01 through CS-R06,
classification policy, prompt identity, generator/model fingerprint, the V00090 traversal
contract, and envelope version 1. A material binding change creates a new Instantiation
or RuleVariant. Display-only history follows the V4 D-3 rulings and never mutates a
binding in place.

## Harvest input contract

The scheduled/manual adapter supplies one versioned envelope:

| Field | Type and rule |
| --- | --- |
| `envelopeVersion` | integer, exactly `1` |
| `runId` | canonical GUID; identifies one lease/checkpointed observation run |
| `idempotencyKey` | canonical GUID; stable across delivery retry |
| `repositoryId` | canonical GUID already registered by authorized scope |
| `rootRegistrationId` | canonical GUID; active and unambiguous at observation time |
| `repoRelativePath` | nonempty forward-slash ordinal path; unrooted, no `.`/`..`, backslash, empty segment, control, or physical root |
| `observedAtUtc` | UTC `datetime2(7)` value supplied by the observation |
| `byteSha256` | lowercase 64-hex hash of exact bytes |
| `normalizedContentSha256` | lowercase 64-hex SHA-256 after BOM exclusion and CRLF/CR normalization to LF |
| `byteCount` | nonnegative 64-bit count |
| `encodingCode` | controlled code; unknown encoding fails closed |
| `lineEndingCode` | `lf`, `crlf`, `cr`, `mixed`, or `none` |
| `finalNewline` | boolean |
| `harvesterEntityId` | canonical GUID |
| `ruleVariantIds` | exact CS-R01 through CS-R06 variant IDs |
| `instantiationId` | exact CS-I01 identity |
| `classificationPolicyId` | exact immutable policy identity |
| `promptRuleVariantId` | exact immutable prompt RuleVariant |
| `generator` | controlled kind/name/version and model provider/id/revision/effort; no credential |
| `dependencies` | ordered typed exact SourceArtifactVersion or controlled external references |
| `safeSummaryText` / `safeLocator` | exactly one for summarized output after redaction; neither for excluded/failure |

Input field order is not semantic. Candidate processing order is canonical
`repoRelativePath` under `Latin1_General_100_BIN2`/ordinal comparison, then byte hash,
then run ID. Dependency order is its explicit ordinal.

## Canonical hashes and idempotency

The canonical request hash is SHA-256 over the UTF-8, no-BOM canonical JSON form of the
admitted envelope. Object members use the order above; dependency rows use ordinal;
timestamps use seven-digit UTC `Z`; GUIDs use lowercase dashed `D`; hashes use lowercase
hex. No locale-dependent formatting is permitted.

The derivation fingerprint is SHA-256 over UTF-8 fields separated by U+001F in this
order:

```text
repositoryId
repoRelativePath
sourceArtifactVersionId
byteSha256
normalizedContentSha256
CS-R01 RuleVariantId
CS-R02 RuleVariantId
CS-R03 RuleVariantId
CS-R04 RuleVariantId
CS-R05 RuleVariantId
CS-R06 RuleVariantId
classificationPolicyId
promptRuleVariantId
generatorKind/name/version/modelProvider/modelId/modelRevision/modelEffort
dependencyFingerprint
instantiationId
```

Same idempotency key plus same canonical request hash returns the original durable result
and creates no new rows. Same key plus different hash is `CS-IDEMP-001` and creates no
effect. A new observation run is distinct provenance even when hashes match. Hash
equality never collapses observation facts whose run, harvester, root registration, or
provenance differs.

## Logical storage contract for Task 15.60.c

Task 15.60.c SHALL add only the minimum authoritative objects below, using native GUIDs,
binary hashes, explicit collations, immutable provenance, and append-only enforcement.

| Logical object | Required key and content |
| --- | --- |
| `Repository` | immutable Entity/Philote-backed RepositoryId; Organization reference; ordinal canonical name; no worktree path in identity |
| `RepositoryRootRegistration` | root-registration ID, RepositoryId, normalized absolute discovery root, root kind, registration/retirement facts and registrar evidence; one active root maps to one Repository |
| `SourceArtifact` | Entity/Philote-backed SourceArtifactId, RepositoryId, locator kind and ordinal repository-relative path; unique repository/path identity |
| `SourceArtifactVersion` | SourceArtifactVersionId, SourceArtifactId, append-only sequence, run/root/harvester provenance, exact/normalized hashes, bytes/encoding/newline facts, observed and recorded UTC |
| `ContentSummary` | Entity/Philote-backed ContentSummaryId, SourceArtifactId, summary profile, classification-policy identity, created/retired facts; unique subject/profile/policy |
| `ContentSummaryVersion` | ContentSummaryVersionId, ContentSummaryId, exact SourceArtifactVersionId, sequence, lifecycle, exact RuleVariant/Instantiation/generator/model provenance, safe text xor safe locator or exclusion evidence, summary hash, generated/recorded UTC, derivation fingerprint |
| `ContentSummaryDependency` | summary version, dependency ordinal/kind, exactly one exact SourceArtifactVersion or controlled external reference, captured UTC and evidence identity |
| `ContentSummaryRefreshAttempt` | append-only attempt/checkpoint, requested/started/completed UTC, result, optional produced version, controlled error code, non-secret diagnostic hash |

Every durable object carries required actor/source/occurred/recorded provenance consistent
with V4. Versions, dependencies, attempts, and lifecycle transitions are inserts only.
`summarized`, `excluded`, `stale`, and `retired` are new ContentSummaryVersion facts, not
updates to an earlier row.

The first migration does not add AgentText persistence, raw source blobs, tenant columns,
localization, confidence/relevance, prompt text, credentials, users, logins, broad table
grants, or automatic Rule publication.

## Lifecycle and freshness

`LifecycleCode` is one of `harvested`, `summarized`, `stale`, `excluded`, or `retired`.

- `harvested` proves eligible discovery and exact source observation; it has no summary
  text.
- `summarized` requires safe text xor safe locator, its SHA-256, exact prompt/generator/
  model/policy/Instantiation provenance, and no exclusion finding.
- `excluded` requires policy/evidence and contains no source or excluded text.
- `stale` references the prior summary version and the first invalidating source,
  dependency, policy, prompt, generator, or Instantiation watermark.
- `retired` closes future selection and preserves all earlier versions.

Freshness is `current` only when all bound exact inputs remain selected at `AsOfUtc` and
no newer eligible source/dependency/policy/binding exists. Any newer input is `stale`; an
unprovable watermark is `unknown`. Default query mode is `CurrentOnly`. `IncludeStale`
requires explicit authorization and labels every returned state. `unknown` is excluded
from both modes and returned only through administrative diagnostics.

## Redaction and authorization order

For ingestion:

1. authenticate and authorize caller/device/Repository scope;
2. validate envelope, limits, canonical identities, hashes, and idempotency;
3. persist accepted V00060 submitted-Tag provenance when invoked through REST-D02;
4. resolve the registered source root;
5. classify and redact locally;
6. scan the redacted candidate for synthetic and real secret indicators;
7. only then permit model egress and append-only ContentSummary persistence.

For query:

1. authenticate and authorize Repository/summary scope;
2. resolve requested Tags as-of;
3. traverse only the authorized Tag graph;
4. match only authorized ContentSummaryVersion assignments;
5. evaluate freshness;
6. rank, count, truncate, and serialize.

An unauthorized row cannot affect counts, ranks, traversal width, truncation, timing-
visible completeness, or the empty/non-empty result. Diagnostics store stable codes and
non-secret hashes only.

## Tags and query composition

Task 15.60.c adds one `TagAssignmentEntityType` row:

```text
EntityTypeCode: content-summary-version
TargetSchemaName: ATAPUtilities
TargetTableName: ContentSummaryVersion
TargetIdColumnName: ContentSummaryVersionId
IsClassificationOnly: 1
```

It does not add confidence/relevance. V00090 assignments remain provenance-bearing and
classification-only. Tags never grant read access.

Task 15.60.d SHALL reuse the frozen Tags traversal algorithm and
`QueryTagLogicalEdgesAsOf`; it SHALL NOT implement a conflicting traversal. It resolves
requested Tag codes to durable TagIds at one `AsOfUtc`, applies the frozen depth, width,
cycle, role, weight, ordering, duplicate-path, timeout, and truncation rules, then passes
only authorization-filtered matches to the ContentSummary candidate query.

### Exact SQL input types

`[ATAPUtilities].[ContentSummaryAuthorizedRepositoryInput]`:

```text
RepositoryId uniqueidentifier PRIMARY KEY
```

`[ATAPUtilities].[ContentSummaryTagMatchInput]`:

```text
RequestOrdinal tinyint NOT NULL
RequestedTagId uniqueidentifier NOT NULL
MatchedTagId uniqueidentifier NOT NULL
Depth tinyint NOT NULL
TraversalOrdinal int NOT NULL
PathWeight decimal(19,12) NOT NULL
PRIMARY KEY (RequestOrdinal, MatchedTagId, Depth, TraversalOrdinal)
```

### Exact candidate query signature

```text
[ATAPUtilities].[QueryContentSummaryCandidatesAsOfV1]
  @AuthorizedRepositories ContentSummaryAuthorizedRepositoryInput READONLY
  @TagMatches ContentSummaryTagMatchInput READONLY
  @MatchMode varchar(3)              -- Any | All
  @AsOfUtc datetime2(7)
  @FreshnessMode varchar(16)         -- CurrentOnly | IncludeStale
  @Limit int                         -- 1..100
```

The procedure returns two result sets. Metadata columns, in order:

```text
AsOfUtc, MatchMode, FreshnessMode, AuthorizedMatchCount, ReturnedCount,
Truncated, RankingContractCode, WatermarkUtc
```

Item columns, in order:

```text
ContentSummaryVersionId, ContentSummaryId, SourceArtifactId,
SourceArtifactVersionId, RepositoryId, RepoRelativePath, SafeText, SafeLocator,
MatchedRequestedTagIdsJson, MatchedResolvedTagIdsJson, FreshnessCode,
RankingContractCode, Rank, SourceObservedAtUtc, GeneratedAtUtc, RecordedAtUtc,
ProducerEntityId, NormalizedContentSha256, SummaryContentSha256,
DerivationFingerprint
```

Ranking contract `content-summary-rank-v1` orders:

1. number of distinct requested Tags matched descending;
2. minimum traversal depth ascending;
3. maximum path weight descending;
4. SourceArtifact `RepoRelativePath` under `Latin1_General_100_BIN2` ascending;
5. `ContentSummaryVersionId` by `CONVERT(binary(16), id)` ascending.

`All` requires every distinct requested Tag ordinal. `Any` requires at least one.
AuthorizedMatchCount is computed after authorization and freshness filtering. Truncated
is true only when that count exceeds Limit.

## Transport boundary for Task 15.60.e

REST and DAB/MCP are adapters over the same authorized query service. They do not query
tables independently. REST keeps POST `/api/v1/gather-content`, loopback HTTPS, ambient
Windows authentication, current request fields, V00060 submitted-Tag capture, and the
stable public envelope. DAB/MCP is read-only and does not perform V00060 capture; it
requires equivalent caller authorization and returns the same item semantics.

The server selects one receipt `AsOfUtc`, default `CurrentOnly`, `Any` match mode, limit
derived from the existing width/depth contract but never above 100, and the allowed
relation-role set for envelope version 1. These defaults preserve the current public
PowerShell interface.

## Error taxonomy

| Code | Meaning and required effect |
| --- | --- |
| `CS-REQ-001` | unsupported envelope/version/field/size/limit; 400; no write |
| `CS-AUTH-001` | unauthenticated; 401; no request detail or write |
| `CS-AUTH-002` | authenticated but unauthorized; 403; no match/count disclosure or write |
| `CS-SRC-001` | missing or ambiguous root/Repository registration; 422; no implicit identity |
| `CS-SRC-002` | invalid/noncanonical locator or path; 422; no source row |
| `CS-HASH-001` | supplied byte/normalized hash mismatch; 422; no derived row |
| `CS-IDEMP-001` | idempotency key bound to different canonical hash; 409; no new effect |
| `CS-CLASS-001` | content excluded by policy; record exclusion fact, no source text/model call |
| `CS-CLASS-002` | redaction or secret-canary verification failed; 422; no model call/summary |
| `CS-RULE-001` | missing/inactive/mismatched RuleVariant or Instantiation; 409; no derivation |
| `CS-HARVEST-001` | source unavailable/changed during read; retryable 503; incomplete attempt only |
| `CS-SUMMARY-001` | generator/model failed or incomplete; retryable 503; no summarized version |
| `CS-FRESH-001` | requested freshness cannot be proven; 409 or explicit empty by public mode |
| `CS-QUERY-001` | requested Tag unresolved/ambiguous/invalid as-of; 422; no partial result |
| `CS-QUERY-002` | query traversal/limit contract invalid; 400; no query execution |
| `CS-QUERY-003` | cancellation or timeout; 504; no partial items/counts |
| `CS-INTERNAL-001` | unexpected internal failure; 500 with correlation ID and safe message only |

An empty authorized result is not an error. Unsupported provider metrics or absent
content remain unavailable, never zero or fabricated.

## Fixture-bindable acceptance matrix

| ID | Required deterministic proof |
| --- | --- |
| `CS-A01` | V00030/V00060 hashes remain exact and neither object is reused as the new model. |
| `CS-A02` | same key/hash replay creates no duplicate; same key/different hash returns `CS-IDEMP-001` with no effect. |
| `CS-A03` | LF/CRLF normalization produces the required normalized hash while exact byte hashes differ; distinct observations remain distinct provenance. |
| `CS-A04` | rooted, backslash, traversal, empty-segment, control, and ordinal-case-collision paths fail closed. |
| `CS-A05` | no/ambiguous root registration creates no implicit Repository or artifact. |
| `CS-A06` | secret canary is excluded or redacted before model invocation and never appears in evidence, summary, response, or logs. |
| `CS-A07` | generator failure records an incomplete attempt and no summarized version. |
| `CS-A08` | newer source/dependency/policy/prompt/generator/Instantiation input makes the prior summary stale; unknown never appears current. |
| `CS-A09` | authorization precedes traversal, matching, ranking, counts, truncation, and empty-result selection. |
| `CS-A10` | Any/All, bounded traversal, cycle/path/weight behavior, rank, and truncation are stable under input and processing reordering. |
| `CS-A11` | accepted REST POST captures V00060 submitted Tags before query; rejected/unauthorized request writes nothing. |
| `CS-A12` | crash at every lease/observation/local-commit/central-commit/ack checkpoint resumes without duplicate or false success. |
| `CS-A13` | query procedure metadata and item column ordinals match this contract exactly. |
| `CS-A14` | `content-summary-version` assignment is classification-only, resolves TagState as-of, and cannot authorize. |
| `CS-A15` | real authorized empty returns `ok`, empty items, not truncated, null error; agent and PowerShell layers do not fabricate. |
| `CS-A16` | V01000 is rejected as unknown while the next migration allocator remains uncommitted until Task 15.60.c. |

## Follow-on task signatures

| Task | Exact input | Required output |
| --- | --- | --- |
| 15.60.c | this contract, fixture manifest, V00090 deployed predecessor | next-unused forward migration; authoritative objects; six Rule contracts and CS-I01 identities; deterministic loader/harvester; fresh/upgrade/negative/recovery tests; no edits to V00030/V00060/V00090 |
| 15.60.d | deployed 15.60.c objects plus frozen Tags traversal | the two TVPs and `QueryContentSummaryCandidatesAsOfV1`; one composed authorized traversal/query service; exact result ordinals and CS-A08-.A10/.A13/.A14 evidence |
| 15.60.e | one 15.60.d query service plus V00060 capture | loopback REST and read-only DAB/MCP adapters with identical authorization/result semantics; no table-specific alternate path |
| 15.60.f | current public `Get-ContentSummary` parameters/envelope | remove stub-only behavior without interface change; prove real retrieval, explicit authorized empty, transport failure, mandatory recording, and no fabrication |

## Exclusions

This contract does not allocate a GUID, physical migration filename, package version,
port, certificate, secret, user, role membership, deployment, or live value. It does not
authorize writing Ace/SharedVSCode/Planning, modifying the AceCommander host, invoking a
model, scanning a real repository, publishing a package, or changing a live database.
