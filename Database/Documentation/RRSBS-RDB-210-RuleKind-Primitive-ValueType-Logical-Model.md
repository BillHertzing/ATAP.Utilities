# RDB-210 RuleKind, Primitive, and ValueType Logical Model

Status: Proposed Wave 3 logical-model slice

Date: 2026-08-03

Owner: RDB-210 / Task 14.20.d.02

## Authority and boundary

This document defines the design-only logical model for `RuleKind`,
`RuleKindVersion`, `Primitive`, `PrimitiveVersion`,
`PrimitiveInputDefinition`, `ValueType`, and their supporting immutable
contract/catalog tables.

The authoritative inputs are:

- [RRSBS ADR-100: Glossary and Entity-Philote Authority](../../SolutionDocumentation/RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md)
- [RRSBS ADR-105: Entity-Reference Contract](../../SolutionDocumentation/RRSBS-ADR-105-Entity-Reference-Contract.md)
- [RRSBS ADR-110: Temporal and Versioning Contract](../../SolutionDocumentation/RRSBS-ADR-110-Temporal-Versioning.md)
- [RRSBS ADR-115: RollItUp Publication and Concurrency](../../SolutionDocumentation/RRSBS-ADR-115-RollItUp-Publication-and-Concurrency.md)
- [RRSBS ADR-130: Typed Values, Bindings, and Secret References](../../SolutionDocumentation/RRSBS-ADR-130-Typed-Values-Bindings-and-Secret-References.md)
- [RRSBS ADR-140: Manifestation, Executor Safety, and UnRollIt Traversal](../../SolutionDocumentation/RRSBS-ADR-140-Manifestation-Executor-Safety.md)
- [RDB-180 retained-grammar reconciliation](RRSBS-RDB-180-Retained-Grammar-Reconciliation.md)
- Final RRSBS plan at
  `_Planning/InformationForTheFuture/RRSBS-Rationalization/Plan-RRSBS-Final.md`

This slice creates no SQL, migration, seed data, grammar/compendium rewrite,
package/feed change, or live-system action. It allocates semantic codes only;
numeric identifiers and Philote GUIDs remain RDB-320 and RDB-500 work.

RDB-220 owns `Rule`, `RuleVersion`, Rule graph nodes, Rule input/default/output
definitions, and their mappings to the primitive inputs defined here. RDB-250
owns actual execution attempts and captured executor/environment identities.
RDB-260 owns `SourceArtifactVersion`; this slice reserves typed grammar and
compendium evidence endpoints for integration by RDB-270.

## Decisions

1. `RuleKind` is the durable semantic identity of a grammar and interpretation
   family. `RuleKindVersion` is one immutable published grammar, executor
   contract selection, safety classification, and round-trip contract.
2. `Primitive` belongs to one durable `RuleKind` for its entire lifetime.
   Reclassifying a Primitive creates a new Primitive identity; it never updates
   the owner kind.
3. Every `PrimitiveVersion` references an exact `RuleKindVersion` belonging to
   the Primitive's durable `RuleKind`. A composite FK proves the match.
4. RDB-220 must apply the same exact-kind-version pattern to `RuleVersion`.
   Global ValueType, DTO-contract, and executor-contract versions are not
   grammar definitions and therefore do not receive a meaningless
   `RuleKindVersion` FK.
5. Grammar and normalized compendium evidence use exact typed
   `SourceArtifactVersion` Entity references plus immutable hashes. A mutable
   path string alone is not authority.
6. Publish-time insertion creates immutable versions. There are no draft rows,
   mutable lifecycle columns, `IsCurrent` flags, or business-validity columns
   in this slice.
7. An executable RuleKindVersion selects one exact
   `ExecutorContractVersion`. Metadata-only and prohibited classifications
   cannot select an executable contract. Unknown classifications fail closed.
