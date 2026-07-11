# Developer SQL Server Instances — Onboarding / Offboarding Runbook

> **Why:** Starting Sprint 0008, the per-developer SQL Server instances
> (`Dev<username>`, `Exp<username>`) are **permanent developer-onboarding
> infrastructure**. They are created once per developer per workstation and are
> *not* created or destroyed at sprint boundaries. Sprint start/end now only drop
> and recreate the **databases inside** those instances. This runbook documents
> the ownership boundary and the procedures for the onboarding/offboarding
> cmdlets that replaced the sprint-scoped instance cmdlets.

Created: 2026-06-11 (Sprint 0008, Task 8.4; migrated from
`_Planning/Explainers/0028-developer-onboarding-sql-instances.md`)
Status: Active
Module of record: `src/ATAP.Utilities.BuildTooling.PowerShell`

**Related documents:**

- [SprintInfrastructure-Naming.md](SprintInfrastructure-Naming.md) — authoritative naming conventions (§2)
- [Database-Change-Unit-and-Flyway-Promotion.md](Database-Change-Unit-and-Flyway-Promotion.md) — database change-unit lifecycle and Flyway promotion
- [`BuildTooling.PowerShell` module INDEX](../src/ATAP.Utilities.BuildTooling.PowerShell/INDEX.md) — sprint start/end execution-order sequences

---

## Parity journal requirement

Before a step in this runbook creates, removes, upgrades, or configures SQL
Server state on `utat022` or `utat01`, append a secret-safe declaration with
`Add-ParityChangeEntry` on the host being changed. Include the category, item,
old/new state, peer host, and a peer action; do not include any secret value.
After the peer applies its corresponding action, acknowledge it from that peer
with `Confirm-ParityChangeApplied`.

---

## 1. The requirement change

Through Sprint 0007, SprintStart created the two named SQL Server instances and
SprintEnd uninstalled them. This was wrong on two counts:

1. **Cost / fragility.** Installing and uninstalling a SQL Server named instance
   on every sprint boundary is slow, error-prone (setup.exe `/ACTION=Uninstall`
   leaves residue), and gains nothing — the instance is identical sprint to
   sprint.
2. **Wrong lifecycle unit.** What actually needs to be reset each sprint is the
   *database schema* (drop, recreate, re-run Flyway), not the *server instance*.

Sprint 0008 inverts the ownership:

| Object                                      | Owner / lifecycle                               | Cmdlet                               |
| ------------------------------------------- | ----------------------------------------------- | ------------------------------------ |
| `Dev<username>` / `Exp<username>` instance  | **Developer onboarding** — once per workstation | `New-DeveloperSqlServerInstances`    |
| (teardown of the instance)                  | **Developer offboarding** — once, deliberate    | `Remove-DeveloperSqlServerInstances` |
| `ATAPUtilities` / `AceCommander` DBs        | **Sprint start** — drop/recreate + Flyway       | `Reset-SprintDatabases`              |
| (drop of those DBs)                         | **Sprint end** — drop, instances remain         | `Remove-SprintDatabases`             |

The instances `Devwhertzing` and `Expwhertzing` remain present throughout all
sprints.

---

## 2. Instance naming convention

Authoritative naming (see
[SprintInfrastructure-Naming.md](SprintInfrastructure-Naming.md) §2): a
3-character tier prefix concatenated with `$env:USERNAME`, **no separator**,
respecting the 16-character SQL Server instance-name limit.

| Tier                       | Prefix | Example (`whertzing`) | Environment label |
| -------------------------- | ------ | --------------------- | ----------------- |
| T2 — Development / Alpha   | `Dev`  | `Devwhertzing`        | `Development`     |
| T1 — Experimental / Sprint | `Exp`  | `Expwhertzing`        | `Experimental`    |

