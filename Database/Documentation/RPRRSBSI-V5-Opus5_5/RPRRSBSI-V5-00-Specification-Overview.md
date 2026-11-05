# RPRRSBSI-V5 Specification Overview

> **V5 revision (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Successor of `Database/Documentation/RPRRSBSI-V4-2-00-Specification-Overview.md`. Requirement and decision IDs keep their V4-2 numbers with the prefix `V5-` (for example `V4-2-CORE-034` is now `V5-CORE-034`); a V4-2 ID that is not repeated here is withdrawn only where the "V5 changes" section says so. The V5 decisions DEC-1 to DEC-6 and the 2026-11-05 training and gamification requirements are summarised in [the V5 overview](RPRRSBSI-V5-00-Specification-Overview.md#v5-decisions); open items are in [HANDOFF-V5.md](HANDOFF-V5.md). **Terminology (DEC-6):** an *Instantiation* is a produced file or row; the run of an executor that produces instantiations is a *Materialization*; the reusable configuration it runs is a *materialization specification*. Where carried-forward V4-2 text uses "Instantiation" for the configured act, read "materialization specification".


Status: expanded task-authoring specification for Sprint 0015 Task 15.140.b.2.

This document set versions the RPRRSBSI V4 design as V4-2. It retains the implemented
V3/PTV baseline and every ratified V4 decision, then incorporates the database-expansion
inputs for plugins, AceCommander, AceOutpost, ContentSummary, and AISupervisor. It is an input
to task creation; it does not authorize SQL, migrations, seeds, deployment, package/feed
changes, or a live database change.

## V5 decisions

V5 is the successor of the V4-2 set. It carries forward every V4-2 requirement that is not changed below and adds the developer direction of 2026-11-03 to 2026-11-05. Sources: `_Planning/InformationForTheFuture/Sprint0018/DatabaseEnhancements/DeveloperNotes-2026-11-03.md`, `DeveloperNotes-2026-11-04.md`, and `Claude-v1/Requirements-Impact-2026-11-04.md` (revision 2), all on `_Planning` branch `44-Sprint-0017-work-items`. The developer states that the newest design documents are the most authoritative and are themselves partly complete.

| ID | Decision (developer, 2026-11-03 to 2026-11-05) | Governing V5 document |
| --- | --- | --- |
| DEC-1 | Instantiation origin values are `Asserted` (entered by a person) and `Generated` (produced by a materializer). | [V5-12](RPRRSBSI-V5-12-Instantiation-And-Materialization.md) |
| DEC-2 | Hand-entered content summaries use a dedicated *asserted* rule set and materialization specification, so the frozen V00100 rule-chain columns stay `NOT NULL`. | [V5-25](RPRRSBSI-V5-25-ContentSummary-Data-Contract.md) |
| DEC-3 | `Ace` is a full copy of every `ATAPUtilities` table, plus Ace-only tables, and every `Ace` row carries owner columns. C-20 and V5-CORE-074 are amended. | [V5-60](RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md) |
| DEC-4 | V5-PDB-002 is amended: a developer user may author DDL in `Ace` only for tables that user owns, through a DDL Authoring mode; such tables are visible only to the owner (and ACE administrators). | [V5-15](RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md) |
| DEC-5 | A marketplace bolt-on submission process, with checks and authorizations, migrates a developer's Ace tables to `ATAPUtilities`, backs up and removes the developer tables, creates owner-column Ace copies, moves the developer data into them, and selects which rows become `ATAPUtilities` template rows. | [V5-15](RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md) |
| DEC-6 | *Instantiation* is a noun: one produced file or one produced row. | [V5-12](RPRRSBSI-V5-12-Instantiation-And-Materialization.md) |
| DEC-7 | The run of an executor that reads BuildSets and inputs and produces instantiations is a **Materialization**; the executor is a **materializer**; its reusable configuration is a **materialization specification**. Confirmed 2026-11-05. | [V5-12](RPRRSBSI-V5-12-Instantiation-And-Materialization.md) |
| DEC-8 | A forward migration renames the existing `ATAPUtilities.Instantiation` table (V00010) to `MaterializationSpecification` and creates a new `Instantiation` table for produced files and rows. Confirmed 2026-11-05. | [V5-12](RPRRSBSI-V5-12-Instantiation-And-Materialization.md) |
| DEC-9 | Both schemas are first given a common initial load; afterwards changes start in `Ace`, and some are promoted to `ATAPUtilities` (2026-11-03). `ATAPUtilities` holds open, template data anyone can use; `Ace` holds rows owned by and restricted to a user or organization. | [V5-60](RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md) |
| DEC-10 | Rules that govern AI agents are held as RRSBS instantiations (2026-11-03; ADR-018). | [V5-12](RPRRSBSI-V5-12-Instantiation-And-Materialization.md) |

New requirements recorded as V5 scope (designs proposed, decisions open where marked in [HANDOFF-V5.md](HANDOFF-V5.md)):

- Organizations own software products and software development processes; a product is built with a process ([V5-62](RPRRSBSI-V5-62-Organization-Identity-Products-And-Estates.md)).
- Deceased persons, household estates, executors and assets ([V5-62](RPRRSBSI-V5-62-Organization-Identity-Products-And-Estates.md)).
- Windows accounts are host-scoped; host and person share an organization ([V5-62](RPRRSBSI-V5-62-Organization-Identity-Products-And-Estates.md)).
- A highly protected sign-in table separated from user-visible data ([V5-65](RPRRSBSI-V5-65-Protected-Authentication.md)).
- Anonymous, registered and paying users; the product is a marketplace ([V5-15](RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md), [V5-65](RPRRSBSI-V5-65-Protected-Authentication.md)).
- Training wizards, training progress, gamification schemes, scenes and reward items; theme selection in the login workflow; a gamification home page ([V5-70](RPRRSBSI-V5-70-Training-And-Gamification.md), [Ace-Outpost-Commander-Integration/40](Ace-Outpost-Commander-Integration/40-Gamification-Home-And-Login-Theme.md)).
- The design is early and will change a lot ([V5-50](RPRRSBSI-V5-50-Layered-Implementation-Handoff.md)).

**Built baseline that V5 starts from.** Migrations `V00010`, `V00030`–`V00210` on `ATAP.Utilities` branch `150-Sprint-0017-work-items`. Only `V00010`–`V00070` are evidenced in Production (package `0.1.6`, 2026-09-01); later migrations are Experimental only (`0.1.19-Sprint.1`).

## Carried-forward V4-2 expansion priority (unchanged)

- **V5-EXP-001:** The first vertical slice SHALL schedule AceOutpost ingestion of Tags
  and ContentSummary output from the `Get-ContentSummary` agent and PowerShell function.
- **V5-EXP-002:** AISupervisor SHALL provide explicit Claude and Codex proxy adapters
  that store safe request/response metadata, headers after redaction, token counts, and
  controlled additional metrics in the `Ace` schema.
- **V5-EXP-003:** AceCommander SHALL visualize raw ContentSummary data, deterministic
  `Any`/`All` Tag-set queries, and UTC token series grouped by harness and model.
- **V5-EXP-004:** The initial implementation SHALL remain narrower than the broader
  plugin, synchronization, Git, photo/NFT, outdoor-activity, and manifestation platform.
- **V5-EXP-005:** New mutable data belongs to the Ace working plane; scheduled
  ingestion or synchronization SHALL NOT publish authoritative ATAPUtilities definitions.

Layered delivery is maintained in the editable diagram source:
[RPRRSBSI-V5-Layered-Delivery.puml](../RPRRSBSI-V5-Layered-Delivery.puml). A rendered SVG
is intentionally not embedded here because the tracked render may lag the editable
source until the coordinator-owned render gate runs.

## Authority and status

The decision/status authority for this overview is the Task 15.140.a structured
operator record at
`_Planning/InformationForTheFuture/Sprint0015/StreamN/Task-15.140.a/RPRRSBSI-V4-Operator-Input.md`
and its editable D-3 companion. The operator record distinguishes Decision Register
rulings from the direct 2026-08-18, 2026-08-30, and 2026-09-04 operator sessions. The source list and historical
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
- D-3 edge cases 1 through 8, C-17 through C-19, C-21 through C-25, and C-27 were
  distinctly ruled on 2026-09-04 and are normative only to the extent stated below.

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

- **V5-BASE-001:** The exact V3 baseline is the eleven-table schema: `Philote`,
  `PhiloteValidityPeriod`, `RuleKind`, `RulePrimitive`, `RulePrimitiveInput`, `Rule`,
  `RuleSet`, `RuleSetRule`, `BuildSet`, `BuildSetRuleSet`, and `Instantiation`.
- **V5-BASE-002:** V4 SHALL extend V3 with forward-only Flyway migrations. It SHALL NOT
  rewrite already-applied V3 migrations.
- **V5-BASE-003:** V4 SHALL retain Philote identity and half-open business validity
  `[ValidFromUtc, ValidToUtc)` as its temporal backbone.
- **V5-BASE-004:** V2 concepts SHALL be recovered selectively where they satisfy a V4
  requirement. V2 physical tables and internal revision-number patterns SHALL NOT be
  copied wholesale.
- **V5-BASE-005:** Every migration layer SHALL be independently deployable and
  verifiable before a later layer is started.
- **V5-BASE-006:** Reference seeds SHALL use fixed registered GUIDs and deterministic
  loader behavior. Production reference data SHALL NOT depend on `NEWID()`.

## Ratified D-1 through D-8 decisions

| Decision | Authority/status | Normative specification |
| --- | --- | --- |
| D-1 / C-01 | Ratified 2026-08-16 | CSV and API GUID text SHALL use canonical lowercase dashed `D` format. Database GUID equality and joins SHALL compare native GUID values, not formatted text. |
| D-2 | Retained ratified decision | Within a BuildSet, a higher `BuildSetRuleSetOccurrence.Ordinal` SHALL have higher precedence. Resolution SHALL use `Ordinal DESC`; duplicate ordinals in one BuildSet are invalid. |
| D-3 / C-02 | Ratified 2026-08-16; edges ruled 2026-09-04 | A material declared-type change SHALL create a new semantic identity and SHALL NOT mutate meaning in place. Material changes include rule-kind, scalar-to-different-scalar, scalar/heap-object boundary, heap/object-type, nullability, precision/scale, collection element-type, container shape/cardinality, and string-length/declared-domain constraint changes. A declared contract-type rename is material; a separate display alias is non-material. A simultaneous type/default change is one material transition whose new definition receives the default as its initial state. Text consumed by code, fixtures, or contracts is material; default-only and genuinely visual display-only changes are non-material. |
| D-4 / C-03 | Ratified 2026-08-16 | An overlay SHALL be a `RuleVariant` of the same `RuleId`, selected by an occurrence whose membership role is `Override`. The Rule SHALL NOT be copied to represent an overlay. |
| D-5 / C-04 | Ratified 2026-08-16 | ATAP SHALL own immutable reference definitions; ACE SHALL own user overlays and sessions; cross-store reads SHALL use a topology-neutral union contract. |
| D-6 / C-05 | Ratified 2026-08-16 | Tag relationships and assignments SHALL point to durable `TagId` roots, with active `TagState` resolved as-of. |
| D-7 / C-06 | Ratified 2026-08-16 | Internal semantic revision rows SHALL use `State` or `Variant`, not `Version`; external software versions retain their normal terminology. |
| D-8 / C-07 | Ratified 2026-08-16 | The first computer-configuration implementation SHALL stop at a validated database-change/configuration plan. Purchasing and provisioning are later capabilities. |

## Ruled C-08 through C-15 Tags decisions

These rulings came from the direct 2026-08-18 operator session recorded in Task
15.140.a. They are normative and have been propagated into the Sprint 0015 Decision
Register.

| Decision | Status | Normative specification |
| --- | --- | --- |
| C-08 | Ruled 2026-08-18 | Tags SHALL live inside `ATAPUtilities`; there is no separate `Tags` schema. |
| C-09 | Ruled 2026-08-18 | The durable `Tag` root SHALL own the Philote/GUID and immutable `(namespace, code)` natural key. `TagState` SHALL have no Philote. Codes are frozen for the Tag lifetime; aliases handle renames and state carries changeable display text. |
| C-10 | Ruled 2026-08-18 | Stewardship SHALL be recorded as data and enforced during authoring. The creator is the namespace's default steward; co-stewards are allowed and transfers retain history. C-16 supplies the opaque principal and provenance contract. |
| C-11 | Ruled 2026-08-18 | `PhiloteValidityPeriod` SHALL represent Tag identity lifespan and `TagState` as-of ranges SHALL represent payload history. No `TagState` may be active outside its Philote validity. |
| C-12 | Ruled 2026-08-18; C-21 ruled 2026-09-04 | Typed Tag-to-Tag relations and generic `(EntityType, EntityId)` assignments are approved. Assignments SHALL target durable `TagId`; active `TagState` resolves as-of. Initial allowed EntityType codes are `rule` and `instantiation`. |
| C-13 | Ruled 2026-08-18; C-23 ruled 2026-09-04 | The temporal payload row SHALL be named `TagState`, not `TagVersion`; label and description SHALL live on that state. Initial localization is omitted and an additive child is reserved. |
| C-14 | Ruled 2026-08-18 | Aliases SHALL be temporal, namespace-local, typed by controlled vocabulary, and not reissued to another Tag after retirement. The durable root keeps the canonical code; the alias registry holds non-canonical aliases. Cross-registry uniqueness SHALL be trigger-enforced using C-26 collation and validated on SQL Server Express under FU-4. |
| C-15 | Ruled 2026-08-18 | Retraction SHALL close/gap identity validity and write a terminal `TagState`, without delete or `IsActive`; foreign keys remain `ON DELETE NO ACTION`. One transactional write path and one sanctioned read path SHALL coordinate both layers. A successor is generally required, subject to FU-6's explicit erroneous-withdrawal exception. |
| C-16 | Ruled 2026-08-30 | Actor identity SHALL be a required opaque `PrincipalId`; active namespace stewardship SHALL gate initial authoring; provenance SHALL retain a source reference and occurred-at/recorded-at UTC timestamps. A generalized approval workflow is deferred. |
| C-20 | Ruled 2026-08-30 | The initial design SHALL use one authoritative logical catalog in `ATAPUtilities` and SHALL NOT add a tenant discriminator. |
| C-26 | Ruled 2026-08-30 | Canonical and alias Tag-code comparisons SHALL use explicit `Latin1_General_100_CI_AS_SC`. |
| FU-4 | Ruled 2026-08-30 | SQL Server Express SHALL be the target free edition; trigger behavior and performance SHALL be validated there. |
| FU-6 | Ruled 2026-08-30 | Successor chains MAY be multi-hop, SHALL reject cycles, and SHALL resolve to the first active terminal successor. Erroneous withdrawal SHALL require a reason and have no successor as an explicit C-15 exception. |

## Ruled 2026-09-04 D-3 and Tags decisions

### D-3 edge cases

| Case | Classification | Status |
| --- | --- | --- |
| 1 | Same-scalar nullability change is material. | Ruled 2026-09-04 |
| 2 | Same-scalar precision or scale change is material. | Ruled 2026-09-04 |
| 3 | Collection element-type change is material. | Ruled 2026-09-04 |
| 4 | A declared contract-type rename is material; a separate display alias is non-material. | Ruled 2026-09-04 |
| 5 | A simultaneous default/type change is one material transition; the default is the new definition's initial state. | Ruled 2026-09-04 |
| 6 | Container cardinality or shape change is material. | Ruled 2026-09-04 |
| 7 | String length or declared-domain constraint change is material. | Ruled 2026-09-04 |
| 8 | Display text consumed by code, fixtures, or contracts is material. | Ruled 2026-09-04 |

### Remaining C decisions ruled 2026-09-04

| Decision | Normative answer | Status |
| --- | --- | --- |
| C-17 | Tags classify and advise but never authorize. | Ruled 2026-09-04 |
| C-18 | Tags have no intrinsic ordering; `Ordinal` is valid only for genuinely ordered collections. | Ruled 2026-09-04 |
| C-19 | Relations use typed, directed, optionally weighted storage; traversal behavior is deferred to Task 15.50.b. | Ruled 2026-09-04 |
| C-21 | Initial assignment `EntityType` allow-list contains `rule` and `instantiation`. | Ruled 2026-09-04 |
| C-22 | Tag relations join durable roots. | Ruled 2026-09-04 |
| C-23 | Localization is omitted from the first migration; an additive child is reserved. | Ruled 2026-09-04 |
| C-24 | No legacy taxonomy rows migrate automatically; reviewed terms may be re-authored later. | Ruled 2026-09-04 |
| C-25 | A separately authorized, recorded metadata inventory is a pre-live gate. | Ruled 2026-09-04 |
| C-27 | Assignment confidence/relevance is omitted until a ContentSummary consumer demonstrates need. | Ruled 2026-09-04 |

### Ruled follow-ups

- **FU-4 — RULED 2026-08-30:** target SQL Server Express and validate trigger behavior
  and performance there.
- **FU-6 — RULED 2026-08-30:** allow multi-hop successor chains, reject cycles, resolve
  to the first active terminal successor, and require a reason with no successor for
  erroneous withdrawal as an explicit C-15 exception.

## Document map

| Document | Task-authoring purpose |
| --- | --- |
| [RPRRSBSI-V5 Source Synthesis and Design Traceability](RPRRSBSI-V5-05-Source-Synthesis-And-Traceability.md) | Normalized requirements and explicit V3-retained/V2-recovered design mapping. |
| [RPRRSBSI-V5 Core Schema Enhancements](RPRRSBSI-V5-10-Core-Schema-Enhancements.md) | Tables, keys, constraints, overlay semantics, graphs, and execution state. |
| [RPRRSBSI-V5 Seed Data and Loader Specification](RPRRSBSI-V5-20-Seed-Data-And-Loaders.md) | CSV inventory, loader contract, reference seeds, and migration quality gates. |
| [RPRRSBSI-V5 Tags Expert System Specification](RPRRSBSI-V5-30-Tags-Expert-System.md) | The first specific expert system and its graph semantics. |
| [RPRRSBSI-V5 Mechanized Engineering Specification](RPRRSBSI-V5-40-Mechanized-Engineering.md) | Initial computer-system configuration inputs, rules, and outputs. |
| [RPRRSBSI-V5 Layered Implementation Handoff](RPRRSBSI-V5-50-Layered-Implementation-Handoff.md) | Ordered work packages, tests, promotion gates, and definition of done. |
| [Plugin, DDL Authoring and Marketplace](RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md) | Plugin ownership, developer DDL authoring (DEC-4), marketplace bolt-on submission (DEC-5), isolation and publication. |
| [ContentSummary Data Contract](RPRRSBSI-V5-25-ContentSummary-Data-Contract.md) | Initial ingestion, storage, Tag association, and query model. |
| [AISupervisor Telemetry](RPRRSBSI-V5-35-AISupervisor-Request-Response-Telemetry.md) | Claude/Codex exchange, safe headers, token counts, and extensible metrics. |
| [Edge Persistence and Synchronization](RPRRSBSI-V5-45-Edge-Persistence-And-Synchronization.md) | Provider-neutral Outpost projection and provider-selection criteria. |
| [Initial Capability Slice](RPRRSBSI-V5-55-Initial-Capability-Slice.md) | Narrow delivery sequence and explicit deferrals. |
| [AceOutpost and AceCommander Integration](Ace-Outpost-Commander-Integration/README.md) | Application service and visualization architecture. |
| [Instantiation and Materialization](RPRRSBSI-V5-12-Instantiation-And-Materialization.md) | **New in V5.** Instantiation noun, Asserted/Generated origin, materialization records, supersession, rename of the V00010 table. |
| [Tags Traversal Contract](RPRRSBSI-V5-31-Tags-Traversal-Contract.md) | Traversal behaviour; V5 adds ownership filtering across the ATAPUtilities/Ace union. |
| [Ownership and the Ace Copy](RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md) | **New in V5.** Ace as a full copy, owner columns, row-level security, generated twins, promotion direction. |
| [Organization, Identity, Products and Estates](RPRRSBSI-V5-62-Organization-Identity-Products-And-Estates.md) | **New in V5.** Software products and processes, host-scoped accounts, estates and assets. |
| [Protected Authentication](RPRRSBSI-V5-65-Protected-Authentication.md) | **New in V5.** Protected credential schema, user-visible profile split, access tiers, security checklist. |
| [Training and Gamification](RPRRSBSI-V5-70-Training-And-Gamification.md) | **New in V5.** Training programs and progress, gamification schemes, scenes, items and rewards. |
| [Ace and Mobile Integration](Ace-Mobile-Integration/README.md) | Requirements companion carried forward from V4; V5 notes the ownership and publication changes. |
| [HANDOFF-V5](HANDOFF-V5.md) | Gaps and the decisions the developer must supply. |

## Expansion HITL register (V4-2 numbering kept; V5 status added)

| ID | Decision needed before physical implementation |
| --- | --- |
| V5-H-01 | Exact agent and PowerShell ContentSummary envelope, field classification, and compatibility policy. **V5: closed in practice by the built V00100/V00110 contract.** |
| V5-H-02 | ContentSummary storage location, prompt/source retention, ranking, freshness, and maximum result contract. **V5: built in V00100; storage location now `ATAPUtilities` templates plus owned `Ace` copies (DEC-3).** |
| V5-H-03 | Claude/Codex integration points, supported harness versions, endpoint allowlist, and proxy failure behavior. |
| V5-H-04 | Header allowlist/redaction/hashing and whether any request, response, prompt, or tool body may be retained. |
| V5-H-05 | Semantics and controlled codes for thinking/reasoning, cache, tool, and later provider metrics. |
| V5-H-06 | Phase-one Outpost device matrix, persistence provider, encryption/store split, and key custody. |
| V5-H-07 | Projection, transport, conflict, deletion, retention, retry, cursor, and synchronization policies. |
| V5-H-08 | Plugin migration lineage, isolation mode, signing/trust, revocation, and removal-data disposition. **V5: lineage decided by DEC-4/DEC-5 (developer DDL outside Flyway; published bolt-ons inside it); the rest open.** |
| V5-H-09 | Exact initial table/key/index/API/DTO inventory after the preceding gates close. |

V5 adds open decisions V5-H-10 onward; they are listed with recommendations in [HANDOFF-V5.md](HANDOFF-V5.md).

## Scope boundary

This specification defines documentation-level schema, seed, loader, query, and
behavioral contracts. It does not execute Flyway against `expwhertzing`, promote a
package, access credentials, purchase components, or run provisioning. Those are
separate implementation tasks with named human-in-the-loop gates.
