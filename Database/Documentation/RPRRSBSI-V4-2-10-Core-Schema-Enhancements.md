# RPRRSBSI-V4-2 Core Schema Enhancements

Status: reconciled task-authoring design. This document defines no migration, seed,
deployment, or live-database action.

## V4-2 core expansion

V4-2 retains every V4 core entity and adds three bounded integration aggregates:

| Aggregate | Plane | Required roots |
| --- | --- | --- |
| ContentSummary ingestion | Ace plus selective Outpost projection | `ContentSummaryIngestion`, `ContentSummaryItem`, `ContentSummaryItemTag` |
| AISupervisor telemetry | Ace plus bounded Outpost buffer | `AISupervisorExchange`, `AISupervisorHeader`, `AISupervisorMetric` |
| Scheduled work and synchronization | Outpost-local with central acknowledgments | run/checkpoint, outbound envelope, cursor, acknowledgment, failure |

- **V4-2-CORE-080:** These aggregates SHALL attach to existing tenant and provenance contracts without granting plugins direct database access.
- **V4-2-CORE-081:** ContentSummary Tag associations SHALL reference durable ATAPUtilities `TagId` roots and resolve `TagState` as-of.
- **V4-2-CORE-082:** AISupervisor mutable telemetry SHALL reside in `Ace` and SHALL not become authoritative reference data.
- **V4-2-CORE-083:** Controlled child metrics SHALL absorb provider metadata evolution; an unbounded JSON property bag SHALL not replace typed primary exchange fields.
- **V4-2-CORE-084:** Central cross-schema relationships SHALL remain topology-neutral and use physical foreign keys only where ownership and deployment topology make them durable.

Authoritative diagram source:
[RPRRSBSI-V4-2-Core-Entity-Model.puml](RPRRSBSI-V4-2-Core-Entity-Model.puml). The tracked
SVG is not embedded here because it was not regenerated during this source-only
reconciliation.

## Decision boundary

D-1 through D-7 are normative here: D-1 and D-3 through D-7 were ratified on
2026-08-16, and D-2 is the retained ratified precedence rule. C-16, C-20, C-26, FU-4,
and FU-6 were ruled on 2026-08-30. The eight D-3 edge cases, C-17 through C-19,
C-21 through C-25, and C-27 were ruled on 2026-09-04.

## Identity and temporal foundation

- **V4-2-CORE-001:** All newly introduced semantic identities SHALL initially use `uniqueidentifier` primary keys and SHALL have application-level typed-ID wrappers.
- **V4-2-CORE-002:** Each Philote-bearing table SHALL use the entity primary-key GUID as its `PhiloteId`, preserving the V3 shared-identity convention.
- **V4-2-CORE-003:** `PhiloteValidityPeriod` SHALL gain a unique constraint on `(PhiloteId, PhiloteValidityPeriodId)` so dependent state rows can prove that a validity period belongs to the expected identity.
- **V4-2-CORE-004:** For any Philote, validity periods SHALL be non-overlapping half-open intervals. Gaps are allowed. A null `ValidToUtc` means open ended.
- **V4-2-CORE-005:** Internal semantic change SHALL be represented by new GUID-identified `State` or `Variant` rows and validity periods, not by an integer or string revision number.
- **V4-2-CORE-006:** External product, package, firmware, and protocol versions remain domain values and are not prohibited by V4-2-CORE-005.
- **V4-2-CORE-007:** CSV and API representations of GUIDs SHALL use canonical lowercase dashed `D` format.
- **V4-2-CORE-008:** Database GUID equality, joins, uniqueness, and referential checks SHALL operate on native `uniqueidentifier` values. Implementations SHALL NOT obtain identity semantics by casting GUIDs to text or comparing their spelling, case, or collation.

## General entity registry

| Table        | Required columns and constraints                                                  | Purpose                                                            |
| ------------ | --------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `EntityType` | `EntityTypeId` PK, `PhiloteId` FK, unique `EntityTypeCode`, name, description     | Stable catalog of addressable semantic kinds.                      |
| `Entity`     | `EntityId` PK, `PhiloteId` FK, `EntityTypeId` FK, optional owning-system identity | A durable endpoint for Tags, provenance, and generic associations. |

- **V4-2-CORE-010:** Every entity kind admitted to generic association SHALL have a fixed seeded `EntityType` identity.
- **V4-2-CORE-011:** Generic associations SHALL reference `Entity`, not an unconstrained GUID whose type cannot be checked.
- **V4-2-CORE-012:** Admission of a local table to `EntityType` SHALL be checked against the schema registry during seed validation.

