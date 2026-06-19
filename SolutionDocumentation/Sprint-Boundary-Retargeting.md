# Sprint-Boundary Retargeting

A sprint worktree's pointers and links must reference the SharedVSCode **sprint**
worktree while a sprint is active, and the **stable** SharedVSCode worktree once the
sprint merges into main. `Set-SprintBoundaryContext`
(`src/ATAP.Utilities.BuildTooling.PowerShell/public/Set-SprintBoundaryContext.ps1`) is
the single orchestrator that performs (Start) or reverses (End) the full retarget.
This document is the source of truth for which concern is retargeted by which worker, and
why two concerns are intentionally left alone. Task 10.20.o extends the boundary with canonical project AI-settings materialization and drift review.

This completes task **V4-H03** (Sprint 0007).

## Boundary concerns

| Concern | Worker(s) | Start action (→ sprint) | End action (→ stable) | Stable-by-design |
| --- | --- | --- | --- | --- |
| Machine links (NTFS junctions) | `Set-WorktreeJunctions` | recreate `.claude` / `.github` / `.vscode` junctions in each sprint worktree, dev-redirected to the SharedVSCode sprint worktree | recreate junctions from the stable repo so they point back to stable SharedVSCode | No |
| SharedVSCode settings | `Set-UserSettingsSymlink`, `Set-ClaudeSettingsSymlink` | point `%APPDATA%\Code\User\settings.json` and `~/.claude/settings.json` at the sprint worktree's `UserSettings.jsonc` / `claude-settings.json` | point both back at the stable SharedVSCode copies | No |
| Downstream contexts | `Initialize-DownstreamSprintFromSharedVSCode` (Start) / `Reset-DownstreamToSharedVSCodeMain` (End) | set each `*.code-workspace` `templateRef`/`profile` to the sprint worktree and re-apply hooks / commit template / gitattributes | reset `templateRef` to `main`, `profile` to `default`, re-apply context | No |
| Canonical project AI settings | `Invoke-SprintAISettingsLifecycle` | render in Antigravity → Codex → Claude Code → Copilot order; real worktrees materialize project scope only | audit each project target as `retarget-clean` or `promote-or-regenerate-review` before link teardown | No |
| PowerShell profiles | — | none | none | **Yes** |
| ConfigRootKeys | — | none | none | **Yes** |

### Why profiles and ConfigRootKeys are stable-by-design

- **PowerShell profiles** load their ATAP modules from the **stable** repo path
  (`C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\...`) and from `PSModulePath`. The
  profile is installed once per machine and is never re-pointed per sprint, so there is
  nothing to retarget at a sprint boundary.
- **ConfigRootKeys** map key-name constants to host/user-specific values
  (`$global:configRootKeys` / `$global:settings`). They store no sprint-worktree paths, so
  they are identical across sprints.

`Set-SprintBoundaryContext` still emits an explicit `StableByDesign = $true` result entry
for both, so the returned contract demonstrably covers all five concerns named in the
V4-H03 acceptance criteria.

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
  canonical project AI settings through `Initialize-SprintAIAdapters`, then the two settings symlinks).
