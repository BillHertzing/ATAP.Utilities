# RPRRSBSI-V4-2 Source Synthesis and Design Traceability

## Evidence reviewed

This V4-2 synthesis is based on five evidence classes: the RPRRSBSI V4 operator record;
the active V3 schema, migrations, seeds, and core-schema documentation; the archived
V2 logical models and decisions; the existing V4 specification family and Ace/mobile
requirements companion; and
`_Planning/InformationForTheFuture/Sprint0015/StreamN/Task-15.140.b.2/DB-Design-Expansion-Consolidated-Inputs.md`.

This document records the synthesis, not a verbatim transcript. The conversation remains the authority for wording disputes; this set converts it into testable requirements.

## V4-2 expansion disposition

| Expansion source area | V4-2 disposition | Governing document |
| --- | --- | --- |
| Plugin-owned expert systems and database expansion | adopted with host-mediated writes and governed migrations | `RPRRSBSI-V4-2-15-Plugin-Database-Expansion.md` |
| Tags and ContentSummary scheduled ingestion | adopted as the first Outpost vertical slice | `RPRRSBSI-V4-2-25-ContentSummary-Data-Contract.md` |
| AI-agent request/response proxy | adopted under Ace AISupervisor, with secret-bearing header values prohibited | `RPRRSBSI-V4-2-35-AISupervisor-Request-Response-Telemetry.md` |
| Remote persistence and synchronization | adopted as provider-neutral architecture; provider selection remains pending | `RPRRSBSI-V4-2-45-Edge-Persistence-And-Synchronization.md` |
| AceCommander visualizers | adopted as initial application consumers | `RPRRSBSI-V4-2-Ace-Outpost-Commander-Integration/30-AceCommander-Visualization.md` |
| Git history, code-to-Rules, photo/NFT, outdoor activity, and broader manifestation | retained as later consumers; deferred from the initial slice | `RPRRSBSI-V4-2-55-Initial-Capability-Slice.md` |

The raw-input consolidation's conservative Proposed status for C-01, C-02, and C-03
does not downgrade them. The existing V4 operator authority records their ratification;
V4-2 preserves that later status while retaining the raw transcript as source evidence.

## V4-2 findings

- **V4-2-FIND-001:** No reviewed, versioned output envelope for both the
  `Get-ContentSummary` agent and PowerShell function is present in the source set; a
  representative fixture is the first implementation prerequisite.
- **V4-2-FIND-002:** The existing two-column
  `AceOutpostContentSummaryPrototype` migration cannot satisfy Tags association,
  tenancy, provenance, synchronization, or query requirements. It remains evidence from
  another task and is not modified or adopted as V4-2 authority.
- **V4-2-FIND-003:** Request and response body retention is unnecessary for the initial
  token visualizer and materially enlarges the security boundary; V4-2 defaults it off
  pending an explicit ruling.
- **V4-2-FIND-004:** A controlled metric child permits provider metadata evolution
  without converting the primary exchange into an untyped property bag.
- **V4-2-FIND-005:** The AceCommander `Any`/`All` and time-series views require
  authorization before filtering and aggregation, not only at final-row presentation.
- **V4-2-FIND-006:** Remote persistence technology cannot be selected responsibly until
  the phase-one device matrix, threat model, encryption boundary, and synchronization
  requirements are approved.

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

- **V4-2-TRACE-001:** V2 physical schemas and table names are not implementation authority; only aligned concepts and constraints are recovered.
- **V4-2-TRACE-002:** Internal `Version` or revision-number rows are replaced by GUID-identified `State` and `Variant` rows with Philote validity.
- **V4-2-TRACE-003:** Free-form polymorphic GUID endpoints are replaced by typed `Entity` endpoints.
- **V4-2-TRACE-004:** One all-purpose graph is rejected; workflow and calculation graphs have different invariants and tables.
- **V4-2-TRACE-005:** Copying a full Rule to override one context is rejected; a RuleVariant reuses the basic Rule identity.
- **V4-2-TRACE-006:** Table-per-plugin duplication is not the default ACE extension strategy.
- **V4-2-TRACE-007:** Tags are not an authorization mechanism.
- **V4-2-TRACE-008:** External-effecting manifestation is not coupled to definition or validation; it requires later plan and approval boundaries.

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

