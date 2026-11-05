# RPRRSBSI-V5 Ownership and the Ace Copy

> **New in V5 (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Implements DEC-3 and DEC-9 from [the V5 overview](RPRRSBSI-V5-00-Specification-Overview.md#v5-decisions) and replaces V4-2-CORE-074 and the V4-2 text of C-20. Logical design only. Diagram: [RPRRSBSI-V5-Ownership-And-Ace-Copy.puml](RPRRSBSI-V5-Ownership-And-Ace-Copy.puml).

## 1. Direction

- `ATAPUtilities` is the **open-source foundation**: template tables and template rows that anyone may read through approved read surfaces. No `ATAPUtilities` table carries owner columns (DEC-3, DEC-9).
- `Ace` is a **full copy** of every `ATAPUtilities` table (same name, columns, constraints and behaviour), plus Ace-only tables. Every `Ace` row is owned by one user or one organization (DEC-3).
- Both schemas receive a **common initial load**; afterwards changes start in `Ace` and some are promoted to `ATAPUtilities` (DEC-9) through the marketplace submission process or a reviewed core migration ([V5-15](RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md)).
- This supersedes RRSBS ADR-125 (AceCommander as an external consumer), the V4 Ace/Mobile parity manifest's ATAP-first direction (its structure is reused, see §6), and ContentSummary invariant INV-10 (ATAPUtilities only).

## 2. Amended rules

> **C-20 (amended 2026-11-05).** `ATAPUtilities` holds one authoritative, tenant-free catalog of template Tags; its Tag tables have no owner or tenant column. `Ace` holds a full copy of every Tag table with owner columns; Ace Tags are owned by a user or an organization and are visible according to that ownership. Tag resolution across both uses the D-5 union contract with explicit source authority.

> **V5-CORE-074 (amended 2026-11-05).** `Ace` SHALL contain, for every `ATAPUtilities` table, a table of the same name with the same columns, constraints and behaviour, plus owner columns. `Ace` MAY contain additional tables. Every `Ace` table SHALL carry owner columns. An `ATAPUtilities` table SHALL NOT carry owner columns.

V5-CORE-072 (ATAP never references Ace) and V5-CORE-073 (union reads) are unchanged.

## 3. Owner columns

| Column | Type | Meaning |
| --- | --- | --- |
| `OwnerUserId` | `uniqueidentifier NULL` | Set when one user owns the row. The row is visible only to that user and to ACE administrators. |
| `OwnerOrganizationId` | `uniqueidentifier NULL` | Set when an organization owns the row. Visible to the organization's members according to their roles. |
| `CreatedByUserId` | `uniqueidentifier NOT NULL` | The user who created the row; attribution, independent of ownership. |

- **V5-OWN-001:** `CHECK ((OwnerUserId IS NULL) <> (OwnerOrganizationId IS NULL))`: exactly one owner.
- **V5-OWN-002:** Owner columns reference `ACE.User` and `ACE.Organization`. They are never added to `ATAPUtilities` tables.
- **V5-OWN-003:** A change of owner (for example an estate transfer, [V5-62](RPRRSBSI-V5-62-Organization-Identity-Products-And-Estates.md), or a developer moving a table to their organization) is a temporal `OwnershipState` row, not an update of the owner columns. Recommended physical form: the owner columns hold the *original* owner; a generic `Ace.RowOwnershipState(EntityTypeId, EntityId, OwnerUserId, OwnerOrganizationId, PhiloteValidityPeriodId, ...)` holds changes; the effective owner is resolved as-of. (Alternative for decision: allow owner-column updates guarded by a trigger that writes history.)
- **V5-OWN-004:** Ace-only system tables follow the same rule: an `ACE.User` row is owned by itself (`OwnerUserId = UserId`); organization rows are owned by the organization. The protected credential schema ([V5-65](RPRRSBSI-V5-65-Protected-Authentication.md)) is outside `Ace` and exempt.
- **V5-OWN-005:** Template derivation is recorded, not ownership: an `Ace` row copied from an `ATAPUtilities` template row stores the template's id and revision (the pattern already built in `ACE.OrganizationFactProvenance`: `TemplateId`, `TemplateRevision`, schema/vocabulary versions, content hash).

## 4. Shared identity registry (exception)

- **V5-OWN-010:** `ATAPUtilities.Philote` and `ATAPUtilities.PhiloteValidityPeriod` are shared by both schemas and are not copied. Every `Ace` row's `PhiloteId` is registered there, so GUIDs are globally unique and cross-schema references keep working (SHARED-REGISTRY126, already built for `ACE.User`). This is the recommended reading of "full copy"; it needs the developer's confirmation (HANDOFF-V5).
- **V5-OWN-011:** The temporal mutation procedures (`ReplacePhiloteValidityPeriodSet` and the seven wrappers) remain the only writers of validity periods for both schemas.

## 5. Enforcement

- **V5-OWN-020:** Visibility and write rights are enforced by **SQL Server Row-Level Security**: one security policy per `Ace` table, using one generic inline predicate function over `OwnerUserId`/`OwnerOrganizationId` (or the effective owner, V5-OWN-003) and the caller identity that the host places in `SESSION_CONTEXT` (`UserId`, effective organization memberships, administrator flag).
- **V5-OWN-021:** Writes remain procedure-only for application principals (built pattern, V00060–V00140). Block predicates prevent a procedure from writing a row for a different owner than the session's.
- **V5-OWN-022:** Read surfaces that combine `ATAPUtilities` and `Ace` apply owner filtering **before** aggregation, counting, ranking or traversal (the built ContentSummary rule "authorization before aggregation").
- **V5-OWN-023:** ACE administrators bypass the predicate only through an explicit, audited administrator session flag.

## 6. Generating the Ace copy

- **V5-OWN-030:** Each `Ace` twin (table, constraints, indexes, triggers, writer procedures, RLS policy) SHALL be **generated** from its `ATAPUtilities` definition plus the owner-column pattern, not hand-written. The generator is itself an RRSBS materializer (SQL kind); each generated twin is a `Generated` instantiation of it ([V5-12](RPRRSBSI-V5-12-Instantiation-And-Materialization.md)).
- **V5-OWN-031:** A copy manifest records, per pair: source table and Ace table, owner-column delta, schema hash of each, and generator version. This reuses the structure of the V4 Ace/Mobile parity manifest (`40-Data-Tenancy-And-Synchronization.md`) with the disposition `mirrored-with-owner` for every table, and `ace-only` for Ace-only tables.
- **V5-OWN-032:** A drift check compares every pair's normalized schema (minus owner columns) and fails the release when they differ.

## 7. Built objects affected

| Built object | Required change |
| --- | --- |
| 53 `ATAPUtilities` tables (V00010–V00120) | Generated `Ace` twins, except the shared registry (§4). |
| `Ace.Tag`, `Ace.TagNamespace` (V00060) | Name collision with the copies and a different shape. Rename to `Ace.GatherContentSubmittedTag` / `Ace.GatherContentTagNamespace` (or fold into the copies) by forward migration, updating `CaptureGatherContentSubmission`, `QueryGatherContentV1` and the AISupervisor procedures that write them. |
| `ATAPUtilities.Repository.OrganizationId` (V00100) | Organization ownership moves to the `Ace` copy; the `ATAPUtilities` row becomes a template, or the column is retired by forward migration. |
| `ATAPUtilities.ContentSummaryDatabasePrincipalRepositoryAuthorization` (V00110) | Per-principal authorization becomes an `Ace` concern under RLS. |
| All `Ace` (11) and `ACE` (21) tables | Owner columns and RLS policies (by forward migration with backfill: organization tables owned by their organization, user tables by their user, telemetry by the capturing user). |

## 8. Promotion direction (DEC-9)

A change that starts in `Ace` reaches `ATAPUtilities` only as:

1. a **marketplace bolt-on** ([V5-15](RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md) §4): developer tables become `ATAPUtilities` template tables with selected template rows, and owned `Ace` copies are generated; or
2. a **core change** made by the ATAP maintainers as a reviewed Flyway migration (the existing release process).

In both cases the `ATAPUtilities` change is a new immutable database package promoted through the five tiers, and the `Ace` twin is generated in the same migration.

## 9. Open items

See [HANDOFF-V5.md](HANDOFF-V5.md): confirmation of the shared registry exception; owner-change representation (V5-OWN-003); RLS session-context contract; renaming of `Ace.Tag*`; backfill owners for existing rows.
