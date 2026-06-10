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

## Public Scripts

The orchestration order is fixed and enforced by `Set-GlobalConfigRootKeys`.

| File                                            | Phase | Role                                                                                              |
| ----------------------------------------------- | ----- | ------------------------------------------------------------------------------------------------- |
| `public/Set-CoreConfigRootKeys.ps1`             |  1    | Bootstrap. Creates `$global:configRootKeys` and registers core/non-domain keys.                   |
| `public/Set-GlobalConfigRootKeys.ps1`           |  —    | Entry-point orchestrator. Dot-sources all phases in fixed order.                                  |
| `public/Add-DatabasesConfigRootKeys.ps1`        |  2    | Adds database connection key constants. Discovers `Databases.*.ConfigRootKeys.ps1` sub-fragments. |
| `public/Databases.ATAPUtilities.ConfigRootKeys.ps1` |  2  | Database sub-fragment for the ATAPUtilities database.                                             |
| `public/BuildMaster.ConfigRootKeys.ps1`         |  4    | BuildMaster automation paths and endpoint key constants.                                          |
| `public/RulesManagement.ConfigRootKeys.ps1`     |  4    | Rules-Management framework key constants.                                                         |
| `public/Add-PackageRepositoriesConfigRootKeys.ps1` |  5  | **Single source of truth** for ProGet / NuGet / PowerShellGet feed key constants. Five-tier canonical set (Experimental / Development / Integration / QA / Stable). Does NOT load any sub-fragments. |

## Deprecated / Unreachable Files

The following files were superseded by `Add-PackageRepositoriesConfigRootKeys`
(the single source of truth) and were **removed** during the PF
(PowerShell Feed Constants Migration) cleanup, Sprint 0007. They used the old
four-tier scheme (Experimental/Development/Testing/Production) and were never
loaded by `Set-GlobalConfigRootKeys` (Phase 3 discovery is disabled).

| File                                                       | Status                                                                  |
| ---------------------------------------------------------- | ----------------------------------------------------------------------- |
| `public/PackageRepositories.Nuget.ConfigRootKeys.ps1`      | **Removed (PF cleanup).** Consolidated into `Add-PackageRepositoriesConfigRootKeys.ps1`. |
| `public/PackageRepositories.PowershellGet.ConfigRootKeys.ps1` | **Removed (PF cleanup).** Consolidated into `Add-PackageRepositoriesConfigRootKeys.ps1`. |

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
