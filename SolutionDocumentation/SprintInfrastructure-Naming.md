# Sprint Infrastructure Naming — Authoritative Reference

**Scope:** All sprint infrastructure components: SQL Server instances,
ProGet feeds, Bitwarden secrets, workTrees, branches, and BuildMaster variables.

**Audience:** Developers starting or ending sprints; SprintStartAgent /
SprintEndAgent; anyone configuring ecosystem tooling.

**Status:** Authoritative. Supersedes all sprint-0005 and earlier naming
conventions. Reverted from per-sprint feed and per-sprint SQL instance
naming adopted during sprint-0006 planning.

**Related Documents:**

- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — index doc
- [CSharp-Packages-Pack-and-Push.md](CSharp-Packages-Pack-and-Push.md) — feed-topology details
- [PowerShell-Modules-Pack-and-Publish.md](PowerShell-Modules-Pack-and-Publish.md) — PowerShell feed usage
- [ProGet-Install-Runbook.md](ProGet-Install-Runbook.md) — permanent ProGet feed topology and connector setup
- [SecretsPluginArchitecture.md](SecretsPluginArchitecture.md) — Bitwarden secret retrieval architecture

---

## 1. Core Principle

All infrastructure is **permanent or long-lived**. Sprint start and end
provision and tear down only the two SQL instances and the Bitwarden
connection-string secrets. Everything else (ProGet feeds, BuildMaster
variables) is created once per workstation or ecosystem host and reused
across sprints.

| Component                                         | Per-sprint?                               | Scope                   |
| ------------------------------------------------- | ----------------------------------------- | ----------------------- |
| SQL instances `Dev<username>` / `Exp<username>`   | ✅ Yes — recreated each sprint            | Developer workstation   |
| Bitwarden secrets (Development / Experimental)    | ✅ Yes — created at start, deleted at end | Developer workstation   |
| ProGet feeds                                      | ❌ No — permanent                         | Ecosystem ProGet host   |
| Bitwarden secrets (Integration / QA / Production) | ❌ No — permanent, one-time onboarding    | Ecosystem               |
| BuildMaster sprint variables                      | ✅ Yes — set at start, cleared at end     | BuildMaster application |
| BuildMaster stable variables                      | ❌ No — permanent                         | BuildMaster application |
| Worktrees / branches                              | ✅ Yes — created per sprint per repo      | Developer workstation   |

---

## 2. SQL Server Instance Naming

### 2.1 Per-sprint instances (developer workstation)

Two instances are created at sprint start and removed at sprint end:

| Instance name   | Tier         | Host                              |
| --------------- | ------------ | --------------------------------- |
| `Dev<username>` | Development  | `localhost` / `$env:COMPUTERNAME` |
| `Exp<username>` | Experimental | `localhost` / `$env:COMPUTERNAME` |

**Rules:**

- Instance names use a 3-character tier prefix (`Dev` / `Exp`) concatenated with `$env:USERNAME`.
- SQL Server named-instance names have a **maximum of 16 characters**; `Development` or `Experimental` concatenated with a username exceeds this limit.
- Both instances exist on the developer workstation; they are not shared.
- Full SQL instance address: `<hostname>\Dev$env:USERNAME` or `<hostname>\Exp$env:USERNAME`.

**Provisioning cmdlet:** [`New-SprintSqlServerInstances`](../src/ATAP.Utilities.BuildTooling.PowerShell/public/New-SprintSqlServerInstances.ps1) (BuildTooling.PowerShell)

**Tear-down cmdlet:** [`Remove-SprintSqlServerInstances`](../src/ATAP.Utilities.BuildTooling.PowerShell/public/Remove-SprintSqlServerInstances.ps1) (BuildTooling.PowerShell)

### 2.2 Permanent ecosystem instances

| Instance name | Tier        | Host      |
| ------------- | ----------- | --------- |
| `Integration` | Integration | `utat022` |
| `QA`          | QA          | `utat022` |
| `Production`  | Production  | `utat022` |

These are provisioned once during ecosystem onboarding. Sprint start/end
never touches them.

### 2.3 Sprint infrastructure health check

`Test-SprintInfrastructureHealth` (BuildTooling.PowerShell) verifies that all
per-sprint infrastructure components are in the expected state. It confirms:

- Both SQL Server named instances are running and accepting connections.
- Both databases (`ATAPUtilities`, `AceCommander`) exist and have the current
  schema version applied.
- All per-sprint Bitwarden secrets are present and non-empty.
- ProGet feeds are reachable from the current host.

**Called by:** `SprintEndAgent` (Step 5.1) before tear-down begins. May also be
run at any point during a sprint to validate workstation readiness.

> **Note:** `Test-SprintInfrastructureHealth.ps1` is a planned cmdlet (TASKS B-T6).
> This section is a forward reference; update to a hyperlink once the script lands.

---

## 3. ProGet Feed Naming

Ten permanent feeds — five NuGet and five PowerShellGet — one per tier per
family. **No per-sprint feeds.**

### 3.1 NuGet feeds (C# packages)

