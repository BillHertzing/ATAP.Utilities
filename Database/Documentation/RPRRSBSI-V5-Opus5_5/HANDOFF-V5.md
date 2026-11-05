# HANDOFF-V5 — gaps and decisions needed

Written 2026-11-05 by the cloud Claude session (Opus 5.5) that produced the `RPRRSBSI-V5-Opus5_5` set. This file lists (1) what V5 decided, (2) the decisions the developer still needs to supply, with a recommendation for each, and (3) known gaps in this set. Nothing in this set authorizes a migration, deployment or code change.

## 1. Already decided (do not reopen without a new decision)

| ID | Decision | Date |
| --- | --- | --- |
| DEC-1 | Instantiation origin values `Asserted` and `Generated`. | 2026-11-05 |
| DEC-2 | Hand-entered content summaries use a dedicated asserted rule set and specification; V00100 columns stay `NOT NULL`. | 2026-11-05 |
| DEC-3 | `Ace` is a full copy of every `ATAPUtilities` table plus Ace-only tables; every `Ace` row has owner columns; C-20 and V5-CORE-074 amended. | 2026-11-05 |
| DEC-4 | V5-PDB-002 amended: developers author DDL in `Ace` only for tables they own, via DDL Authoring mode; such tables are visible only to them. | 2026-11-05 |
| DEC-5 | Marketplace bolt-on submission process (migrate to `ATAPUtilities`, back up and remove developer tables, create owned `Ace` copies, move data, choose template rows). | 2026-11-05 |
| DEC-6 | *Instantiation* = a produced file or row. | 2026-11-05 |
| DEC-7 | *Materialization* = the run of an executor (*materializer*) over BuildSets and inputs; its reusable configuration is a *materialization specification*. | 2026-11-05 |
| DEC-8 | Forward migration renames V00010 `Instantiation` → `MaterializationSpecification` and creates a new `Instantiation` table. | 2026-11-05 |
| DEC-9 | Common initial load of both schemas; afterwards changes start in `Ace` and some are promoted to `ATAPUtilities`. | 2026-11-03 |
| DEC-10 | Rules that govern AI agents are held as RRSBS instantiations (ADR-018). | 2026-11-03 |

## 2. Decisions the developer needs to supply

Ordered roughly by what blocks the earliest slices ([V5-50](RPRRSBSI-V5-50-Layered-Implementation-Handoff.md) V5-S1 … V5-S9). Each has a recommendation; choosing the recommendation is a valid answer.

### Blocks V5-S1/S2 (materialization and asserted summaries)