## Expert-system definition

| Table                    | Key relationships                                 | Purpose                                                                                    |
| ------------------------ | ------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `ExpertSystem`           | Philote-bearing root                              | Stable identity and code for a generic or specific expert system.                          |
| `ExpertSystemState`      | `ExpertSystemId`, matching validity period        | Temporal name, description, lifecycle state, and default entry point.                      |
| `ExpertSystemComponent`  | `ExpertSystemId`, `EntityId`, role, ordinal       | Associates RuleSets, BuildSets, workflows, and other components without hiding their type. |
| `ExpertSystemEntryPoint` | `ExpertSystemId`, workflow node or BuildSet, code | Declares supported starts such as create, edit, validate, and explain.                     |

- **V4-2-CORE-020:** A generic expert system SHALL be definable entirely from catalog, rule, graph, and seed data; system-specific tables MAY be added only for irreducibly domain-specific facts.
- **V4-2-CORE-021:** Every runtime result SHALL be traceable to the expert system, BuildSet, effective rule variants, input values, and as-of instant used.
- **V4-2-CORE-022:** Definition data SHALL be immutable through normal application operations. Corrections create new states, variants, or overlay definitions.

## Rule variants and ordered occurrences

V3 has a basic `Rule` and set-membership joins. V4 keeps the basic identity and adds explicit variant and occurrence identities so the same rule can be supplied, overridden, suppressed, ordered, and explained without copying its definition.

| Table                       | Required columns and constraints                                                                                            |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `RuleVariant`               | PK and Philote; same-basic-rule `RuleId` FK; owning `RuleSetId` FK; unique variant code within owner; unique `(RuleVariantId, OwningRuleSetId)` owner key. |
| `RuleVariantState`          | PK; `RuleVariantId`; matching validity period; purpose; executor contract; normalized body/configuration; lifecycle status. |
| `RuleSetRuleOccurrence`     | PK; `RuleSetId`; `RuleVariantId`; membership role; `Ordinal`; optional condition; unique ordinal within RuleSet; composite FK `(RuleVariantId, RuleSetId)` to the variant owner key. |
| `BuildSetRuleSetOccurrence` | PK; `BuildSetId`; `RuleSetId`; `Ordinal`; optional condition; unique ordinal within BuildSet.                               |
| `RuleSetMembershipRole`     | Fixed values `Add`, `Override`, `Suppress`.                                                                                 |

- **V4-2-CORE-030:** `RuleVariant.RuleId` SHALL identify the basic semantic rule being varied.
- **V4-2-CORE-031:** A baseline ATAP variant and an ACE override variant MAY reference the same `RuleId`; their `RuleVariantId` and owning RuleSet SHALL differ.
- **V4-2-CORE-031A:** D-4 is normative: an overlay SHALL be a `RuleVariant` of the same `RuleId`, and an occurrence with membership role `Override` SHALL select it. An implementation SHALL NOT copy the basic `Rule` to represent an overlay.
- **V4-2-CORE-031B:** A `RuleSetRuleOccurrence` SHALL select only a `RuleVariant` owned by
  that same RuleSet. Cross-owner selection is prohibited. The physical contract SHALL
  expose `UNIQUE (RuleVariantId, OwningRuleSetId)` and enforce the occurrence pair
  `(RuleVariantId, RuleSetId)` through a composite foreign key to that owner key.
- **V4-2-CORE-031C:** Conformance tests SHALL reject an occurrence whose `RuleSetId`
  differs from the selected variant's `OwningRuleSetId`, even when the variant shares the
  expected `RuleId` and the occurrence role is `Override`.
- **V4-2-CORE-032:** Membership and BuildSet composition SHALL use occurrence identities; the V3 composite join tables remain readable during transition but SHALL NOT constrain V4 to one occurrence per pair.
- **V4-2-CORE-033:** A RuleSet SHALL reject duplicate occurrence ordinals. A BuildSet SHALL reject duplicate `BuildSetRuleSetOccurrence.Ordinal` values; duplicate ordinals in one BuildSet are invalid input and SHALL NOT be tie-broken.
- **V4-2-CORE-034:** D-2 is normative: effective resolution SHALL order BuildSet RuleSet occurrences by `Ordinal DESC`; the higher ordinal has higher precedence.

Authoritative diagram source:
[RPRRSBSI-V4-2-Rule-Overlay-Resolution.puml](RPRRSBSI-V4-2-Rule-Overlay-Resolution.puml).
The tracked SVG is not embedded here because it was not regenerated during this
source-only reconciliation.

### Effective-resolution algorithm