- **V4-2-TRACE-020:** A derived task SHALL cite a V4 requirement ID and identify whether its authority is V3-retained, V2-recovered, user-new, or an open decision.
- **V4-2-TRACE-021:** If a task changes a working open decision, it SHALL update every affected schema, seed, diagram, query, and test contract before implementation begins.
- **V4-2-TRACE-022:** Historical documents may explain intent but SHALL NOT override the active V3 baseline or a ratified V4 decision.

## Inherited-decision disposition matrix

This matrix is the Task 15.140.b decision-level successor record. Its disposition
vocabulary is closed: `adopted`, `adapted`, `superseded`, and `rejected`. Historical
documents remain historical even when a decision is adopted. A disposition never edits
past facts or authorizes SQL, migration, seed, package, feed, deployment, or live-system
work.

### V2 inherited decisions

| ID | Historical V2 decision or decision family | Disposition | V4 successor meaning | Historical citation |
| --- | --- | --- | --- | --- |
| V2-01 | Physical V2 schema/table names as implementation authority | superseded | V4 recovers concepts only; V3/PTV is the physical starting baseline. | `_Planning/InformationForTheFuture/RRSBS-V2-Design-Archive/INDEX.md`; fragment catalog |
| V2-02 | Durable EntityType/Entity registry and typed generic endpoints | adapted | Typed endpoints remain useful, but free-form polymorphic GUID use is rejected and exact relations use typed contracts. | `fragments__RDB-400-410__Foundation-Kind-Primitive.sql`; V4-2-TRACE-003 |
| V2-03 | Authority, Expert, ExpertiseDomain, Tag, attribution, and assignment model | adapted | Authority/provenance concepts are retained selectively; Tags follow C08-C15 and authorization remains separate. | `fragments__RDB-400-410__Foundation-Kind-Primitive.sql`; C08-C15 operator record |
| V2-04 | RuleKind, primitive, value-type, executor, and structured-value foundation | adapted | Stable kind/primitive identity is retained while internal Version rows become State/Variant contracts. | `fragments__RDB-400-410__Foundation-Kind-Primitive.sql`; C06 |
| V2-05 | Rule composition, definitions, defaults, outputs, nodes, and bindings | adapted | V4 separates workflow and calculation graphs and adds typed output/input bindings. | `fragments__RDB-420__Rule-Composition.sql`; V4-2-TRACE-004 |
| V2-06 | RuleSet/BuildSet version-member rows | adapted | Collection meaning is retained through identified occurrences; V2/V3 pair-key membership is not the V4 composition authority. | `fragments__RDB-430__RuleSet-BuildSet.sql`; retained D2; C03 |
| V2-07 | Instantiation, edit session, InputBlock, binding resolution, and permission-grant model | adapted | V4 recovers grouped inputs and immutable snapshots but keeps authorization as an independently approved boundary. | `fragments__RDB-440__Instantiation-InputBlock.sql`; V4-2-TRACE-008 |
| V2-08 | SourceArtifact, context, ContentSummary, AgentText, and provenance model | adapted | Explanation/ingestion concepts return only through typed provenance relationships and separately approved layer contracts. | `fragments__RDB-460-470__Context-Content-Retained.sql`; V4-2-TRACE-020 |
| V2-09 | Separate physical `Tags` schema and legacy Tags tables | rejected | C08 places Tags inside `ATAPUtilities`; C09-C15 define the durable-root/State successor shape. | `fragments__RDB-460-470__Context-Content-Retained.sql`; C08-C15 |
| V2-10 | Generic Gmail, Repository, Organization, and other retained-context tables as automatic V4 scope | rejected | A source-list entry or historical table is not V4 scope without a ratified requirement. | `fragments__RDB-460-470__Context-Content-Retained.sql`; V4-2-TRACE-022 |
| V2-11 | RDB-500 language/domain catalog fragments A/B/C/D/E/F/H/I/O/P | adapted | The catalog evidence is preserved; exact V2 rows and GUIDs are not V4 seed authority. | `_Planning/InformationForTheFuture/RRSBS-V2-Design-Archive/INDEX.md`; RDB-500 fragments |
| V2-12 | RDB-010D proposed consumer routing | superseded | Its proposals remain recovery evidence; V4 work requires current consumer discovery and an approved contract. | `RDB-010D__ConsumerMap.md` |
| V2-13 | RDB-010F structured-GUID origin recommendations | superseded | C01 governs GUID text/value handling; V3 registry GUIDs remain baseline identities only. | `RDB-010F__structured-guid-origin-analysis.md`; C01 |
| V2-14 | RDB-180A/B stable-identity and content-hash evidence | adopted | Byte/hash evidence remains historical provenance; it does not allocate V4 semantic identity. | RDB-180A/B `ContentHash*`, `StableIdentityDisposition`, and `Verification` packets |
| V2-15 | RDB-480 D1/D2/D3 option analyses and recommendations | superseded | Unapproved recommendations are not inherited architecture rulings; ratified V4 decisions and explicit future gates govern. | `RDB-480-D1__analysis.md`; `RDB-480-D2__analysis.md`; `RDB-480-D3__analysis.md` |
| V2-16 | RDB-500G/J/K/L/M/N do-not-seed decisions | adopted | Their negative gate remains: no seed exists or is authorized merely because V4 cites the historical domain. | RDB-500G/J/K/L/M/N `NonSeedDisposition.md` packets |
| V2-17 | Independent review conclusion that no future-use V2 design is stranded only under `_generated` | adopted | Durable archive provenance remains valid; it does not revive V2 implementation authority. | `_Planning/InformationForTheFuture/RRSBS-V2-Design-Archive/Independent-Review.md` |

