# ATAP.Utilities.RulesManagement.PowerShell

This module contains the agent-facing PowerShell API for RRSBS rule kinds,
grammar inspection, Flyway migration scaffolding, and documentation sync.

Sprint 0008 adds the AgentText pilot:

- `Import-AgentTextFromFiles.ps1` loads SharedVSCode `.ai` manifests and
  Markdown/TOML sources into AgentText-shaped objects or SQL fragments.
- `Export-AgentTextToFiles.ps1` instantiates those records back into native
  adapter files for copy and generated-wrapper targets.
- `SolutionDocumentation/Rules Compendium.AgentText.md` defines the pilot kind
  and embeds the AgentText grammar.
- `Database/Flyway/SQL/V00.02.000040__Add_AgentText_Rule_Kind.sql` creates the
  AgentText pilot tables and seeds the RRSBS primitives/composition.
  (Renumbered from V00.01.000302, which Integration/QA/Production already used
  for the obsolete UserInformation decrypt procedure.)

See [INDEX.md](INDEX.md) for the complete function and table inventory.