8. Value types separate stable semantic identity from immutable contract
   versions. Query/integrity values use canonical scalar storage; structured
   JSON requires an exact versioned DTO contract; collections name an exact
   element ValueTypeVersion and ordering policy; secret references store only
   an opaque SecretName contract; Entity references use typed Entity policies.
9. `PrimitiveInputDefinition` belongs to one immutable `PrimitiveVersion`, has
   one exact `ValueTypeVersion`, and declares cardinality, nullability,
   ordering, and validation semantics. A free-form input name/value pair is
   not valid.
10. Primitive output semantics remain a single declared output contract on
    `PrimitiveVersion`. Public Rule inputs/outputs and mapping cardinality
    belong to RDB-220.

## Shared RDB-200 Entity contract

The following rows are Entity-bearing and use the RDB-200 subtype-registration
triple `(EntityId, EntityTypeId, EntityPhiloteId)`:

- `RuleKind`
- `RuleKindVersion`
- `Primitive`
- `PrimitiveVersion`
- `PrimitiveInputDefinition`
- `ValueType`
- `ValueTypeVersion`
- `StructuredValueContract`
- `StructuredValueContractVersion`
- `ExecutorContract`
- `ExecutorContractVersion`

Every table has its own table-specific Philote equal to the Entity Philote in
the subtype-registration FK. Supporting catalogs and compatibility relations
are not generic Entity targets unless RDB-270 records a proven need.

## Versioning convention

Each durable/version pair uses:

- immutable durable Philote and stable code on the root;
- immutable version Philote on the published version;
- unique `(DurableId, RevisionSequence)`;
- optional predecessor constrained to the same durable parent;
- unique predecessor to prevent ambiguous direct successors;
- `PublishedAtUtc` distinct from creation and business time;
- trusted publication validation for predecessor cycles and monotonic
  revision allocation.

No concept in this slice has an approved business-effective consumer, so no
`ValidFromDTS` or `ValidToDTS` column is present.

## RuleKind and executor contract tables

### RuleKind

Durable representation/grammar identity.

| Logical column | Null | Contract |
| --- | --- | --- |
| `RuleKindId` | No | Numeric PK. |
| `RuleKindPhiloteId` | No | Unique immutable GUID and Entity Philote. |
| `EntityId`, `EntityTypeId` | No | RDB-200 subtype-registration FK. |
| `RuleKindCode` | No | Immutable unique code, including approved aliases only through an explicit alias relation later. |
| `CreatedAtUtc` | No | Durable identity creation time. |

The stable code is not an executor identity, domain tag, or permission.

### RuleKindVersion

Immutable interpretation contract for one RuleKind.

| Logical column | Null | Contract |
| --- | --- | --- |
| `RuleKindVersionId` | No | Numeric PK. |
| `RuleKindVersionPhiloteId` | No | Unique immutable GUID and Entity Philote. |
| `EntityId`, `EntityTypeId` | No | RDB-200 subtype-registration FK. |
| `RuleKindId` | No | Durable parent FK. |
| `RevisionSequence` | No | Unique and monotonic within RuleKind. |
| `PredecessorRuleKindVersionId` | Yes | Same-parent immutable predecessor. |
| `GrammarSourceEntityId`, `GrammarSourceEntityTypeId` | No | Typed exact `SourceArtifactVersion` Entity FK after RDB-260/RDB-270 integration. |
| `GrammarHashAlgorithmCode`, `GrammarContentHash` | No | Immutable grammar-byte proof. |
| `CompendiumSourceEntityId`, `CompendiumSourceEntityTypeId` | No | Typed exact normalized-compendium `SourceArtifactVersion` Entity FK. |
| `CompendiumHashAlgorithmCode`, `CompendiumContentHash` | No | Immutable compendium-byte proof. |
| `ExecutorContractVersionId` | Conditional | Exact executor contract; required for executable classifications and prohibited otherwise. |
| `ExecutionClassificationCode` | No | FK to finite execution classification. |
| `SecurityCapabilityCode` | No | FK to finite default-deny safety classification. |
| `RoundTripPolicyCode` | No | FK to finite reproducibility/round-trip policy. |
| `PublishedAtUtc` | No | Immutable publication time. |

