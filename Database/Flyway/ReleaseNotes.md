# ATAPUtilities.Database release notes

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
