# ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell

Sprint lifecycle commands for SprintStart, SprintEnd, worktree teardown, checkpoint archival, and sprint-boundary validation.

SprintEnd handoffs invoke `Remove-SprintWorktreeSafely`: teardown is blocked for active
Codex/VS Code roots, retries are bounded, and an incomplete teardown leaves a minimal
retry handoff instead of recursively deleting the worktree.

The parent `ATAP.Utilities.BuildTooling.PowerShell` module retains the legacy command surface by requiring this child module.

## Functional area

PowerShell Build & Packaging - START HERE: `SolutionDocumentation/PowerShell-Modules-Build-Process.md`.