Candidate key `(RuleKindVersionId, RuleKindId)` supports same-kind composite
FKs. Grammar/compendium paths may be projected for display, but paths are not
identity or authority.

### RuleKindVersionCompatibility

Explicit directed compatibility decision between two versions of the same
RuleKind.

| Logical column | Null | Contract |
| --- | --- | --- |
| `FromRuleKindVersionId`, `RuleKindId` | No | Composite FK to source version. |
| `ToRuleKindVersionId`, `RuleKindId` | No | Composite FK to target version. |
| `CompatibilityDispositionCode` | No | `byte-compatible`, `semantic-compatible`, `conversion-required`, or `incompatible`. |
| `CompatibilityEvidenceEntityId`, `CompatibilityEvidenceEntityTypeId` | No | Typed exact evidence Entity. |
| `RecordedAtUtc` | No | Decision record time. |

Primary key: `(FromRuleKindVersionId, ToRuleKindVersionId)`. Source and target
must differ, share one RuleKind, and move forward in revision sequence.
Compatibility is never inferred solely from matching codes, labels, or
executor aliases.

### ExecutionClassification

Finite catalog implementing SECURITY-01:

| Code | Execution posture |
| --- | --- |
| `deterministic` | Executable only through an approved exact plan; reproducibility contract required. |
| `approved-ai-directed` | Executable only through an exact approved plan with model/provider/prompt/tool policy captured; output is non-deterministic unless frozen. |
| `observational` | Read/observe only under an approved target and evidence contract; no mutation implied. |
| `metadata-only` | No executor may be selected or invoked. |
| `prohibited` | No planning or execution is permitted. |

Catalog fields declare `AllowsExecutorContract`, `RequiresPlanApproval`,
`AllowsSideEffects`, `RequiresObservationOnly`, and `RequiresFrozenOutput`.
The physical checks fail closed on contradictory combinations.

### SecurityCapabilityClassification

Finite default-deny catalog describing the maximum capability class of a
RuleKindVersion. Initial semantic codes are `reference-safe`,
`security-sensitive`, `offensive-metadata-only`, `legal-metadata-only`,
`financial-metadata-only`, and `prohibited`.

This classification is not authorization. RDB-146/RDB-250 must still bind an
exact approved plan and target. An ExpertiseDomain tag cannot change the
capability class.

### RoundTripPolicy

Finite catalog with initial codes `byte-identical`, `semantic-equivalent`,
`observational-freeze`, and `not-applicable`. It declares which hashes,
encoding/BOM/newline rules, canonicalization rules, and comparison fixture
families are required before publication and execution.

### ExecutorContract and ExecutorContractVersion

`ExecutorContract` is the stable identity of one renderer/planner/executor
interface. `ExecutorContractVersion` is its immutable versioned contract.

An ExecutorContractVersion records:

- contract schema version;
- executor interface code and exact version;
- permitted locator/effect class policy;
- required runtime/toolchain/dependency-lock identity fields;
- required encoding/BOM/newline/locale fields;
- plan-hash field contract;
- validation entry point and compatibility fixture family;
- publication time and predecessor lineage.

It does not record a mutable executable path or imply runtime authorization.
RDB-250 records the exact implementation/build used by an execution.

## Primitive tables

### Primitive

Durable identity of one atomic construct.

| Logical column | Null | Contract |
| --- | --- | --- |
| `PrimitiveId` | No | Numeric PK. |
| `PrimitivePhiloteId` | No | Unique immutable GUID and Entity Philote. |
| `EntityId`, `EntityTypeId` | No | RDB-200 subtype-registration FK. |
| `RuleKindId` | No | Immutable owner-kind FK. |
| `PrimitiveCode` | No | Stable code unique within RuleKind. |
| `CreatedAtUtc` | No | Durable identity creation time. |

