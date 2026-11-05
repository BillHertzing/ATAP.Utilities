# RPRRSBSI-V5 Core Schema Enhancements

> **V5 revision (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Successor of `Database/Documentation/RPRRSBSI-V4-2-10-Core-Schema-Enhancements.md`. Requirement and decision IDs keep their V4-2 numbers with the prefix `V5-` (for example `V4-2-CORE-034` is now `V5-CORE-034`); a V4-2 ID that is not repeated here is withdrawn only where the "V5 changes" section says so. The V5 decisions DEC-1 to DEC-6 and the 2026-11-05 training and gamification requirements are summarised in [the V5 overview](RPRRSBSI-V5-00-Specification-Overview.md#v5-decisions); open items are in [HANDOFF-V5.md](HANDOFF-V5.md). **Terminology (DEC-6):** an *Instantiation* is a produced file or row; the run of an executor that produces instantiations is a *Materialization*; the reusable configuration it runs is a *materialization specification*. Where carried-forward V4-2 text uses "Instantiation" for the configured act, read "materialization specification".


Status: reconciled task-authoring design. This document defines no migration, seed,
deployment, or live-database action.

## V5 changes

| Change | Requirement IDs | Source |
| --- | --- | --- |
| Build status recorded against migrations V00010–V00210 | annotations below | SQL on `150-Sprint-0017-work-items` |
| Runtime tables renamed to the Materialization vocabulary; the `Instantiation` noun redefined | V5-CORE-060…063, new V5-CORE-064…069 | DEC-6, DEC-7, DEC-8; [V5-12](RPRRSBSI-V5-12-Instantiation-And-Materialization.md) |
| Ownership boundary rewritten: Ace is a full copy with owner columns | V5-CORE-071, V5-CORE-074 (amended), new V5-CORE-077…079 | DEC-3, DEC-9; [V5-60](RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md) |
| C-20 amended in the Tags authority boundary | Tags section | DEC-3 |
| General entity registry: role confirmed as the typed target for row instantiations | V5-CORE-010…013 | DEC-6 |
| Gamification, training, organization, estate and authentication tables | not here | [V5-62](RPRRSBSI-V5-62-Organization-Identity-Products-And-Estates.md), [V5-65](RPRRSBSI-V5-65-Protected-Authentication.md), [V5-70](RPRRSBSI-V5-70-Training-And-Gamification.md) |

**Build status (checked in SQL, 2026-11-05).** Built by `V00080`: `ValueType` (10 values), `InputNormalizationContract`, `RuleInputDefinition(+State)`, `RuleDefaultInputValue`, `RuleOutputDefinition(+State)`, `RuleValueConstraint`, `RuleVariant(+State)` with `UNIQUE (RuleVariantId, OwningRuleSetId)` and the composite foreign key from `RuleSetRuleOccurrence`, `RuleSetMembershipRole` (`Add`/`Override`/`Suppress`), `BuildSetRuleSetOccurrence`, and `ResolveBuildSetRulesAsOf` ordering BuildSet occurrences by `Ordinal DESC`. `ScalarStorageKind` exists only as the column `ValueType.StorageKindCode`. **Not built:** `EntityType`/`Entity`, the ExpertSystem family, the input-workflow and calculation graphs, and every runtime table. The three integration aggregates below were built in a different shape: ContentSummary as `SourceArtifact`/`ContentSummaryVersion` (V00100), AISupervisor without a header table (V00070), scheduled work not at all.

## Carried-forward V4-2 core expansion

V4-2 retains every V4 core entity and adds three bounded integration aggregates:

| Aggregate | Plane | Required roots |
| --- | --- | --- |
| ContentSummary ingestion | Ace plus selective Outpost projection | `ContentSummaryIngestion`, `ContentSummaryItem`, `ContentSummaryItemTag` |
| AISupervisor telemetry | Ace plus bounded Outpost buffer | `AISupervisorExchange`, `AISupervisorHeader`, `AISupervisorMetric` |
| Scheduled work and synchronization | Outpost-local with central acknowledgments | run/checkpoint, outbound envelope, cursor, acknowledgment, failure |

- **V5-CORE-080:** These aggregates SHALL attach to existing tenant and provenance contracts without granting plugins direct database access.
- **V5-CORE-081:** ContentSummary Tag associations SHALL reference durable ATAPUtilities `TagId` roots and resolve `TagState` as-of.
- **V5-CORE-082:** AISupervisor mutable telemetry SHALL reside in `Ace` and SHALL not become authoritative reference data.
- **V5-CORE-083:** Controlled child metrics SHALL absorb provider metadata evolution; an unbounded JSON property bag SHALL not replace typed primary exchange fields.
- **V5-CORE-084:** Central cross-schema relationships SHALL remain topology-neutral and use physical foreign keys only where ownership and deployment topology make them durable.

Authoritative diagram source:
[RPRRSBSI-V5-Core-Entity-Model.puml](RPRRSBSI-V5-Core-Entity-Model.puml). The tracked
SVG is not embedded here because it was not regenerated during this source-only
reconciliation.

## Decision boundary

D-1 through D-7 are normative here: D-1 and D-3 through D-7 were ratified on
2026-08-16, and D-2 is the retained ratified precedence rule. C-16, C-20, C-26, FU-4,
and FU-6 were ruled on 2026-08-30. The eight D-3 edge cases, C-17 through C-19,
C-21 through C-25, and C-27 were ruled on 2026-09-04.

## Identity and temporal foundation

- **V5-CORE-001:** All newly introduced semantic identities SHALL initially use `uniqueidentifier` primary keys and SHALL have application-level typed-ID wrappers.
- **V5-CORE-002:** Each Philote-bearing table SHALL use the entity primary-key GUID as its `PhiloteId`, preserving the V3 shared-identity convention.
- **V5-CORE-003:** `PhiloteValidityPeriod` SHALL gain a unique constraint on `(PhiloteId, PhiloteValidityPeriodId)` so dependent state rows can prove that a validity period belongs to the expected identity.
- **V5-CORE-004:** For any Philote, validity periods SHALL be non-overlapping half-open intervals. Gaps are allowed. A null `ValidToUtc` means open ended.
- **V5-CORE-005:** Internal semantic change SHALL be represented by new GUID-identified `State` or `Variant` rows and validity periods, not by an integer or string revision number.
- **V5-CORE-006:** External product, package, firmware, and protocol versions remain domain values and are not prohibited by V5-CORE-005.
- **V5-CORE-007:** CSV and API representations of GUIDs SHALL use canonical lowercase dashed `D` format.
- **V5-CORE-008:** Database GUID equality, joins, uniqueness, and referential checks SHALL operate on native `uniqueidentifier` values. Implementations SHALL NOT obtain identity semantics by casting GUIDs to text or comparing their spelling, case, or collation.

## General entity registry

| Table        | Required columns and constraints                                                  | Purpose                                                            |
| ------------ | --------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `EntityType` | `EntityTypeId` PK, `PhiloteId` FK, unique `EntityTypeCode`, name, description     | Stable catalog of addressable semantic kinds.                      |
| `Entity`     | `EntityId` PK, `PhiloteId` FK, `EntityTypeId` FK, optional owning-system identity | A durable endpoint for Tags, provenance, and generic associations. |

- **V5-CORE-010:** Every entity kind admitted to generic association SHALL have a fixed seeded `EntityType` identity.
- **V5-CORE-011:** Generic associations SHALL reference `Entity`, not an unconstrained GUID whose type cannot be checked.
- **V5-CORE-012:** Admission of a local table to `EntityType` SHALL be checked against the schema registry during seed validation.
- **V5-CORE-013 (new):** The registry SHALL be the typed target for every *row* instantiation (DEC-6): an `Instantiation` that is a database row references `(EntityTypeId, EntityId)`, never an unchecked schema/table/key string. Until the registry is built, the built `ATAPUtilities.TagAssignmentEntityType` catalog (V00090, which already names target schema, table and id column) MAY serve as the interim type catalog. Every `Ace` copy of a table is a distinct `EntityType` from its `ATAPUtilities` template (DEC-3).

## Expert-system definition

| Table                    | Key relationships                                 | Purpose                                                                                    |
| ------------------------ | ------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `ExpertSystem`           | Philote-bearing root                              | Stable identity and code for a generic or specific expert system.                          |
| `ExpertSystemState`      | `ExpertSystemId`, matching validity period        | Temporal name, description, lifecycle state, and default entry point.                      |
| `ExpertSystemComponent`  | `ExpertSystemId`, `EntityId`, role, ordinal       | Associates RuleSets, BuildSets, workflows, and other components without hiding their type. |
| `ExpertSystemEntryPoint` | `ExpertSystemId`, workflow node or BuildSet, code | Declares supported starts such as create, edit, validate, and explain.                     |

- **V5-CORE-020:** A generic expert system SHALL be definable entirely from catalog, rule, graph, and seed data; system-specific tables MAY be added only for irreducibly domain-specific facts.
- **V5-CORE-021:** Every runtime result SHALL be traceable to the expert system, BuildSet, effective rule variants, input values, and as-of instant used.
- **V5-CORE-022:** Definition data SHALL be immutable through normal application operations. Corrections create new states, variants, or overlay definitions.

## Rule variants and ordered occurrences

V3 has a basic `Rule` and set-membership joins. V4 keeps the basic identity and adds explicit variant and occurrence identities so the same rule can be supplied, overridden, suppressed, ordered, and explained without copying its definition.

| Table                       | Required columns and constraints                                                                                            |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `RuleVariant`               | PK and Philote; same-basic-rule `RuleId` FK; owning `RuleSetId` FK; unique variant code within owner; unique `(RuleVariantId, OwningRuleSetId)` owner key. |
| `RuleVariantState`          | PK; `RuleVariantId`; matching validity period; purpose; executor contract; normalized body/configuration; lifecycle status. |
| `RuleSetRuleOccurrence`     | PK; `RuleSetId`; `RuleVariantId`; membership role; `Ordinal`; optional condition; unique ordinal within RuleSet; composite FK `(RuleVariantId, RuleSetId)` to the variant owner key. |
| `BuildSetRuleSetOccurrence` | PK; `BuildSetId`; `RuleSetId`; `Ordinal`; optional condition; unique ordinal within BuildSet.                               |
| `RuleSetMembershipRole`     | Fixed values `Add`, `Override`, `Suppress`.                                                                                 |

- **V5-CORE-030:** `RuleVariant.RuleId` SHALL identify the basic semantic rule being varied.
- **V5-CORE-031:** A baseline ATAP variant and an ACE override variant MAY reference the same `RuleId`; their `RuleVariantId` and owning RuleSet SHALL differ.
- **V5-CORE-031A:** D-4 is normative: an overlay SHALL be a `RuleVariant` of the same `RuleId`, and an occurrence with membership role `Override` SHALL select it. An implementation SHALL NOT copy the basic `Rule` to represent an overlay.
- **V5-CORE-031B:** A `RuleSetRuleOccurrence` SHALL select only a `RuleVariant` owned by
  that same RuleSet. Cross-owner selection is prohibited. The physical contract SHALL
  expose `UNIQUE (RuleVariantId, OwningRuleSetId)` and enforce the occurrence pair
  `(RuleVariantId, RuleSetId)` through a composite foreign key to that owner key.
- **V5-CORE-031C:** Conformance tests SHALL reject an occurrence whose `RuleSetId`
  differs from the selected variant's `OwningRuleSetId`, even when the variant shares the
  expected `RuleId` and the occurrence role is `Override`.
- **V5-CORE-032:** Membership and BuildSet composition SHALL use occurrence identities; the V3 composite join tables remain readable during transition but SHALL NOT constrain V4 to one occurrence per pair.
- **V5-CORE-033:** A RuleSet SHALL reject duplicate occurrence ordinals. A BuildSet SHALL reject duplicate `BuildSetRuleSetOccurrence.Ordinal` values; duplicate ordinals in one BuildSet are invalid input and SHALL NOT be tie-broken.
- **V5-CORE-034:** D-2 is normative: effective resolution SHALL order BuildSet RuleSet occurrences by `Ordinal DESC`; the higher ordinal has higher precedence.

Authoritative diagram source:
[RPRRSBSI-V5-Rule-Overlay-Resolution.puml](../RPRRSBSI-V4-2-Rule-Overlay-Resolution.puml).
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

- **V5-CORE-035:** Resolution SHALL be deterministic for identical stored data and as-of instant.
- **V5-CORE-036:** Invalid overlay graphs SHALL be rejected before instantiation and SHALL NOT be resolved by accidental insertion order.

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

- **V5-CORE-040:** Typed values SHALL use a discriminated representation with at most one populated physical value column consistent with `ScalarStorageKind`.
- **V5-CORE-041:** Secret values SHALL NOT be stored as seed or runtime plaintext. The stored value is a secret name/reference only.
- **V5-CORE-042:** Defaults SHALL be distinguishable from user-supplied, imported, calculated, and inherited values.
- **V5-CORE-043:** Every normalization operation SHALL be deterministic, identified, and included in execution provenance.
- **V5-CORE-044:** D-3 is normative: a material declared-type change SHALL create a new basic semantic identity. Existing identities SHALL NOT be mutated to carry a materially different meaning.
- **V5-CORE-045:** The 2026-08-16 material classes are (1) any rule-kind change;
  (2) scalar-to-different-scalar; (3) scalar/heap-object boundary crossing; and (4) any
  heap/object-type change, including single value to collection. V5-CORE-045A and
  V5-CORE-045B add the edge classifications ruled on 2026-09-04.
- **V5-CORE-045A:** The 2026-09-04 edge rulings additionally classify nullability,
  precision/scale, collection element type, container cardinality/shape, and string-length
  or declared-domain constraint changes as material. A declared contract-type rename is
  material; a separate display alias is non-material. Text consumed by code, fixtures,
  or contracts is material.
- **V5-CORE-045B:** A simultaneous type/default change is one material transition; the
  default is the replacement definition's initial state.
- **V5-CORE-046:** A default-value change and a change to text used only for visual display are non-material and MAY retain the existing semantic identity, while still using the applicable state/validity history.

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

- **V5-CORE-046A:** Every new identity in the table SHALL receive a separately
  registered GUID before it is referenced by seed, migration, API, or fixture data.
- **V5-CORE-046B:** No implementation SHALL update `RuleId`, `RuleVariantId`,
  `RuleInputDefinitionId`, `RuleOutputDefinitionId`, declared type, or storage
  discriminant in place to simulate a material transition.
- **V5-CORE-046C:** Positive fixtures SHALL prove all four material rows allocate the
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
[RPRRSBSI-V5-Input-And-Execution-Graphs.puml](RPRRSBSI-V5-Instantiation-And-Materialization.puml).
The tracked SVG is not embedded here because it was not regenerated during this
source-only reconciliation.

| Graph                  | Tables                                                                              | Semantics                                                               |
| ---------------------- | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Input workflow         | `InputWorkflow`, `InputWorkflowNode`, `InputWorkflowEdge`, `InputWorkflowCondition` | Controls what is asked, grouped, skipped, revisited, or explained.      |
| Calculation dependency | `RuleDependencyEdge`, `RuleOutputInputBinding`                                      | Controls dependency order, invalidation, and incremental recomputation. |

- **V5-CORE-050:** The two graphs SHALL NOT be conflated into one general edge table.
- **V5-CORE-051:** Calculation dependencies SHALL form a directed acyclic graph after effective overlay resolution.
- **V5-CORE-052:** Workflow cycles MAY exist only when explicitly bounded by a validation rule.
- **V5-CORE-053:** Bindings SHALL be type-compatible after normalization; incompatible bindings fail validation before execution.

## Runtime: materialization and instantiation

V5 replaces the V4-2 runtime table list with the Materialization vocabulary (DEC-6, DEC-7, DEC-8). Full contract: [V5-12 Instantiation and Materialization](RPRRSBSI-V5-12-Instantiation-And-Materialization.md).

| V4-2 table | V5 table | Purpose |
| --- | --- | --- |
| `Instantiation` (V00010, built) | `MaterializationSpecification` (renamed by forward migration, DEC-8) | Reusable configuration: BuildSet, input binding, materializer. |
| `InstantiationState` | `MaterializationSpecificationState` | Temporal lifecycle of a specification. |
| `EditSession` | `EditSession` (unchanged; also used by DDL authoring, V5-15) | User editing boundary with optimistic concurrency token. |
| `InstantiationRuleBinding` | `MaterializationRuleBinding` | Frozen effective RuleVariants used by one materialization. |
| `InputBlock` / `InputBlockState` | unchanged | Grouped, repeatable, temporal set of inputs. |
| `InputValue` | `MaterializationInputValue` | Typed value, origin, normalized form, confidence and provenance used by one materialization. |
| `InstantiationNodeState` | `MaterializationNodeState` | Workflow progress and validation state. |
| `DirtyWorkItem` | unchanged | Minimal invalidated calculation target and cause. |
| `ExecutionAttempt` | `MaterializationAttempt` | Materializer, inputs hash, start/end, status, diagnostics. |
| `ExecutionResult` | **`Instantiation`** (new table, DEC-8) | One produced file or row, with origin `Asserted` or `Generated`. |
| — | `Materialization` (new) | One run of a materializer for a specification, by an acting user on behalf of an owner. |
| — | `InstantiationSupersession` (new) | An `Asserted` instantiation replaced by a `Generated` one. |

- **V5-CORE-060:** Changing an input SHALL dirty only the reachable dependent calculation subgraph.
- **V5-CORE-061:** A materialization SHALL be idempotent for the same effective definition and normalized input hash unless the materializer is explicitly classified otherwise.
- **V5-CORE-062:** Materialization failures SHALL preserve diagnostics without replacing the last valid instantiation.
- **V5-CORE-063:** Materialization rule bindings SHALL make later explanation independent of subsequent definition changes.
- **V5-CORE-064 (new):** Every `Instantiation` SHALL carry `OriginKind` `Asserted` or `Generated` (DEC-1). A `Generated` instantiation SHALL reference exactly one `Materialization`; an `Asserted` one SHALL reference none and SHALL record the asserting user and evidence.
- **V5-CORE-065 (new):** An `Asserted` instantiation MAY name the materialization specification intended to produce it later, so the work-backwards path exists before the rules do.
- **V5-CORE-066 (new):** Replacing an `Asserted` instantiation SHALL close it and record an `InstantiationSupersession` to its `Generated` successor with comparison evidence; neither row is updated or deleted.
- **V5-CORE-067 (new):** A file instantiation SHALL reference a `SourceArtifact`/`SourceArtifactVersion` (repository-relative identity, V00100); a row instantiation SHALL reference a typed entity (V5-CORE-013).
- **V5-CORE-068 (new):** Every `Materialization` SHALL record the acting user and the owner (user or organization) on whose behalf it ran (DEC-3).
- **V5-CORE-069 (new):** Rules that govern AI agents SHALL be representable as file instantiations; the current `.ai/core/main-instructions.md` is the intended first `Asserted` file instantiation (DEC-10, ADR-018).

## ATAP and ACE ownership boundary

Rewritten for V5 (DEC-3, DEC-9). Full contract: [V5-60 Ownership and the Ace Copy](RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md).

- **V5-CORE-070:** ATAP SHALL own distributable reference catalogs, reference expert systems, baseline RuleSets, RuleVariants, reference Tags and every other *template* row. `ATAPUtilities` data is open: anyone may read it through approved read surfaces.
- **V5-CORE-071 (amended):** ACE SHALL own all user- and organization-owned data: overlays, edit sessions, user input, user Tags, materializations and instantiations, developer-authored tables, marketplace activations, training progress and gamification choices.
- **V5-CORE-072 (unchanged):** ATAP SHALL NOT require a foreign key into an ACE database or schema.
- **V5-CORE-073 (unchanged):** D-5 is normative: effective reads across ATAP and ACE SHALL use a topology-neutral union contract with explicit source authority and deterministic precedence.
- **V5-CORE-074 (amended 2026-11-05, replaces the V4-2 text):** `Ace` SHALL contain, for every `ATAPUtilities` table, a table of the same name with the same columns, constraints and behaviour, plus owner columns. `Ace` MAY contain additional tables. Every `Ace` table SHALL carry owner columns. An `ATAPUtilities` table SHALL NOT carry owner columns. The V4-2 rule "separate tables only where ownership differs; table-per-plugin duplication is not the default" is withdrawn.
- **V5-CORE-075:** D-6 is normative for the Tags layer: Tag relations and assignments SHALL target durable `TagId` roots, and the applicable `TagState` SHALL be resolved as-of. This applies in both schemas.
- **V5-CORE-076:** D-7 is normative: internal semantic history SHALL use `State` or `Variant`. `Version` is reserved for external software, package, firmware and protocol versions.
- **V5-CORE-077 (new):** Owner columns are `OwnerUserId`, `OwnerOrganizationId` and `CreatedByUserId`. Exactly one of the first two is set. Ownership changes are temporal state, never updates.
- **V5-CORE-078 (new):** The identity and temporal registry (`ATAPUtilities.Philote`, `ATAPUtilities.PhiloteValidityPeriod`) is shared by both schemas and is not copied, so GUIDs stay globally unique (recommended interpretation of DEC-3; confirmation requested in HANDOFF-V5).
- **V5-CORE-079 (new):** Changes start in `Ace` after the common initial load; a change reaches `ATAPUtilities` only through the bolt-on submission process (V5-15) or a reviewed core migration (DEC-9).

## Tags authority boundary

C-16, C-20, C-26, FU-4, and FU-6 were ruled distinctly on 2026-08-30. The initial Tag
contract SHALL use opaque `PrincipalId`, active namespace stewardship as its authoring
gate, source reference and occurred/recorded UTC timestamps, one authoritative
`ATAPUtilities` template catalog with no tenant discriminator **(C-20 as amended 2026-11-05: `Ace` holds a full copy of every Tag table with owner columns; Ace Tags are owned by a user or organization and are visible according to that ownership; resolution across both uses the D-5 union contract)**, and
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
