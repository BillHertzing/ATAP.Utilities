# RPRRSBSI-V4 Specification Overview

Status: first implementable specification draft for Sprint 0015 Stream N.

This document set expands the RPRRSBSI V3 database design into V4. It consolidates the user requirements captured in the RPRRSBSI V4 conversation, the active V3 design, relevant V2 entities and relationships, and the source inventory named by `RRSBSISourceDocList.md`. It is written as an input to task creation; it does not authorize a live database change.

![RPRRSBSI-V4 layered delivery](Images/RPRRSBSI-V4-Layered-Delivery.svg)

Editable diagram source: [RPRRSBSI-V4-Layered-Delivery.puml](RPRRSBSI-V4-Layered-Delivery.puml).

## Intended outcomes

V4 shall support, in increasing order of complexity:

1. A generic deterministic expert-system definition and execution model.
2. A Tags expert system that manages a temporal, directed, weighted classification graph and first emits a validated database-change plan.
3. The beginning of a computer-system configuration expert system, named Mechanized Engineering, that produces an inspectable configuration plan.
4. Later ACE-owned editing, compound instantiation, manifestation, approval, execution, and operational hardening.

## Normative language

`SHALL` is required for V4 conformance. `SHOULD` is the preferred design unless a task records a contrary decision. `MAY` is optional. Requirements have stable identifiers so another agent can derive tasks, migrations, seeds, and tests without reinterpreting prose.

## Baseline and design posture

- **V4-BASE-001:** The exact V3 baseline is the eleven-table schema: `Philote`, `PhiloteValidityPeriod`, `RuleKind`, `RulePrimitive`, `RulePrimitiveInput`, `Rule`, `RuleSet`, `RuleSetRule`, `BuildSet`, `BuildSetRuleSet`, and `Instantiation`.
- **V4-BASE-002:** V4 SHALL extend V3 with forward-only Flyway migrations. It SHALL NOT rewrite already-applied V3 migrations.
- **V4-BASE-003:** V4 SHALL retain Philote identity and half-open business validity `[ValidFromUtc, ValidToUtc)` as its temporal backbone.
- **V4-BASE-004:** V2 concepts SHALL be recovered selectively where they satisfy a V4 requirement. V2 physical tables and internal revision-number patterns SHALL NOT be copied wholesale.
- **V4-BASE-005:** Every migration layer SHALL be independently deployable and verifiable before a later layer is started.
- **V4-BASE-006:** Reference seeds SHALL use fixed registered GUIDs and deterministic loader behavior. Production reference data SHALL NOT depend on `NEWID()`.

## Ratified decisions

| Decision | Status              | Specification                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| -------- | ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D-1      | Ratified 2026-08-16 | CSV and API GUID text SHALL use canonical lowercase dashed `D` format. Database GUID equality and joins SHALL compare native GUID values, not formatted text.                                                                                                                                                                                                                                                                                                                                                                                              |
| D-2      | Ratified 2026-08-14 | Within a BuildSet, a higher `BuildSetRuleSetOccurrence.Ordinal` has higher precedence. Resolution orders occurrences by `Ordinal DESC`. Duplicate ordinals in one BuildSet are invalid.                                                                                                                                                                                                                                                                                                                                                                     |
| D-3      | Ratified 2026-08-16 | A material declared-type change SHALL create a new semantic identity and SHALL NOT mutate meaning in place. Material changes are any rule-kind change; a scalar type changing to a different scalar type; any scalar/heap-object boundary change; and any change involving a heap/object type, including a single value becoming a collection. Default-value changes and display-only text changes are non-material. Unclassified edge cases remain explicit clarification items rather than inferred exceptions. |
| D-4      | Ratified 2026-08-16 | An overlay SHALL be a `RuleVariant` of the same `RuleId`, selected by an occurrence with membership role `Override`. The rule SHALL NOT be copied to represent an overlay.                                                                                                                                                                                                                                                                                                                                                                                    |

## Decisions still requiring ratification

| Decision                   | Working specification                                                                                                                     | Effect if changed                      |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| D-5 ATAP/ACE topology      | ATAP owns immutable reference definitions; ACE owns user overlays and sessions; cross-store reads use a topology-neutral union contract.  | Foreign keys and deployment packaging. |
| D-6 durable Tag endpoints  | Tag relationships and assignments point to durable identities; temporal states provide the as-of meaning.                                 | Tag FK details.                        |
| D-7 terminology            | Do not use `Version` for internal semantic revision rows; use `State` or `Variant`. External software versions retain their normal names. | Naming across schema and code.         |
| D-8 manifestation scope    | The first computer-configuration implementation stops at a validated plan; purchasing and provisioning are later capabilities.            | Sprint boundary.                       |

## Document map

| Document                                                                                                    | Task-authoring purpose                                                             |
| ----------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| [RPRRSBSI-V4 Source Synthesis and Design Traceability](RPRRSBSI-V4-05-Source-Synthesis-And-Traceability.md) | Normalized user requirements and explicit V3-retained/V2-recovered design mapping. |
| [RPRRSBSI-V4 Core Schema Enhancements](RPRRSBSI-V4-10-Core-Schema-Enhancements.md)                          | Tables, keys, constraints, overlay semantics, graphs, and execution state.         |
| [RPRRSBSI-V4 Seed Data and Loader Specification](RPRRSBSI-V4-20-Seed-Data-And-Loaders.md)                   | CSV inventory, loader contract, reference seeds, and migration quality gates.      |
| [RPRRSBSI-V4 Tags Expert System Specification](RPRRSBSI-V4-30-Tags-Expert-System.md)                        | The first specific expert system and its graph semantics.                          |
| [RPRRSBSI-V4 Mechanized Engineering Specification](RPRRSBSI-V4-40-Mechanized-Engineering.md)                | Initial computer-system configuration inputs, rules, and outputs.                  |
| [RPRRSBSI-V4 Layered Implementation Handoff](RPRRSBSI-V4-50-Layered-Implementation-Handoff.md)              | Ordered work packages, tests, promotion gates, and definition of done.             |

## Scope boundary

This specification defines schema, seed, loader, query, and behavioral contracts. It does not execute Flyway against `expwhertzing`, promote a package, access credentials, purchase components, or run provisioning. Those are separate implementation tasks with named human-in-the-loop gates.