Required candidate key: `(PrimitiveId, RuleKindId)`. Natural key:
`(RuleKindId, PrimitiveCode)`.

### PrimitiveVersion

Immutable definition under one exact RuleKindVersion.

| Logical column | Null | Contract |
| --- | --- | --- |
| `PrimitiveVersionId` | No | Numeric PK. |
| `PrimitiveVersionPhiloteId` | No | Unique immutable GUID and Entity Philote. |
| `EntityId`, `EntityTypeId` | No | RDB-200 subtype-registration FK. |
| `PrimitiveId`, `RuleKindId` | No | Composite FK to durable Primitive. |
| `RuleKindVersionId`, `RuleKindId` | No | Composite FK to exact same-kind RuleKindVersion. |
| `RevisionSequence` | No | Unique and monotonic within Primitive. |
| `PredecessorPrimitiveVersionId` | Yes | Same-Primitive predecessor. |
| `GrammarProductionCode` | No | Exact production key within selected grammar version. |
| `DefinitionText` | No | Immutable normalized EBNF/definition fragment. |
| `DefinitionHashAlgorithmCode`, `DefinitionContentHash` | No | Immutable definition-byte proof. |
| `OutputValueTypeVersionId` | No | Exact output type version. |
| `OutputMinCardinality`, `OutputMaxCardinality` | No/Yes | Output cardinality; max null means unbounded. |
| `PublishedAtUtc` | No | Immutable publication time. |

Required constraints:

- unique `(PrimitiveId, RevisionSequence)`;
- unique predecessor;
- `OutputMinCardinality >= 0`;
- `OutputMaxCardinality IS NULL OR OutputMaxCardinality >= OutputMinCardinality`;
- a successor changing RuleKindVersion must reference a recorded compatible or
  conversion-required RuleKindVersion transition;
- the grammar production must exist exactly once in the selected grammar
  artifact and agree with the stored definition hash.

### PrimitiveInputDefinition

Immutable typed input slot owned by one PrimitiveVersion.

| Logical column | Null | Contract |
| --- | --- | --- |
| `PrimitiveInputDefinitionId` | No | Numeric PK. |
| `PrimitiveInputDefinitionPhiloteId` | No | Unique immutable GUID and Entity Philote. |
| `EntityId`, `EntityTypeId` | No | RDB-200 subtype-registration FK. |
| `PrimitiveVersionId` | No | Exact owner PrimitiveVersion FK. |
| `InputCode` | No | Stable within this PrimitiveVersion. |
| `Ordinal` | No | Deterministic order, unique and gap-free within owner version. |
| `ValueTypeVersionId` | No | Exact immutable value contract. |
| `MinCardinality`, `MaxCardinality` | No/Yes | Required multiplicity; max null means unbounded. |
| `AllowsNullElement` | No | Distinct from zero cardinality and collection emptiness. |
| `ValidationContractCode` | No | Controlled validation entry point/policy. |

Required constraints:

- unique `(PrimitiveVersionId, InputCode)`;
- unique `(PrimitiveVersionId, Ordinal)`;
- ordinals are non-negative and gap-free at publication;
- `MinCardinality >= 0`;
- `MaxCardinality IS NULL OR MaxCardinality >= MinCardinality`;
- collection ordering comes from the exact ValueTypeVersion, not input text;
- secret-reference inputs store only future opaque SecretName values and never
  resolve or validate a live secret during definition/publication.

## ValueType and serialized-contract tables

### ValueType and ValueTypeVersion

`ValueType` is a durable semantic type identity with stable `ValueTypeCode`.
`ValueTypeVersion` is its immutable storage/serialization/validation contract.

Each ValueTypeVersion has exactly one `ValueCategoryCode`:

