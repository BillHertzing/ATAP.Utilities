# RPRRSBSI-V5 Plugin Database Expansion, Developer DDL Authoring and Marketplace

> **V5 revision (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Successor of `Database/Documentation/RPRRSBSI-V4-2-15-Plugin-Database-Expansion.md`. Requirement and decision IDs keep their V4-2 numbers with the prefix `V5-` (for example `V4-2-CORE-034` is now `V5-CORE-034`); a V4-2 ID that is not repeated here is withdrawn only where the "V5 changes" section says so. The V5 decisions DEC-1 to DEC-6 and the 2026-11-05 training and gamification requirements are summarised in [the V5 overview](RPRRSBSI-V5-00-Specification-Overview.md#v5-decisions); open items are in [HANDOFF-V5.md](HANDOFF-V5.md). **Terminology (DEC-6):** an *Instantiation* is a produced file or row; the run of an executor that produces instantiations is a *Materialization*; the reusable configuration it runs is a *materialization specification*. Where carried-forward V4-2 text uses "Instantiation" for the configured act, read "materialization specification".


## V5 changes

| Change | Source |
| --- | --- |
| V5-PDB-002 amended: developer users may author DDL in `Ace` for tables they own | DEC-4 |
| V5-PDB-003, -004, -006 qualified for developer-owned tables | DEC-4 |
| DDL Authoring mode added (§ "Developer DDL authoring") | DEC-4 |
| Publication boundary replaced by the marketplace bolt-on submission process | DEC-5 |
| Marketplace entities, rights and entitlements added | DEC-5, 2026-11-04 marketplace requirement |
| V5-H-PDB-01 decided in part | DEC-4, DEC-5 |

The marketplace is the product (2026-11-04): developers come into the application, create Ace tables and seed data, turn them into a set of instantiations that make up a software program, and each user who buys it gets that program as a bolt-on to their Ace application.

Status: design contract; no DDL, migration, plugin activation, or production publication is authorized.

## Purpose

This specification defines how plugins may extend the database without becoming database owners. It preserves the `ATAPUtilities` published-reference plane, the `Ace` mutable working plane, and provider-neutral Outpost persistence.

## Ownership model

- **V5-PDB-001:** A plugin SHALL declare every durable object, data class, permission, dependency, background trigger, and synchronization contract in a signed manifest.
- **V5-PDB-002 (amended 2026-11-05, DEC-4):** Plugins and users SHALL write through host-owned repositories and SHALL NOT receive arbitrary SQL, schema-owner, or central-database credentials. **Exception:** a user holding the developer right MAY author DDL in `Ace` only for tables that user owns, through the DDL Authoring service (V5-PDB-030…038). No user receives DDL on tables they do not own, or any DDL in `ATAPUtilities`. All authored DDL is validated, generated and applied by host-owned procedures and recorded as `Generated` instantiations.
- **V5-PDB-003:** Shared expert-system concepts SHALL use core-owned tables. A plugin-specific table is permitted only when the fact is irreducibly domain-specific and its lifecycle cannot be represented by the shared model. Developer-authored tables (V5-PDB-030) are permitted under the same test, but the test is applied at bolt-on submission review, not at authoring time.
- **V5-PDB-004:** Central plugin-specific tables SHALL remain in the `Ace` schema unless a separately approved publication creates an authoritative `ATAPUtilities` object.
- **V5-PDB-005:** Plugin object names SHALL be manifest-declared, collision checked, and attributable to immutable plugin identity and software version.
- **V5-PDB-006:** Runtime plugin *installation* SHALL NOT execute DDL. A migration service applies an immutable, reviewed, forward-only database package. Developer DDL authoring (V5-PDB-035) is a separate, owner-scoped service and is not plugin installation.

## Migration and compatibility

- **V5-PDB-010:** The selected migration topology SHALL provide one unambiguous order across core and plugin changes, immutable checksums, predecessor requirements, and independent verification of each schema effect.
- **V5-PDB-011:** A plugin manifest SHALL declare minimum and maximum compatible core schema contracts and dependencies on other plugin contracts.
- **V5-PDB-012:** Upgrade failure SHALL leave the prior activated plugin and durable data usable or explicitly quarantined; silent partial activation is prohibited.
- **V5-PDB-013:** Rollback means deactivation plus a separately reviewed forward correction. Applied migrations are never edited or removed from history.
- **V5-PDB-014:** Plugin removal SHALL default to retaining durable data in a disabled, exportable state until a retention disposition is approved.

## Tenancy and security

- **V5-PDB-020:** Every Ace row SHALL carry owner columns (`OwnerUserId` xor `OwnerOrganizationId`, plus `CreatedByUserId`) enforced by row-level security ([V5-60](RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md)); a client-supplied identifier is not authorization evidence.
- **V5-PDB-021:** Plugin permissions SHALL be default-deny and separately enumerate local non-sensitive store, local sensitive store, Ace repository, network destination, filesystem boundary, scheduling, synchronization, secrets-derived operations, and manifestation output.
- **V5-PDB-022:** Tags classify data and SHALL NOT grant any permission.
- **V5-PDB-023:** Header, prompt, source-code, location, EXIF, activity, and LLM payload fields SHALL carry a data classification before storage or synchronization.

## Publication boundary

**Replaced in V5 (DEC-5).** The V4-2 route `productionPublishNewOrModifiedPlugin` is replaced by the marketplace bolt-on submission process below. Its requirements (immutable candidate bytes, manifests and hashes, independent validation, malware and dependency checks, provenance, explicit approval, a new forward-only `ATAPUtilities` release) are kept as checks within that process. Ordinary synchronization still never implies publication authority.

## Developer DDL authoring (DEC-4)

- **V5-PDB-030:** A user holding the `DdlAuthoring` capability MAY enter **DDL Authoring mode**. In that mode the user defines, changes and retires tables that are wholly owned by that user and visible only to that user and ACE administrators.
- **V5-PDB-031:** Authored tables live in a **per-developer schema** (proposed name `AceDev_<short user key>`), created by the host on first use. `VIEW DEFINITION`, `SELECT` and DML on that schema are denied to every principal except the owner's role, the DDL authoring service and ACE administrators. The diagram viewer shows the schema only to its owner and administrators.
- **V5-PDB-032:** Tables are defined **as data**, not as SQL text: `AceDdl.TableDefinition`, `ColumnDefinition`, `KeyDefinition`, `IndexDefinition`, `CheckDefinition`, `ForeignKeyDefinition`, each owned by the developer and versioned by State rows. These definitions are RRSBS rules of the SQL kind; each applied table is a `Generated` instantiation of a materialization of them ([V5-12](RPRRSBSI-V5-12-Instantiation-And-Materialization.md)).
- **V5-PDB-033:** An authoring session is an `EditSession` (V5-CORE) with a concurrency token. One open authoring session per developer. A session is validated, then applied or abandoned.
- **V5-PDB-034:** Validation before apply SHALL enforce: allowed data types and size limits; naming rules and reserved prefixes; a primary key; automatic owner columns ([V5-60](RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md)); foreign keys only to the developer's own tables, to `ATAPUtilities` template tables, or to `ATAPUtilities.Philote`; no triggers, procedures, functions, views with dynamic SQL, synonyms, cross-database references, permissions or schema changes outside the developer schema; quotas on tables, columns, rows and storage.
- **V5-PDB-035:** Apply is performed by a host procedure under a privileged principal the developer never holds. It generates `CREATE`/`ALTER` statements from the validated definitions and runs them in the developer schema. Dropping a table is retire, back up, then drop.
- **V5-PDB-036:** Developers read and write their own tables through host procedures or a generic row API under row-level security; no direct table grants.
- **V5-PDB-037:** Developer-authored DDL is **outside** the Flyway lineage. Every apply is recorded as a materialization with the generated DDL text and its SHA-256, so it is reproducible and auditable. Database reset and backup procedures SHALL treat developer schemas as user data: never cleared without a verified backup.
- **V5-PDB-038:** Seed data for developer tables is entered through the same row API and is owned by the developer. It becomes public only if selected as template rows during submission (V5-PDB-042).

## Marketplace bolt-on submission (DEC-5)

Rights: `MarketplaceDeveloper` (submits), `MarketplaceReviewer` (content, licensing, data), `AtapMaintainer` (approves changes to the open `ATAPUtilities` foundation), database release operator (existing pipeline). Reviewer and maintainer approvals SHALL come from people other than the submitter.

| Step | What happens | Checks and authorizations |
| --- | --- | --- |
| 1. Submit | The developer creates a `BoltOnSubmission`: the developer tables included, name, version, description, licence, intended plan/price, and the template-row selection (step 2). A snapshot of definitions and data hashes is frozen. | Submitter holds `MarketplaceDeveloper`; tables are owned by the submitter; no open authoring session on them. |
| 2. Choose template rows | For each table, the developer marks which rows become **`ATAPUtilities` template rows** (public, open source, visible to anyone). Default: none. | Automated: no personal data, credentials or secrets (classification and pattern scan); referential closure (template rows reference only template rows, other `ATAPUtilities` rows or `Philote`); licence consent recorded; deterministic GUIDs allocated. Reviewer confirms. |
| 3. Automated checks | Schema lint against `ATAPUtilities` conventions; name collision check; generated migration parses; disposable-database rehearsal (fresh install, upgrade from current head, data move). | All must pass before human review. |
| 4. Human review | Reviewer approves content, licensing and data; maintainer approves the `ATAPUtilities` change. | Approvals bound to the snapshot hash. |
| 5. Generate migration | One forward Flyway migration: the new `ATAPUtilities` tables (no owner columns); their template rows; the generated `Ace` copies with owner columns; RLS policies. | Generated only from the approved snapshot; immutable; hashed. |
| 6. Release | New immutable `ATAPUtilities.Database` package through the five tiers, each tier its own gate ([V5-50](RPRRSBSI-V5-50-Layered-Implementation-Handoff.md)). | Existing release rules. |
| 7. Back up and move the developer's data | After the migration is applied in the developer's tier: verified backup of the developer tables (ADR-149); copy the non-template rows into the new `Ace` tables owned by the developer (or the developer's organization); verify counts and hashes; record each copied row as a `Generated` instantiation of the promotion materialization. | Runtime operation, **not** part of the migration: private developer data never enters source control or a package. |
| 8. Remove developer tables | Retire, then drop, the developer tables and their authoring definitions; keep the backup for the rollback window; write `BoltOnPromotionReceipt`. | Requires the backup receipt and verification evidence. |
| 9. Publish | Create `MarketplaceOffering` (+ version) and plan/price. | Reviewer confirms listing. |
| 10. Purchase and activation | A buyer obtains an `Entitlement`; `BoltOnActivation` materializes the bolt-on for the buyer: rows in the `Ace` copies owned by the buyer, optionally initialized from the template rows (derived-from-template, origin `Generated`). | Payment outside the database; only provider references stored. |

- **V5-PDB-040:** Steps 5–6 are the only way a developer's table becomes an `ATAPUtilities` table (V5-CORE-079).
- **V5-PDB-041:** A template row loses owner columns in `ATAPUtilities` but keeps attribution: an `ATAPUtilities.PublisherAttribution` record names the publisher by a public publisher identity, never an `Ace` `UserId` (V5-CORE-072).
- **V5-PDB-042:** Template rows are public reference data needed to make the bolt-on usable on activation (lookup values, example configurations, sample records). Never personal data, customer data, secrets, or data the developer cannot license as open source.
- **V5-PDB-043:** A later version of a bolt-on repeats the process with forward `ALTER`-style migrations; buyers' existing rows are migrated, not replaced.
- **V5-PDB-044:** New `ATAPUtilities` table names SHALL be collision-free; naming scheme (publisher prefix or per-bolt-on namespace) is a pending decision.

## Marketplace entities

| Entity | Schema | Purpose |
| --- | --- | --- |
| `BoltOnSubmission`, `BoltOnSubmissionTable`, `BoltOnTemplateRowSelection`, `BoltOnReview`, `BoltOnPromotionReceipt` | `Ace` | Submission workflow and evidence. |
| `MarketplaceOffering`, `MarketplaceOfferingVersion`, `Plan`, `Price` | `ATAPUtilities` (listing is public) with `Ace` copies | What is for sale. An offering is a `SoftwareProduct` ([V5-62](RPRRSBSI-V5-62-Organization-Identity-Products-And-Estates.md)). |
| `Purchase`, `Entitlement`, `BoltOnActivation` | `Ace` | Per-user (or per-organization) rights and activation; temporal and revocable. |
| `PublisherAttribution` | `ATAPUtilities` | Public credit for template rows and published tables. |
| `UserCapability` | `Ace` | `DdlAuthoring`, `MarketplaceDeveloper`, `MarketplaceReviewer`, `AtapMaintainer`, `AceAdministrator`. |

Diagram: [RPRRSBSI-V5-Plugin-DDL-Authoring-And-Marketplace.puml](RPRRSBSI-V5-Plugin-DDL-Authoring-And-Marketplace.puml).

## Named expert-system consumers

| Expert system | Durable domain facts | First-slice status |
| --- | --- | --- |
| ContentSummary and Tags | summary items, durable Tag associations, candidate/overlay Rules, provenance | prioritized |
| AISupervisor | request/response exchange metadata, safe headers, provider token metrics | prioritized |
| Git history and code-to-Rules | repository/file/commit observations, temporal sidecars, source-to-Rule traceability | deferred |
| Photo, plant lifecycle, and NFT | EXIF sidecars, geospatial/lifecycle classifications, rights and collection facts | deferred |
| Outdoor activity | source activities, tracks/summaries, attachments, provenance, privacy state | deferred |
| Mechanized Engineering | reference components, overlays, calculations, validated non-effecting plans | deferred |

All named systems use the same plugin identity, permissions, tenancy, provenance,
scheduling, projection, and publication boundaries. Their domain facts do not justify
duplicating the generic expert-system core.

## HITL decisions

| ID | Required decision |
| --- | --- |
| V5-H-PDB-01 | Coordinated core/plugin Flyway lineage versus separately identifiable lineages. **V5: decided in part: developer-authored tables are outside Flyway (V5-PDB-037); published bolt-ons enter the core `ATAPUtilities` lineage (V5-PDB-040). Whether third-party plugins (not via the marketplace) get their own lineage stays open.** |
| V5-H-PDB-02 | In-process, out-of-process, or mixed isolation by plugin risk class. |
| V5-H-PDB-03 | Signing layers, trust roots, publisher enrollment, revocation, and offline trust refresh. |
| V5-H-PDB-04 | Retain, archive, export, or delete policy for each plugin data class after removal. |

See [the plugin expansion diagram](RPRRSBSI-V5-Plugin-DDL-Authoring-And-Marketplace.puml).
