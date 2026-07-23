# ATAP.Utilities.BuildTooling.PlanningSession.PowerShell

This child owns scope-creep capture and the start/complete planning-session
workflow. `Add-ScopeCreepIdea` remains a global compatibility contract during
the family migration.

The child requires GitWorktree 0.1.3 or later for
`Resolve-PlanningWorktreeRoot`. It has no top-level executable code and no
`Write-Host` debt in its frozen Task 13.72.2 scope.

## Functional area

PowerShell Build & Packaging - START HERE: `SolutionDocumentation/PowerShell-Modules-Build-Process.md`.
