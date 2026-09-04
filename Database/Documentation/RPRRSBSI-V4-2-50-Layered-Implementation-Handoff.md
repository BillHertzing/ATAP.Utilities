# RPRRSBSI-V4-2 Layered Implementation Handoff

Status: reconciled task-authoring handoff for Task 15.140.b. This document authorizes
documentation and task decomposition only. It does not authorize SQL, Flyway changes,
seed publication, package/feed work, deployment, or a live database action.

## V4-2 prioritized service track

The broad V4 layers remain the long-term dependency model. Task 15.140.b.2 adds a narrow service track:

1. freeze and classify the `Get-ContentSummary` agent and PowerShell envelopes;
2. supply the minimum durable Tag/as-of read dependency;
3. implement idempotent Outpost scheduled ingestion and the three Ace ContentSummary aggregates;
4. implement Claude/Codex AISupervisor adapters and exchange/header/metric aggregates with body capture disabled;
5. implement authorized AceCommander raw, Tag-set, and token-timeline queries; and
6. prove restart, replay, redaction, authorization-before-aggregation, and incomplete token-count behavior.

This track defers arbitrary plugin DDL, automatic ATAP publication, full Ace parity,
broader expert systems, and external-effecting manifestation. See
[the initial slice](RPRRSBSI-V4-2-55-Initial-Capability-Slice.md).

Editable diagram source:
[RPRRSBSI-V4-2-Layered-Delivery.puml](RPRRSBSI-V4-2-Layered-Delivery.puml). The previously
rendered SVG is not embedded because this source changed and rendering is a
coordinator-owned step.

## Authority and decision boundary

The Task 15.140.a operator record is authoritative for decision status. The
[V4 overview](RPRRSBSI-V4-2-00-Specification-Overview.md),
[core schema](RPRRSBSI-V4-2-10-Core-Schema-Enhancements.md),
[seed contract](RPRRSBSI-V4-2-20-Seed-Data-And-Loaders.md),
[Tags specification](RPRRSBSI-V4-2-30-Tags-Expert-System.md), and
[Mechanized Engineering specification](RPRRSBSI-V4-2-40-Mechanized-Engineering.md) are
the reconciled implementation inputs.

- D-1 and D-3 through D-8 were ratified through C-01 through C-07.
- D-2 is the retained ratified precedence and duplicate-rejection decision.
- C-08 through C-15 were ruled on 2026-08-18 and are normative.
- C-16, C-20, C-26, FU-4, and FU-6 were distinctly ruled on 2026-08-30.
- D-3 edge cases 1 through 8, C-17 through C-19, C-21 through C-25, and C-27 were
  distinctly ruled on 2026-09-04 and are normative implementation inputs.
- Task 15.140.b ends with design. Task 15.140.c is the separate forward-only
  migration implementation. Every live `expwhertzing` increment requires its own built
  implementation task, but execution under that task requires no separate explicit HITL
  gate. An applied migration is never edited.

## Mandatory conformance gates

| Gate | Required acceptance evidence |
| --- | --- |
| C-01 / D-1 interface | CSV and API fixtures contain canonical lowercase dashed `D` GUID text. Non-canonical text is rejected even when parseable. |
| C-01 / D-1 database | Equality, joins, uniqueness, registry checks, and duplicate detection compare native database `uniqueidentifier` values, not text spelling, case, or collation; a database-value test proves equivalent GUID spellings resolve to the same value. |
| C-02 / D-3 | A material declared-type change creates a new semantic identity. The 2026-09-04 edge rulings cover nullability, precision/scale, element type, container shape/cardinality, declared contract rename, combined type/default, declared-domain constraint, and code/fixture/contract-consumed text; only genuine display aliases/text and default-only changes retain identity. |
| C-03 / D-4 | Baseline and overlay have distinct `RuleVariantId` values but the same `RuleId`. An `Override` occurrence selects the overlay; no copied Rule represents it. |
| C-04 / D-5 | ATAP immutable references and ACE overlays/sessions remain separate ownership planes behind one topology-neutral union contract; storage location never supplies precedence. |
| C-05 / D-6 | Tag relations and assignments use durable `TagId` endpoints and resolve the applicable `TagState` as-of. |
| C-06 / D-7 | Internal history is named `State` or `Variant`; `Version` remains reserved for external software/package/firmware/protocol versions. |
| C-07 / D-8 | The first manifestation emits a validated database-change/configuration plan and stops; it does not purchase, provision, or apply the plan. |
| D-2 | Resolution orders `BuildSetRuleSetOccurrence.Ordinal DESC`; the higher ordinal wins and duplicates are rejected, never tie-broken. |
| C-08 through C-27 | Tests map individually to the ruled Tags contracts below; separately authorized pre-live inventory remains mandatory under C-25. |

## Ordered implementation layers

Layers are dependency ordered. A later layer may start only when every preceding gate
it consumes has passed.

### Layer 0 — characterize V3

Deliverables: eleven-table schema assertions, seed/natural-key and validity tests, and a
repeatable V3-shaped upgrade fixture.

