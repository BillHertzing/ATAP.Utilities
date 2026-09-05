# ATAPUtilities.Database release notes

## 0.1.12

Status: source and disposable-database verified; unbuilt, unpublished, and not
applied to any permanent database.

- Retains immutable V00010 through V00120 migration bytes.
- Adds V00130 with an exact code-or-alias resolver and the
  `ATAPContentSummaryRuntimeQuery` least-privilege database role.
- Grants only the three runtime query procedures plus `EXECUTE` and `REFERENCES`
  on their three table types; direct `ATAPUtilities` schema reads remain denied.
- Leaves database-user creation and role membership to environment deployment.

## 0.1.11

Status: source and disposable-database verified; unbuilt, unpublished, and not
applied to any permanent database.

- Retains immutable V00010 through V00110 migration bytes.
- Adds V00120 with catalogued operational identities, a distinct immutable
  prompt RuleVariant, idempotent serializable Repository/root provisioning,
  and canonical Windows-root equivalence.
- Adds controlled ContentSummaryVersion Tag assignment and database-principal
  authorization, plus append-close root correction and retirement procedures.
- Grants an execute-only provisioner role without creating users, logins,
  memberships, or direct table access.
- Excludes live database application, package publication, promotion, and
  service deployment.

## 0.1.7

Status: source and disposable-database verified; unbuilt, unpublished, and not
applied to any permanent database.

- Retains the immutable V00010 through V00070 migration bytes.
- Adds V00080 with typed Rule input/output identities, temporal display and
  default history, owner-bound RuleVariants, controlled Add/Override/Suppress
  occurrences, and ordered BuildSet composition.
- Adds deterministic as-of resolution that validates overlay graphs and returns
  selected, suppressed, and shadowed candidates with occurrence provenance.
- Rejects cross-owner variants, duplicate ordinals, missing override/suppression
  baselines, Add collisions, and in-place semantic definition mutations.
- Excludes live or permanent database application, package publication,
  promotion, installation, and deployment.

## 0.1.6

Status: source and disposable-database verified; unbuilt, unpublished, and not applied
to any permanent database.

- Retains the immutable V00010 through V00060 migration bytes.
- Adds V00070 with the bounded Ace-owned AISupervisor persistence contract:
  append-only exchange, sanitized-prompt, Tag-occurrence, physical-attempt,
  provider-usage, controlled-metric catalog, and metric records.
- Adds procedure-only capture and AceCommander timeline-read roles. The token
  query preserves missing counts as `NULL` and reports completeness explicitly.
- Excludes raw prompts, response/tool bodies, credentials, header values, the
  D2-EXC troubleshooting store, Windows identities, and role memberships.
- Does not authorize package publication, permanent-database application,
  proxy/listener activation, provider traffic, or service grants.

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
