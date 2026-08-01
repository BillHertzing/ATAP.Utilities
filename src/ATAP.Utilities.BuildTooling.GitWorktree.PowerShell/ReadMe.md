# ATAP.Utilities.BuildTooling.GitWorktree.PowerShell

This child owns Git repository/worktree discovery, validation, hooks, junction setup, GitHub issue creation, grouped commits, and the local BuildMaster poller's Git operations. It temporarily exports fourteen commands: the thirteen frozen GitWorktree contracts plus `Start-LocalPowerShellModuleBuildMasterPoller`, which the BuildMaster child must assume in its later iteration. Each exported command has its own public source file so package generation preserves the full surface. The compatibility parent re-exports only the legacy commands in its frozen surface.

It depends on `ATAP.Utilities.BuildTooling.Common.PowerShell` 0.1.5 or later for repository-root and workspace helpers. Implementation moves are serialized in Task 13.72.1 batches; no other extraction owns these files.

Version 0.1.2 is the accepted Stable/AllUsers release. Its immutable Stable
package SHA-256 is
`A7F7C6CD876EF37C6F392AF553DAB7A377F2F7F6C5845BEFC51A6DEA05BF5884`.
Versions 0.1.0 and 0.1.1 are burned and must not be selected as rollback targets.

Version 0.1.3 promotes `Resolve-PlanningWorktreeRoot` as a child-only public
contract so PlanningSession can declare a real module dependency instead of
reaching into GitWorktree private scope. The parent does not re-export it.

## Functional area

PowerShell Build & Packaging - START HERE: `SolutionDocumentation/PowerShell-Modules-Build-Process.md`.
