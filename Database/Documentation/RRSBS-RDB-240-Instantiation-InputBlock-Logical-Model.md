# RDB-240 — Instantiation, InputBlock, and Authorization Logical Model

Status: Wave 3 design-only contract. No SQL, migrations, seed data, package,
feed, live-tier, or AceCommander changes are authorized by this document.

## Purpose and boundary

This slice defines the durable editable Instantiation surface and the immutable
input snapshots selected at publication. It resolves OCC-01 by separating three
identities which prior designs conflated:

1. a deterministic occurrence in an exact `BuildSetVersion` graph;
2. a durable, editable binding scope owned by one `Instantiation`; and
3. an immutable `InstantiationVersion` selection of exact
   `InputBlockVersion` snapshots.

It also defines source/fork lineage, permission records for the complete verb
set, and an EditSession boundary. It consumes RuleSet/BuildSet member paths as
external RDB-230 contracts; it neither changes their model nor assigns their
numeric identifiers. RDB-250 owns plans, approvals, execution, and observed
artifacts. RDB-270 closes cross-slice FK and EntityType policy; RDB-280/RDB-440
own executable invalid-row proof and physical enforcement.

## Decisions

1. `Instantiation` is a durable, independently owned customization identity.
   It has one immutable owner authority reference and may fork an exact source
   `InstantiationVersion`; a fork receives a new Philote and never mutates or
   reuses the source identity.
2. `InstantiationVersion` is an immutable published snapshot of exactly one
   `BuildSetVersion`. It has monotonic per-Instantiation revision sequence,
   one predecessor at most, one successor at most, UTC publication time, and
   a graph-and-input content hash. It has no mutable draft/current flag.
3. `BuildSetRuleOccurrence` is the deterministic, immutable occurrence path
   through exact BuildSet member, RuleSet member, and RuleVersion member
   identities. Its stable `OccurrenceKey` is derived from those member
   Philotes/identities and is unique within an exact BuildSetVersion. The same
   RuleVersion may therefore occur repeatedly without collapsing bindings.
4. `InstantiationOccurrenceBinding` is the durable editable scope, owned by
   exactly one Instantiation and mapped to exactly one compatible occurrence.
   Its candidate key `(InstantiationId, OccurrenceKey)` prevents duplicate
   scopes for the same occurrence while allowing the same RuleVersion in two
   distinct occurrences.
5. `InputBlock` is one durable editable block for one binding. Its
   `InputBlockVersion` rows are immutable session-produced snapshots. An
   `InputValue` belongs to one exact InputBlockVersion and one declared
   `RuleInputDefinition`; it uses RDB-130 typed scalar/validated DTO storage,
   never untyped text/JSON or resolved secret material.
6. Publication (`RollItUp`) atomically selects exactly one compatible
   InputBlockVersion for every required binding into
   `InstantiationVersionInputBlock`. The composite FK proves the selected
   snapshot belongs to the same Instantiation and exact binding/occurrence.
   It also copies/resolves applicable Rule defaults so later default changes
   cannot alter an already published version.
7. A successor BuildSetVersion is compared by deterministic occurrence key.
   Compatible unchanged occurrences may carry a binding forward; an added,
   removed, duplicated, or RuleVersion-incompatible occurrence requires a
   recorded `BindingResolution` of `carry-forward`, `map`, `default`, or
   `remove`. Publication fails closed while a required resolution is absent.
8. Authorization is append-only, authority-scoped, and verb-specific. The
   supported verb catalog is `view`, `edit`, `publish`, `fork`, `plan`,
   `execute`, `approve`, and `read-artifacts`. The record stores opaque
   external authority/tenant/session identifiers rather than FKs into
   AceCommander. Current authorization evaluation, inheritance and deny/allow
   precedence are versioned contract inputs; historical grants/revocations are
   never rewritten. The future AceCommander catalog-rationalization plan owns
   its user/session and tenant implementation.
9. `EditSession` is a mutable, short-lived authoring transaction boundary,
   not a published version. It has an optimistic-concurrency token and closed
   / abandoned / published terminal state. Only one successful session may
   publish a particular successor revision; publication records the exact
   session but does not expose session state as an immutable model property.

## Shared Entity and version contract

`Instantiation`, `InstantiationVersion`, `InputBlock`, and
`InputBlockVersion` are RDB-200 Entity subtypes with table-specific immutable
Philotes. `BuildSetRuleOccurrence`, bindings, selection rows, grants,
resolutions, sessions, and values are typed relations, not generic Entity
endpoints. RDB-270 owns final EntityType catalogue/allow-list closure.

