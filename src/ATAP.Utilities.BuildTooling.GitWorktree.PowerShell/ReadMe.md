# ATAP.Utilities.BuildTooling.GitWorktree.PowerShell

This child owns Git repository/worktree discovery, validation, hooks, junction setup, GitHub issue creation, grouped commits, and the local BuildMaster poller's Git operations. The compatibility parent re-exports its thirteen public commands during the migration.

It depends on `ATAP.Utilities.BuildTooling.Common.PowerShell` 0.1.5 or later for repository-root and workspace helpers. Implementation moves are serialized in Task 13.72.1 batches; no other extraction owns these files.

## Functional area

PowerShell Build & Packaging - START HERE: `SolutionDocumentation/PowerShell-Modules-Build-Process.md`.
