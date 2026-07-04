# Sprint-Boundary Retargeting

A sprint worktree's pointers and links must reference the SharedVSCode **sprint**
worktree while a sprint is active, and the **stable** SharedVSCode worktree once the
sprint merges into main. `Set-SprintBoundaryContext`
(`src/ATAP.Utilities.BuildTooling.PowerShell/public/Set-SprintBoundaryContext.ps1`) is
the single orchestrator that performs (Start) or reverses (End) the full retarget.
This document is the source of truth for which concern is retargeted by which worker, and
why two concerns are intentionally left alone. Task 10.20.o added canonical
project AI settings; Task 10.26 consolidated that lifecycle onto the sole
`Render-AIAdapters` and `Test-AIAdapterDrift` APIs.

This completes task **V4-H03** (Sprint 0007).

## Boundary concerns

| Concern | Worker(s) | Start action (→ sprint) | End action (→ stable) | Stable-by-design |
| --- | --- | --- | --- | --- |
| Machine links (NTFS junctions) | `Set-WorktreeJunctions` | recreate `.claude` / `.github` / `.vscode` junctions in each sprint worktree, dev-redirected to the SharedVSCode sprint worktree | recreate junctions from the stable repo so they point back to stable SharedVSCode | No |
| SharedVSCode settings | `Invoke-SprintAIAdapterLifecycle`, `Set-UserSettingsSymlink`, `Set-ClaudeSettingsSymlink` | re-render the SharedVSCode settings target for the sprint boundary, point `%APPDATA%\Code\User\settings.json` at the sprint `UserSettings.jsonc`, and render `~/.claude/settings.json` as a real file from `.ai/config/claudecode/settings.overlay.json` | re-render the SharedVSCode settings target for stable, point VS Code user settings back at stable, and render Claude user settings from the stable overlay | No |
| Downstream contexts | `Initialize-DownstreamSprintFromSharedVSCode` (Start) / `Reset-DownstreamToSharedVSCodeMain` (End) | set each `*.code-workspace` `templateRef`/`profile` to the sprint worktree and re-apply hooks / commit template / gitattributes | reset `templateRef` to `main`, `profile` to `default`, re-apply context | No |
| Canonical project AI adapters | `Invoke-SprintAIAdapterLifecycle` | call `Render-AIAdapters -Domain settings,permissions` in Antigravity → Codex → Claude Code → Copilot order; real worktrees materialize project scope only | call `Test-AIAdapterDrift -Domain settings,permissions`; unexplained drift blocks link teardown pending promote/regenerate review | No |
| PowerShell 7 profile symlinks | `Set-PowerShell7ProfileSymlink` | point `C:\Program Files\PowerShell\7\profile.ps1` at the ATAP.Utilities sprint worktree and `HostSettings.ps1` at the ATAP.IAC sprint worktree; remove the obsolete `global_ConfigRootKeys.ps1` / `global_environmentVariables.ps1` links | point `profile.ps1` / `HostSettings.ps1` back at the stable ATAP.Utilities / ATAP.IAC repos | No |
| Developer PowerShell profiles | `Set-SprintBoundaryUserProfiles` | discover developers from `OverviewSprintNNNN.code-workspace` and install each developer's `Documents\PowerShell\profile.ps1` from `CurrentUserAllHostsV7CoreProfile.ps1` in the sprint ATAP.Utilities worktree | install each developer profile from the stable ATAP.Utilities `CurrentUserAllHostsV7CoreProfile.ps1` | No |
| Service-account PowerShell profiles | `Set-SprintBoundaryUserProfiles` | discover configured service accounts from host settings and install each available account's `Documents\PowerShell\profile.ps1` from `ProfileForServiceAccountUsers.ps1` in the sprint ATAP.Utilities worktree | install each available service-account profile from the stable ATAP.Utilities `ProfileForServiceAccountUsers.ps1`; missing/disabled accounts are warned, not hard-coded | No |
| ConfigRootKeys | — | none (in-process bootstrap) | none (in-process bootstrap) | **Yes** |

## AIAdapter lifecycle contract

`Invoke-SprintAIAdapterLifecycle` is the BuildTooling entry point. It loads the
SharedVSCode `Invoke-AIAdapterLifecycle` worker from the selected stable or
sprint worktree:

- **Start:** `Render-AIAdapters -Domain settings,permissions`, fixed caller order
  Antigravity → Codex → Claude Code → Copilot, project scope by default.
- **End:** `Test-AIAdapterDrift -Domain settings,permissions` before any junction,
  settings-link, or downstream-context teardown. Unexplained drift leaves the
  sprint wiring intact for promote/regenerate review.
- **Boundary settings refresh:** `Set-SprintBoundaryContext` also reuses the Start
  render against the selected SharedVSCode target at both boundaries so
  `settings.overlay.json` output such as `permissions.additionalDirectories` and
  hook command paths is regenerated before VS Code user settings are repointed
  and Claude user settings are rendered.
- **Safety:** `-WhatIf` is nonmutating. Live user/global replacement requires
  explicit approval and `-CheckpointConfirmed`; backups/evidence stay beneath
  `_generated/`. Runtime and MCP state remain preserve/defer surfaces.

Task 10.26.k removed the settings-named transition command after parity; all
documentation and callers use `Invoke-SprintAIAdapterLifecycle`.

### PowerShell profiles are retargeted or deployed; ConfigRootKeys are stable-by-design