1. Select the BuildSet and an explicit as-of UTC instant.
2. Select only occurrences and states active at that instant.
3. Sort RuleSets by `BuildSetRuleSetOccurrence.Ordinal DESC`.
4. Within a RuleSet, process rule occurrences in deterministic ordinal order.
5. Group all candidates by basic `RuleId`, retaining enough lower-precedence provenance to validate an `Override`; the first valid higher-precedence occurrence determines the effective outcome.
6. `Suppress` emits no effective variant and records the suppressed candidates.
7. An occurrence whose role is `Override` SHALL select that occurrence's `RuleVariant`, whose `RuleId` is the same as the lower-precedence candidate's basic `RuleId`; absence of that lower-precedence same-`RuleId` candidate is a validation error.
8. `Add` SHALL NOT collide with an already-visible lower-precedence candidate for the same `RuleId`; collision is a validation error.
9. Return selected, suppressed, and shadowed candidates with provenance. Never return an unexplained flattened set.

- **V4-2-CORE-035:** Resolution SHALL be deterministic for identical stored data and as-of instant.
- **V4-2-CORE-036:** Invalid overlay graphs SHALL be rejected before instantiation and SHALL NOT be resolved by accidental insertion order.

## Typed inputs, outputs, defaults, and constraints

| Table                        | Purpose                                                                                                                |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `ValueType`                  | Semantic types such as Boolean, Integer, Decimal, Text, Guid, Uri, DateTimeUtc, Duration, Quantity, and JSON document. |
| `ScalarStorageKind`          | Physical discriminant for validated scalar columns.                                                                    |
| `RuleInputDefinition`        | Stable named input, declared type, required flag, ordinal, normalization contract, and secret policy.                  |
| `RuleDefaultInputValue`      | Typed default attached to an input definition and validity period.                                                     |
| `RuleOutputDefinition`       | Stable named output, declared type, ordinal, and disposition.                                                          |
| `RuleValueConstraint`        | Range, length, pattern, allowed-set, unit, and cross-field constraint metadata.                                        |
| `InputNormalizationContract` | Named deterministic normalization behavior.                                                                            |

- **V4-2-CORE-040:** Typed values SHALL use a discriminated representation with at most one populated physical value column consistent with `ScalarStorageKind`.
- **V4-2-CORE-041:** Secret values SHALL NOT be stored as seed or runtime plaintext. The stored value is a secret name/reference only.
- **V4-2-CORE-042:** Defaults SHALL be distinguishable from user-supplied, imported, calculated, and inherited values.
- **V4-2-CORE-043:** Every normalization operation SHALL be deterministic, identified, and included in execution provenance.
- **V4-2-CORE-044:** D-3 is normative: a material declared-type change SHALL create a new basic semantic identity. Existing identities SHALL NOT be mutated to carry a materially different meaning.
- **V4-2-CORE-045:** The 2026-08-16 material classes are (1) any rule-kind change;
  (2) scalar-to-different-scalar; (3) scalar/heap-object boundary crossing; and (4) any
  heap/object-type change, including single value to collection. V4-2-CORE-045A and
  V4-2-CORE-045B add the edge classifications ruled on 2026-09-04.
- **V4-2-CORE-045A:** The 2026-09-04 edge rulings additionally classify nullability,
  precision/scale, collection element type, container cardinality/shape, and string-length
  or declared-domain constraint changes as material. A declared contract-type rename is
  material; a separate display alias is non-material. Text consumed by code, fixtures,
  or contracts is material.
- **V4-2-CORE-045B:** A simultaneous type/default change is one material transition; the
  default is the replacement definition's initial state.
- **V4-2-CORE-046:** A default-value change and a change to text used only for visual display are non-material and MAY retain the existing semantic identity, while still using the applicable state/validity history.

### Material-change identity transition contract

The identity that changes is the durable semantic row that owns the changed declaration,
not an arbitrary ancestor and not a formatting-only state row. The following table is the
fixture-binding authority for the ratified D-3 classes, including the eight edge rulings.

