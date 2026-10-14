# RPRRSBSI-V4-2 Tags Expert System Specification

Status: reconciled documentation-only design contract for Task 15.140.b. This document
defines no SQL, migration, CSV identity, live inventory, package/feed action, or
deployment.

## V4-2 ContentSummary integration

- **V4-2-TAG-080:** Ace ContentSummary items SHALL associate to durable `TagId` roots; active labels and descriptions resolve through `TagState` at an explicit as-of instant.
- **V4-2-TAG-081:** Scheduled ingestion MAY propose Tag assignments, but under ruled
  C-16 each assignment SHALL preserve producer, plugin/version, source hash, asserted
  time, recorded time, and policy/approval status.
- **V4-2-TAG-082:** AceCommander Tag-set search SHALL specify `Any` or `All` and return matched Tags and provenance. Tags SHALL never authorize returned content.
- **V4-2-TAG-083:** Inferred Tags Rules and ContentSummary Rules remain Ace overlays or publication candidates. Ingestion SHALL NOT mutate immutable reference Rules.

The editable diagram source is
[RPRRSBSI-V4-2-Tags-Expert-System.puml](RPRRSBSI-V4-2-Tags-Expert-System.puml).
The tracked SVG is not embedded because the PlantUML source changed during this
source-only reconciliation and no render was authorized for this worker unit.

## Authority and decision boundary

The decision authority is the Task 15.140.a structured operator record and its
Sprint-0015 Decision Register source. C-08 through C-15 were ruled by the operator on
2026-08-18 and are normative here. Ratified D-6/C-05 and C-12 supply the current durable
Tag endpoint contract. Historical V2/V3 documents are traceability inputs only.

C-16, C-20, C-26, FU-4, and FU-6 were ruled on 2026-08-30. The eight D-3 edge
cases, C-17 through C-19, C-21 through C-25, and C-27 were ruled on 2026-09-04.
All are normative below.

## Ruled C-08 through C-15 contract

| Decision | Required V4 Tags design |
| --- | --- |
| C-08 | Tags live inside `ATAPUtilities`; this design creates no separate `Tags` schema. C-25 still gates any live metadata inventory before implementation. |
| C-09 | The durable `Tag` root alone owns its Philote/GUID and immutable namespace-local canonical code. `TagState` owns no Philote. The root has the non-temporal natural key `UNIQUE(TagNamespaceId, TagCode)`; aliases, not root mutation, represent renamed codes. |
| C-10 | `TagNamespace` is first-class. Stewardship is recorded as data and enforced during authoring. The creator is the default self-steward; co-stewards are allowed; transfers remain history. C-16 requires opaque `PrincipalId`, source reference, and occurred-at/recorded-at UTC timestamps; generalized approval remains deferred. |
| C-11 | `PhiloteValidityPeriod` records Tag identity lifespan as half-open intervals, with gaps permitted on reinstatement. `TagState` intervals record payload history. No TagState interval may be active outside Philote validity coverage. |
| C-12 | Typed Tag-to-Tag relations and generic `(EntityType, EntityId)` assignments are approved. Assignments target durable `TagId`, readers resolve active `TagState` as-of, and C-21 initially allows `rule` and `instantiation`. |
| C-13 | The temporal payload row is `TagState`, not `TagVersion`; label and description live on it. C-23 omits localization initially and reserves an additive child. |
| C-14 | Non-canonical aliases are namespace-local, temporal, and typed by controlled vocabulary. A retired alias remains permanently claimed and cannot be reissued to another Tag. One trigger enforces namespace/code uniqueness across canonical root codes and every alias row ever. |
| C-15 | Retraction closes or gaps Philote validity and writes a terminal `TagState`; it never deletes and never uses `IsActive`. FKs remain `ON DELETE NO ACTION`. One mandated procedure performs both writes in one transaction; one sanctioned view/function resolves both layers. FU-6 allows multi-hop successors, rejects cycles, resolves the first active terminal successor, and permits erroneous withdrawal only with a reason and no successor. |

## Logical schema slice

The names below are logical design names. They do not allocate physical identifiers,
choose SQL types or collation, or authorize DDL.

