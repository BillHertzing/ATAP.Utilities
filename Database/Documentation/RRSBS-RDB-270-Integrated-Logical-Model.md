# RDB-270 — Integrated Logical Model and Draft Data Dictionary

Status: Wave 3 design-only integration contract. This is not SQL, a migration,
seed data, package/feed work, scanner/renderer work, or authorization for a
live target.

## Integration decisions

1. A cross-slice reference uses an exact immutable identity or typed relation;
   names, hashes, labels, and an untyped `EntityId` never substitute for a FK.
2. `Entity` is the only polymorphic supertype. Every subtype has one closed
   `EntityTypeCode`; endpoint and typed-value policies use closed allow-lists.
3. Versioned relations target exact versions. A durable root cannot substitute
   for a version, and same-parent/same-kind composite checks remain mandatory.
4. RDB-240's `BuildSetRuleOccurrence` is the canonical bridge from selected
   BuildSet membership to an exact RuleVersion. RDB-250 consumes that bridge.
5. `SourceArtifactVersion` is the content-evidence endpoint. ContentSummary
   and AgentText are derived and cannot edit source, Rule, or authority facts.

## Draft data dictionary

Local column definitions stay owned by their source slices. This dictionary
publishes integration ownership, identity class, and cross-slice purpose.

| Slice | Tables / catalog family | Identity class | Integrated responsibility |
| --- | --- | --- | --- |
| RDB-200 | `EntityType`, `Entity`, endpoint policy; Authority/Expert/Domain/Tag, assignment, Attribution/dispute families | catalog / Entity / relation | Closed polymorphic identity, typed assertions, classification, and authority vocabulary. |
| RDB-210 | RuleKind, executor, value-type, primitive, grammar, and policy families | Entity / catalog | Exact RuleKind/Primitive/ValueType contracts and fail-closed capability metadata. |
| RDB-220 | Rule/RuleVersion, nodes, inputs, defaults, outputs | Entity / relation | Immutable recursive Rule composition using exact RDB-210 contracts. |
| RDB-230 | RuleSet/BuildSet, versions, and members | Entity / relation | Ordered repeatable membership without identity collapse. |
| RDB-240 | Instantiation, occurrence, binding, InputBlock/value, permission, session families | Entity / relation | Selected occurrence and typed input-snapshot boundary. |
| RDB-250 | plan, approval, manifestation, attempt, execution, artifact, event, usage families | Entity / relation | Approved plan-to-observed-run provenance and idempotent execution evidence. |
| RDB-260 | context, artifact/version/lineage, summary/version/dependency, projection/version/refresh families | Entity / relation | Context plus append-only source and derived-content provenance. |

## Foreign-key closure

| Consumer | Required exact parent(s) | Fail-closed rule |
| --- | --- | --- |
| Any Entity subtype | `Entity(EntityTypeId, EntityId)` | The subtype has a matching closed type; no generic endpoint bypass. |
| RuleKind/Primitive versions | durable parent, same-parent predecessor, exact RuleKind/ValueType contracts | Revision and predecessor are parent-scoped; value shape is allow-listed. |
| RuleVersion node/input/output | exact RuleVersion, PrimitiveVersion, RuleKindVersion, ValueTypeVersion | Node primitive kind equals owner RuleVersion kind; an input selects exactly one permitted typed shape. |
| RuleSet/BuildSet members | exact parent and child version | `(parent version, MemberOccurrenceKey)` and ordinal are unique; repeated children are valid. |
| RDB-240 occurrence / selection | exact BuildSet-member, RuleSet-member, RuleVersion, Instantiation, binding, InputBlockVersion | Composite keys prove one BuildSetVersion, compatible occurrence, common Instantiation, and exact type/cardinality. |
| RDB-250 plan / approval / execution | exact InstantiationVersion, occurrence, RuleVersion, plan/approval, attempt, artifact slot | An approval repeats plan-bound identity/fingerprint facts; execution rule equals occurrence rule; one producer per artifact slot. |
| RDB-250 usage | typed subject Entity/version and exact RuleVersion | Closed role plus observed/planned source fact; no bare Rule claim. |
| RDB-260 artifact / summary | Repository, SourceArtifact, exact SourceArtifactVersion, prompt/render RuleVersion | Repository path is binary/root-independent; a summary uses its own artifact's version. |
| RDB-260 dependency / projection | typed SourceArtifactVersion or controlled external ref; exact summary inputs | One typed target; no future input or freshness claim beyond watermark. |

## EntityType allow-list closure

Numeric IDs, GUIDs, and seeds remain RDB-320/RDB-500. These semantic codes are
the Wave 3 closed registration set.

| Owner | EntityType codes |
| --- | --- |
| RDB-200 | `authority`, `authority-version`, `expert`, `expert-version`, `expertise-domain`, `expertise-domain-version`, `tag`, `tag-version`, `attribution`, `attribution-dispute` |
| RDB-210 | `rule-kind`, `rule-kind-version`, `executor-contract`, `executor-contract-version`, `primitive`, `primitive-version`, `primitive-input-definition`, `value-type`, `value-type-version`, `structured-value-contract`, `structured-value-contract-version` |
| RDB-220 | `rule`, `rule-version`, `rule-input-definition`, `rule-default-input-value`, `rule-output-definition` |
| RDB-230 | `rule-set`, `rule-set-version`, `build-set`, `build-set-version` |
| RDB-240 | `instantiation`, `instantiation-version`, `input-block`, `input-block-version` |
| RDB-250 | `manifestation-plan`, `plan-approval`, `manifestation`, `manifestation-artifact` |
| RDB-260 | `organization`, `repository`, `source-artifact`, `content-summary`, `agent-text-projection` |

Tags and ExpertiseDomains remain classification; neither can grant an RDB-240
permission or authorize an RDB-250 operation. A new endpoint/type requires an
approved logical-model amendment, not a wildcard policy row.

## Dictated-concept coverage and gates

| Concept | Integrated representation | Status |
| --- | --- | --- |
| Immutable identity/version/Philote | RDB-200 Entity plus durable/version tables | covered |
| Typed Entity references | closed EntityType, endpoint, and ValueType policies | covered |
| Grammar, values, SecretName boundary | RDB-210 exact contracts | covered; resolution deferred |
| Recursive Rule and repeatable membership | RDB-220 graph and RDB-230/240 occurrence bridge | covered |
| Inputs, permission, plan, approval, execution | RDB-240/250 immutable provenance | covered |
| Source, ContentSummary, AgentText provenance | RDB-260 exact source/version and watermarks | covered |
| Physical constraints and invalid-row execution | RDB-280 and RDB-400–460 | deliberately deferred |

RDB-280 adversarially proves invalid rows are rejected. RDB-320 owns physical
names, IDs, GUIDs, and registries; RDB-400–460 own migrations and database
enforcement. No physical or live-system outcome is claimed by this document.