| Ratified change class | Required new identity | Identity retained | Reference transition and retained history |
| --- | --- | --- | --- |
| Rule-kind change | New `RuleId`, new baseline `RuleVariantId`, and new input/output definition IDs for the replacement Rule | No Rule identity is reused | New occurrences and bindings reference the replacement Rule graph. The prior Rule, variants, definitions, occurrences, instantiation bindings, results, and provenance remain immutable and queryable. |
| Scalar to different scalar on an input or output | New `RuleInputDefinitionId` or `RuleOutputDefinitionId` plus a new `RuleVariantId` for the changed definition set; the parent `RuleId` remains the same | Basic Rule identity | New occurrences select the replacement variant and its registered definition IDs. Existing occurrences and frozen instantiation bindings retain the prior variant and definitions. |
| Scalar/heap-object boundary crossing on an input or output | New `RuleInputDefinitionId` or `RuleOutputDefinitionId` plus a new `RuleVariantId`; the parent `RuleId` remains the same | Basic Rule identity | Same transition and history-retention rule as scalar-to-different-scalar. No declared type or storage discriminant is updated in place. |
| Heap/object-type change, including single value to collection, on an input or output | New `RuleInputDefinitionId` or `RuleOutputDefinitionId` plus a new `RuleVariantId`; the parent `RuleId` remains the same | Basic Rule identity | Same transition and history-retention rule as scalar-to-different-scalar. Old object/collection contracts remain bound to their original definitions. |
| Default-value-only change | New validity-bounded default row/state; no new Rule, variant, or input-definition identity | `RuleId`, `RuleVariantId`, `RuleInputDefinitionId` | The prior default remains queryable as-of; only the default state/value reference changes. |
| Display-only text change | New applicable `State` row for the display payload; no new semantic definition identity | The owning Rule, variant, input/output definition, or catalog identity | Historical display state remains queryable as-of. Text that feeds code or fixtures is still D-3 edge case 8 and is not covered by this control. |
| Same-scalar nullability or precision/scale change | New input/output definition ID plus new `RuleVariantId` | Basic `RuleId` | Prior accepted-value domain remains bound to its original definition. |
| Collection element-type or container cardinality/shape change | New input/output definition ID plus new `RuleVariantId` | Basic `RuleId` | Prior collection contract remains immutable and queryable. |
| Declared contract-type rename | New input/output definition ID plus new `RuleVariantId` | Basic `RuleId` | A separate display alias may retain identity; the contract declaration may not. |
| Simultaneous type/default change | One new input/output definition ID plus new `RuleVariantId`; default recorded as the new definition's initial state | Basic `RuleId` | No artificial intermediate definition is created; prior definition/default history remains intact. |
| String-length or declared-domain constraint change | New input/output definition ID plus new `RuleVariantId` | Basic `RuleId` | Prior constraint/domain remains bound to its original definition. |
| Text consumed by code, fixtures, or contracts | New owning semantic definition identity plus new `RuleVariantId` where rule-bound | Basic `RuleId` when applicable | Genuinely visual display-only text remains the non-material control. |

- **V4-2-CORE-046A:** Every new identity in the table SHALL receive a separately
  registered GUID before it is referenced by seed, migration, API, or fixture data.
- **V4-2-CORE-046B:** No implementation SHALL update `RuleId`, `RuleVariantId`,
  `RuleInputDefinitionId`, `RuleOutputDefinitionId`, declared type, or storage
  discriminant in place to simulate a material transition.
- **V4-2-CORE-046C:** Positive fixtures SHALL prove all four material rows allocate the
  required identities and preserve old references. Negative fixtures SHALL attempt the
  prohibited in-place update. The two non-material controls SHALL prove identity reuse
  through explicit State/default history, not through overwriting prior history.

### D-3 edge-case clarification register

The classifications below were explicitly ruled on 2026-09-04.

| # | Edge case | Classification | Status |
| -: | --- | --- | --- |
| 1 | Same-scalar nullability change | Material | Ruled 2026-09-04 |
| 2 | Same-scalar precision or scale change | Material | Ruled 2026-09-04 |
| 3 | Collection element-type change | Material | Ruled 2026-09-04 |
| 4 | Declared contract-type rename; separate display alias | Material; display alias non-material | Ruled 2026-09-04 |
| 5 | Default-value change combined with a type change | One material transition; default is initial state | Ruled 2026-09-04 |
| 6 | Container cardinality or shape change with unchanged element type | Material | Ruled 2026-09-04 |
| 7 | String length or declared-domain constraint change | Material | Ruled 2026-09-04 |
| 8 | Display text consumed by code, fixtures, or contracts | Material | Ruled 2026-09-04 |

## Separate workflow and calculation graphs

Authoritative diagram source:
[RPRRSBSI-V4-2-Input-And-Execution-Graphs.puml](RPRRSBSI-V4-2-Input-And-Execution-Graphs.puml).
The tracked SVG is not embedded here because it was not regenerated during this
source-only reconciliation.

