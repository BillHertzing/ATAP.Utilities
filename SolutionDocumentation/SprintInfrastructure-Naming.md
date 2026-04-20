# Sprint Infrastructure Naming — Authoritative Reference

**Scope:** All sprint infrastructure components: SQL Server instances,
ProGet feeds, Bitwarden secrets, worktrees, branches, and BuildMaster variables.

**Audience:** Developers starting or ending sprints; SprintStartAgent /
SprintEndAgent; anyone configuring ecosystem tooling.

**Status:** Authoritative. Supersedes all sprint-0005 and earlier naming
conventions. Reverted from per-sprint feed and per-sprint SQL instance
naming adopted during sprint-0006 planning.

**Related Documents:**

- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — index doc
- [CSharp-Packages-Pack-and-Push.md](CSharp-Packages-Pack-and-Push.md) — feed-topology details
- [PowerShell-Modules-Pack-and-Publish.md](PowerShell-Modules-Pack-and-Publish.md) — PowerShell feed usage

---

## 1. Core Principle

All infrastructure is **permanent or long-lived**. Sprint start and end
provision and tear down only the two SQL instances and the Bitwarden
connection-string secrets. Everything else (ProGet feeds, BuildMaster
variables) is created once per workstation or ecosystem host and reused
across sprints.

| Component                                         | Per-sprint?                               | Scope                   |
| ------------------------------------------------- | ----------------------------------------- | ----------------------- |
| SQL instances `Development` / `Experimental`      | ✅ Yes — recreated each sprint            | Developer workstation   |
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

| Instance name  | Tier | Host                              |
| -------------- | ---- | --------------------------------- |
| `Development`  | T2   | `localhost` / `$env:COMPUTERNAME` |
| `Experimental` | T1   | `localhost` / `$env:COMPUTERNAME` |

**Rules:**

- Instance names are the **bare tier name only** — no sprint number, no username.
- Both instances exist on the developer workstation; they are not shared.
- Full SQL instance address: `<hostname>\Development` or `<hostname>\Experimental`.

**Provisioning cmdlet:** `New-SprintSqlServerInstances` (BuildTooling.PowerShell)

**Tear-down cmdlet:** `Remove-SprintSqlServerInstances` (BuildTooling.PowerShell)

### 2.2 Permanent ecosystem instances

| Instance name | Tier | Host      |
| ------------- | ---- | --------- |
| `Integration` | T3   | `utat022` |
| `QA`          | T4   | `utat022` |
| `Production`  | T5   | `utat022` |

These are provisioned once during ecosystem onboarding. Sprint start/end
never touches them.

---

## 3. ProGet Feed Naming

Ten permanent feeds — five NuGet and five PowerShellGet — one per tier per
family. **No per-sprint feeds.**

### 3.1 NuGet feeds (C# packages)

| Feed name            | Tier | Hermetic                                       |
| -------------------- | ---- | ---------------------------------------------- |
| `nuget-experimental` | T1   | No (has `nuget.org` connector)                 |
| `nuget-development`  | T2   | No (has `nuget.org` + experimental connectors) |
| `nuget-integration`  | T3   | ✅ Yes (no public connector)                   |
| `nuget-qa`           | T4   | ✅ Yes                                         |
| `nuget-stable`       | T5   | No (has `nuget.org` connector)                 |

### 3.2 PowerShellGet feeds (PowerShell modules)

| Feed name                    | Tier |
| ---------------------------- | ---- |
| `powershellget-experimental` | T1   |
| `powershellget-development`  | T2   |
| `powershellget-integration`  | T3   |
| `powershellget-qa`           | T4   |
| `powershellget-stable`       | T5   |

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

**Provisioning cmdlet:** `New-SprintBitwardenSecrets`

**Tear-down cmdlet:** `Remove-SprintBitwardenSecrets`

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

All secrets are retrieved via `Get-BitwardenSecret -SecretName <name>` from
`ATAP.Utilities.Security.Powershell`. The cmdlet passes the name unchanged
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

> **Note:** Sprint-0006 worktrees use lowercase `sprint` for historical
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
| `NuGetFeedName_Experimental`                       | `nuget-experimental`                                            |
| `NuGetFeedUrl_Experimental`                        | `http://localhost:50000/nuget/nuget-experimental/v3/index.json` |
| `PowerShellGetFeedName_Experimental`               | `powershellget-experimental`                                    |
| _(and one URL + one name pair per remaining tier)_ |                                                                 |

20 feed name/URL variables + 3 SQL instance variables = 23 stable variables
per BuildMaster application (`AceCommander`, `ATAP.Utilities`).

**Set cmdlet:** `Set-BuildMasterStableVariables`

---

## 7. Summary Table

| Component               | Naming pattern                                   | Per-sprint? | Cmdlet                                  |
| ----------------------- | ------------------------------------------------ | ----------- | --------------------------------------- |
| SQL — sprint            | `Development` / `Experimental`                   | ✅          | `New-SprintSqlServerInstances`          |
| SQL — permanent         | `Integration` / `QA` / `Production` on `utat022` | ❌          | manual / IAC                            |
| ProGet NuGet feed       | `nuget-<tier>`                                   | ❌          | `New-ProGetFeedSet`                     |
| ProGet PS feed          | `powershellget-<tier>`                           | ❌          | `New-ProGetFeedSet`                     |
| Bitwarden — sprint      | `dbConnectionString-<DB>-<Host>-<Tier>-<User>`   | ✅          | `New-SprintBitwardenSecrets`            |
| Bitwarden — permanent   | `dbConnectionString-<DB>-<Host>-<Tier>`          | ❌          | `New-PermanentBitwardenSecrets`         |
| Worktree / branch       | `<repo>-wt-<N>-Sprint-<NNNN>-work-items`         | ✅          | `New-SprintStage1` / `New-SprintStage2` |
| BuildMaster sprint vars | `SprintNumber`, `UserName`, `SprintBranchName`   | ✅          | `Set-BuildMasterSprintVariables`        |
| BuildMaster stable vars | feed names/URLs, SQL instances                   | ❌          | `Set-BuildMasterStableVariables`        |
