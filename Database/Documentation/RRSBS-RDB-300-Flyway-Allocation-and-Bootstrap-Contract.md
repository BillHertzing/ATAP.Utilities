# RDB-300 — Flyway Allocation and Bootstrap Contract

Status: Wave 4 design record. This document allocates the new RRSBS database
lineage; it does not create a migration, reset a database, change a package,
publish a package, or authorize a deployment.

## Allocation record

| Allocation | Value | Contract |
| --- | --- | --- |
| Database package ID | `ATAPUtilities.Database` | Existing package identity remains the owner of the new lineage. |
| New package version | `0.0.1` | The first immutable package for the rebaselined RRSBS lineage. It is distinct from the current `0.1.3` legacy-lineage package. |
| New Flyway baseline version | `00010` | RDB-480 is the sole integrator that may create `V00010__Create_RRSBS_Baseline.sql`. No preceding or parallel RRSBS baseline migration is permitted. |
| New history table | `rrsbs_flyway_schema_history` | The new Flyway configuration must explicitly name this table; it is not the legacy default `flyway_schema_history`. |
| Legacy source maximum | `00.02.000140` | The highest active source migration at allocation time. The legacy chain and its history are preserved as evidence, never extended by RRSBS V2 work. |
| Legacy package version | `0.1.3` | The latest known package at allocation time; it cannot be relabeled or overwritten as `0.0.1`. |

The leading zeroes in `00010` are allocation syntax, not an instruction to
reuse the legacy `00.01.000010` migration. The new baseline receives new bytes
only after RDB-400 through RDB-480 complete their SQL and integration gates.

## Lineage and mixing rule

One installable package declares exactly one lineage:

| Lineage | History table | Allowed migration family | Package family |
| --- | --- | --- | --- |
| Legacy | `flyway_schema_history` | Existing `V00.*` migrations through `V00.02.000140` | Existing `0.1.x` artifacts |
| RRSBS V2 | `rrsbs_flyway_schema_history` | `V00010__Create_RRSBS_Baseline.sql` and later RRSBS V2 migrations | `0.0.x` artifacts beginning with `0.0.1` |

The package manifest and build gate must reject a package that contains inputs
from both rows. Bootstrap must also fail closed if an intended RRSBS V2 target
already contains the legacy history table or if an intended legacy target
contains the RRSBS V2 history table. A later RDB-570 rehearsal proves these
negative cases; this record does not claim that implementation exists.

## Bootstrap boundary

The operator bootstrap is an exact-target, reviewed operation external to the
immutable Flyway migration. It owns:

- required backup and restore plan;
- client disconnect and drop/create decision;
- database ownership, collation, compatibility level, and recovery model;
- credential provisioning and secret resolution by `SecretName` only; and
- creation/initialization of `rrsbs_flyway_schema_history` through the approved
  Flyway invocation.

The immutable baseline owns only schema/data objects that are part of the
approved RRSBS V2 package. It must not drop or create the database, alter
server-level settings, create logins, resolve credentials, create backups, or
initialize a history table by ad hoc SQL.

## Tier contract

| Authorized tier | RDB-300 outcome | Execution condition |
| --- | --- | --- |
| `DevWhertzing` | Allocated for the new lineage. | Per-target RDB-850 approval and later rehearsal evidence. |
| `ExpWhertzing` | Allocated for the new lineage. | Per-target RDB-850 approval and later rehearsal evidence. |
| `Integration` | Allocated for the new lineage. | Per-target RDB-850 approval, backup, and rehearsal evidence. |
| `QA` | Allocated for the new lineage. | Per-target RDB-850 approval, backup, and rehearsal evidence. |
| `Production` | Allocated for the new lineage; existing state is observed-stale evidence only. | Per-target RDB-850 approval, retained backup, restore plan, and rehearsal evidence. |

Allocation is not reset authorization. No target name, connection string,
credential, backup location, or destructive command is recorded here.

## Scope and `USE` disposition

`RESET-01` and `RESET-SCOPE-01` select a fresh database with the new immutable
lineage. Tags and Gmail are within the ATAP.Utilities reset scope; RDB-310 owns
their exact object disposition. Other deferred scopes remain untouched unless a
later approved RDB-310 disposition explicitly changes that boundary.

The new baseline must remove `USE [ATAPUtilities]`. The operator selects the
approved target database through the connection/runner contract, and baseline
SQL must use schema-qualified object names. This prevents a package from
silently changing database context after the exact target has been chosen.

## Acceptance and deferred owners

- RDB-310 resolves each non-RRSBS object and deferred-scope preservation path.
- RDB-320 freezes object, constraint, index, and identity registries.
- RDB-400 through RDB-460 author disjoint SQL fragments.
- RDB-480 integrates the sole `V00010` baseline and parser/double-run proof.
- RDB-550 through RDB-575 implement package, manifest, and mixing gates.
- RDB-810, RDB-815, and RDB-850 through RDB-870 rehearse and authorize any
  reset or deployment.

Close variants that must remain rejected are: a `0.0.1` package that contains a
`V00.*` migration, a `0.1.x` package that contains `V00010`, a target with both
history tables, and a baseline that changes context with `USE [ATAPUtilities]`.
