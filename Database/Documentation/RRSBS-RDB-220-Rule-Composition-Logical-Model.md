# RDB-220 Rule and Recursive Composition Logical Model

Status: Proposed Wave 3 logical-model slice

Date: 2026-08-03

Owner: RDB-220 / Task 14.20.d.03

## Authority and boundary

This design-only slice defines `Rule`, `RuleVersion`, `RuleVersionNode`,
`RuleVersionNodeInput`, `RuleInputDefinition`, `RuleDefaultInputValue`,
`RuleOutputDefinition`, and the supporting finite catalogs. It realizes the
approved Rule composition and typed-binding contracts without creating SQL,
migrations, seed data, package/feed changes, or live-system action.

It applies [ADR-105: Entity-reference contract](../../SolutionDocumentation/RRSBS-ADR-105-Entity-Reference-Contract.md),
[ADR-110: Temporal and versioning contract](../../SolutionDocumentation/RRSBS-ADR-110-Temporal-Versioning.md),
[ADR-115: RollItUp publication and concurrency](../../SolutionDocumentation/RRSBS-ADR-115-RollItUp-Publication-and-Concurrency.md),
and [ADR-130: typed values, bindings, and secret references](../../SolutionDocumentation/RRSBS-ADR-130-Typed-Values-Bindings-and-Secret-References.md).
The RDB-210 [logical model](RRSBS-RDB-210-RuleKind-Primitive-ValueType-Logical-Model.md)
is the authority for RuleKind, Primitive, and ValueType definitions.

RDB-230 owns composition of published Rules into RuleSets and BuildSets.
RDB-240 owns Instantiation overrides and resolved occurrence snapshots.
RDB-250 owns execution and observed artifacts. RDB-270 integrates EntityType
allow-lists and cross-slice FK closure; RDB-280/RDB-420 own executable
rejection proof and physical enforcement.

## Decisions

1. `Rule` is a durable authored identity permanently owned by one `RuleKind`.
   `RuleVersion` is one immutable published composition under one exact,
   same-kind `RuleKindVersion`; a durable RuleKind alone is insufficient.
2. A RuleVersion is a finite rooted ordered tree of `RuleVersionNode` rows.
   It has exactly one root, every non-root has one parent in the same version,
   and a node cannot parent itself or form a cycle.
3. A node identifies the exact `PrimitiveVersion` it instantiates. Its owner
   RuleVersion's exact RuleKindVersion and that PrimitiveVersion's exact
   RuleKindVersion must be identical. Compatibility by display code, alias, or
   a merely durable RuleKind is forbidden.
4. Child ordinals are non-negative, unique, and gap-free within a parent.
   `MinOccurs` and nullable `MaxOccurs` constrain the child occurrence; null
   maximum means unbounded. A choice discriminator is a controlled code and
   is permitted only for an approved routing/choice Primitive contract.
5. `RuleVersionNodeInput` maps exactly one declared `PrimitiveInputDefinition`
   of one node using exactly one source shape: fixed typed constant, exposed
   Rule input, or approved versioned derivation. It stores no free-form JSON
   where an FK describes identity, type, or source.
6. A public `RuleInputDefinition` is immutable, typed, ordered, and local to
   one RuleVersion. It may feed many node inputs only through explicit,
   type/cardinality-compatible mappings. Every required primitive input is
   satisfied exactly once unless an explicit composition policy permits more.
7. A Rule default belongs to one exact Rule input and is an immutable typed
   value. Precedence is compatible Instantiation override, then this default,
   then a required-value failure. Defaults never resolve secrets or alter an
   already published snapshot.
8. A Rule output is an immutable declared port. It names one exact
   ValueTypeVersion, cardinality, media/artifact policy, and locator/hash
   expectation; it is not an observed Manifestation artifact.
9. Publication is one trusted atomic operation. It validates root, reachability,
   acyclicity, ordered children, exact types, mapping completeness, version
   lineage, and immutable hashes before it exposes a version.

## Shared Entity and version contract

`Rule`, `RuleVersion`, `RuleVersionNode`, `RuleInputDefinition`,
`RuleDefaultInputValue`, and `RuleOutputDefinition` are RDB-200 Entity
subtypes, registered through `(EntityId, EntityTypeId, EntityPhiloteId)` with
one table-specific immutable Philote. `RuleVersionNodeInput` is a binding
relation rather than a generic endpoint. RDB-270 must close the EntityType
catalog and endpoint allow-lists.

