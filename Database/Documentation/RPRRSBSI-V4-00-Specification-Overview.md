# RPRRSBSI-V4 Specification Overview

> **Historical predecessor — superseded for current task authoring.** Use
> [RPRRSBSI-V4-2 Specification Overview](RPRRSBSI-V4-2-00-Specification-Overview.md)
> as the current authority. The V4 body below is retained unchanged as historical design
> context; its decision-status statements do not override V4-2 or the operator record.

Status: reconciled task-authoring specification for Sprint 0015 Stream N.

This document set expands the implemented RPRRSBSI V3/PTV database design into V4. It
consolidates the explicit operator record, the active V3 design, selectively recovered
V2 concepts, and the source inventory named by `RRSBSISourceDocList.md`. It is an input
to task creation; it does not authorize SQL, migrations, seeds, deployment, package/feed
changes, or a live database change.

Layered delivery is maintained in the editable diagram source:
[RPRRSBSI-V4-Layered-Delivery.puml](RPRRSBSI-V4-Layered-Delivery.puml). A rendered SVG
is intentionally not embedded here because the tracked render may lag the editable
source until the coordinator-owned render gate runs.

## Authority and status

The decision/status authority for this overview is the Task 15.140.a structured
operator record at
`_Planning/InformationForTheFuture/Sprint0015/StreamN/Task-15.140.a/RPRRSBSI-V4-Operator-Input.md`
and its editable D-3 companion. The operator record distinguishes Decision Register
rulings from the direct 2026-08-18 operator session. The source list and historical
V2/V3 material supply traceability and recovery evidence, but they do not override an
operator ruling or decide a pending item.

The current status boundary is:

- D-1 and D-3 through D-8 are ratified through C-01 through C-07 on 2026-08-16.
- D-2 is an earlier ratified rule explicitly retained in the operator record.
- C-08 through C-15 were ruled in the direct operator session on 2026-08-18. Their
  propagation into the Sprint 0015 Decision Register is follow-up bookkeeping, not a
  reason to describe the rulings as pending.
- C-16, C-20, C-26, FU-4, and FU-6 were distinctly ruled on 2026-08-30 and are
  normative only to the extent stated below.
- D-3 edge cases 1 through 8, C-17 through C-19, C-21 through C-25, and C-27 remain
  `HITL-PENDING`. They are questions only and have no normative force.

## Intended outcomes

V4 shall support, in increasing order of complexity:

1. A generic deterministic expert-system definition and execution model.
2. A Tags expert system that manages a temporal, directed, weighted classification
   graph and first emits a validated database-change plan.
3. The beginning of a computer-system configuration expert system, named Mechanized
   Engineering, that produces an inspectable configuration plan.
4. Later ACE-owned editing, compound instantiation, manifestation, approval, execution,
   and operational hardening.

## Normative language

`SHALL` is required for V4 conformance. `SHOULD` is the preferred design unless a task
records a contrary decision. `MAY` is optional. Requirements have stable identifiers so
another agent can derive tasks, migrations, seeds, and tests without reinterpreting
prose. Text explicitly marked `HITL-PENDING` or non-normative is not a requirement.

## Baseline and design posture

- **V4-BASE-001:** The exact V3 baseline is the eleven-table schema: `Philote`,
  `PhiloteValidityPeriod`, `RuleKind`, `RulePrimitive`, `RulePrimitiveInput`, `Rule`,
  `RuleSet`, `RuleSetRule`, `BuildSet`, `BuildSetRuleSet`, and `Instantiation`.
- **V4-BASE-002:** V4 SHALL extend V3 with forward-only Flyway migrations. It SHALL NOT
  rewrite already-applied V3 migrations.
- **V4-BASE-003:** V4 SHALL retain Philote identity and half-open business validity
  `[ValidFromUtc, ValidToUtc)` as its temporal backbone.
- **V4-BASE-004:** V2 concepts SHALL be recovered selectively where they satisfy a V4
  requirement. V2 physical tables and internal revision-number patterns SHALL NOT be
  copied wholesale.
- **V4-BASE-005:** Every migration layer SHALL be independently deployable and
  verifiable before a later layer is started.
- **V4-BASE-006:** Reference seeds SHALL use fixed registered GUIDs and deterministic
  loader behavior. Production reference data SHALL NOT depend on `NEWID()`.

## Ratified D-1 through D-8 decisions

