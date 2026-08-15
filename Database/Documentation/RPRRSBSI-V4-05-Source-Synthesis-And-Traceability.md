# RPRRSBSI-V4 Source Synthesis and Design Traceability

## Evidence reviewed

This first draft is based on four evidence classes: the user's RPRRSBSI V4 mobile conversation normalized to remove greetings, acknowledgements, dictation repairs, and repeated requests while preserving design intent; the active RPRRSBSI V3 schema, migrations, seeds, and core-schema documentation; the archived RRSBS/RPRRSBSI V2 logical models, decisions, migrations, and seed concepts; and every file or directory named by Sprint 0015 `InformationForTheFuture/RRSBSISourceDocList.md`.

This document records the synthesis, not a verbatim transcript. The conversation remains the authority for wording disputes; this set converts it into testable requirements.

## Normalized user requirement themes

- Treat RuleSets as ordered layers and support ATAP reference RuleSets plus ACE/user RuleSet overlays.
- Allow several keys and identities to coexist where they serve different purposes: durable GUID identity, human-readable code, namespace-scoped natural key, external registry code, and occurrence identity.
- Preserve history and as-of meaning without an internal revision-number model.
- Distinguish a basic Rule from its baseline and override variants.
- Make precedence explicit and deterministic. D-2 confirms that higher BuildSet RuleSet ordinal means higher precedence.
- Separate the graph controlling input/question flow from the graph controlling calculation dependencies and incremental recomputation.
- Store typed inputs, defaults, constraints, outputs, origins, and explanations.
- Permit user edits and overlays without modifying ATAP-distributed reference definitions.
- Provide a generic expert-system core, prove it with Tags, then begin computer-system configuration/Mechanized Engineering.
- Grow the schema through Flyway migrations and deterministic CSV seeds, beginning in `expwhertzing` only under a separate human-approved implementation task, then promote the same package through wider quality tiers and tests.

## V3 structures retained

| V3 structure                             | V4 disposition                                              | Reason                                                                    |
| ---------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------- |
| `Philote`                                | Retain and extend usage                                     | Durable shared identity for temporal semantic objects.                    |
| `PhiloteValidityPeriod`                  | Retain; add ownership-strengthening uniqueness              | Half-open as-of semantics already match the requirement.                  |
| `RuleKind`                               | Retain                                                      | Stable classification of rules and primitives.                            |
| `RulePrimitive` and `RulePrimitiveInput` | Retain; bridge to richer typed definitions                  | Existing executor/template vocabulary remains useful.                     |
| `Rule`                                   | Retain as basic semantic rule identity                      | Variants and overlays refer to, rather than copy, this identity.          |
| `RuleSet`                                | Retain                                                      | Becomes the owner/layer for variants and occurrences.                     |
| `RuleSetRule`                            | Preserve for V3 compatibility; supersede for V4 composition | Its pair key cannot represent separately identified occurrences.          |
| `BuildSet`                               | Retain                                                      | Selects the ordered RuleSet layers used to instantiate.                   |
| `BuildSetRuleSet`                        | Preserve for V3 compatibility; supersede for V4 composition | Its pair key and ambiguous order are insufficient for overlay provenance. |
| `Instantiation`                          | Retain as durable runtime root                              | New state, input, binding, and result tables attach to it.                |

## V2 concepts recovered into V4

| V2 concept or relationship                       | V4 form                                              | Recovery rationale                                               |
| ------------------------------------------------ | ---------------------------------------------------- | ---------------------------------------------------------------- |
| Entity type/object registries                    | `EntityType` → `Entity`                              | Typed generic endpoints for Tags and provenance.                 |
| Rich rule purpose/value catalogs                 | Fixed catalog tables and CSV seeds                   | Replaces free-form strings with testable contracts.              |
| Rule composition and dependency edges            | `RuleDependencyEdge` and `RuleOutputInputBinding`    | Deterministic ordering and incremental dirty propagation.        |
| RuleSet/BuildSet membership objects              | `RuleSetRuleOccurrence`, `BuildSetRuleSetOccurrence` | Recovers identity and provenance while applying D-2 ordering.    |
| Input blocks and runtime values                  | `InputBlock`, `InputBlockState`, `InputValue`        | Grouped/repeatable inputs, provenance, and editing.              |
| Context/source artifacts                         | Generic `Entity` plus provenance relationships       | Retained where explanation or ingestion requires it.             |
| Plan/approval/run/artifact/event/usage lifecycle | Layer 7 manifestation model                          | Aligns with future controlled external effects.                  |
| Tags and typed tag relations                     | Dedicated temporal Tags model                        | Directly satisfies the first specific expert-system requirement. |

## V2 decisions not carried forward

- **V4-TRACE-001:** V2 physical schemas and table names are not implementation authority; only aligned concepts and constraints are recovered.
- **V4-TRACE-002:** Internal `Version` or revision-number rows are replaced by GUID-identified `State` and `Variant` rows with Philote validity.
- **V4-TRACE-003:** Free-form polymorphic GUID endpoints are replaced by typed `Entity` endpoints.
- **V4-TRACE-004:** One all-purpose graph is rejected; workflow and calculation graphs have different invariants and tables.
- **V4-TRACE-005:** Copying a full Rule to override one context is rejected; a RuleVariant reuses the basic Rule identity.
- **V4-TRACE-006:** Table-per-plugin duplication is not the default ACE extension strategy.
- **V4-TRACE-007:** Tags are not an authorization mechanism.
- **V4-TRACE-008:** External-effecting manifestation is not coupled to definition or validation; it requires later plan and approval boundaries.

## Relationship traceability

```text
ExpertSystem -> components/entry points -> BuildSet
BuildSet -> ordered RuleSet occurrences (higher ordinal wins)
RuleSet -> ordered RuleVariant occurrences (Add/Override/Suppress)
RuleVariant -> basic Rule + temporal RuleVariantState
RuleVariant -> typed inputs/outputs -> dependency bindings
Instantiation -> frozen effective variants + input blocks + execution results
EntityType -> Entity -> TagAssignment <- Tag
Tag -> temporal TagState
Tag -> directed typed weighted TagRelation -> Tag
Plan -> Approval -> Run -> Artifact/Event/Usage (deferred Layer 7)
```

## Traceability rule for future tasks

- **V4-TRACE-020:** A derived task SHALL cite a V4 requirement ID and identify whether its authority is V3-retained, V2-recovered, user-new, or an open decision.
- **V4-TRACE-021:** If a task changes a working open decision, it SHALL update every affected schema, seed, diagram, query, and test contract before implementation begins.
- **V4-TRACE-022:** Historical documents may explain intent but SHALL NOT override the active V3 baseline or a ratified V4 decision.
