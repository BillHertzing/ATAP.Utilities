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
| SharedVSCode settings | `Set-UserSettingsSymlink`, `Set-ClaudeSettingsSymlink` | point `%APPDATA%\Code\User\settings.json` and `~/.claude/settings.json` at the sprint worktree's `UserSettings.jsonc` / `claude-settings.json` | point both back at the stable SharedVSCode copies | No |
| Downstream contexts | `Initialize-DownstreamSprintFromSharedVSCode` (Start) / `Reset-DownstreamToSharedVSCodeMain` (End) | set each `*.code-workspace` `templateRef`/`profile` to the sprint worktree and re-apply hooks / commit template / gitattributes | reset `templateRef` to `main`, `profile` to `default`, re-apply context | No |
| Canonical project AI adapters | `Invoke-SprintAIAdapterLifecycle` | call `Render-AIAdapters -Domain settings,permissions` in Antigravity → Codex → Claude Code → Copilot order; real worktrees materialize project scope only | call `Test-AIAdapterDrift -Domain settings,permissions`; unexplained drift blocks link teardown pending promote/regenerate review | No |
| PowerShell 7 profile symlinks | `Set-PowerShell7ProfileSymlink` | point `C:\Program Files\PowerShell\7\profile.ps1` at the ATAP.Utilities sprint worktree and `HostSettings.ps1` at the ATAP.IAC sprint worktree; remove the obsolete `global_ConfigRootKeys.ps1` / `global_environmentVariables.ps1` links | point `profile.ps1` / `HostSettings.ps1` back at the stable ATAP.Utilities / ATAP.IAC repos | No |
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
- **Safety:** `-WhatIf` is nonmutating. Live user/global replacement requires
  explicit approval and `-CheckpointConfirmed`; backups/evidence stay beneath
  `_generated/`. Runtime and MCP state remain preserve/defer surfaces.

Task 10.26.k removed the settings-named transition command after parity; all
documentation and callers use `Invoke-SprintAIAdapterLifecycle`.

### PowerShell 7 profile symlinks are retargeted; ConfigRootKeys are stable-by-design

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
- **ConfigRootKeys** remain genuinely stable-by-design: they are bootstrapped **in-process**
  by `Initialize-ATAPConfigurationGlobals` (Task 10.5) into `$global:configRootKeys` /
  `$global:settings` rather than dot-sourced from a `C:\Program Files\PowerShell\7` symlink,
  so there is no sprint-worktree path to retarget.

`Set-SprintBoundaryContext` emits one concern entry per row above: the
`PowerShell7ProfileSymlinks` concern carries `StableByDesign = $false` and its active
`Set-PowerShell7ProfileSymlink` result, while `ConfigRootKeys` keeps `StableByDesign = $true`.
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
(mocked workers): Start vs End worker dispatch and targets, the five-concern return
contract, per-worktree breakdown, missing-worktree error handling, settings-only
invocation, and `-WhatIf` no-mutation. Run:

```powershell
pwsh -Command "Invoke-Pester -Path 'src/ATAP.Utilities.BuildTooling.PowerShell/tests/Unit/Set-SprintBoundaryContext.Tests.ps1' -Output Minimal"
```
