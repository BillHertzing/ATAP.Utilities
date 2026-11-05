# RPRRSBSI-V5 Plugin Database Expansion

> **V5 revision (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Successor of `Database/Documentation/RPRRSBSI-V4-2-15-Plugin-Database-Expansion.md`. Requirement and decision IDs keep their V4-2 numbers with the prefix `V5-` (for example `V4-2-CORE-034` is now `V5-CORE-034`); a V4-2 ID that is not repeated here is withdrawn only where the "V5 changes" section says so. The V5 decisions DEC-1 to DEC-6 and the 2026-11-05 training and gamification requirements are summarised in [the V5 overview](RPRRSBSI-V5-00-Specification-Overview.md#v5-decisions); open items are in [HANDOFF-V5.md](HANDOFF-V5.md). **Terminology (DEC-6):** an *Instantiation* is a produced file or row; the run of an executor that produces instantiations is a *Materialization*; the reusable configuration it runs is a *materialization specification*. Where carried-forward V4-2 text uses "Instantiation" for the configured act, read "materialization specification".


Status: design contract; no DDL, migration, plugin activation, or production publication is authorized.

## Purpose

This specification defines how plugins may extend the database without becoming database owners. It preserves the `ATAPUtilities` published-reference plane, the `Ace` mutable working plane, and provider-neutral Outpost persistence.

## Ownership model

- **V5-PDB-001:** A plugin SHALL declare every durable object, data class, permission, dependency, background trigger, and synchronization contract in a signed manifest.
- **V5-PDB-002:** Plugins SHALL write through host-owned repositories and SHALL NOT receive arbitrary SQL, DDL, schema-owner, or central-database credentials.
- **V5-PDB-003:** Shared expert-system concepts SHALL use core-owned tables. A plugin-specific table is permitted only when the fact is irreducibly domain-specific and its lifecycle cannot be represented by the shared model.
- **V5-PDB-004:** Central plugin-specific tables SHALL remain in the `Ace` schema unless a separately approved publication creates an authoritative `ATAPUtilities` object.
- **V5-PDB-005:** Plugin object names SHALL be manifest-declared, collision checked, and attributable to immutable plugin identity and software version.
- **V5-PDB-006:** Runtime installation SHALL NOT execute DDL. A migration service applies an immutable, reviewed, forward-only database package.

## Migration and compatibility

- **V5-PDB-010:** The selected migration topology SHALL provide one unambiguous order across core and plugin changes, immutable checksums, predecessor requirements, and independent verification of each schema effect.
- **V5-PDB-011:** A plugin manifest SHALL declare minimum and maximum compatible core schema contracts and dependencies on other plugin contracts.
- **V5-PDB-012:** Upgrade failure SHALL leave the prior activated plugin and durable data usable or explicitly quarantined; silent partial activation is prohibited.
- **V5-PDB-013:** Rollback means deactivation plus a separately reviewed forward correction. Applied migrations are never edited or removed from history.
- **V5-PDB-014:** Plugin removal SHALL default to retaining durable data in a disabled, exportable state until a retention disposition is approved.

## Tenancy and security

- **V5-PDB-020:** Every mutable Ace aggregate SHALL have an enforceable ownership path to `UserId` and `OrganizationId`; a client-supplied identifier is not authorization evidence.
- **V5-PDB-021:** Plugin permissions SHALL be default-deny and separately enumerate local non-sensitive store, local sensitive store, Ace repository, network destination, filesystem boundary, scheduling, synchronization, secrets-derived operations, and manifestation output.
- **V5-PDB-022:** Tags classify data and SHALL NOT grant any permission.
- **V5-PDB-023:** Header, prompt, source-code, location, EXIF, activity, and LLM payload fields SHALL carry a data classification before storage or synchronization.

## Publication boundary

`productionPublishNewOrModifiedPlugin` is the only route from mutable Ace work into authoritative ATAPUtilities definitions. It requires immutable candidate bytes, manifests and hashes, independent validation, malware and dependency checks, provenance, explicit approval, and a new forward-only ATAPUtilities release. Ordinary synchronization never implies publication authority.

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
| V5-H-PDB-01 | Coordinated core/plugin Flyway lineage versus separately identifiable lineages. |
| V5-H-PDB-02 | In-process, out-of-process, or mixed isolation by plugin risk class. |
| V5-H-PDB-03 | Signing layers, trust roots, publisher enrollment, revocation, and offline trust refresh. |
| V5-H-PDB-04 | Retain, archive, export, or delete policy for each plugin data class after removal. |

See [the plugin expansion diagram](RPRRSBSI-V5-Plugin-DDL-Authoring-And-Marketplace.puml).
