# ATAP.Utilities.BuildTooling.PlanningSession.PowerShell

This child owns scope-creep capture and the start/complete planning-session
workflow. `Add-ScopeCreepIdea` remains a global compatibility contract during
the family migration.

The child requires GitWorktree 0.1.3 or later for
`Resolve-PlanningWorktreeRoot`. It has no top-level executable code and no
`Write-Host` debt in its frozen Task 13.72.2 scope.

`Start-PlanningSession` and `Complete-PlanningSession` resolve configuration
through `Get-PVal`, so the manifest also declares
`ATAP.Utilities.Powershell` 0.1.23 through 0.999.999 explicitly.

## Functional area

PowerShell Build & Packaging - START HERE: `SolutionDocumentation/PowerShell-Modules-Build-Process.md`.