| Category | Required contract | Prohibited alternatives |
| --- | --- | --- |
| `scalar` | Exact `ScalarStorageKindCode` and validation contract. | DTO, element, secret, and Entity policy columns. |
| `structured` | Exact `StructuredValueContractVersionId`. | Treating JSON as queryable/integrity authority. |
| `collection` | Exact `ElementValueTypeVersionId` and `CollectionOrderingCode`. | Delimited scalar or untyped JSON array. |
| `secret-reference` | Exact `SecretReferencePolicyId`. | Resolved secret material, DTO payload, or scalar fallback. |
| `entity-reference` | One or more `ValueTypeAllowedEntityType` rows. | String GUID, table-name/key pair, or unrestricted Entity type. |

Common version columns are durable parent, revision sequence, predecessor,
publication time, and a controlled validation contract. Category-specific
columns satisfy an exactly-one-shape check.

Collection element versions cannot reference the collection version itself or
form a recursive cycle. RDB-400 owns trusted cycle validation.

### ScalarStorageKind

Finite catalog of canonical relational scalar forms, such as bounded Unicode
text, signed integer, decimal with declared precision/scale, Boolean, UTC
timestamp, duration, binary hash, controlled enum code, and GUID identity.

The catalog records the required relational representation and canonical
serialization. A queryable number, Boolean, UTC time, enum, or GUID cannot
fall back to untyped text/JSON.

### StructuredValueContract and StructuredValueContractVersion

Durable/version pair for one serialized .NET DTO contract. A version records:

- contract schema version unique within the durable contract;
- source-generated `System.Text.Json` context identity;
- DTO type identity distinct from persistence and domain models;
- validation entry point;
- canonicalization policy;
- compatibility fixture family and content hash;
- predecessor and publication time.

Unknown or incompatible schema versions fail closed; no untyped dictionary
fallback is permitted.

### SecretReferencePolicy

Finite catalog declaring:

- resolver code fixed to `Get-SecretATAP`;
- SecretName syntax policy;
- whether a non-secret selector/field is permitted;
- redaction and logging policy;
- whether the SecretName itself may appear in a plan hash;
- explicit prohibition on publication-time resolution.

It stores no SecretName instances or secret values.

### ValueTypeAllowedEntityType

Finite allow-list for an `entity-reference` ValueTypeVersion.

Primary key: `(ValueTypeVersionId, EntityTypeId)`. Each row FKs the exact
ValueTypeVersion and RDB-200 `EntityType`. At least one row is required for the
category, and wildcard EntityTypes are prohibited.

## EntityType registration owned by this slice

RDB-210 reserves semantic codes, not numeric IDs or GUIDs:

- `rule-kind`
- `rule-kind-version`
- `primitive`
- `primitive-version`
- `primitive-input-definition`
- `value-type`
- `value-type-version`
- `structured-value-contract`
- `structured-value-contract-version`
- `executor-contract`
- `executor-contract-version`

RDB-270 must merge these codes into the integrated EntityType catalog and add
them to the exact RDB-200 relationship endpoint policies where appropriate.

## Relational counterexamples

The physical implementation and RDB-280 fixtures must reject all of these:

1. A RuleKind, Primitive, ValueType, DTO contract, or executor contract subtype
   disagrees with its EntityType or Entity Philote registration.
2. A Primitive changes durable RuleKind or duplicates its code within one
   RuleKind.
3. A PrimitiveVersion omits RuleKindVersion, references a version from another
   RuleKind, or relies only on the durable RuleKind.
4. A future RuleVersion is accepted without one exact RuleKindVersion.
5. A grammar/compendium uses a mutable path without exact SourceArtifactVersion
   identity and immutable hash.
6. A published version changes content, parent, Philote, predecessor,
   classification, contract selection, or publication time.
7. A predecessor belongs to another durable parent, receives two direct
   successors, forms a cycle, or permits revision regression.
