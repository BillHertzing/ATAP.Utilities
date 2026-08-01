# AiRendering module index

## Public commands

- `Build-AgentSpecificPerRepository`
- `Build-AGENTSPerRepository` — sole writer of repo `AGENTS.md`; composes AI-LOCAL,
  AI-CORE, and (Task 13.76.b) AI-AGENT-CODEX. See ReadMe "AGENTS.md composition".
- `Build-AIInstructionsPerRepository`
- `Build-CLAUDEPerRepository`
- `Convert-DiagramsToImages`
- `Get-NumberOfFailingTestsFromTRX`
- `Invoke-FailureAcknowledgedGate`
- `Reset-DownstreamToSharedVSCodeMain`
- `Set-ClaudeSettingsSymlink`
- `Test-FailureAcknowledgedGate`
- `Test-PairedAgentTextSuite`

## Assets

- `Resources/FailureAcknowledged.schema.json`

## Boundary

SC-0246 still owns the future relocation of the ten SharedVSCode `.ai/tools`
PowerShell files. This module contains only BuildTooling workflow support and does
not claim those files.