### V3 inherited decisions and implemented facts

| ID | V3 decision or implemented fact | Disposition | V4 successor meaning | V3 citation |
| --- | --- | --- | --- | --- |
| V3-01 | V3 supersedes V1/V2 without rewriting history | adopted | V4 follows the same history-preserving rule and succeeds V3 forward-only. | `_Planning/InformationForTheFuture/Plan_RPRRSBSI_V3Redesign.md`, Source review |
| V3-02 | Implemented eleven-table V3/PTV baseline | adopted | It is the factual migration starting point, not the complete V4 endpoint. | `ATAP.Utilities/Database/Documentation/RPRRSBSI-V3-Data-Dictionary.md`; active V00010 |
| V3-03 | Retained PowerShell/Path catalogs and exact HelloWorld example | adopted | V4 preserves baseline identities and facts while adding richer contracts. | `ATAP.Utilities/Database/Documentation/RPRRSBSI-V3-Path-Selection.md`; GUID registry |
| V3-04 | Same GUID for each Philote-bearing entity key and Philote key | adapted | Baseline equality remains; V4 durable roots/states apply the ratified identity rules per entity type. | V3 Data Dictionary; V3-D04; C02; C09 |
| V3-05 | Half-open PhiloteValidityPeriod chain with gaps and procedure boundary | adopted | V4 uses the implemented as-of foundation and adds entity-specific invariants. | V3 Data Dictionary, Temporal-validity exactness; C11; C15 |
| V3-06 | V3 internal Version/effective-dating/lineage objects excluded | adapted | V4 still rejects revision-number semantics but uses ratified `State` and `Variant` terminology. | V3 plan, Explicitly excluded; C06 |
| V3-07 | V3 excluded InputBlock, provenance, Tags, ContentSummary, manifestation, and execution domains | superseded | The exclusion bounded V3 correctly; ratified V4 requirements selectively add these domains in later layers. | V3 plan, Explicitly excluded; V4 normalized themes |
| V3-08 | V3 external CSV plus deterministic loader pattern | adopted | Future approved V4 seeds retain deterministic source-controlled inputs; this task authorizes none. | V3-D03; V3 plan, Proposed migration allocation |
| V3-09 | V3 GUID registry contains 22 fixed baseline semantic identities | adopted | Those identities remain baseline facts; new V4 identities require a separate registry allocation. | `ATAP.Utilities/Database/Documentation/RPRRSBSI-V3-GUID-Registry.csv` |
| V3-D01 | Seed both retained PowerShell primitives and use complete-cmdlet for HelloWorld | adopted | Baseline catalog and example remain unchanged. | V3 plan, V3-D01 |
| V3-D02 | Retain 13 Path primitives, 21 inputs, no new primitive, exact relative path | adopted | V4 does not amend the grammar in this design disposition. | V3 plan, V3-D02; V3 Path Selection |
| V3-D03 | External CSV per seed table and loader per table | adopted | Pattern remains the deterministic seed contract, subject to later approved V4 seed design. | V3 plan, V3-D03 |
| V3-D04 | Entity/Philote key equality and explicit FK | adapted | Applied to the V3 baseline; V4 state/root allocation follows C02/C09 and does not infer universal state Philotes. | V3 plan, V3-D04; C02; C09 |
| V3-D05 | Retain RuleSetRule and BuildSetRuleSet ordered pair memberships | superseded | Tables remain baseline facts; identified occurrences replace them for V4 composition and overlays. | V3 plan, V3-D05; retained D2; C03 |
| V3-D06 | Canonical pre-V3 archive root | adopted | The archive remains historical and byte-preserving. | V3 plan, V3-D06 |
| V3-D07 | Historical lineage labeling/removal and V3 package restart | adopted | The recorded lineage fact remains; this documentation task performs no package/feed/live action. | V3 plan, V3-D07; G0/G1 record |
| V3-D08 | Intentional `Write-Host` in minimal generated sample | adopted | Historical sample content remains exact; it is not a module logging precedent. | V3 plan, V3-D08 |
| V3-D09 | Coordinator may define the smallest complete V3 physical contract for HITL review | superseded | That authority was consumed by the implemented V3/PTV contract; V4 physical changes require their own ratified gates. | V3 plan, V3-D09; V3 G0 record |
| V3-PTV | PTV amendment replaces V3 TimeBlock before packaging | adopted | `PhiloteValidityPeriod` is the active implemented temporal baseline. | V3 plan, 2026-08-08 Philote temporal rebaseline; V3 Data Dictionary |