| Graph                  | Tables                                                                              | Semantics                                                               |
| ---------------------- | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Input workflow         | `InputWorkflow`, `InputWorkflowNode`, `InputWorkflowEdge`, `InputWorkflowCondition` | Controls what is asked, grouped, skipped, revisited, or explained.      |
| Calculation dependency | `RuleDependencyEdge`, `RuleOutputInputBinding`                                      | Controls dependency order, invalidation, and incremental recomputation. |

- **V4-2-CORE-050:** The two graphs SHALL NOT be conflated into one general edge table.
- **V4-2-CORE-051:** Calculation dependencies SHALL form a directed acyclic graph after effective overlay resolution.
- **V4-2-CORE-052:** Workflow cycles MAY exist only when explicitly bounded by a validation rule.
- **V4-2-CORE-053:** Bindings SHALL be type-compatible after normalization; incompatible bindings fail validation before execution.

## Runtime and incremental execution

| Table                            | Purpose                                                                        |
| -------------------------------- | ------------------------------------------------------------------------------ |
| `InstantiationState`             | Temporal lifecycle and selected effective definition for a V3 `Instantiation`. |
| `EditSession`                    | ACE-owned user editing boundary with optimistic concurrency token.             |
| `InstantiationRuleBinding`       | Frozen association between an instantiation and the effective variant used.    |
| `InputBlock` / `InputBlockState` | A grouped, repeatable, temporal set of inputs.                                 |
| `InputValue`                     | Typed value, origin, normalized form, confidence, and provenance.              |
| `InstantiationNodeState`         | Workflow progress and validation state.                                        |
| `DirtyWorkItem`                  | Minimal invalidated calculation target and cause.                              |
| `ExecutionAttempt`               | Executor, inputs hash, start/end, status, and diagnostics.                     |
| `ExecutionResult`                | Typed outputs and provenance.                                                  |

- **V4-2-CORE-060:** Changing an input SHALL dirty only the reachable dependent calculation subgraph.
- **V4-2-CORE-061:** Execution SHALL be idempotent for the same effective definition and normalized input hash unless the executor is explicitly classified otherwise.
- **V4-2-CORE-062:** Execution failures SHALL preserve diagnostics without replacing the last valid result.
- **V4-2-CORE-063:** Instantiation bindings SHALL make later explanation independent of subsequent definition changes.

## ATAP and ACE ownership boundary

- **V4-2-CORE-070:** ATAP SHALL own distributable reference catalogs, reference expert systems, baseline RuleSets, RuleVariants, and reference Tags.
- **V4-2-CORE-071:** ACE SHALL own user overlays, edit sessions, user input, user Tags, and user instantiations.
- **V4-2-CORE-072:** ATAP SHALL NOT require a foreign key into an ACE database.
- **V4-2-CORE-073:** D-5 is normative: effective reads across ATAP and ACE SHALL use a topology-neutral union contract with explicit source authority and deterministic precedence.
- **V4-2-CORE-074:** Separate tables SHALL be introduced for ACE only where ownership, retention, security, or lifecycle differs materially; table-per-plugin duplication is not the default.
- **V4-2-CORE-075:** D-6 is normative for the Tags layer: Tag relations and assignments SHALL target durable `TagId` roots, and the applicable `TagState` SHALL be resolved as-of. This core model SHALL NOT substitute a state-row endpoint for that durable identity.
- **V4-2-CORE-076:** D-7 is normative: internal semantic history SHALL use `State` or `Variant`. The term `Version` is reserved here for external software, package, firmware, and protocol versions.

## Tags authority boundary

C-16, C-20, C-26, FU-4, and FU-6 were ruled distinctly on 2026-08-30. The initial Tag
contract SHALL use opaque `PrincipalId`, active namespace stewardship as its authoring
gate, source reference and occurred/recorded UTC timestamps, one authoritative
`ATAPUtilities` catalog with no tenant discriminator, and
`Latin1_General_100_CI_AS_SC` for canonical/alias code comparison. SQL Server Express is
the target and trigger behavior/performance SHALL be validated there. Successor chains
may be multi-hop, reject cycles, and resolve to the first active terminal successor;
erroneous withdrawal requires a reason and has no successor as an explicit C-15
exception. A generalized approval workflow is deferred.

C-17 through C-19, C-21 through C-25, and C-27 are ruled: Tags never authorize; Tags
have no intrinsic order; relations are typed, directed, and optionally weighted while
traversal is deferred to Task 15.50.b; initial assignment types are `rule` and
`instantiation`; relations use durable roots; initial localization and legacy taxonomy
migration are omitted; a separately authorized recorded metadata inventory gates live
work; and assignment confidence/relevance is omitted until demonstrated consumer need.
