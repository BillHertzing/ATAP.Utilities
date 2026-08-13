# RDB-260 — Context, SourceArtifact, AgentText, and ContentSummary Logical Model

Status: Wave 3 design-only contract. No SQL, migrations, seed data, package,
feed, live-tier, scanner, renderer, filesystem, or AceCommander changes are
authorized by this document.

## Purpose and boundary

This slice realizes the context, source-provenance, agent-facing projection, and
ContentSummary contracts already approved by
[RDB-147](../../SolutionDocumentation/RRSBS-ADR-147-SourceArtifact-and-Path-Identity.md)
and
[RDB-190](../../SolutionDocumentation/RRSBS-ADR-190-ContentSummary-Reconciliation.md).
It supplies a durable, append-only account of a source artifact's identity and
observed bytes, then derives versioned ContentSummary and AgentText read models
without creating a second source, Rule, Entity, or authorization identity.

RDB-200 remains the authority for Entity identity, attribution, authorization,
and Organization semantics. RDB-210/220 supply exact RuleKindVersion and
RuleVersion identities. RDB-270 closes all cross-slice names, EntityType
allow-lists, and composite FKs; RDB-280 adversarially tests the integrated
model; RDB-460 owns physical SQL and fixtures.

## Decisions

1. `Organization`, `Repository`, `RepositoryRootRegistration`, and
   `SourceModule` form discovery context only. A Repository has one durable
   identity across stable and sprint worktrees; a root registration identifies
   where a scanner may discover it, never a component of source identity.
2. `SourceArtifact` is the durable identity of one controlled locator in one
   Repository. Repository-contained identity is the binary-collated pair
   `(RepositoryId, RepoRelativePath)`; it is forward-slash, unrooted, and
   cannot contain a physical root. External locators use the finite
   RDB-147 locator-type catalog and cannot impersonate repository paths.
3. `SourceArtifactVersion` is append-only observation or authoring provenance.
   It captures normalized and exact-byte hashes, byte and encoding facts,
   harvester identity, and observed time. Equal hashes do not merge rows whose
   observation or provenance differs.
4. `SourceArtifactLineage` records accepted immutable predecessor/successor
   relationships such as rename, move, copy, or supersession. A retirement or
   rename never rekeys, deletes, or silently revives the predecessor.
5. `ContentSummary` is a durable summary subject for one SourceArtifact;
   `ContentSummaryVersion` is its immutable lifecycle/version fact. Each
   version is sourced from exactly one SourceArtifactVersion, records the
   exact prompt RuleVersion and generator/model identity, has a controlled
   lifecycle state, and preserves exclusion/redaction facts without storing
   excluded material.
6. `ContentSummaryDependency` records an ordered, typed dependency from one
   summary version to either an exact SourceArtifactVersion or a controlled
   external reference. It never stores a dependency as an untyped path/string
   alone and cannot point to a future or unrelated summary version.
7. `AgentTextProjection` is a named, policy-scoped projection contract;
   `AgentTextProjectionVersion` is an immutable materialization of that
   contract. A projection version uses source ContentSummaryVersion rows at or
   before its input watermark, records refresh/failure/staleness facts, and
   has no authority to edit source artifacts, summaries, Rules, or policies.
8. Agent-facing text is a derived read model, not a source of truth. It stores
   safe rendered text or a non-secret content hash according to its approved
   classification policy; source bytes, excluded content, resolved SecretNames,
   keys, and credentials do not enter the projection.

## Shared identity and temporal contract

`Organization`, `Repository`, `SourceArtifact`, `ContentSummary`, and
`AgentTextProjection` are RDB-200 Entity subtypes with immutable Philotes.
Registrations, modules, versions, lineage, dependencies, and refresh facts are
typed relations. RDB-270 owns the final EntityType registrations and composite
foreign-key closure.

Every source observation, lineage decision, summary lifecycle transition,
dependency, projection materialization, and refresh outcome is append-only. A
new worktree root, scan, rename acceptance, re-summary, exclusion, correction,
refresh, failure, or retirement creates a linked fact; it never overwrites
historic bytes, provenance, rendered text, or lifecycle evidence.

## Logical tables

### Context and discovery

| Logical table | Key and responsibility |
| --- | --- |
| `Organization` | PK plus immutable Philote; durable organization identity, ordinal normalized name, controlled classification, and retirement lineage. It is not a user, actor, credential, or authorization grant. |
| `Repository` | PK plus immutable Philote; one logical source-control repository; Organization FK; ordinal canonical repository name; optional immutable remote-identity evidence; classification and retirement facts. Unique `(OrganizationId, CanonicalRepositoryName)`. |
| `RepositoryRootRegistration` | PK; one Repository; normalized local absolute discovery root, root kind (`stable`, `sprint`, `mirror`, `scanner-sandbox`), registration/retirement facts, and registrar evidence. A root maps to exactly one active Repository. |
| `SourceModule` | PK; one Repository; binary-collated repository-relative module path, controlled module kind, parent module FK, discovery/retirement facts. Unique `(RepositoryId, ModuleRelativePath)`; module membership is classification, not artifact identity. |