Gate: all current objects and expected rows are characterized; the fixture restores
repeatedly; no V3 row is lost or reinterpreted. Only this baseline may precede
Task 15.140.c.

### Layer 1 — identities, catalogs, and generic root

Deliverables: `EntityType`, `Entity`, expert-system roots/states/components/entry
points, catalogs, fixed GUID registry, foundational CSV contracts, loader validation,
and one domain-neutral expert system.

Gate: fresh and V3-upgrade paths pass; identities and loads are deterministic; C-01/D-1
interface and native-value tests pass; a generic definition is queryable as-of.

C-21 permits `rule` and `instantiation`; fixed GUID registration and seed implementation
remain work for the owning implementation task.

### Layer 2 — variants, occurrences, overlays, and resolution

Deliverables: `RuleVariant`/State, RuleSet and BuildSet occurrences,
Add/`Override`/Suppress roles, D-2 resolution, provenance, and overlay fixtures.

Gate: baseline/1500/1200 as-of scenarios pass; higher ordinal wins; duplicate ordinals,
invalid roles, different-`RuleId` overrides, and copied-Rule overlays are rejected.
The ACE variant retains the baseline `RuleId`, is selected through `Override`, and
has its own `RuleVariantId`.

### Layer 3 — typed I/O and deterministic execution

Deliverables: typed values/defaults/constraints, separate workflow and calculation
graphs, bindings, InstantiationState, dirty work, attempts/results, and one safe
deterministic executor.

Gate: type errors and calculation cycles are rejected; classified material changes
create new identities; default/display-only changes retain identity through history;
dirty propagation is reachable-only; identical inputs and definitions reproduce output
and provenance.

The eight D-3 edge classifications are ruled; Layer 3 fixtures must prove their exact
new-identity and retained-history behavior.

### Layer 4 — Tags expert system

Permitted now: the C-08 through C-27 documentation-level logical slice, reference-file
contracts respecting the ruled omissions, as-of/retraction/collision test designs, and a
database-change plan that cannot apply itself.

| Decision | Required contract |
| --- | --- |
| C-08 | Tags live in `ATAPUtilities`; no separate `Tags` schema. C-25 gates live inventory. |
| C-09 | Only durable `Tag` owns Philote/GUID and immutable namespace-local code. `TagState` has no Philote. `UNIQUE(TagNamespaceId, TagCode)` is non-temporal. |
| C-10/C-16 | `TagNamespace` is first-class; stewardship is data; self-stewardship, co-stewards, and transfer history are required. Opaque `PrincipalId`, active stewardship, source reference, and occurred/recorded UTC timestamps govern initial authoring; generalized approval is deferred. |
| C-11 | `PhiloteValidityPeriod` carries identity lifespan and `TagState` payload history. State intervals are fully covered by validity; reinstatement gaps are allowed. |
| C-12/C-21/C-22 | Typed relations and assignments use durable `TagId` and resolve `TagState` as-of. Initial assignment types are `rule` and `instantiation`; relations use durable roots. |
| C-13/C-20/C-23 | Payload history is `TagState`; label/description live there. One authoritative `ATAPUtilities` catalog has no initial tenant discriminator; localization is omitted initially with an additive child reserved. |
| C-17/C-18/C-19 | Tags never authorize and have no intrinsic order. Relations are typed, directed, and optionally weighted; traversal is deferred to Task 15.50.b. |
| C-24/C-25/C-27 | No legacy taxonomy migrates automatically; separately authorized recorded metadata inventory gates live work; assignment confidence/relevance is omitted until demonstrated consumer need. |
| C-14/C-26/FU-4 | Aliases are namespace-local, temporal, controlled-type, and permanently claimed. One trigger using `Latin1_General_100_CI_AS_SC` prevents canonical/alias reissue/collision; behavior/performance must validate on SQL Server Express. |
| C-15/FU-6 | Retraction closes/gaps identity validity and writes terminal `TagState` in one transaction; sanctioned reads consult both; no delete/`IsActive`; `ON DELETE NO ACTION`. Multi-hop successors reject cycles and resolve to the first active terminal successor; erroneous withdrawal requires a reason and no successor. |

Gate: applicable ruled scenarios pass, including required negative/omission cases. Plan
application remains disabled until C-25 inventory and the Task 15.140.c protocol pass.

### Layer 5 — Mechanized Engineering starter

Deliverables: normalized inputs, synthetic license-safe reference components/facts,
compatibility/cost/power/thermal/memory/workload rules, workflow, BOM, findings, and a
validated database-change/configuration plan.

Gate: the baseline/1500/1200 overlay budget scenario passes with the Layer 2
same-`RuleId`/`RuleVariant`/`Override` and D-2 rules; GUID and D-3 gates pass;
violations are explained; the plan contains no executable SQL, purchase, reservation,
provisioning, deployment, or other external effect.

Stop gate: the first manifestation ends at a reviewed plan under D-8. Purchasing,
provisioning, and infrastructure execution require separate tasks and named HITL
authority. Database application to `expwhertzing` requires a separate implementation
task but no separate explicit HITL gate.

### Layer 6 — ACE sessions and compound instantiation