| Feed name            | Tier         | Hermetic                                       |
| -------------------- | ------------ | ---------------------------------------------- |
| `nuget-experimental` | Experimental | No (has `nuget.org` connector)                 |
| `nuget-development`  | Development  | No (has `nuget.org` + experimental connectors) |
| `nuget-integration`  | Integration  | ✅ Yes (no public connector)                   |
| `nuget-qa`           | QA           | ✅ Yes                                         |
| `nuget-stable`       | Production   | No (has `nuget.org` connector)                 |

### 3.2 PowerShellGet feeds (PowerShell modules)

| Feed name                    | Tier         |
| ---------------------------- | ------------ |
| `powershellget-experimental` | Experimental |
| `powershellget-development`  | Development  |
| `powershellget-integration`  | Integration  |
| `powershellget-qa`           | QA           |
| `powershellget-stable`       | Production   |

### 3.3 Connector chain

```text
experimental ← nuget.org (upstream fetch)
development  ← experimental ← nuget.org
integration  ← development  (NO public connector — hermetic)
qa           ← integration  (NO public connector — hermetic)
stable       ← nuget.org
```

Same chain for both feed families.

### 3.4 Tier-name / feed-name mapping

The tier name embedded in the version string (`version.json` `Prerelease`)
maps to feed names via `Get-ATAPIACConstant` constants:

| NBGV Prerelease label     | `NuGetFeedName_*` constant   | `PowerShellGetFeedName_*` constant   |
| ------------------------- | ---------------------------- | ------------------------------------ |
| `Experimental` / `Sprint` | `NuGetFeedName_Experimental` | `PowerShellGetFeedName_Experimental` |
| `Development` / `Alpha`   | `NuGetFeedName_Development`  | `PowerShellGetFeedName_Development`  |
| `Integration` / `Beta`    | `NuGetFeedName_Integration`  | `PowerShellGetFeedName_Integration`  |
| `QA`                      | `NuGetFeedName_QA`           | `PowerShellGetFeedName_QA`           |
| `Production` / `Stable`   | `NuGetFeedName_Stable`       | `PowerShellGetFeedName_Stable`       |

---

## 4. Bitwarden Connection-String Secret Naming

Each Bitwarden item is a **Secure Note** whose hidden field `connString`
holds the full ADO.NET connection string.

### 4.1 Per-sprint secrets (Development and Experimental tiers)

```text
dbConnectionString-<Database>-<Host>-<Tier>-<DeveloperUSERNAME>
```

| Segment               | Values                                       |
| --------------------- | -------------------------------------------- |
| `<Database>`          | `ATAPUtilities` \| `AceCommander`            |
| `<Host>`              | `$env:COMPUTERNAME` or `localhost`           |
| `<Tier>`              | `Development` \| `Experimental`              |
| `<DeveloperUSERNAME>` | `$env:USERNAME` on the developer workstation |

**Example:** `dbConnectionString-ATAPUtilities-DEVBOX01-Development-jsmith`

A sprint start creates 8 secrets per developer:
2 databases × 2 hosts (`$env:COMPUTERNAME` + `localhost`) × 2 tiers = 8

**Provisioning cmdlet:** [`New-SprintBitwardenSecrets`](../src/ATAP.Utilities.BuildTooling.PowerShell/public/New-SprintBitwardenSecrets.ps1)

**Tear-down cmdlet:** [`Remove-SprintBitwardenSecrets`](../src/ATAP.Utilities.BuildTooling.PowerShell/public/Remove-SprintBitwardenSecrets.ps1)

### 4.2 Permanent secrets (Integration, QA, Production tiers)

```text
dbConnectionString-<Database>-<Host>-<Tier>
```

No username suffix — these secrets are shared across all developers on the
ecosystem and belong to the dedicated server accounts.

| Segment      | Values                                    |
| ------------ | ----------------------------------------- |
| `<Database>` | `ATAPUtilities` \| `AceCommander`         |
| `<Host>`     | `utat022` (default; overridable per tier) |
| `<Tier>`     | `Integration` \| `QA` \| `Production`     |

**Example:** `dbConnectionString-ATAPUtilities-utat022-Integration`

6 permanent secrets total: 2 databases × 3 tiers.

**Onboarding cmdlet:** `New-PermanentBitwardenSecrets` — run **once** per
ecosystem during initial setup. NOT called by SprintStartAgent.

### 4.3 Retrieval

All secrets are retrieved via `Get-SecretATAP -SecretName <name>` from
`ATAP.Utilities.BuildTooling.PowerShell`. The cmdlet passes the name unchanged
to `Get-Secret` (SecretManagement) — no character filtering occurs, so names
containing hyphens, machine names, and usernames are handled correctly.

---

## 5. Worktree and Branch Naming

### 5.1 Pattern (from sprint-0007 onward)

```text
<repo-short>-wt-<N>-Sprint-<NNNN>-work-items
```

| Segment        | Description                                                         |
| -------------- | ------------------------------------------------------------------- |
| `<repo-short>` | Short repository identifier (e.g. `ATAP.Utilities`, `SharedVSCode`) |
| `<N>`          | Monotonic issue / worktree number                                   |
| `Sprint`       | Capital S — required                                                |
| `<NNNN>`       | Zero-padded sprint number (e.g. `0007`)                             |