8. RuleKindVersion compatibility crosses durable RuleKinds, moves backward,
   lacks evidence, or is inferred from matching labels/aliases.
9. An executable classification omits an ExecutorContractVersion, or a
   metadata-only/prohibited classification selects one.
10. An unknown or security-sensitive classification becomes executable by
    default, or an ExpertiseDomain/tag is treated as authorization.
11. A PrimitiveVersion grammar production is absent/ambiguous in the exact
    grammar artifact or its definition hash differs.
12. Primitive output cardinality is negative, inverted, or incompatible with
    its exact ValueTypeVersion.
13. A PrimitiveInputDefinition duplicates input code/ordinal, has a gapful
    ordinal sequence, invalid cardinality, or no exact ValueTypeVersion.
14. A required primitive input is represented only by free-form name/value
    text or untyped JSON.
15. A scalar query/integrity value uses untyped text/JSON instead of its
    canonical scalar storage kind.
16. A structured value omits exact DTO/schema/serializer/validator/fixture
    contracts or falls back to an untyped dictionary.
17. A collection omits its exact element type/ordering policy, uses a delimited
    scalar, or forms a recursive type cycle.
18. A secret-reference type permits stored/resolved secret material, another
    resolver, publication-time resolution, or secret-bearing evidence.
19. An Entity-reference value uses a string GUID, table-name/key pair,
    unrestricted Entity type, or no allowed EntityType row.
20. Category-specific ValueTypeVersion columns satisfy zero or multiple shapes.
21. A later RuleKind, ValueType, DTO, or executor-contract version silently
    changes a previously published PrimitiveVersion or input definition.
22. Executor aliases, mutable executable paths, or latest-version selection
    replace the exact ExecutorContractVersion.
23. `ValidFromDTS`, `ValidToDTS`, or mutable `IsCurrent` is added without an
    approved business-effective or publication projection contract.
24. Numeric IDs, Philote GUIDs, seed rows, grammar edits, executor invocation,
    or live secret resolution are performed as part of this design slice.

## Integration obligations

RDB-220 must:

- give every RuleVersion one exact RuleKindVersion FK;
- prove every RuleVersionNode's PrimitiveVersion is compatible with that exact
  RuleKindVersion;
- map every required PrimitiveInputDefinition exactly once through a typed
  constant, exposed Rule input, or approved versioned derivation;
- keep Rule defaults/output declarations immutable and typed.

RDB-270 must:

- merge RDB-210 EntityTypes and RDB-200 endpoint policies;
- bind grammar and compendium evidence to exact RDB-260
  SourceArtifactVersions;
- reconcile RuleKindVersion compatibility with RDB-220 graph publication;
- publish one integrated data-dictionary draft without wildcard types.

RDB-280 must execute invalid-row scenarios for every counterexample above.
RDB-410 owns physical SQL constraints and trusted publication operations.
RDB-500A-I owns retained-kind identity allocation and reference-safe seed rows.

## Adversarial self-pass

Close variants that defeat a superficial implementation include:

- matching `RuleKindId` on Primitive while allowing PrimitiveVersion to point
  at a different kind's version;
- recording a grammar hash while allowing its SourceArtifactVersion identity
  to change;
- treating `metadata-only` as executable because an executor alias happens to
  exist;
- changing an input's ValueType or cardinality while retaining its code and
  silently carrying bindings forward;
- representing `List<SecretName>` as structured JSON so secret-reference
  constraints never run;
- allowing an Entity-reference ValueType to target every future EntityType via
  a wildcard;
- accepting a newer executor contract through `latest` while preserving the
  old RuleKindVersion row;
- declaring DTO compatibility without fixtures or canonicalization proof.

These cases require composite same-kind FKs, exact version identities,
category-shape checks, finite allow-lists, immutable hashes, and trusted
publication validation together. Application-only validation is insufficient.