`Rule` and `RuleVersion` use the approved durable/version pattern: immutable
Philotes, `RevisionSequence` unique within the durable parent, same-parent
predecessor, one direct successor at most, monotonic allocation, and immutable
`PublishedAtUtc`. No draft rows, `IsCurrent`, mutable lifecycle field, or
business-effective period is introduced here.

## Logical tables

### Rule and RuleVersion

| Logical column | `Rule` contract | `RuleVersion` contract |
| --- | --- | --- |
| Identity | `RuleId` PK; immutable `RulePhiloteId`; RDB-200 Entity registration | `RuleVersionId` PK; immutable `RuleVersionPhiloteId`; Entity registration |
| Parent/kind | `RuleKindId` immutable owner; `RuleCode` unique within RuleKind | `(RuleId, RuleKindId)` FK to Rule and `(RuleKindVersionId, RuleKindId)` FK to exact same-kind RuleKindVersion |
| Version lineage | `CreatedAtUtc` only | `RevisionSequence`, nullable same-Rule predecessor, `PublishedAtUtc`; unique `(RuleId, RevisionSequence)` |
| Definition proof | No mutable definition body | `CompositionHashAlgorithmCode`, `CompositionContentHash`, and exact grammar/compendium evidence inherited through RuleKindVersion |

Candidate keys `(RuleId, RuleKindId)` and `(RuleVersionId, RuleId)` make
same-parent and downstream exact-version constraints explicit. A successor
that changes RuleKindVersion requires an approved RDB-210 compatibility record.

### RuleVersionNode

| Logical column | Null | Contract |
| --- | --- | --- |
| `RuleVersionNodeId`, `RuleVersionNodePhiloteId` | No | PK and immutable Entity Philote. |
| `RuleVersionId` | No | Exact owner RuleVersion FK. |
| `ParentRuleVersionNodeId` | Yes | Null only for the one root; otherwise same RuleVersion parent FK. |
| `Ordinal` | No | Root has `0`; child ordinal is non-negative, unique and gap-free within parent. |
| `PrimitiveVersionId` | No | Exact PrimitiveVersion FK whose RuleKindVersion equals owner RuleVersion's. |
| `MinOccurs`, `MaxOccurs` | No/Yes | Minimum is non-negative; maximum is null or at least minimum. |
| `ChoiceDiscriminatorCode` | Yes | Controlled routing/choice code; prohibited for a Primitive contract that has no choice semantics. |
| `NodeLabel` | Yes | Display-only; never identity, routing authority, or a fallback primitive key. |

The trusted publication procedure enforces a single root, same-version parent,
root reachability, no cycles, and gap-free siblings. A node's PrimitiveVersion
is not inferred from a primitive code, a RuleKind code, or a current version.

### RuleVersionNodeInput

One row binds one declared Primitive input of one node. Its candidate key is
`(RuleVersionNodeId, PrimitiveInputDefinitionId)`. It carries the target's
exact `ValueTypeVersionId`, target cardinality, and a binding shape:

| Shape | Required columns | Prohibited columns |
| --- | --- | --- |
| `constant` | `ConstantValueTypeVersionId`, typed scalar/validated DTO payload reference, canonical hash | Rule input and derivation columns |
| `rule-input` | `RuleInputDefinitionId`, exact source ValueTypeVersion and conversion policy | constant and derivation columns |
| `derivation` | `DerivationContractVersionId`, exact source node/output or input reference, conversion policy | constant and direct Rule-input columns |

Exactly one shape is required. The target PrimitiveInputDefinition must belong
to the node's PrimitiveVersion. Every source and target type/cardinality is
compatible under the declared conversion policy. A constant is stored in the
canonical scalar representation or validated versioned DTO payload; it cannot
be an untyped JSON/text escape hatch. A secret-reference constant stores only
an opaque SecretName and is never resolved during authoring or publication.

`DerivationContractVersion` is a future immutable contract endpoint, not an
ad-hoc expression string. It declares expression language code, exact language
version, source/target types, cardinality transform, validator, and content
hash. An unrecognized language/version or a missing contract fails closed.

### RuleInputDefinition and RuleDefaultInputValue

`RuleInputDefinition` belongs to one RuleVersion and declares `InputCode`,
gap-free `Ordinal`, exact `ValueTypeVersionId`, `MinCardinality`, nullable
`MaxCardinality`, `AllowsNullElement`, and a controlled validation contract.
`(RuleVersionId, InputCode)` and `(RuleVersionId, Ordinal)` are unique.