### Ratified or ruled V4 carry-forward decisions

| ID | Decision | Disposition | V4 use | Authority citation |
| --- | --- | --- | --- | --- |
| C01 | Canonical lowercase dashed GUID text; database comparison by value | adopted | Normative for CSV/API fixtures and database comparisons. | Operator Input section 2 |
| D2 | Higher BuildSet occurrence ordinal wins; duplicate ordinals invalid | adopted | Normative precedence rule. | Operator Input section 2, retained D2 |
| C02 | Material declared-type change creates new semantic identity | adopted | Normative for the general rule and all eight edge classifications ruled 2026-09-04. | Operator Input C02 and D-3 companion |
| C03 | Overlay is a same-RuleId RuleVariant selected by Override occurrence | adopted | Replaces copied-rule overlay behavior. | Operator Input C03 |
| C04 | ATAP immutable references; ACE overlays/sessions; topology-neutral union | adopted | Normative ownership/topology boundary. | Operator Input C04 |
| C05 | Durable Tag endpoints with active TagState resolved as-of | adopted | Normative Tags endpoint rule. | Operator Input C05 |
| C06 | Use State/Variant; reserve Version for software releases | adopted | Normative terminology rule. | Operator Input C06 |
| C07 | First manifestation stops at validated change/configuration plan | adopted | Purchasing/provisioning remains deferred. | Operator Input C07 |
| C08 | Tags live in `ATAPUtilities`, not a separate `Tags` schema | adopted | Governs V4 Tags physical placement. | Operator Input C08 |
| C09 | Durable Tag root owns Philote and immutable namespace/code; TagState has no Philote | adopted | Governs Tags identity and natural key. | Operator Input C09 |
| C10 | Namespace stewardship is data and an authoring gate with history/co-stewards | adopted | Governs stewardship model; C16 supplies the opaque principal/provenance contract. | Operator Input C10 |
| C11 | Philote validity is identity lifespan; TagState is payload timeline | adopted | Governs dual temporal model and containment invariant. | Operator Input C11 |
| C12 | Typed relations and generic assignment; assignment targets durable TagId | adopted | Governs relation and assignment endpoints; C21/C22 are ruled 2026-09-04. | Operator Input C12 |
| C13 | TagVersion becomes TagState; label/description live on state | adopted | Governs state terminology and display payload; C23 omits initial localization. | Operator Input C13 |
| C14 | Temporal aliases, namespace-local, no reissue, controlled type, trigger uniqueness | adopted | C26 fixes collation; FU-4 fixes SQL Server Express and its validation burden. | Operator Input C14; 2026-08-30 rulings |
| C15 | Dual-layer retraction, one write/read path, required successor pointer | adopted | FU-6 defines multi-hop, cycle, terminal-resolution, and erroneous-withdrawal semantics. | Operator Input C15; 2026-08-30 rulings |
| C16 | Opaque principal, active-steward authoring gate, source reference, dual UTC timestamps | adopted | Generalized approval workflow remains deferred. | 2026-08-30 operator ruling |
| C20 | One authoritative `ATAPUtilities` catalog; no initial tenant discriminator | adopted | Governs initial catalog and key scope. | 2026-08-30 operator ruling |
| C26 | Explicit `Latin1_General_100_CI_AS_SC` Tag-code collation | adopted | Governs canonical and alias comparisons. | 2026-08-30 operator ruling |
| FU-4 | SQL Server Express target with trigger behavior/performance validation | adopted | Governs target-platform evidence. | 2026-08-30 operator ruling |
| FU-6 | Multi-hop successors, cycle rejection, first active terminal resolution, erroneous-withdrawal exception | adopted | Governs successor behavior and C15 exception. | 2026-08-30 operator ruling |
| D3-1..8 | Eight declared-type edge classifications | adopted | All eight exact material/non-material boundaries are normative. | 2026-09-04 operator ruling; D-3 companion |
| C17 | Tags never authorize | adopted | Hard architecture and negative-test invariant. | 2026-09-04 operator ruling |
| C18 | No intrinsic Tag ordering | adopted | `Ordinal` is used only on genuinely ordered collections. | 2026-09-04 operator ruling |
| C19 | Typed, directed, optionally weighted Tag relations | adopted | Storage is governed here; traversal behavior is deferred to Task 15.50.b. | 2026-09-04 operator ruling |
| C21 | Initial assignment EntityType allow-list | adopted | Initial codes are `rule` and `instantiation`. | 2026-09-04 operator ruling |
| C22 | Durable-root relation endpoints | adopted | No exact-state relation FK. | 2026-09-04 operator ruling |
| C23 | No initial localization | adopted | Reserve an additive localization child. | 2026-09-04 operator ruling |
| C24 | No automatic legacy taxonomy migration | adopted | Reviewed terms may be re-authored later. | 2026-09-04 operator ruling |
| C25 | Recorded metadata inventory pre-live gate | adopted | Requires separate authorization; does not itself authorize inventory. | 2026-09-04 operator ruling |
| C27 | No initial assignment confidence/relevance | adopted | Add only after demonstrated ContentSummary need. | 2026-09-04 operator ruling |

## Ratification boundary

The D-3 and Tags items formerly held here were all ruled on 2026-09-04 and now have
explicit adopted rows above. No item in that enumerated packet remains pending. Newly
discovered architecture questions still require their own operator ruling.

Authority: `_Planning/InformationForTheFuture/Sprint0015/StreamN/Task-15.140.a/RPRRSBSI-V4-Operator-Input.md`
and its companion
`_Planning/InformationForTheFuture/Sprint0015/StreamN/Task-15.140.a/RPRRSBSI-V4-D3-EdgeCase-Clarifications.md`.