All immutable version rows use the approved TM-01 pattern: unique revision
sequence within their durable parent, same-parent predecessor, direct
successor uniqueness, immutable UTC publication timestamp, and immutable
content hash. An editable durable object is never made immutable by attaching
it directly to an InstantiationVersion.

## Logical tables

### Instantiation identity and occurrence projection

| Logical table | Key and responsibility |
| --- | --- |
| `Instantiation` | `InstantiationId` PK; immutable `InstantiationPhiloteId`; one `OwnerAuthorityReference`; optional exact `ForkedFromInstantiationVersionId`; immutable creation metadata. |
| `InstantiationVersion` | PK plus Entity Philote; `(InstantiationId, RevisionSequence)` unique; exact `BuildSetVersionId`; same-Instantiation predecessor; graph/input hash and immutable `PublishedAtUtc`. |
| `BuildSetRuleOccurrence` | PK; exact `BuildSetVersionId`, BuildSet-member, RuleSet-member, and RuleVersion-member identities; exact `RuleVersionId`; deterministic `OccurrenceKey`; unique `(BuildSetVersionId, OccurrenceKey)`. |
| `InstantiationOccurrenceBinding` | PK; `InstantiationId`, exact BuildSetVersion and occurrence key, `BindingCompatibilityContractVersionId`; unique `(InstantiationId, OccurrenceKey)`. |
| `BindingResolution` | Immutable decision for a successor binding: predecessor binding/occurrence, successor occurrence, controlled resolution verb, selected target/default/map evidence, deciding authority, and decision time. |

The occurrence path includes member occurrences rather than only child version
IDs. A `RuleVersion` that appears twice therefore produces two different
OccurrenceKeys. The stored key is verified against the member-path derivation
at publication; it is never a caller-supplied free-form string.

Compatibility requires exact RuleVersion and declared input contract equality,
or an approved immutable `BindingCompatibilityContractVersion`. Similar name,
same durable Rule, current/latest alias, or display-code equality is not
compatibility.

### Editable bindings and immutable values

| Logical table | Key and responsibility |
| --- | --- |
| `InputBlock` | Durable editable block owned by one `InstantiationOccurrenceBinding`; one current authoring surface, no direct InstantiationVersion ownership. |
| `InputBlockVersion` | Immutable snapshot with `(InputBlockId, RevisionSequence)` unique, same-block predecessor, source EditSession, canonical content hash, and `PublishedAtUtc`. |
| `InputValue` | One typed value in one InputBlockVersion for one exact `RuleInputDefinition`; unique `(InputBlockVersionId, RuleInputDefinitionId)`; exact ValueTypeVersion/cardinality and canonical payload/hash. |
| `InstantiationVersionInputBlock` | Immutable selection row keyed by `(InstantiationVersionId, InstantiationOccurrenceBindingId)` and referencing one exact InputBlockVersion. Composite keys prove common Instantiation and compatible occurrence. |

An InputValue is a typed value or validated versioned DTO reference as selected
by RDB-130. Secret references are opaque SecretNames only; no secret,
credential, connection string, resolved-secret hash, or sensitive plaintext is
persisted. An InputBlockVersion cannot be selected for an occurrence it does
not own, for another Instantiation, or for an incompatible Rule input shape.

### Permission and edit-session relations

| Logical table | Key and responsibility |
| --- | --- |
| `InstantiationPermissionGrant` | Append-only grant or revoke event for one Instantiation, opaque authority reference, authority/tenant scope, exact PermissionVerb, effect, precedence class, effective UTC interval, and decision/audit reference. |
| `PermissionVerb` | Closed catalog of the eight verbs stated above. No free-form `RoleName` or wildcard verb authorizes an operation. |
| `EditSession` | Mutable authoring lease for one Instantiation and actor authority reference: base InstantiationVersion, session token, started/heartbeat/terminal UTC times, controlled terminal state, and proposed successor revision. |

Permission evaluation is fail-closed. It records an evaluation snapshot/hash at
the security-sensitive publish/plan/execute/approve boundary, while RDB-250
owns approval and execution authorization facts. Expiry and revocation affect
future authorization but do not alter historical grants, publication facts, or
audit records.

## Required constraints

- Every InstantiationVersion references exactly one immutable BuildSetVersion
  and exact predecessor from the same Instantiation; sequence allocation is
  monotonic and branch-free.
