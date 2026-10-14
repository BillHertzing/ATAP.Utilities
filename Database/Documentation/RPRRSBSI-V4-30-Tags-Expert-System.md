# RPRRSBSI-V4 Tags Expert System Specification

> **Historical predecessor — superseded for current task authoring.** Use
> [RPRRSBSI-V4-2 Tags Expert System Specification](RPRRSBSI-V4-2-30-Tags-Expert-System.md)
> as the current authority. The V4 body below is retained unchanged as historical design
> context; its decision-status statements do not override V4-2 or the operator record.

Status: reconciled documentation-only design contract for Task 15.140.b. This document
defines no SQL, migration, CSV identity, live inventory, package/feed action, or
deployment.

The editable diagram source is
[RPRRSBSI-V4-Tags-Expert-System.puml](RPRRSBSI-V4-Tags-Expert-System.puml).
The tracked SVG is not embedded because the PlantUML source changed during this
source-only reconciliation and no render was authorized for this worker unit.

## Authority and decision boundary

The decision authority is the Task 15.140.a structured operator record and its
Sprint-0015 Decision Register source. C-08 through C-15 were ruled by the operator on
2026-08-18 and are normative here. Ratified D-6/C-05 and C-12 supply the current durable
Tag endpoint contract. Historical V2/V3 documents are traceability inputs only.

The eight D-3 edge cases, C-16 through C-27, FU-4, and FU-6 remain
`HITL-PENDING`. Recommendations, earlier V3 packet text, and the absence of a ruling do
not fill those gaps.

## Ruled C-08 through C-15 contract

| Decision | Required V4 Tags design |
| --- | --- |
| C-08 | Tags live inside `ATAPUtilities`; this design creates no separate `Tags` schema. C-25 still gates any live metadata inventory before implementation. |
| C-09 | The durable `Tag` root alone owns its Philote/GUID and immutable namespace-local canonical code. `TagState` owns no Philote. The root has the non-temporal natural key `UNIQUE(TagNamespaceId, TagCode)`; aliases, not root mutation, represent renamed codes. |
| C-10 | `TagNamespace` is first-class. Stewardship is recorded as data and enforced during authoring. The creator is the default self-steward; co-stewards are allowed; transfers remain history. C-16 still gates the exact actor, provenance, timestamp, and approval representation. |
| C-11 | `PhiloteValidityPeriod` records Tag identity lifespan as half-open intervals, with gaps permitted on reinstatement. `TagState` intervals record payload history. No TagState interval may be active outside Philote validity coverage. |
| C-12 | Typed Tag-to-Tag relations and generic `(EntityType, EntityId)` assignments are approved. Assignments target durable `TagId`, and readers resolve active `TagState` as-of. C-21 still gates allowed EntityType codes. |
| C-13 | The temporal payload row is `TagState`, not `TagVersion`; label and description live on it. Localization is not decided and remains gated by C-20/C-23. |
| C-14 | Non-canonical aliases are namespace-local, temporal, and typed by controlled vocabulary. A retired alias remains permanently claimed and cannot be reissued to another Tag. One trigger enforces namespace/code uniqueness across canonical root codes and every alias row ever. |
| C-15 | Retraction closes or gaps Philote validity and writes a terminal `TagState`; it never deletes and never uses `IsActive`. FKs remain `ON DELETE NO ACTION`. One mandated procedure performs both writes in one transaction; one sanctioned view/function resolves both layers. Retraction requires a successor pointer, while its chain semantics remain gated by FU-6. |

## Logical schema slice

The names below are logical design names. They do not allocate physical identifiers,
choose SQL types or collation, or authorize DDL.

