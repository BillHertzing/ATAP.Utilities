# ATAP.Utilities.BuildTooling.AiRendering.PowerShell

This child owns BuildTooling's repository instruction combiners, diagram rendering,
failure-acknowledgement gates, SharedVSCode reset wrapper, Claude settings render helper,
TRX failure count reader, and AgentText validation suite.

The public surface contains eleven commands. `Set-ClaudeSettingsSymlink` is child-public
so the compatibility parent and later SprintLifecycle child can call it across module
scope, but it is intentionally omitted from the compatibility parent's legacy export
surface.

## AGENTS.md composition (Task 13.76.b)

`Build-AGENTSPerRepository` is the **only** writer of a repository's `AGENTS.md`. It
composes three sentinel-delimited regions, in this order:

| Region | Source |
| --- | --- |
| `<!-- AI-LOCAL -->` | the repo's `ai-local.md` (legacy `CLAUDE-local.md` fallback) |
| `<!-- AI-CORE -->` | SharedVSCode `AGENTS-base.md`, verbatim |
| `<!-- AI-AGENT-CODEX -->` | SharedVSCode `.ai/core/agent-specific/codex.md`, when present |

The Codex region is **appended after** the core, never in place of it. On 2026-07-25 the
`ai.core.agent-specific.codex.v1` manifest record was rendered directly to `AGENTS.md`
and replaced the whole composed carrier with its 35-line body in four sprint worktrees.
That record is now marked `materialization: "composer-owner"`, which makes
`Render-AIAdapters` both skip the write and refuse to rebaseline the carrier's hash under
`-UpdateManifest` — the rebaseline is what let the clobber pass the drift gates.

Consequences for callers:

- To change Codex policy, edit the canonical `.ai/core/agent-specific/codex.md` and re-run
  this cmdlet. Do not re-point the manifest record at `AGENTS.md`.
- An absent or whitespace-only canonical file omits the block entirely, so repos and
  sprints without it compose exactly as before.
- Composition is verified by SharedVSCode `Tests/PesterTests/AIAdapter-SharedCore.Tests.ps1`
  ("AI-AGENT-CODEX composer block") and by this module's
  `tests/Unit/Build-AGENTSPerRepository.Tests.ps1`. The AI-adapter drift gate deliberately
  does not check the carrier, so those suites are the contract.

This module depends on `ATAP.Utilities.BuildTooling.Common.PowerShell` 0.1.5 or later.
The ten PowerShell tools under SharedVSCode `.ai/tools` remain separately owned by the
future `ATAP.Utilities.AIAdapters.PowerShell` module under SC-0246; they are not part of
this child.

## Functional area

PowerShell Build & Packaging - START HERE: `SolutionDocumentation/PowerShell-Modules-Build-Process.md`.