| Decision | Authority/status | Normative specification |
| --- | --- | --- |
| D-1 / C-01 | Ratified 2026-08-16 | CSV and API GUID text SHALL use canonical lowercase dashed `D` format. Database GUID equality and joins SHALL compare native GUID values, not formatted text. |
| D-2 | Retained ratified decision | Within a BuildSet, a higher `BuildSetRuleSetOccurrence.Ordinal` SHALL have higher precedence. Resolution SHALL use `Ordinal DESC`; duplicate ordinals in one BuildSet are invalid. |
| D-3 / C-02 | Ratified 2026-08-16 | A material declared-type change SHALL create a new semantic identity and SHALL NOT mutate meaning in place. Material changes are any rule-kind change, scalar-to-different-scalar change, scalar/heap-object boundary crossing, or any heap/object-type change, including single value to collection. Default-value and display-only text changes are non-material. The eight unclassified edge cases remain pending and are not exceptions or extensions to this rule. |
| D-4 / C-03 | Ratified 2026-08-16 | An overlay SHALL be a `RuleVariant` of the same `RuleId`, selected by an occurrence whose membership role is `Override`. The Rule SHALL NOT be copied to represent an overlay. |
| D-5 / C-04 | Ratified 2026-08-16 | ATAP SHALL own immutable reference definitions; ACE SHALL own user overlays and sessions; cross-store reads SHALL use a topology-neutral union contract. |
| D-6 / C-05 | Ratified 2026-08-16 | Tag relationships and assignments SHALL point to durable `TagId` roots, with active `TagState` resolved as-of. |
| D-7 / C-06 | Ratified 2026-08-16 | Internal semantic revision rows SHALL use `State` or `Variant`, not `Version`; external software versions retain their normal terminology. |
| D-8 / C-07 | Ratified 2026-08-16 | The first computer-configuration implementation SHALL stop at a validated database-change/configuration plan. Purchasing and provisioning are later capabilities. |

## Ruled C-08 through C-15 Tags decisions

These rulings came from the direct 2026-08-18 operator session recorded in Task
15.140.a. They are normative even though the follow-up to copy them into the Sprint
0015 Decision Register remains open.

| Decision | Status | Normative specification |
| --- | --- | --- |
| C-08 | Ruled 2026-08-18 | Tags SHALL live inside `ATAPUtilities`; there is no separate `Tags` schema. |
| C-09 | Ruled 2026-08-18 | The durable `Tag` root SHALL own the Philote/GUID and immutable `(namespace, code)` natural key. `TagState` SHALL have no Philote. Codes are frozen for the Tag lifetime; aliases handle renames and state carries changeable display text. |
| C-10 | Ruled 2026-08-18 | Stewardship SHALL be recorded as data and enforced during authoring. The creator is the namespace's default steward; co-stewards are allowed and transfers retain history. C-16 supplies the opaque principal and provenance contract. |
| C-11 | Ruled 2026-08-18 | `PhiloteValidityPeriod` SHALL represent Tag identity lifespan and `TagState` as-of ranges SHALL represent payload history. No `TagState` may be active outside its Philote validity. |
| C-12 | Ruled 2026-08-18 | Typed Tag-to-Tag relations and generic `(EntityType, EntityId)` assignments are approved. Assignments SHALL target durable `TagId`; active `TagState` resolves as-of. Allowed EntityType codes remain gated by C-21. |
| C-13 | Ruled 2026-08-18 | The temporal payload row SHALL be named `TagState`, not `TagVersion`; label and description SHALL live on that state. Localization remains gated by C-23. |
| C-14 | Ruled 2026-08-18 | Aliases SHALL be temporal, namespace-local, typed by controlled vocabulary, and not reissued to another Tag after retirement. The durable root keeps the canonical code; the alias registry holds non-canonical aliases. Cross-registry uniqueness SHALL be trigger-enforced using C-26 collation and validated on SQL Server Express under FU-4. |
| C-15 | Ruled 2026-08-18 | Retraction SHALL close/gap identity validity and write a terminal `TagState`, without delete or `IsActive`; foreign keys remain `ON DELETE NO ACTION`. One transactional write path and one sanctioned read path SHALL coordinate both layers. A successor is generally required, subject to FU-6's explicit erroneous-withdrawal exception. |
| C-16 | Ruled 2026-08-30 | Actor identity SHALL be a required opaque `PrincipalId`; active namespace stewardship SHALL gate initial authoring; provenance SHALL retain a source reference and occurred-at/recorded-at UTC timestamps. A generalized approval workflow is deferred. |
| C-20 | Ruled 2026-08-30 | The initial design SHALL use one authoritative logical catalog in `ATAPUtilities` and SHALL NOT add a tenant discriminator. |
| C-26 | Ruled 2026-08-30 | Canonical and alias Tag-code comparisons SHALL use explicit `Latin1_General_100_CI_AS_SC`. |
| FU-4 | Ruled 2026-08-30 | SQL Server Express SHALL be the target free edition; trigger behavior and performance SHALL be validated there. |
| FU-6 | Ruled 2026-08-30 | Successor chains MAY be multi-hop, SHALL reject cycles, and SHALL resolve to the first active terminal successor. Erroneous withdrawal SHALL require a reason and have no successor as an explicit C-15 exception. |