An Organization can own many Repositories, and a Repository can have many
simultaneous worktree registrations. A scanner must resolve its local root to
one active registration before deriving repository-relative source paths. It
fails closed on no match or ambiguous match; it does not infer an Organization,
Repository, or root from a directory name.

### Source identity, observations, and lineage

| Logical table | Key and responsibility |
| --- | --- |
| `SourceArtifact` | PK plus immutable Philote; Repository FK; optional SourceModule FK; locator type; canonical repository-relative path or external locator; creation and retirement facts. A `RepositoryPath` requires the `(RepositoryId, RepoRelativePath)` binary uniqueness contract. |
| `SourceArtifactVersion` | PK; SourceArtifact FK; append-only sequence/observation identity; `NormalizedContentSha256`, optional `ByteSha256`, byte count, encoding, BOM, line-ending/final-newline facts, extraction/harvester identity, and observed UTC. Unique `(SourceArtifactId, VersionSequence)` and provenance fingerprint. |
| `SourceArtifactLineage` | PK; predecessor and successor SourceArtifact FKs; controlled relation kind; accepted-at UTC; accepting Entity/policy evidence; optional proposal evidence. Unique predecessor/successor/relation combination; predecessor and successor differ. |

`SourceArtifactVersion` uses the RDB-147 hash contract: normalized SHA-256 is
lowercase hexadecimal after CRLF-to-LF normalization and BOM exclusion; byte
hash preserves original bytes. Exact-byte consumers require `ByteSha256` and
matching byte metadata. `SourceArtifact` path identity is binary/ordinal and
case-sensitive, even when a local Windows worktree is not.

### ContentSummary lifecycle and dependency provenance

| Logical table | Key and responsibility |
| --- | --- |
| `ContentSummary` | PK plus immutable Philote; exactly one SourceArtifact FK; controlled summary profile/kind and classification-policy version; created/retired facts. Unique `(SourceArtifactId, SummaryProfileCode, ClassificationPolicyVersionId)`. |
| `ContentSummaryVersion` | PK; ContentSummary FK; immutable version sequence; exact SourceArtifactVersion FK; lifecycle state (`harvested`, `summarized`, `stale`, `excluded`, `retired`); prompt RuleVersion FK; generator/model identity; redaction/exclusion policy/evidence; summary hash or approved safe text; generated UTC. Unique `(ContentSummaryId, VersionSequence)`. |
| `ContentSummaryDependency` | PK; dependent ContentSummaryVersion FK; dependency ordinal and controlled dependency kind; exactly one target: SourceArtifactVersion FK or controlled ExternalReference FK; captured UTC and evidence identity. Unique `(ContentSummaryVersionId, DependencyOrdinal)`. |

The source version, prompt RuleVersion, generator/model identity, and policy
are mandatory provenance for every `summarized` version. `harvested` records
eligible discovery before model generation; `excluded` records why content is
not summarized; `stale` records that a newer source/dependency/policy revision
invalidates a prior derived version; `retired` closes future selection without
deleting history. A state change is a new ContentSummaryVersion, not an update.

### AgentText projection refresh and staleness

| Logical table | Key and responsibility |
| --- | --- |
| `AgentTextProjection` | PK plus immutable Philote; named projection contract; consumer class; immutable selection policy version, rendering RuleVersion, classification policy version, and owner Entity/policy reference; created/retired facts. Unique active `(ProjectionName, ConsumerClassCode)`. |
| `AgentTextProjectionVersion` | PK; AgentTextProjection FK; immutable materialization sequence; input ContentSummary watermark UTC and monotonic source-version watermark; rendering RuleVersion FK; selected-summary-set fingerprint; projection content hash or approved safe text; materialization state; generated UTC. Unique `(AgentTextProjectionId, VersionSequence)` and input fingerprint. |
| `AgentTextProjectionRefresh` | PK; one AgentTextProjection; append-only refresh request/attempt sequence; requested/started/completed UTC, requested input watermark, result (`succeeded`, `failed`, `stale-observed`, `superseded`), optional produced projection-version FK, controlled error taxonomy, and non-secret diagnostic hash. Unique `(AgentTextProjectionId, RefreshSequence)`. |

