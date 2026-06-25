# ATAP.Utilities.ConfigRootKeys.PowerShell — INDEX

This module bootstraps `$global:configRootKeys`, the canonical hashtable of key
**name** constants used throughout the ATAP codebase to look values up in
`$global:settings`.

The module is loaded early in the PowerShell profile so that subsequent settings
fragments and consumers can refer to keys by their well-known constant names
rather than hard-coding strings.

## Module Files

| File                                          | Role                                                                                |
| --------------------------------------------- | ----------------------------------------------------------------------------------- |
| `ATAP.Utilities.ConfigRootKeys.PowerShell.psd1` | Module manifest                                                                     |
| `ATAP.Utilities.ConfigRootKeys.PowerShell.psm1` | Module entry point (dot-sources `public/` scripts)                                  |
| `ReadMe.md`                                   | Module overview                                                                     |
| `version.json`                                | NBGV version configuration                                                          |
| `tests/Unit/`                                 | Pester 5 tests: orchestration, in-module sibling resolution, and the no-top-level-code / eponymous-function structural rules |

## Public Scripts

Every file in `public/` is an **eponymous advanced function** (cmdlet shape with
`begin`/`process`/`end`) — there is **no top-level executable code** and there are
**no `*.ConfigRootKeys.ps1` fragments**. The invocation order is fixed and made
**explicit** by `Set-GlobalConfigRootKeys`; nothing is discovered by a directory scan.

| File                                                  | Order | Role                                                                                              |
| ----------------------------------------------------- | ----- | ------------------------------------------------------------------------------------------------- |
| `public/Set-GlobalConfigRootKeys.ps1`                 |  —    | Entry-point orchestrator. Invokes the section functions below, by name, in a fixed order.         |
| `public/Set-CoreConfigRootKeys.ps1`                   |  1    | Bootstrap. Creates `$global:configRootKeys` and registers core/non-domain keys. Must run first.   |
| `public/Add-DatabasesConfigRootKeys.ps1`              |  2    | Adds database connection key constants, then invokes the per-database section functions by name.  |
| `public/Set-DatabasesATAPUtilitiesConfigRootKeys.ps1` |  2a   | Per-database section function for the ATAPUtilities database name key.                             |
| `public/Set-DatabasesAceCommanderConfigRootKeys.ps1`  |  2b   | Per-database section function for the AceCommander database name key.                              |
| `public/Set-BuildMasterConfigRootKeys.ps1`            |  3    | BuildMaster automation paths, endpoint, and the module→application map (`BuildMasterApplicationByModuleConfigRootKey`) key constants. |
| `public/Set-RulesManagementConfigRootKeys.ps1`        |  4    | Rules-Management framework key constants.                                                          |
| `public/Add-PackageRepositoriesConfigRootKeys.ps1`    |  5    | **Single source of truth** for ProGet / NuGet / PowerShellGet feed key constants. Five-tier canonical set (Experimental / Development / Integration / QA / Stable). Loads no sub-fragments. |

### Explicit loading — no fragment discovery

The previous design dropped `*.ConfigRootKeys.ps1` "fragments" into `public/` and let a
higher-level function **discover** them with `Get-ChildItem` scans. That is no longer
allowed. Every set of ConfigRootKeys must be an **explicitly named** `Set-*ConfigRootKeys`
(or `Add-*ConfigRootKeys`) function, listed in `FunctionsToExport` in the manifest and
named in the ordered invocation list inside `Set-GlobalConfigRootKeys`
(and `Add-DatabasesConfigRootKeys` for the per-database sections). To add a new section:

1. Create `public/Set-<Domain>ConfigRootKeys.ps1` as an eponymous cmdlet that guards on
   `$global:configRootKeys` existing and `.Add(...)`s its keys inside the `process` block.
2. Add the function name to `FunctionsToExport` in the `.psd1`.
3. Add the function name to the ordered list in the appropriate orchestrator
   (`Set-GlobalConfigRootKeys`, or `Add-DatabasesConfigRootKeys` for a database).

### In-module sibling resolution (development-from-source guard)