| Logical table or contract | Required content and constraints |
| --- | --- |
| `TagNamespace` | Durable namespace identity and immutable namespace code. It owns the stewardship relationship and records C-16 source reference plus occurred-at and recorded-at UTC provenance. |
| `TagNamespaceSteward` | Historical steward assignments for a namespace keyed by opaque `PrincipalId`. More than one current assignment permits co-stewardship. Namespace creation through the authoring path also creates the creator's active self-steward assignment, which gates initial authoring. Generalized approval remains deferred. |
| `Tag` | Durable `TagId`, the root's `PhiloteId`, `TagNamespaceId`, and immutable canonical `TagCode`. `UNIQUE(TagNamespaceId, TagCode)` is time-free. The root carries no mutable display payload. |
| `TagState` | `TagId`, a half-open payload interval, label, description, and terminal-retraction payload. It has no Philote. Every active interval must be contained by the Tag Philote's validity coverage. A terminal retraction records a successor except for an erroneous withdrawal carrying a required reason and no successor; resolution follows FU-6 multi-hop/cycle/terminal rules. |
| `TagAliasType` | Controlled alias-type vocabulary. Exact initial codes are not allocated by this design. |
| `TagAlias` | Durable `TagId`, `TagAliasTypeId`, non-canonical alias code, and half-open as-of range. Namespace is derived from the owning Tag; an alias cannot span namespaces. Closing an interval does not free its code. |
| `TagRelationType` | Type identity for an approved directed Tag-to-Tag relation with optional weight metadata. Traversal behavior is deferred to Task 15.50.b. |
| `TagRelation` | Two durable `TagId` endpoints and a relation type. State-row endpoints are prohibited; Tags have no intrinsic order. |
| `TagAssignment` | Durable `TagId` plus generic `(EntityType, EntityId)` endpoint, initially allow-listed to `rule` and `instantiation`. Active TagState is resolved as-of. C-16 provenance remains mandatory; C-27 omits confidence/relevance initially. |

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
in force. FU-4 fixes SQL Server Express as the target and requires validation of trigger
behavior and performance there; FU-5 measures the required trigger's execution burden.
Neither follow-up authorizes replacing or silently omitting the ruled trigger.

### Dual-layer retraction and sanctioned paths

Retraction SHALL be performed only by the mandated retraction procedure. In one database
transaction it SHALL close or gap the current Philote identity validity and append the
terminal TagState carrying the required successor pointer. It SHALL preserve all rows,
use no `IsActive` flag, and rely on `ON DELETE NO ACTION` references.

Reads that determine whether a Tag is effective SHALL use the one sanctioned resolution
view/function. That path SHALL consult both identity validity and payload state as-of the
same instant and SHALL not return a Tag that is effective in only one layer.

FU-6 permits multi-hop successor chains, rejects cycles, resolves to the first active
terminal successor, and makes erroneous withdrawal with a required reason and no
successor the explicit C-15 exception. No example in this document
supplies a placeholder answer.

## C-22 durable-root authority

C-22 confirms D-6/C-05 and C-12: Tag relationships and assignments point to durable
`TagId` roots. The design adds no relation-state FK, snapshot rule, or alternate endpoint.

## Ruled 2026-08-30 follow-ups

- **C-16:** Opaque `PrincipalId`, active-steward initial-authoring gate, source reference,
  and separate occurred-at/recorded-at UTC timestamps; generalized approval is deferred.
- **C-20:** One authoritative logical catalog in `ATAPUtilities`; no initial tenant
  discriminator.
- **C-26:** Canonical and alias Tag-code comparison uses
  `Latin1_General_100_CI_AS_SC`.
- **FU-4:** SQL Server Express is the target; trigger behavior and performance are
  validation requirements.
- **FU-6:** Multi-hop successors are allowed, cycles are rejected, resolution returns the
  first active terminal successor, and erroneous withdrawal requires a reason and no
  successor.

## Ruled 2026-09-04 boundaries

| Gate | Normative boundary |
| --- | --- |
| C-17 | Tags classify and advise but never authorize; negative tests are mandatory. |
| C-18 | Tags have no intrinsic ordering; `Ordinal` is valid only for genuinely ordered collections. |
| C-19 | Relations are typed, directed, and optionally weighted; traversal is deferred to Task 15.50.b. |
| C-21 | Initial assignment `EntityType` codes are `rule` and `instantiation`. |
| C-22 | Relations join durable roots. |
| C-23 | Initial localization is omitted; an additive child is reserved. |
| C-24 | No legacy taxonomy is migrated automatically; reviewed terms may be re-authored later. |
| C-25 | A separately authorized recorded metadata inventory is required before live work. |
| C-27 | Confidence/relevance is omitted until demonstrated ContentSummary need. |

## Documentation-level acceptance checks

1. The logical model places Tags inside `ATAPUtilities` and contains no separate `Tags`
   schema.
2. A durable Tag owns one Philote and immutable namespace-local canonical code; its
   states own neither.
3. Namespace creation records self-stewardship, co-stewards can coexist, and transfers
   retain history using the ruled opaque principal and dual-UTC provenance contract.
4. An as-of example can demonstrate identity validity plus contained payload state,
   including a reinstatement gap, without persisting a state endpoint.
5. A collision example proves that a historical alias remains claimed and cannot be
   reissued to a different Tag.
6. A retraction example uses the one transactional write path and is invisible through
   the sanctioned read path when either layer is not effective.
7. A review confirms every ruling through 2026-09-04 is implemented exactly, including
   required omissions, negative authorization behavior, D-3 identity transitions, and
   the separately authorized C-25 pre-live inventory gate.