- **PowerShell 7 profile symlinks** are **not** stable-by-design (corrected under
  H09/SC-0188, Task 10.13). `C:\Program Files\PowerShell\7\profile.ps1` is how the
  AllUsersAllHosts core profile (`AllUsersAllHostsV7CoreProfile.ps1`) detects whether the
  active session is in a stable or sprint worktree, so it must track the ATAP.Utilities
  sprint worktree while a sprint is open and reset to stable at SprintEnd. `HostSettings.ps1`
  follows the ATAP.IAC worktree the same way. `Set-PowerShell7ProfileSymlink` performs the
  retarget (and removes the obsolete `global_ConfigRootKeys.ps1` /
  `global_environmentVariables.ps1` symlinks). SprintEnd 0009 not resetting
  `global_ConfigRootKeys.ps1` left it pointed at the deleted Sprint 0009 worktree — the root
  cause of the recurring config-globals breakage this concern now prevents.
- **Developer and service-account profiles** are also **not** stable-by-design
  (Tasks 11.7.f/g). `Set-SprintBoundaryUserProfiles` resolves developers from the
  sprint Overview workspace and service accounts from the existing host settings,
  then ensures each available identity has `Documents\PowerShell\profile.ps1`
  sourced from the correct sprint or stable ATAP.Utilities profile file. SprintEnd
  verification re-discovers those managed profiles and proves that they are
  readable, stable-sourced, and free of stale sprint-worktree references.
- **ConfigRootKeys** remain genuinely stable-by-design: they are bootstrapped **in-process**
  by `Initialize-ATAPConfigurationGlobals` (Task 10.5) into `$global:configRootKeys` /
  `$global:settings` rather than dot-sourced from a `C:\Program Files\PowerShell\7` symlink,
  so there is no sprint-worktree path to retarget.

`Set-SprintBoundaryContext` emits one concern entry per row above: the
`PowerShell7ProfileSymlinks` concern carries `StableByDesign = $false` and its active
`Set-PowerShell7ProfileSymlink` result, the `DeveloperPowerShellProfiles` and
`ServiceAccountPowerShellProfiles` concerns carry `StableByDesign = $false`, and
`ConfigRootKeys` keeps `StableByDesign = $true`.
The returned contract demonstrably covers every concern named in the V4-H03 acceptance
criteria as extended by H09/SC-0188 (Task 10.13).

## Contract

```powershell
# Sprint start — retarget every sprint worktree to the SharedVSCode sprint worktree
$worktrees = Get-ChildItem 'C:\Dropbox\whertzing\GitHub' -Directory `
    -Filter '*-wt-*-Sprint-0007-work-items'
Set-SprintBoundaryContext -Boundary Start `
    -WorktreePaths $worktrees.FullName `
    -SharedVSCodeWorktreePath 'C:\Dropbox\whertzing\GitHub\SharedVSCode-wt-42-Sprint-0007-work-items'

# Sprint end — retarget everything back to stable SharedVSCode
Set-SprintBoundaryContext -Boundary End `
    -WorktreePaths $worktrees.FullName `
    -SharedVSCodeWorktreePath 'C:\Dropbox\whertzing\GitHub\SharedVSCode'
```

The cmdlet supports `-WhatIf` (every worker runs under the orchestrator's `ShouldProcess`,
so a dry run mutates nothing) and returns a `[PSCustomObject]` with:

- `Boundary`, `DryRun`
- `Concerns[]` — one entry per concern (`Concern`, `Action`, `StableByDesign`,
  `Succeeded`, `Error`)
- `PerWorktree[]` — `WorktreePath`, derived `StableRepoPath`, `JunctionsRetargeted`,
  `ContextRetargeted`, `Error`
- `Errors[]` — aggregate of all failures (the cmdlet continues past a per-worktree
  failure and surfaces every error)

Omit `-WorktreePaths` to retarget only the machine-global settings symlinks (for example,
when repairing a single host after a partial sprint-start).

## Where it is invoked

- **Sprint start.** `New-SprintStage1` and `New-SprintStage2` perform the equivalent
  Start-boundary retarget during sprint creation (junctions + downstream context per repo,
  then the two settings symlinks). `SprintStartAgent` names `Set-SprintBoundaryContext`
  `-Boundary Start` as the canonical retargeting entry point and idempotent repair path.
- **Sprint end.** `SprintEndAgent` calls `Set-SprintBoundaryContext -Boundary End`
  directly to audit canonical project settings, retarget junctions/settings symlinks/downstream
  contexts back to stable, and block clean teardown when settings require promote/regenerate review.

## Tests

`src/ATAP.Utilities.BuildTooling.PowerShell/tests/Unit/Set-SprintBoundaryContext.Tests.ps1`
(mocked workers): Start vs End worker dispatch and targets, the seven-concern return
contract, shared-settings re-rendering, managed profile deployment, per-worktree
breakdown, missing-worktree error handling, settings-only invocation, and
`-WhatIf` no-mutation. `tests/Unit/Set-SprintBoundaryUserProfiles.Tests.ps1`
exercises developer/service-account profile discovery and deployment, and
`tests/Unit/SprintEndLifecycle.Tests.ps1` verifies that
`Test-SprintEndBoundaryState` auto-discovers the managed profiles. Run:

```powershell
pwsh -Command "Invoke-Pester -Path 'src/ATAP.Utilities.BuildTooling.PowerShell/tests/Unit/Set-SprintBoundaryContext.Tests.ps1' -Output Minimal"
```
