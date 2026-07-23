# ATAP.Utilities.BuildTooling.AiRendering.PowerShell

This child owns BuildTooling's repository instruction combiners, diagram rendering,
failure-acknowledgement gates, SharedVSCode reset wrapper, Claude settings render helper,
TRX failure count reader, and AgentText validation suite.

The public surface contains eleven commands. `Set-ClaudeSettingsSymlink` is child-public
so the compatibility parent and later SprintLifecycle child can call it across module
scope, but it is intentionally omitted from the compatibility parent's legacy export
surface.

This module depends on `ATAP.Utilities.BuildTooling.Common.PowerShell` 0.1.5 or later.
The ten PowerShell tools under SharedVSCode `.ai/tools` remain separately owned by the
future `ATAP.Utilities.AIAdapters.PowerShell` module under SC-0246; they are not part of
this child.

## Functional area

PowerShell Build & Packaging - START HERE: `SolutionDocumentation/PowerShell-Modules-Build-Process.md`.