| ID | Question | Recommendation | Document |
| --- | --- | --- | --- |
| V5-H-10 | When does the DEC-8 rename reach Production: alone, or only inside the next consolidated baseline? | Only inside the consolidated baseline; keep all post-V00070 work Experimental-only until then. | V5-12 §4, V5-50 |
| V5-H-11 | Is every `ContentSummaryVersion` also registered as an `Instantiation` row, or does it carry the instantiation columns itself? | Register it (one place to ask "what produced this row?"). | V5-12, V5-25 |
| V5-H-12 | What counts as "equal" when a `Generated` instantiation supersedes an `Asserted` one: normalized byte hash for files; which column set for rows? | Files: normalized SHA-256 (LF, no BOM, as V00100). Rows: all non-provenance, non-owner columns. Allow a reviewed difference. | V5-12 |
| V5-H-13 | Codes for the asserted ContentSummary rule set and specification. | `CS-A00-contentsummary-asserted-v1`, `CS-A01`…`CS-A06`, `CS-A-PROMPT-asserted-v1`. | V5-25 |
| V5-H-14 | Are telemetry rows (AISupervisor, gather-content) instantiations? | No, by default: operational data; register only when traceability is needed. | V5-35 |
| V5-H-15 | AgentText kind: revive it as the kind for AI-agent rules and pilot `main-instructions.md` as the first asserted file instantiation? (ADR-018's four questions remain open.) | Yes, as the V5-S2 pilot. | V5-12 |

### Blocks V5-S3 (protected authentication)

| ID | Question | Recommendation | Document |
| --- | --- | --- | --- |
| V5-H-20 | Name and scope of the protected schema; who are ACE administrators. | `AceAuth`; administrators via a `AceAdministrator` capability. | V5-65 |
| V5-H-21 | Which security items in the first increment (S1–S9). | S1 isolation, S2 pepper, S3 HMAC email key, S5 lockout, S7 audit; defer S4, S6, S8. | V5-65 §3 |
| V5-H-22 | Keep local passwords, or delegate sign-in to an external identity provider later? | Keep local passwords now; design so an external provider can be added. | V5-65 |

### Blocks V5-S4/S5 (ownership and the Ace copy)

| ID | Question | Recommendation | Document |
| --- | --- | --- | --- |
| V5-H-30 | Are `Philote` and `PhiloteValidityPeriod` shared rather than copied? ("full copy" would otherwise create a second identity registry.) | Shared. | V5-60 §4 |
| V5-H-31 | Owner columns: `OwnerUserId` xor `OwnerOrganizationId` plus `CreatedByUserId`? | Yes. | V5-60 §3 |
| V5-H-32 | How are ownership changes stored: a generic temporal `RowOwnershipState`, or updates guarded by a history trigger? | `RowOwnershipState`; owner columns keep the original owner. | V5-60 §3 |
| V5-H-33 | Row-level security session contract: what the host puts in `SESSION_CONTEXT` (user, organizations, administrator flag) and how administrators bypass. | As V5-60 §5, with audited administrator sessions. | V5-60 §5 |
| V5-H-34 | Existing `Ace.Tag`/`Ace.TagNamespace` (V00060): rename or fold into the new copies? | Rename to `Ace.GatherContentSubmittedTag`/`Ace.GatherContentTagNamespace`. | V5-60 §7, V5-30 |
| V5-H-35 | Owners for existing rows when owner columns are retrofitted (organization tables, user tables, telemetry). | Organization rows → their organization; user rows → the user; telemetry → the capturing user. | V5-60 §7 |
| V5-H-36 | Generate `Ace` twins from `ATAPUtilities` definitions with an RRSBS SQL-kind materializer, or hand-write them? | Generate; add a copy manifest and drift check. | V5-60 §6 |
| V5-H-37 | `ATAPUtilities.Repository.OrganizationId`: retire the column, or keep repositories as organization-owned exceptions? | Retire; ownership lives in the `Ace` copy. | V5-60 §7 |

### Blocks V5-S6/S7 (DDL authoring and marketplace)

| ID | Question | Recommendation | Document |
| --- | --- | --- | --- |
| V5-H-40 | Per-developer schemas (`AceDev_<key>`) or one shared developer schema with per-object denies? | Per-developer schemas. | V5-15 |
| V5-H-41 | Quotas for developer tables (tables, columns, rows, storage). | Start small (for example 20 tables, 100 columns, 100k rows, 1 GB) and adjust. | V5-15 |
| V5-H-42 | Naming of published bolt-on tables in `ATAPUtilities`: publisher prefix, or a per-bolt-on schema/namespace? | Publisher prefix plus bolt-on code, kept in `ATAPUtilities`. | V5-15 |
| V5-H-43 | Open-source licence for template rows and published table definitions; how publisher attribution is identified publicly. | One fixed permissive licence for all template content; a public `Publisher` identity, not an Ace `UserId`. | V5-15 |
| V5-H-44 | Who holds `MarketplaceReviewer` and `AtapMaintainer`; is a two-person rule required for every submission? | Yes, two people other than the submitter. | V5-15 |
| V5-H-45 | Purchase and entitlement model: one-time vs subscription; per user or per organization; payment provider. | Entitlements per user or organization, temporal; provider chosen later; store only provider references. | V5-15, V5-65 |
| V5-H-46 | Third-party plugins that do not come through the marketplace: own Flyway lineage or none? (remainder of V5-H-PDB-01) | Not allowed until needed. | V5-15 |
| V5-H-47 | Capabilities: a new `UserCapability` table, or extend `ACE.RoleAssignment`? | New `UserCapability` table (platform-scoped). | V5-62 §5 |

### Blocks V5-S4 gamification and the AceCommander UI

| ID | Question | Recommendation | Document |
| --- | --- | --- | --- |
| V5-H-50 | Where are scene and item images stored (asset store, repository files, database blobs)? | Outside the database; reference by SHA-256 and locator; register as file instantiations. | V5-70 |
| V5-H-51 | Can a user change theme after onboarding? Are placements kept per theme? | Yes, from settings; placements kept per theme. | V5-70, UI 40 |
| V5-H-52 | Is training progress per user only, or also per organization? | Per user; organizations can see members' progress later if needed. | V5-70 |
| V5-H-53 | Completion rules: quiz scoring, pass marks, retries. | Per-step completion rule in `TrainingWizardStep`; simple pass/fail first. | V5-70 |
| V5-H-54 | Initial content: which schemes, scenes, items and value tiers, and which training program, are seeded first? | One scheme, three scenes, four value tiers, one introductory program. | V5-70, V5-20 |
| V5-H-55 | Is training content itself RRSBS-materialized (files from rules) or authored directly? | Authored directly as asserted file instantiations first. | V5-70 |
| V5-H-56 | Scene canvas technology in AceCommander (Syncfusion Diagram, HTML canvas, SVG), mobile layout, keyboard placement. | SVG overlay with keyboard placement; decide with the Blazor/Syncfusion rules loaded. | UI 40 |

### Organization, identity and estates

| ID | Question | Recommendation | Document |
| --- | --- | --- | --- |
| V5-H-60 | `ACE.Project` vs `SoftwareProduct`: keep both or merge; allow organization ownership of projects. | Keep both (a project produces products); allow organization owners. | V5-62 §3 |
| V5-H-61 | Is a software development process a BuildSet, an ExpertSystem, or its own entity linked to one? | Its own entity linked to a BuildSet now, to an ExpertSystem when that is built. | V5-62 §3 |
| V5-H-62 | Enforce the same-organization rule when an identity binding is created (today only at read)? Materialize `HostAccount`? | Enforce at write; defer `HostAccount`. | V5-62 §2 |
| V5-H-63 | Estate stages, will status, executor role, asset kinds, jurisdiction. | Stages `Active` → `DeceasedUnadministered` → `UnderAdministration` → `Closed`; will status separate; jurisdiction later. | V5-62 §4 |

### Still open from V4-2 (carried forward unchanged)

V5-H-03…V5-H-07 and V5-H-09 ([V5-00](RPRRSBSI-V5-00-Specification-Overview.md)); V5-H-AIS-01…05 ([V5-35](RPRRSBSI-V5-35-AISupervisor-Request-Response-Telemetry.md)); V5-H-PDB-02…04 ([V5-15](RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md)); V5-H-EDGE-01…04 ([V5-45](RPRRSBSI-V5-45-Edge-Persistence-And-Synchronization.md)).

## 3. Gaps in this V5 set

1. **Reading depth.** The V4-2 documents were carried forward whole by a script (IDs, links and titles rewritten) and then amended where the decisions apply. Of the sources, `RPRRSBSI-V4-2-10` and `-35` were read in full earlier; `-25` about 75%; the rest at opening, headings and targeted sections. Carried-forward text that was not re-read may still contain V4-2 wording that conflicts with DEC-3 or DEC-6 (for example "tenant", "Instantiation" in the old sense, or the ATAP-first direction). Each document's header states how to read such text. A keyword pass (2026-11-05) annotated the C-20 statements in V5-20, -30, -40 and -50, and "tenant" in V5-10, -35 and -45, and marked the old meaning of "Instantiation" in V5-25; "mirror" and `productionPublishNewOrModifiedPLugin` in the Ace/Mobile suite are covered by its V5 changes section. A line-by-line review is still needed.
2. **Diagrams not validated.** Six V5 PlantUML files were written (core entity model, instantiation and materialization, ownership and the Ace copy, DDL authoring and marketplace, ContentSummary, training and gamification). PlantUML was not available in the cloud session, and downloading it was blocked, so they have not been rendered. The PlantUML MCP server failed to start because `pwsh` is missing. Other V4-2 diagrams are referenced unchanged.
3. **Existing diagrams outside this folder are misleading.** `../Ace_Schema.puml` and `../Represented_Entities_Domain_Model.puml` show unbuilt designs (Codex-V3 `Org.*` tables, Antigravity `ProjectContentSummary`) beside built tables without marking which is which. The built organization tables are `ACE.*` (V00160–V00210).
4. **Not versioned to V5.** The V4 (non-"-2") predecessors (superseded by V4-2, so their content is in V5 via V4-2); `RPRRSBSI-V3-*`, `RRSBS-RDB-*`, `ADR-Philote-Temporal-Validity-Relational-Contract.md`, `AceCommander-UserLogin-Relational-Contract.md`, and the operational documents. These are referenced, not copied. `AceCommander-UserLogin-Relational-Contract.md` will need a V5 revision when V5-S3 is designed.
5. **Folder index not updated.** `../Index.md` and `../ReadMe.md` do not yet point to this folder; they also still describe package `0.1.0`/`0.1.6`.
6. **Root `CLAUDE.md` is out of date.** Its "Rule Grammar Database Schema" section describes `PrimitiveLanguageKind`/`RulePrimitiveComposition`, which no current migration creates. Its source is the SharedVSCode `.ai` canonical files, a high-impact repository; changing it needs confirmation.
7. **Release history inconsistencies.** `Database/Flyway/ReleaseNotes.md` disagrees with the release records about 0.1.5/0.1.6 and lacks several versions; Production state after `V00070` is unknown.
8. **No application review.** AceCommander and AceOutpost code was not read; UI requirements in `Ace-Outpost-Commander-Integration/40` are new and untested against the current login flow beyond the 2026-11-03 identity handoff.
9. **Legal terms.** Estate terms in V5-62 follow the developer notes; they are not checked against any jurisdiction.

## 4. Where the inputs live

- Developer notes: `_Planning` branch `44-Sprint-0017-work-items`, `InformationForTheFuture/Sprint0018/DatabaseEnhancements/DeveloperNotes-2026-11-03.md`, `DeveloperNotes-2026-11-04.md`.
- Analysis: same folder, `Claude-v1/Requirements-Impact-2026-11-04.md` (revision 2), `Claude-v1/Database-ADR-V1.md` (ADR-001…018), `Claude-v1/DatabaseDocumentationCatalog-v2.json`, `Claude-v1/CheckpointSummaries.md`.
- Built schema: `ATAP.Utilities` branch `150-Sprint-0017-work-items`, `Database/Flyway/SQL/V00010`–`V00210`.
