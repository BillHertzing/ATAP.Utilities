# Release notes

## 0.1.0

- Created the child scaffold and moved the three frozen PlanningSession commands.
- Declared GitWorktree 0.1.3 for Planning-root resolution and
  ATAP.Utilities.Powershell 0.1.23 for `Get-PVal`.
- Split resolver coverage to GitWorktree ownership while retaining the four
  `Add-ScopeCreepIdea` functional contexts in PlanningSession.
- Corrected the pre-existing nested wrapper around `Complete-PlanningSession`
  so its public parameter contract is active.