The latest successful projection is selected only when its source watermark and
selection/render/classification policy versions satisfy the consumer's
freshness contract. A newer eligible ContentSummaryVersion, dependency change,
policy change, failed refresh, or watermark gap makes it stale. Staleness is
observed and recorded; it does not silently serve a projection as current or
mutate an older projection version. A failed refresh produces no partial
successful projection version.

## Required constraints

- Context identities are immutable; one active normalized root registration
  maps to one Repository, and a Repository may span stable/sprint roots without
  changing its identity.
- `SourceArtifact` accepts only a closed locator type. `RepositoryPath`
  requires a Repository and a canonical binary-collated relative path; external
  locator types require their corresponding controlled normalizer/evidence.
- Artifact versions, lineage edges, summary versions/dependencies, projection
  versions, and refresh facts are append-only. Hash equality cannot merge
  provenance-distinct versions or create a lineage edge.
- A lineage edge cannot self-reference, overwrite a predecessor, cross an
  incompatible Repository without a controlled cross-repository relation, or
  make a retired path active without an explicit new identity decision.
- A ContentSummaryVersion must share its ContentSummary's SourceArtifact,
  reference an exact source version of that artifact, use an approved prompt
  RuleVersion/model/policy, and have one controlled lifecycle state.
- `summarized` requires approved safe rendered content or a summary hash,
  prompt/model provenance, and no exclusion finding; `excluded` requires an
  exclusion policy/evidence and must not carry excluded text; `stale` and
  `retired` preserve the prior version they supersede/close.
- A summary dependency has exactly one typed target, cannot use a free-form
  locator, and cannot target a future version or a version disallowed by the
  summary's classification policy.
- A projection version uses only source summary versions no later than its
  declared watermark and records exact selection, rendering, and classification
  policy versions. It cannot claim freshness beyond its input watermark.
- A refresh result is controlled; only `succeeded` references one complete
  projection version. Failure/staleness diagnostics are non-secret and do not
  alter any previously materialized version.

## EntityType registrations

This slice reserves semantic codes only: `organization`, `repository`,
`source-artifact`, `content-summary`, and `agent-text-projection`. Numeric
identifiers, GUID allocation, physical names, extended properties, indexes, and
seed rows remain RDB-320/RDB-460/RDB-500 work.

## Relational counterexamples

RDB-280/RDB-460 must reject each of the following:

1. A stable and sprint worktree create distinct Repository identities, or one active normalized root belongs to two Repositories.
2. An unmatched/ambiguous root causes implicit Organization, Repository, or root registration, or an absolute root enters SourceArtifact identity.
3. A repository path is rooted, contains backslashes, traversal, empty segments, controls, ordinal-case/Unicode collisions, or is stored as an external locator.
4. An external URI receives Windows-path normalization, an unknown locator type/scheme is accepted, or an opaque reference hides a RepositoryPath.
5. A new observation rewrites/deletes an artifact version; equal hashes collapse distinct observation/harvester facts; or an exact-byte consumer accepts only normalized hash data.
6. A rename/move overwrites or rekeys an old artifact, a self/cross-repository lineage edge lacks controlled evidence, or a retired artifact silently revives.
7. A ContentSummaryVersion references another artifact's version, a mutable/latest RuleVersion alias, no generator/model identity, no policy, or a free-form source path.
8. A summary embeds excluded material, a secret/key/resolved SecretName, or treats `excluded`/`stale`/`retired` as an in-place update.
9. A dependency is an untyped string, has both/neither target, targets a future/foreign forbidden version, or omits its ordinal/type/evidence.
10. A projection claims a watermark beyond its selected summary versions, changes selection/render/policy in place, or exposes source bytes/excluded material in AgentText.
11. A failed/partial refresh creates a successful projection version, marks an older projection current despite a watermark/policy gap, or records secret-bearing diagnostics.
12. Any context, artifact, summary, dependency, projection, or refresh history is updated/deleted to hide a scan, exclusion, stale state, failure, or retirement fact.

## Integration obligations and deferred work

RDB-200 supplies Entity, attribution, classification, and authorization
identities; RDB-210/220 supply immutable prompt and renderer RuleVersion
references; RDB-240/250 may consume artifacts or projections only through exact
version provenance. RDB-270 owns final EntityType, external-reference,
generator/model, policy, and cross-slice FK closure. RDB-280/RDB-460 convert
these counterexamples into invalid-row fixtures and physical enforcement.
RDB-640/RDB-650 own projection consumers and their tests.

This slice does not allocate IDs/GUIDs, move parked ContentSummary drafts,
create migrations, scan real repositories, generate summaries, invoke a model,
resolve secrets, refresh agent text, mutate a worktree, publish a package, or
access a live tier.