## Non-normative pending gates

Nothing in this section is approved design. Recommendations in the operator record may
inform HITL review but SHALL NOT be implemented as if ruled.

### D-3 edge cases

| Case | Unresolved classification | Status |
| --- | --- | --- |
| 1 | Same-scalar nullability change | `HITL-PENDING` |
| 2 | Same-scalar precision or scale change | `HITL-PENDING` |
| 3 | Collection element-type change | `HITL-PENDING` |
| 4 | Renamed type with unchanged shape and semantics | `HITL-PENDING` |
| 5 | Default-value and type change in the same revision | `HITL-PENDING` |
| 6 | Container cardinality or shape change with unchanged element type | `HITL-PENDING` |
| 7 | String length or constraint change | `HITL-PENDING` |
| 8 | Display text that also feeds generated code or fixtures | `HITL-PENDING` |

These cases neither narrow nor widen D-3 until an explicit operator ruling is recorded
in the editable companion.

### Remaining C decisions

| Decision | Question only; no normative answer | Status |
| --- | --- | --- |
| C-17 | Tags as a hard non-authorization invariant | `HITL-PENDING` |
| C-18 | Absence of Tag ordering and valid uses of `Ordinal` | `HITL-PENDING` |
| C-19 | Typed weighted relation behavior beyond the already ruled relation existence/endpoints | `HITL-PENDING` |
| C-21 | Allowed `EntityType` codes, including `rule` and `instantiation` | `HITL-PENDING` |
| C-22 | Whether Tag relations join durable roots or exact states | `HITL-PENDING` |
| C-23 | Whether localization is required in the first migration | `HITL-PENDING` |
| C-24 | Whether to migrate any legacy filing taxonomy rows | `HITL-PENDING` |
| C-25 | Whether a live `Tags` schema exists; any inventory requires separate authorization | `HITL-PENDING` |
| C-27 | Per-assignment confidence or relevance | `HITL-PENDING` |

### Ruled follow-ups

- **FU-4 — RULED 2026-08-30:** target SQL Server Express and validate trigger behavior
  and performance there.
- **FU-6 — RULED 2026-08-30:** allow multi-hop successor chains, reject cycles, resolve
  to the first active terminal successor, and require a reason with no successor for
  erroneous withdrawal as an explicit C-15 exception.

## Document map

| Document | Task-authoring purpose |
| --- | --- |
| [RPRRSBSI-V4 Source Synthesis and Design Traceability](RPRRSBSI-V4-05-Source-Synthesis-And-Traceability.md) | Normalized requirements and explicit V3-retained/V2-recovered design mapping. |
| [RPRRSBSI-V4 Core Schema Enhancements](RPRRSBSI-V4-10-Core-Schema-Enhancements.md) | Tables, keys, constraints, overlay semantics, graphs, and execution state. |
| [RPRRSBSI-V4 Seed Data and Loader Specification](RPRRSBSI-V4-20-Seed-Data-And-Loaders.md) | CSV inventory, loader contract, reference seeds, and migration quality gates. |
| [RPRRSBSI-V4 Tags Expert System Specification](RPRRSBSI-V4-30-Tags-Expert-System.md) | The first specific expert system and its graph semantics. |
| [RPRRSBSI-V4 Mechanized Engineering Specification](RPRRSBSI-V4-40-Mechanized-Engineering.md) | Initial computer-system configuration inputs, rules, and outputs. |
| [RPRRSBSI-V4 Layered Implementation Handoff](RPRRSBSI-V4-50-Layered-Implementation-Handoff.md) | Ordered work packages, tests, promotion gates, and definition of done. |

## Scope boundary

This specification defines documentation-level schema, seed, loader, query, and
behavioral contracts. It does not execute Flyway against `expwhertzing`, promote a
package, access credentials, purchase components, or run provisioning. Those are
separate implementation tasks with named human-in-the-loop gates.
