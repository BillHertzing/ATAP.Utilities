<meta http-equiv="refresh" content="0; URL=ReadMe.html"/>
# ATAP Utilities Repository Root Index
This file contains a bried description of every file and folder located in the repository root## This note applies to teh .mcp.json file### MCP configuration files in this repo

This repository includes an `.mcp.json` file at the root alongside a `.vscode/mcp.json` file. Both describe the same set of MCP servers (for example, the local PlantUML MCP server) and may look redundant at first glance.

The duplication is intentional:

- `.mcp.json` is the primary, tool-agnostic configuration used by Claude Code and other MCP‑aware clients that look for a project‑level MCP definition in the repo root. It ensures the project’s MCP setup is explicit, versioned, and portable across editors and machines.
- `.vscode/mcp.json` is the Visual Studio Code–specific MCP configuration that VS Code itself (and extensions that rely on VS Code’s MCP integration) can read. Keeping this file allows other tools such as Copilot Chat or future MCP‑enabled extensions to reuse the same server definitions without additional setup.

For now, both files intentionally mirror each other so that different MCP clients (Claude Code and VS Code–native integrations) can share the same local MCP servers. If the ecosystem converges on a single configuration location in the future, we can remove this duplication and point everything at one source of truth.

### Generated diagram pipeline

The PlantUML MCP server is for interactive client rendering. Checked-in diagram
images are generated with the PowerShell command documented in
[`SolutionDocumentation/Generated-Diagram-Pipeline.md`](SolutionDocumentation/Generated-Diagram-Pipeline.md).
Editable `.puml`, `.uml`, and `.drawio` sources stay in their documentation
folders; rendered images are written under `_generated/diagrams`.

### RepoHealth gate

`Build\Invoke-RepoHealthGate.ps1` runs repository-wide checks that are too broad
for an individual package/module test suite. The current gate invokes
`tests\RepoHealth\Directory.Build.Props.Properties.Tests.ps1` after C# restore
and before pack/publish to verify `Directory.Build.props` properties across all
C# projects under `src/`.

### AgentText RRSBS pilot

Sprint 0008 adds an AgentText rule kind for AI agent and instruction text.
The compendium lives at
[`SolutionDocumentation/Rules Compendium.AgentText.md`](SolutionDocumentation/Rules%20Compendium.AgentText.md),
with its grammar embedded in that compendium and import/export functions under
`src/ATAP.Utilities.RulesManagement.PowerShell/public/`.

### Agent instruction surfaces

`AGENTS.md`, `CLAUDE.md`, and `.agents/skills/bitwarden/SKILL.md` carry the
Sprint 0010 Task 10.7 Bitwarden split: `Get-SecretATAP` defaults to
Bitwarden Secrets Manager (`bws` plus process/DPAPI token), while Password
Manager `bw` + `BW_SESSION` is opt-in for personal user-owned secrets only.

### Research reports

- `Research/ReportOnAccessingSecretsFromBitwarden.md` in the `_Planning` Sprint
  0010 worktree records the Task 10.7 review of Bitwarden Password Manager
  `bw`, Bitwarden Secrets Manager `bws`, DPAPI token resolution, BuildMaster
  secret access, and the DB connection-string BWS cleanup.
