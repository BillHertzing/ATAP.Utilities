# ATAP.Utilities.RulesManagement.PowerShell

PowerShell module that implements the agent-facing API for the RRSBS (Rules, Rule Sets, and Build Sets)
system. Functions read from and write to the `ATAPUtilities` SQL Server schema and keep the associated
Markdown documentation in sync.

## Directory Layout

```
ATAP.Utilities.RulesManagement.PowerShell/
├── public/          # Exported functions (one file per function)
├── private/         # Internal helpers (e.g. Get-RuleKindRows.ps1 — loaded by Get-RuleKinds)
├── tests/           # Pester test files (empty)
├── Documentation/   # Extended module documentation (empty)
├── INDEX.md         # This file
└── ReadMe.md
```

## Public Functions

| Function | Purpose |
|---|---|
| [Get-RuleKinds](public/Get-RuleKinds.ps1) | List all `PrimitiveLanguageKind` rows; entry point for the new-rule-kind skill |
| [Get-GrammarForKind](public/Get-GrammarForKind.ps1) | Return a `GrammarModel` (Kind + Primitives + ordered Compositions) for a named Kind |
| [Get-RulePrimitiveInputs](public/Get-RulePrimitiveInputs.ps1) | Return all `RulePrimitiveInput` rows bound to a given primitive Id |
| [Test-CompositionOrder](public/Test-CompositionOrder.ps1) | Validate proposed composition rows (contiguous positions, valid cardinality, required anchor) — **critical gate** before any DB write |
| [New-RuleKindMigration](public/New-RuleKindMigration.ps1) | Scaffold the next `V{n}__Add_{KindName}Kind.sql` Flyway migration inside a single transaction |
| [Test-FlywayMigrationDryRun](public/Test-FlywayMigrationDryRun.ps1) | Run `flyway validate` against a migration path without executing it |
| [Add-RuleKindToCompendium](public/Add-RuleKindToCompendium.ps1) | Insert a formatted Kind section into a Rules Compendium `.md` file before the `<!-- rule-compendium-end -->` marker |
| [Sync-RuleDocumentation](public/Sync-RuleDocumentation.ps1) | Insert cross-reference entries for a new Kind into all `.md` files that contain `<!-- rule-index -->` or `<!-- rule-table-start/end -->` markers |

## Typical Workflow (new-rule-kind skill)

```
Get-RuleKinds          ← read existing landscape
Get-GrammarForKind     ← read a reference Kind for structural comparison
Get-RulePrimitiveInputs← inspect inputs for individual primitives
Test-CompositionOrder  ← validate proposed composition BEFORE any write
New-RuleKindMigration  ← scaffold the Flyway SQL (supports -WhatIf)
Test-FlywayMigrationDryRun ← flyway validate safety gate
Add-RuleKindToCompendium   ← update Compendium .md (supports -WhatIf)
Sync-RuleDocumentation     ← propagate cross-references (supports -WhatIf)
```

## Database Tables Accessed

| Table | Access |
|---|---|
| `ATAPUtilities.PrimitiveLanguageKind` | SELECT (Get-RuleKinds, Get-GrammarForKind), INSERT (New-RuleKindMigration) |
| `ATAPUtilities.RulePrimitive` | SELECT (Get-GrammarForKind), INSERT (New-RuleKindMigration) |
| `ATAPUtilities.RulePrimitiveComposition` | SELECT (Get-GrammarForKind), INSERT (New-RuleKindMigration) |
| `ATAPUtilities.RulePrimitiveInput` | SELECT (Get-RulePrimitiveInputs), INSERT (New-RuleKindMigration) |

## Dependencies

- **PSFramework** — all logging (`Write-PSFMessage`)
- **Microsoft.Data.SqlClient** — direct ADO.NET SQL connections
- **dbatools** — connection string builder via `New-ConnectionStringBuilderFromDbaTools`
- **Flyway CLI** — required on PATH for `Test-FlywayMigrationDryRun`
- `Get-ParameterValueFromNeoConfigurationRoot` (dot-sourced from `ATAP.Utilities.Powershell`) — parameter resolution from `$global:settings`

## Authentication

All database functions support two parameter sets:

- **IntegratedSecurity** (default) — Windows Authentication
- **CredentialsFromVault** — Bitwarden vault key resolved via `Get-BitWardenSecret`

## Related Files

- `SolutionDocumentation/Rules Compendium.md` — master RRSBS reference
- `docs/grammar/*.grammar.ebnf` — canonical grammar authority for each Kind
- `.claude/skills/new-rule-kind/SKILL.md` — agent skill that orchestrates these functions