**Example:** `ATAP.Utilities-wt-105-Sprint-0007-work-items`

> **Note:** Sprint-0006 workTrees use lowercase `sprint` for historical
> reasons. The capital-S form applies from sprint-0007 onward.

### 5.2 Glob / regex patterns

BuildMaster Repository Monitor `BranchFilter`:

```text
*-Sprint-*-work-items
```

SprintStartAgent / SprintEndAgent PowerShell glob:

```powershell
"*-wt-*-Sprint-$sprintNumber-work-items"
```

---

## 6. BuildMaster Variable Naming

### 6.1 Sprint-scoped variables (set at sprint start, cleared at sprint end)

| Variable           | Value example                                  |
| ------------------ | ---------------------------------------------- |
| `SprintNumber`     | `0007`                                         |
| `UserName`         | `jsmith`                                       |
| `SprintBranchName` | `ATAP.Utilities-wt-105-Sprint-0007-work-items` |

**Set cmdlet:** `Set-BuildMasterSprintVariables`

**Clear cmdlet:** `Clear-BuildMasterSprintVariables`

### 6.2 Stable variables (set once during ecosystem onboarding)

| Variable                                           | Value example                                                   |
| -------------------------------------------------- | --------------------------------------------------------------- |
| `IntegrationSqlInstance`                           | `utat022\Integration`                                           |
| `QASqlInstance`                                    | `utat022\QA`                                                    |
| `ProductionSqlInstance`                            | `utat022\Production`                                            |
| `IntegrationDatabaseDBConnectionStringSecretName`           | `dbConnectionString-AceCommander-utat022-Integration`           |
| `NuGetFeedName_Experimental`                       | `nuget-experimental`                                            |
| `NuGetFeedUrl_Experimental`                        | `http://localhost:50000/nuget/nuget-experimental/v3/index.json` |
| `PowerShellGetFeedName_Experimental`               | `powershellget-experimental`                                    |
| _(and one URL + one name pair per remaining tier)_ |                                                                 |

The `IntegrationDatabaseDBConnectionStringSecretName` value follows §4.2 and is the
ReleaseBundle Integration-stage Flyway rehearsal connection contract. BuildMaster
passes this name to `Invoke-FlywayRehearsal -DBConnectionStringSecretName`; it does not
pass `DatabaseHost` / `SqlInstance` for that rehearsal.

20 feed name/URL variables + 3 SQL instance variables + 1 ReleaseBundle
Integration DB secret-name variable = 24 stable variables per BuildMaster
application that runs the ReleaseBundle plan (`AceCommander-ReleaseBundle`,
`ATAP.Utilities-ReleaseBundle`). Non-ReleaseBundle applications may omit the DB
secret-name variable.

**Set cmdlet:** `Set-BuildMasterStableVariables` for feed and SQL-instance
variables; set `IntegrationDatabaseDBConnectionStringSecretName` during ReleaseBundle
application onboarding until that onboarding automation owns the secret-name
variable too.

---

## 7. Summary Table

| Component               | Naming pattern                                                          | Per-sprint? | Cmdlet                                                           |
| ----------------------- | ----------------------------------------------------------------------- | ----------- | ---------------------------------------------------------------- |
| SQL — sprint            | `Dev<username>` / `Exp<username>`                                       | ✅          | `New-SprintSqlServerInstances` (see §2.1)                        |
| SQL — permanent         | `Integration` / `QA` / `Production` on `utat022`                       | ❌          | manual / IAC                                                     |
| SQL — health check      | n/a                                                                     | n/a         | `Test-SprintInfrastructureHealth` _(planned — see §2.3)_         |
| ProGet NuGet feed       | `nuget-<tier>`                                                          | ❌          | `New-ProGetFeedSet`                                              |
| ProGet PS feed          | `powershellget-<tier>`                                                  | ❌          | `New-ProGetFeedSet`                                              |
| Bitwarden — sprint      | `dbConnectionString-<DB>-<Host>-<Tier>-<User>`                          | ✅          | `New-SprintBitwardenSecrets` (see §4.1)                          |
| Bitwarden — permanent   | `dbConnectionString-<DB>-<Host>-<Tier>`                                 | ❌          | `New-PermanentBitwardenSecrets`                                  |
| Worktree / branch       | `<repo>-wt-<N>-Sprint-<NNNN>-work-items`                               | ✅          | `New-SprintStage1` / `New-SprintStage2` (function definition files; callers must `Import-Module ATAP.Utilities.BuildTooling.PowerShell -Force` or dot-source before invoking) |
| BuildMaster sprint vars | `SprintNumber`, `UserName`, `SprintBranchName`                          | ✅          | `Set-BuildMasterSprintVariables`                                 |
| BuildMaster stable vars | feed names/URLs, SQL instances, ReleaseBundle Integration DB secret name | ❌          | `Set-BuildMasterStableVariables` + ReleaseBundle app onboarding  |