Directional deliverables: edit-session ownership, optimistic concurrency, repeatable
inputs, compound/nested instantiation, user Tag/overlay storage, and topology-neutral
reads.

Blocked release: a session/compound-design packet must be ratified. C-16, C-20, and
C-21 govern the initial Tag slice but do not independently
ratify ACE session/compound design. D-5 ownership alone is not physical design authority.

### Layer 7 — manifestation lifecycle

Directional deliverables: Plan, Approval, Run, Artifact, Event, and Usage concepts
selectively recovered from V2, executor classifications, and approval/replay contracts.

Blocked release: C-16 and a ratified lifecycle packet must define actor, provenance,
timestamps, and approval/policy. No external effect occurs without an approved immutable
plan, permitted tier, authorized executor, and immutable-input binding.

### Layer 8 — operational hardening

Directional deliverables: backup/restore, retention, disaster recovery, topology
validation, performance budgets, concurrency, authorization, and security tests.

Blocked release: C-17 authorization tests, C-20 topology evidence, FU-4 platform evidence, Layers 6/7 closure,
and named Production HITL are required. A build or local test is not deploy-state
evidence.

## Ruled-authority implementation matrix

Each row is a ruled input whose executable evidence remains Task 15.140.c or later work.

| Authority | Required implementation behavior |
| --- | --- |
| D-3 edges 1-8 | Layer 3+ fixtures prove every exact classification, new identity, and retained-history boundary. |
| C-17 | Layers 4/8 prove Tags never authorize through negative tests. |
| C-18 | Layer 4 omits intrinsic Tag ordering and limits `Ordinal` to genuinely ordered collections. |
| C-19 | Layer 4 stores typed, directed, optionally weighted relations; Task 15.50.b owns traversal behavior. |
| C-21 | Layers 1/4 register fixed identities and seed only `rule` and `instantiation` initially. |
| C-22 | Layer 4 uses durable relation roots and no alternate state FK. |
| C-23 | Layer 4 omits first-migration localization and reserves an additive child. |
| C-24 | Layer 4 migrates no legacy taxonomy automatically. |
| C-25 | Task 15.140.c obtains separately authorized, recorded live metadata inventory before live work. |
| C-27 | Layer 4 omits confidence/relevance until demonstrated ContentSummary need. |

## Task 15.140.c forward-only delivery protocol

Task 15.140.c owns implementation. Task 15.140.b completion releases no migration or
live action. Each increment SHALL use this order:

1. close every decision gate affecting the increment and cite the ruling;
2. characterize the exact predecessor and allocate the next unused Flyway version;
3. author a new forward-only migration and rollback-by-forward-fix strategy;
4. update registered GUIDs, CSV/loader behavior, tests, diagrams, and docs;
5. prove static, fresh, V3-upgrade, negative, semantic/as-of, and relevant
   generic/Tags/Mechanized Engineering checks in disposable scope;
6. freeze the candidate and hashes and bind them to the increment-specific
   **implementation task**; no separate explicit HITL gate is required for execution
   against `expwhertzing`;
7. apply only that immutable increment to `expwhertzing` through approved Flyway and
   capture deploy-state/recovery evidence; and
8. stop on failure. Repair with a new forward-only migration; never edit, reuse,
   renumber, or relabel an applied migration.

Every higher-tier promotion is a separate named HITL gate and promotes the same immutable
bytes. Rebuilding between tiers is not promotion evidence.

## Task-authoring and release rules

- **V4-2-HANDOFF-001:** Every task SHALL cite the V4 requirement and decision IDs it
  satisfies.
- **V4-2-HANDOFF-002:** Every schema task SHALL cover migration, GUID registry, CSV/loader,
  fresh, V3-upgrade, negative, semantic/as-of, documentation, and evidence impacts.
- **V4-2-HANDOFF-003:** No task SHALL combine an unresolved design choice with schema or
  live mutation. Ratify first, then implement.
- **V4-2-HANDOFF-004:** No layer crosses a pending-authority or live-action gate.
- **V4-2-HANDOFF-005:** Task slices SHOULD be small: decision closure; logical schema;
  migration; registered seeds; loader; resolution; tests; documentation/evidence;
  experimental deployment; then one task per promotion.
- **V4-2-HANDOFF-006:** A layer is complete only when schema, seeds, loader behavior,
  tests, diagrams, explanations, and deploy-state evidence agree.
- **V4-2-HANDOFF-007:** Plans, logs, and evidence SHALL contain no credential, connection
  string, token, or secret value.

## Adversarial release checklist

Reviewers SHALL reject:

- non-canonical GUID text accepted at an interface because it parses;
- GUID identity compared through text rather than native database value;
- a D-3 edge silently classified;
- a material change that reuses identity or a display/default-only change that
  needlessly invents one;
- an overlay that copies a Rule, changes `RuleId`, omits `Override`, or wins by
  insertion order;
- duplicate BuildSet ordinals resolved with a tie-break;
- a C-08 through C-15 field whose pending dependent authority was inferred;
- a database-change plan reinterpreted as execution permission;
- an applied migration edited or `expwhertzing` reached without an increment-specific
  implementation task; or
- a later layer started because an earlier gate was documented rather than closed.