`RuleDefaultInputValue` has one row at most for each RuleInputDefinition. It
stores the exact type version, canonical typed value/payload reference and
hash, the selected default rationale/evidence Entity, and immutable publication
time. Its type/cardinality must agree exactly with its input. It is not a
mutable user preference, an Instantiation input, or secret material.

### RuleOutputDefinition

`RuleOutputDefinition` belongs to one RuleVersion and declares a unique
`OutputCode`, gap-free `Ordinal`, exact `ValueTypeVersionId`, cardinality,
controlled `OutputDispositionCode`, `MediaTypePolicyCode`,
`ArtifactLocatorPolicyCode`, and `HashExpectationPolicyCode`.

Output policies describe the expected result contract only. They cannot embed a
filesystem path, a live endpoint, a credential, a SecretName value, or an
observed artifact identity. RDB-250 links actual observed artifacts to these
declared ports through exact typed references.

## Required constraints

- Rule code is unique within immutable owner RuleKind; RuleVersion uses one
  exact same-kind RuleKindVersion and immutable predecessor lineage.
- Every RuleVersion has exactly one root node; every row is reachable from it;
  every non-root parent belongs to the same RuleVersion; cycles are rejected.
- Every node targets exactly one PrimitiveVersion of the owner RuleVersion's
  exact RuleKindVersion. Sibling order is gap-free within its parent.
- Every required PrimitiveInputDefinition has exactly one compatible mapping;
  a mapping targets no undeclared/foreign primitive input and has exactly one
  discriminated source shape.
- Public inputs/defaults/outputs use exact immutable ValueTypeVersions and
  valid cardinalities. A default cannot be attached to an undeclared input.
- All published model rows and hashes are immutable. Physical checks and the
  publication transaction are owned by RDB-420.

## EntityType registrations

This slice reserves semantic codes only: `rule`, `rule-version`,
`rule-version-node`, `rule-input-definition`, `rule-default-input-value`, and
`rule-output-definition`. Numeric identifiers, GUID allocations, and seed rows
remain RDB-320/RDB-500 work.

## Relational counterexamples

RDB-280/RDB-420 must reject all of the following:

1. A Rule durable owner changes RuleKind or duplicates a code within it.
2. A RuleVersion omits RuleKindVersion or references a different RuleKind.
3. A RuleVersion uses a mutable/current/latest version alias instead of an exact FK.
4. A version predecessor belongs to another Rule, branches, cycles, or regresses.
5. A RuleVersion has zero or multiple roots.
6. A non-root node has a parent from another RuleVersion or parents itself.
7. A node graph contains a cycle or a node unreachable from the root.
8. Sibling ordinals duplicate, are negative, or contain a gap.
9. Node occurrence bounds are negative or inverted.
10. A node references an absent PrimitiveVersion or one from another RuleKindVersion.
11. A choice discriminator appears on a primitive with no approved choice contract.
12. A node input targets a PrimitiveInputDefinition owned by another primitive version.
13. A required primitive input is unmapped, or a non-composable target is mapped twice.
14. A node input has zero or multiple binding shapes.
15. A Rule input mapping has an incompatible type/cardinality or unapproved conversion.
16. A constant bypasses canonical typed storage with free-form text or unvalidated JSON.
17. A derivation omits its exact language/versioned contract or uses unknown language.
18. A secret value, resolved-secret hash, credential, or connection string is persisted.
19. RuleInputDefinition codes or ordinals duplicate within one RuleVersion.
20. An input's type/cardinality or nullability disagrees with its mapping/default.
21. A default exists for an undeclared input, changes a published version, or overrides an explicit compatible value.
22. RuleOutputDefinition codes or ordinals duplicate, or output bounds invert.
23. An output uses an untyped locator/path, observed artifact, or unrestricted media/hash policy.
24. A published Rule graph/node/input/default/output is updated or deleted in place.
25. A generic `TableName`/`SchemaName` address or wildcard EntityType replaces a typed FK.
26. A RuleVersion is published without a rooted, acyclic, reachable, typed, and gap-free composition.

## Integration obligations and deferred work

RDB-270 must reconcile EntityType policies, exact SourceArtifact evidence, and
cross-slice FK coverage. RDB-230 must consume exact RuleVersions through
occurrence keys without collapsing duplicate occurrences. RDB-240 must snapshot
resolved inputs/defaults against exact RuleVersion and occurrence identities.
RDB-250 owns observed output artifacts and execution. RDB-280/RDB-420 own SQL,
trusted publication, and invalid-row fixtures.

This slice does not claim physical enforcement, numeric IDs, Philote GUIDs,
seed data, grammar changes, package actions, execution, secret resolution, or
live-tier work.