| Logical table or contract | Required content and constraints |
| --- | --- |
| `TagNamespace` | Durable namespace identity and immutable namespace code. It owns the stewardship relationship. Exact creator/actor and provenance fields wait for C-16. |
| `TagNamespaceSteward` | Historical steward assignments for a namespace. More than one current assignment permits co-stewardship. Namespace creation through the authoring path also creates the creator's self-steward assignment. Exact principal representation, authorization evidence, timestamps, and interval enforcement wait for C-16. |
| `Tag` | Durable `TagId`, the root's `PhiloteId`, `TagNamespaceId`, and immutable canonical `TagCode`. `UNIQUE(TagNamespaceId, TagCode)` is time-free. The root carries no mutable display payload. |
| `TagState` | `TagId`, a half-open payload interval, label, description, and terminal-retraction payload. It has no Philote. Every active interval must be contained by the Tag Philote's validity coverage. A terminal retraction records the C-15-required successor pointer; its exact physical shape and meaning wait for FU-6. |
| `TagAliasType` | Controlled alias-type vocabulary. Exact initial codes are not allocated by this design. |
| `TagAlias` | Durable `TagId`, `TagAliasTypeId`, non-canonical alias code, and half-open as-of range. Namespace is derived from the owning Tag; an alias cannot span namespaces. Closing an interval does not free its code. |
| `TagRelationType` | Type identity for an approved Tag-to-Tag relation. Direction, weight meaning, traversal, ordering, and other behavior beyond typed existence remain gated by C-18/C-19. |
| `TagRelation` | Two durable `TagId` endpoints and a relation type. Under the current ratified D-6/C-05 and C-12 contract, state-row endpoints are not substituted. C-22 remains an explicit reconciliation question described below. |
| `TagAssignment` | Durable `TagId` plus generic `(EntityType, EntityId)` endpoint. Active TagState is resolved as-of rather than stored as the assignment endpoint. Allowed EntityType codes, provenance fields, and confidence remain gated by C-21, C-16, and C-27. |

### Namespace stewardship behavior

The sanctioned namespace-authoring operation SHALL create the namespace and its creator's
steward assignment atomically. Subsequent authoring or publication into that namespace
SHALL require a current steward authorization record. The relation permits simultaneous
co-stewards, and a transfer SHALL end or supersede earlier stewardship without erasing
history.

This is the C-10 behavior contract, not a decision about principal shape. C-16 must still
answer who or what the actor is, which provenance is mandatory, which timestamps exist,
and how an approval/policy gate is represented before physical implementation can define
the authorizing predicate.

### Durable root and dual timelines

The durable lookup identity is `(TagNamespaceId, TagCode) -> TagId`. `Tag` owns the
Philote; `TagState` does not. Label or description edits add payload history and do not
change the durable identity or canonical code.

For an as-of instant `T`, a Tag is resolvable only when both conditions hold:

1. `T` is covered by a `PhiloteValidityPeriod` for the Tag's Philote; and
2. `T` is covered by the applicable `TagState` interval.

The C-11 containment invariant is stronger than an ordinary overlap check: every point
in a TagState interval must be covered by the Tag's identity-validity timeline. Gaps are
permitted for reinstatement, but a state cannot bridge an identity gap.

Relations and assignments retain durable `TagId` endpoints across payload-state changes.
Their effective meaning at `T` is obtained only through the sanctioned as-of resolution
path; callers do not persist an exact `TagStateId` as a substitute endpoint.

### Temporal alias registry and collision trigger

The root canonical code is immutable and `TagAlias` contains non-canonical aliases only.
Alias validity is temporal for as-of lookup, but code ownership is permanent: retired
aliases remain in the collision set forever.

The C-14 trigger SHALL reject any write that would cause, within one namespace:

- two durable Tags to share one canonical code;
- an alias to collide with any durable Tag's canonical code;
- aliases, current or historical, owned by different Tags to share one code; or
- a retired canonical or alias code to be reissued to a different Tag.

A canonical and alias spelling belonging to the same Tag still require an unambiguous
registry rule in the physical design; this document does not use that detail to weaken
the cross-Tag prohibition. The recorded future quarantine-plus-steward relaxation is not
in force. FU-4 must confirm the exact free SQL Server edition/platform; FU-5 must measure
the required trigger's execution burden. Neither follow-up authorizes replacing or
silently omitting the ruled trigger.

### Dual-layer retraction and sanctioned paths

Retraction SHALL be performed only by the mandated retraction procedure. In one database
transaction it SHALL close or gap the current Philote identity validity and append the
terminal TagState carrying the required successor pointer. It SHALL preserve all rows,
use no `IsActive` flag, and rely on `ON DELETE NO ACTION` references.