When a higher-level function (e.g. `Set-GlobalConfigRootKeys`) calls a lower-level
function in the **same module** (e.g. `Set-CoreConfigRootKeys`) while running **from
source** — its `.ps1` dot-sourced individually rather than imported as a built module —
PowerShell command **autoloading** would resolve the first match on `$env:PSModulePath`.
If an **installed, production-grade** copy of this module is present, autoloading loads
*that* version and silently shadows the in-development code in the sprint worktree.

To guarantee the co-located (sprint-worktree) version wins, each orchestrator's `begin`
block dot-sources every section function it invokes from the co-located source file
(`-Path` directory, default `$PSScriptRoot`) **when that file is present**:

- **Running from source** — the sibling `.ps1` exists next to the orchestrator → it is
  dot-sourced into the orchestrator's local scope, so `& <SectionFunction>` resolves the
  worktree version, not an installed one.
- **Built / installed module** — the build merges all `public/*.ps1` into the single
  `.psm1`, so the individual files are absent; the already-loaded module-scoped function
  is used (which, in production, is exactly the installed version you want).
- **Neither present** — an actionable error names the missing function and the path it
  looked for.

This is the canonical pattern for "a higher-level function calling a lower-level function
in the same module under development." A scope-creep item tracks propagating it to the
other ATAP PowerShell modules.

## Deprecated / Removed Files

| File                                                       | Status                                                                  |
| ---------------------------------------------------------- | ----------------------------------------------------------------------- |
| `public/BuildMaster.ConfigRootKeys.ps1`                    | **Renamed** to `Set-BuildMasterConfigRootKeys.ps1` (now an eponymous cmdlet). |
| `public/RulesManagement.ConfigRootKeys.ps1`                | **Renamed** to `Set-RulesManagementConfigRootKeys.ps1`.                  |
| `public/Databases.ATAPUtilities.ConfigRootKeys.ps1`        | **Renamed** to `Set-DatabasesATAPUtilitiesConfigRootKeys.ps1`.           |
| `public/Databases.AceCommander.ConfigRootKeys.ps1`         | **Renamed** to `Set-DatabasesAceCommanderConfigRootKeys.ps1`.            |
| `public/PackageRepositories.Nuget.ConfigRootKeys.ps1`      | **Removed (PF cleanup, Sprint 0007).** Consolidated into `Add-PackageRepositoriesConfigRootKeys.ps1`. |
| `public/PackageRepositories.PowershellGet.ConfigRootKeys.ps1` | **Removed (PF cleanup, Sprint 0007).** Consolidated into `Add-PackageRepositoriesConfigRootKeys.ps1`. |

## Key Naming Conventions

- ConfigRootKey constant name: ends with `ConfigRootKey`
  (e.g. `ProGetFeedNuGetExperimentalFeedNameConfigRootKey`).
- The **value** assigned to a ConfigRootKey is the literal string used as a key
  into `$global:settings`
  (e.g. `'ProGetFeedNuGetExperimentalFeedName'`).
- The **value stored at that `$global:settings` key** is the actual runtime data
  — for ProGet feeds, the lowercase canonical feed name
  (e.g. `'nuget-experimental'`, `'powershellget-experimental'`).

## Tier Mapping (Canonical Five-Tier Pipeline)

| Tier         | NBGV label    | NuGet feed name      | PowerShellGet feed name     |
| ------------ | ------------- | -------------------- | --------------------------- |
| Experimental | `-Sprint-`    | `nuget-experimental` | `powershellget-experimental`|
| Development  | `-Alpha-`     | `nuget-development`  | `powershellget-development` |
| Integration  | `-Beta-`      | `nuget-integration`  | `powershellget-integration` |
| QA           | `-QA-`        | `nuget-qa`           | `powershellget-qa`          |
| Stable       | _(no label)_  | `nuget-stable`       | `powershellget-stable`      |

## Related Documentation

- `_Planning/Explainers/0111-proget-feed-tier-dependency-build-report.md` —
  Source-of-truth report on five-tier feed dependency policy.
- `ATAP.IAC/constants/FeedConstants.psd1` — canonical feed name and URL
  defaults consumed by host settings.
