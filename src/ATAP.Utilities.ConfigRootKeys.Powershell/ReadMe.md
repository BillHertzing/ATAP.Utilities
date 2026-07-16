# ATAP.Utilities.ConfigRootKeys.PowerShell

Builds `$global:configRootKeys` — the host-invariant vocabulary of settings-key
**name** constants used throughout the ATAP PowerShell ecosystem to index
`$global:settings`. This is **Tier 1** of the two-tier global-settings pattern; see
[`SolutionDocumentation/ConfigRootKeys-and-HostSettings.md`](../../SolutionDocumentation/ConfigRootKeys-and-HostSettings.md)
for the full design.

## Usage

```powershell
Import-Module ATAP.Utilities.ConfigRootKeys.PowerShell
Set-GlobalConfigRootKeys     # creates and fully populates $global:configRootKeys
```

The module has no `private/` folder today. Its module entry point treats that
folder as optional, so profile-time `Import-Module` works from an AllUsers
PowerShell 7 profile without requiring an empty placeholder directory (Task 12.63).

`Set-GlobalConfigRootKeys` is the single entry point. It invokes each section
function — `Set-CoreConfigRootKeys`, `Add-DatabasesConfigRootKeys` (which in turn
invokes the per-database `Set-Databases*ConfigRootKeys` functions),
`Set-SqlInstanceTopologyConfigRootKeys`, `Set-BuildMasterConfigRootKeys`,
`Set-RulesManagementConfigRootKeys`, and
`Add-PackageRepositoriesConfigRootKeys` — **by name, in a fixed order**.

The SQL topology section defines only host-invariant schema keys. ATAP.IAC's
`HostSettings.IAC.Fragment.SqlInstanceTopology.ps1` remains the single source of
truth for current/planned hosts, instance names, filesystem paths, and TCP ports.

## Design rules

- **Eponymous functions only.** Every file in `public/` defines exactly one advanced
  function (cmdlet shape, `begin`/`process`/`end`) named for the file. No top-level
  executable code runs at import time.
- **Explicit loading, no discovery.** Each set of ConfigRootKeys is an explicitly named
  `Set-*ConfigRootKeys` / `Add-*ConfigRootKeys` function listed in the manifest and in
  the orchestrator's ordered invocation list. There is no `*.ConfigRootKeys.ps1`
  fragment scan.
- **In-module sibling resolution.** When run from source, each orchestrator dot-sources
  its callees from their co-located source files so the in-development sprint-worktree
  version wins over any installed production module that autoloading might otherwise
  resolve. In a built module the merged `.psm1` functions are used instead.

See [`INDEX.md`](INDEX.md) for the file map, the explicit-loading rules, the
sibling-resolution guard, and how to add a new section.

## Tests

```powershell
Invoke-Pester -Path ./tests/Unit -Output Detailed
```

- Version bumped to 0.1.4 in Sprint 11

## Functional area

Environment / Workstation Setup - START HERE: SolutionDocumentation\NewComputerSetup.md (see also ConfigRootKeys-and-HostSettings.md) (link-up added 2026-07-07, Sprint 0012 Task 12.46.f)
