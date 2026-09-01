# ATAPUtilities.Database release notes
## 0.1.5

Status: source and disposable-database verified; unbuilt, unpublished, and not
applied to any permanent database.

- Retains the immutable V00010, V00030, V00040, and V00050 migration bytes.
- Adds V00060 with the bounded `Ace` gather-content submission contract:
  four append-only tables, one ordered Tag table type, exact-once capture and
  direct-current-Tag query procedures, and procedure-only database roles.
- Keeps `ATAPUtilities.Tag*` read-only and excludes Prompt, proxy/metering,
  Windows users, and role memberships.
- Fresh and V00050-upgrade disposable-database tests passed under Task 15.185.b.
- Does not authorize package publication, permanent-database application,
  service grants, or promotion beyond source verification.
## 0.1.4

Status: released through BuildMaster to Experimental only at
`utat022\EXPWHERTZING\ATAPUtilities`; Development and higher remain unpromoted.

- Retains the immutable V00010 core schema and V00030 historical
  AceOutpostContentSummaryPrototype migration.
- Adds V00040 to enforce the same-identity validity-period key required by the
  tag-root relationships.
- Adds V00050 to create the read-only `ATAPUtilities.Tag*` root and its governed
  authorization, lifecycle, relationship, and as-of-resolution contracts.
- Freezes the exact four-migration and eleven-seed-file source boundary in the
  tracked package content allowlist.
- Does not authorize promotion or deployment to Development, Integration, QA,
  or Production.

## 0.1.0

Status: source accepted at PTV-G4; unpublished and uninstalled.

- Establishes one consolidated initial migration:
  `V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql`.
- Creates the exact RPRRSBSI V3 11-table graph with 45 columns and 72 named
  constraints.
- Replaces the superseded temporal table with the five-column
  `PhiloteValidityPeriod` predecessor-chain contract.
- Loads eleven approved CSV inputs, including 22 deterministic initial validity
  periods for the 22 Philotes.
- Creates the validity-period table type and eight atomic mutation procedures.
- Excludes every archived pre-adoption migration and archived temporal CSV.

The PTV-460 candidate and PTV-450 disposable rehearsal prove the local source and
runtime contract. Publication, promotion, installation, permanent-database work,
and deployment require later explicit authorization.