Reads that determine whether a Tag is effective SHALL use the one sanctioned resolution
view/function. That path SHALL consult both identity validity and payload state as-of the
same instant and SHALL not return a Tag that is effective in only one layer.

FU-6 is still required before physical implementation can define multi-hop successor
resolution, termination, cycle handling, or the successor for an erroneous withdrawal.
The required pointer is ruled; those semantics are not. No example in this document
supplies a placeholder answer.

## C-22 authority tension — exact pending question

The pending C-22 question is: **“Relations join roots or exact states?”** Ratified
D-6/C-05 already states that Tag relationships and assignments point to durable `TagId`
roots, and C-12 approves typed Tag-to-Tag relations while explicitly rewriting assignment
endpoints to durable `TagId`.

Accordingly, the current V4 contract in this document preserves durable relation roots
and does not invent exact-state endpoints. C-22 nevertheless remains `HITL-PENDING` in
the later worksheet. It must explicitly reconcile whether it merely confirms the
existing durable-root authority or amends the relation portion of that authority. Until
then, this design adds no relation-state FK, snapshot rule, or alternate endpoint.

## Non-normative pending gates

Nothing in this section is an approved answer.

| Gate | Exact unresolved boundary |
| --- | --- |
| C-16 | Actor/principal representation; authoring and transfer provenance; dual timestamps; approval/policy gate. These details are required to finish the C-10 stewardship predicate. |
| C-17 | Whether “Tags never affect authorization” becomes a hard architecture and test invariant. This document does not use a Tag as an authorization grant, but it does not ratify the invariant. |
| C-18 | Whether Tags have ordering and where `Ordinal` is valid. No Tag ordering or tie-break is introduced here. |
| C-19 | Relation weighting, directionality, traversal behavior, aggregation, limits, and semantics beyond ruled typed relations and current durable endpoints. No weight column or algorithm is selected here. |
| C-20 | Tenant scope, authoritative logical catalog, and physical-store topology. C-08 decides the schema location only; it does not decide tenancy. |
| C-21 | Allowed generic-assignment `EntityType` codes, including `rule` and `instantiation`. No code is seeded here. |
| C-22 | Whether relations join durable roots or exact states; it must reconcile the ratified D-6/C-05 and C-12 durable-root authority as described above. |
| C-23 | Whether localization is required now. No `TagStateLocalization` child is specified. |
| C-24 | Whether any legacy 35-row filing taxonomy is migrated. No legacy row is selected or mapped. |
| C-25 | Whether a live `Tags` schema exists. Any metadata-only inventory requires separate authorization; none was performed. |
| C-26 | Tag-code collation. The canonical/alias uniqueness rules are logical and do not select case, accent, width, or kana behavior. |
| C-27 | Per-assignment confidence/relevance. No field, range, or default is specified. |
| FU-4 | Exact free SQL Server edition/platform confirmation. The trigger remains required; edition-specific implementation claims wait. |
| FU-6 | Successor-chain multi-hop, termination, cycle, and erroneous-withdrawal semantics. |

All eight D-3 material-change edge cases also remain `HITL-PENDING`: same-scalar
nullability; precision/scale; collection element type; renamed same-shape type; combined
default and type change; container cardinality/shape; string length/constraint; and
display text that feeds generated code or fixtures. They neither narrow nor widen the
ruled Tags contract.

## Documentation-level acceptance checks

1. The logical model places Tags inside `ATAPUtilities` and contains no separate `Tags`
   schema.
2. A durable Tag owns one Philote and immutable namespace-local canonical code; its
   states own neither.
3. Namespace creation records self-stewardship, co-stewards can coexist, and transfers
   retain history without choosing the still-pending actor/provenance schema.
4. An as-of example can demonstrate identity validity plus contained payload state,
   including a reinstatement gap, without persisting a state endpoint.
5. A collision example proves that a historical alias remains claimed and cannot be
   reissued to a different Tag.
6. A retraction example uses the one transactional write path and is invisible through
   the sanctioned read path when either layer is not effective.
7. A review confirms every C-16 through C-27, FU-4, FU-6, and D-3 edge-case question is
   visibly gated rather than answered by schema shape, example, default, or prose.
