# ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell

Sprint lifecycle commands for SprintStart, SprintEnd, worktree teardown, checkpoint archival, and sprint-boundary validation.

Version 0.1.14 is installed AllUsers on UTAT01 and UTAT022. Service-profile fallback discovery is bounded to `SvcBuildMaster`, `SvcProGet`, and `SvcSQLServer`; an authenticated service identity manages only its own profile, while an operator session may deploy the approved set. Focused discovery tests pass 8/8, isolated SprintEnd lifecycle tests pass 25/25, and all six host/account targets are idempotent at the canonical profile hash.

SprintEnd handoffs invoke `Remove-SprintWorktreeSafely`: teardown is blocked for active
Codex/VS Code roots, retries are bounded, and an incomplete teardown leaves a minimal
retry handoff instead of recursively deleting the worktree.

The parent `ATAP.Utilities.BuildTooling.PowerShell` module retains the legacy command surface by requiring this child module.

## Functional area

PowerShell Build & Packaging - START HERE: `SolutionDocumentation/PowerShell-Modules-Build-Process.md`.