The instance prefix is what `Reset-SprintDatabases` / `New-DeveloperSqlServerInstances`
use to derive the Flyway `Environment` value (`Dev*` → `Development`,
`Exp*` → `Experimental`).

---

## 3. Onboarding runbook (run once per developer per workstation)

Prerequisites:

- SQL Server Express setup media extracted (default lookup:
  `D:\Temp\SQLExpr\extracted\setup.exe`, with a SQL Server Bootstrap fallback).
- `dbatools` PowerShell module available **and intact** (≥2.8.1). If
  `Import-Module dbatools` errors with *"Unable to find type [DbaInstanceParameter]"*,
  the highest installed copy has a missing/partial `bin/` folder — remove the
  corrupt version folder under `C:\Program Files\PowerShell\Modules\dbatools\`
  (elevated shell) and reinstall with
  `Install-Module dbatools -Scope AllUsers -Force -AllowClobber`
  (root-caused in Sprint 0008, Task 8.6 / SC-0174).
- The ATAP PowerShell profile loaded (so `$global:settings` and `Get-PVal` are
  present) — do **not** pass `-NoProfile`.

Steps:

```powershell
# 1. Preview (no changes are made under -WhatIf)
New-DeveloperSqlServerInstances -WhatIf

# 2. Provision both instances and build ATAPUtilities + AceCommander from Flyway
New-DeveloperSqlServerInstances -Verbose
```

Behaviour:

- Idempotent. If `MSSQL$<Instance>` already exists, instance creation is skipped.
  If a database already exists on the instance, the Flyway rebuild is skipped.
- Returns one `[PSCustomObject]` per (instance × database) with
  `instanceReady` / `built` / `error`.
- Never touches sprint state; safe to re-run.

---

## 4. Offboarding runbook (developer offboarding / workstation teardown only)

```powershell
# Preview
Remove-DeveloperSqlServerInstances -WhatIf

# Remove the per-developer instances (drops their databases first, then
# uninstalls via setup.exe /ACTION=Uninstall)
Remove-DeveloperSqlServerInstances -Confirm:$false
```

`-WhatIf` / `$WhatIfPreference` propagate to every destructive step (database
drop and instance uninstall). Unreachable instances are reported as `Skipped`,
not errors. **Do not call this cmdlet from any sprint-lifecycle agent or
script** — it is offboarding only.

---

## 5. What changed in code (Sprint 0008)

- `New-SprintSqlServerInstances.ps1` → **renamed** to
  `New-DeveloperSqlServerInstances.ps1`.
- `Remove-SprintSqlServerInstances.ps1` → **renamed** to
  `Remove-DeveloperSqlServerInstances.ps1`.
- The old names survive only as deprecated **aliases**
  (`[Alias('New-SprintSqlServerInstances')]`,
  `[Alias('Remove-SprintSqlServerInstances', 'Remove-DeveloperDatabaseInstances')]`)
  and are listed in the module manifest `AliasesToExport`, so existing call
  sites keep working until they migrate.
- The sprint path no longer references instance installation:
  `New-SprintStage2` calls `Reset-SprintDatabases` (Task 8.2); SprintEnd calls
  `Remove-SprintDatabases` (Task 8.3).

---

## 6. Cross-references

- Sprint 0008 Task 8.1 — `Reset-SprintDatabases` (sprint-start database reset).
- Sprint 0008 Task 8.2 — `New-SprintStage2` rewired to database reset.
- Sprint 0008 Task 8.3 — `Remove-SprintDatabases` (sprint-end database drop).
- Sprint 0008 Task 8.5 — SprintStartAgent / SprintEndAgent doc updates for the
  new lifecycle (SharedVSCode), including
  `SharedVSCode/SolutionDocumentation/Sprint-Lifecycle-Agent-Workflow.md`.
- [`BuildTooling.PowerShell` module INDEX](../src/ATAP.Utilities.BuildTooling.PowerShell/INDEX.md)
  — sprint start/end execution-order sequences.