- Every occurrence is derived from one complete exact member path. Its
  OccurrenceKey is unique per BuildSetVersion and permits repeated RuleVersion
  children only at distinct paths.
- A binding is owned by one Instantiation and is unique for its occurrence.
  Its source occurrence is compatible by exact identity or approved immutable
  compatibility contract.
- One InputBlock belongs to one binding. Every InputBlockVersion belongs to its
  InputBlock, is immutable after publication, and has a same-block lineage.
- Every selected InputBlockVersion is FK-proven to the selected binding,
  occurrence, and owning Instantiation. Required inputs appear exactly once;
  undeclared, duplicate, incompatible, or missing values are rejected.
- A successor with added, removed, duplicated, or incompatible occurrences has
  a complete immutable BindingResolution set before publication.
- Permission grants use a catalogued verb and effect, bounded scope and UTC
  interval. A grant does not implicitly authorize another verb. Revocation is
  append-only and authorization fails closed when resolution is ambiguous.
- An EditSession can only author one Instantiation; its base version belongs to
  that Instantiation. A closed/abandoned session cannot mutate or publish; one
  proposed successor revision has one successful publisher.

## EntityType registrations

This slice reserves semantic codes only: `instantiation`,
`instantiation-version`, `input-block`, and `input-block-version`. Numeric
identifiers, GUID allocation, physical table names, and seed rows remain
RDB-320/RDB-440/RDB-500 work.

## Relational counterexamples

RDB-280/RDB-440 must reject each of the following:

1. An Instantiation has no owner, changes its owner, or forks a non-existent/non-exact source version.
2. A fork reuses the source Instantiation or Philote rather than creating a new identity.
3. An InstantiationVersion references a mutable/current/latest BuildSet alias.
4. Version predecessor belongs to another Instantiation, branches, cycles, or regresses revision sequence.
5. A repeated RuleVersion collapses to one occurrence because only RuleVersionId is used as key.
6. An occurrence omits a BuildSet/RuleSet/Rule member identity or has a caller-supplied key that fails deterministic derivation.
7. Two different paths share an occurrence key within one BuildSetVersion, or one path has two keys.
8. A binding is reused by another Instantiation or duplicates an Instantiation/OccurrenceKey pair.
9. A binding carries forward after its RuleVersion/input contract becomes incompatible without an approved immutable mapping contract.
10. A new, removed, duplicated, or incompatible occurrence lacks a BindingResolution at publication.
11. An InputBlock is attached directly to an InstantiationVersion rather than its durable binding.
12. An InputBlockVersion is selected from a different Instantiation, binding, occurrence, or incompatible input contract.
13. An InputBlockVersion predecessor is from another InputBlock, branches, or mutates a published snapshot.
14. An InputValue targets an undeclared/foreign RuleInputDefinition, duplicates an input, or has incompatible type/cardinality.
15. A value uses free-form JSON/text where typed scalar or validated DTO storage is required.
16. A value persists a secret, credential, connection string, or resolved-secret hash.
17. A published selection omits a required binding/input or selects two versions for one binding.
18. A permission row uses a wildcard/free-form verb, grants `approve` from `execute`, or has an unbounded unsupported scope.
19. A deny/allow conflict has no recorded precedence/evaluation contract and is treated as allowed.
20. A revocation rewrites a historical grant or changes a past publication authorization fact.
21. A session edits an Instantiation other than its owner, uses a foreign base version, or continues after terminal state.
22. Two sessions publish the same successor revision, or an abandoned session publishes.
23. A generic TableName/SchemaName address or wildcard EntityType replaces an exact typed FK.
24. A published InstantiationVersion, InputBlockVersion, selection, binding-resolution, or audit grant is updated/deleted in place.

## Integration obligations and deferred work

RDB-230 provides the immutable member identities from which occurrences derive;
this slice does not revise them. RDB-270 reconciles composite key names, exact
RuleInputDefinition links, EntityType endpoint policies, and data-dictionary
coverage. RDB-280/RDB-440 turn these counterexamples into invalid-row tests and
physical SQL. RDB-250 owns plans, plan approval, execution, and observed
artifacts. The future AceCommander catalog-rationalization plan owns user,
tenant, session, permission-inheritance UI/API, and topology implementation.

This slice does not claim SQL enforcement, numeric IDs, Philote GUIDs, seed
data, secret resolution, AceCommander changes, package actions, or live-tier
work.
