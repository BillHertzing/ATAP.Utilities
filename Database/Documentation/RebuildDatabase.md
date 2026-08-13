# Rebuild the ATAPUtilities database

## Authority boundary

The active package source is `Database/Flyway` and the package identity is
`ATAPUtilities.Database` `0.1.0`. Its active lineage contains one migration:
`SQL/V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql` plus the eleven
approved CSV inputs in `Data/`.

A rebuild is destructive. Do not run it from this document alone. The operator
must have separate human approval for the exact SQL Server instance, database
name, backup or backup-waiver decision, and unchanged package hash. There is no
SQL Server instance named `Experimental`. The developer-scoped instance used by
the guarded rehearsal is `utat022\expWhertzing`; logical package tiers do not
rename SQL Server instances.

## Required preflight

1. Resolve the approved connection secret by its configured SecretName through
   `Get-SecretATAP`; never paste a connection string into a command or file.
2. Prove the connected server identity and exact target database name.
3. Inventory the target and protected databases before any mutation.
4. Verify the local package ID, version, manifest, and SHA-256 against the
   approved release evidence.
5. Run Flyway `info` and `validate`. A pre-migration validation failure is
   expected only for a newly created empty target with migration `00010` pending.
6. Stop on any target, history, package, or hash mismatch.

## Approved apply sequence

After the exact-target and destructive-action gates are recorded:

1. Back up the existing target, or record the approved backup waiver when the
   target is proven absent.
2. Create or replace only the exact approved database.
3. Apply the unchanged `ATAPUtilities.Database` `0.1.0` package through the
   approved Flyway runner.
4. Run Flyway `validate`.
5. Run `Database/Powershell/tests/PhiloteTemporalValidity-Source.Tests.ps1` and
   the authorized database suite.
6. Verify the exact 11-table, 45-column, 72-constraint, eight-procedure,
   one-table-type, 22-Philote, and 22-validity-period contract.
7. Independently compare the protected-database inventory to the preflight.
8. Record rollback readiness and the final deployed package identity.

## Disposable rehearsal precedent

PTV-450 applied the exact unpublished package twice from empty to
`ATAPUtilities_PTV450_Rehearsal_20260809` on
`utat022\expWhertzing`. Both runs passed 21/21 runtime tests and produced
identical schema, seed, and Flyway-history hashes. Each disposable database was
dropped, and an independent master-catalog query proved final absence. That
evidence validates the runbook mechanics; it does not authorize a permanent
target or a future package/feed/deployment action.

## Prohibited shortcuts

- Do not run Flyway `clean`, edit Flyway history, or execute archived migrations.
- Do not apply the archived 13-migration pre-adoption V3 sequence.
- Do not seed the archived temporal CSV.
- Do not infer a database target from a logical tier name.
- Do not reuse a prior approval for another instance, database, package hash, or
  point in time.
