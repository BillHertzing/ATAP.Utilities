# Task 12.15 - Add-ScopeCreepIdea planning-root resolution

Date: 2026-07-05

## Change

- Updated `Resolve-PlanningWorktreeRoot` so callers outside any sprint worktree first inspect `Overview.Sprint*.code-workspace` files and use a sprint `_Planning` worktree when present.
- Preserved stable-maintenance fallback through `Overview.code-workspace` and `<ReposParent>\_Planning` when no sprint overview exists.
- Added regression coverage in `Add-ScopeCreepIdea.Tests.ps1` for outside-sprint callers resolving the sprint overview workspace.

## Validation

- `pwsh -Command "Invoke-Pester -Path 'src/ATAP.Utilities.BuildTooling.PowerShell/tests/Unit/Add-ScopeCreepIdea.Tests.ps1' -Output Minimal"`
- Result: 12 tests passed, 0 failed.

## Deploy State

- Source-verified only in this task.
- BuildTooling package version bump, promotion, and installation were not performed.
