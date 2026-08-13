# Rules Compendium — PowerShell

<!-- METADATA
  Language:        PowerShell
  Created:         2026-08-02
  Kind Count:      1
  Primitive Count: 2
  Template version: 1.0
  Source skill:    .claude/skills/new-rule-kind/SKILL.md
-->

This is the normalized compendium for the retained PowerShell RuleKind. It
documents the stable legacy corpus without authorizing a migration, seed change,
executor, package, or live-system action.

---

## Philote Identity Convention

A Philote is a stable, table-specific GUID for a durable or versioned
first-class RRSBS row. It is not a permission, mutable display name, or generic
table/key reference. The current legacy `PrimitiveLanguageKind` row has numeric
Id `2` and no Philote column; this document does not invent one.

---

## Overview

PowerShell Rules render PowerShell source text from Rule Primitives. The current
seed corpus contains two primitives, eight Rules, and eight instantiations. The
grammar authority is `SolutionDocumentation/grammers/PowerShell.grammar.ebnf`.

---

## Language / Tooling Version

The grammar is a bounded profile of the PowerShell language specification and
does not set a runtime-version policy. Version selection and executor policy are
outside RDB-180A.

---

## Part I — Grammar Specification

<!-- rule-grammar-start -->

### Kind: PowerShell

**Philote ID:** Not present in the retained `PrimitiveLanguageKind` schema.

**Grammar file:** `SolutionDocumentation/grammers/PowerShell.grammar.ebnf`

**DB record:** `ATAPUtilities.PrimitiveLanguageKind` Id = `2`; retained legacy
name `Powershell` aliases the normalized display name `PowerShell`.

**Description:** PowerShell script-language primitives and Rules.

#### Grammar

<!-- EMBEDDED from SolutionDocumentation/grammers/PowerShell.grammar.ebnf -->
```ebnf
<powershell-artifact> ::= <function-definition> | <script-block>
<function-definition> ::= "function" <ws> <command-name> <ws-opt> "{" <script-block> "}"
<script-block> ::= <param-block-opt> <named-block-list-opt> <statement-list-opt>
<param-block-opt> ::= "" | <param-block> <statement-terminator-opt>
<param-block> ::= "param" <ws-opt> "(" <parameter-list-opt> ")"
<parameter-list-opt> ::= "" | <script-parameter> { "," <script-parameter> }
<script-parameter> ::= <attribute-list-opt> <variable> <default-value-opt>
<attribute-list-opt> ::= "" | { <attribute> }
<attribute> ::= "[" <attribute-name> <attribute-arguments-opt> "]"
<attribute-arguments-opt> ::= "" | "(" <expression-list-opt> ")"
<default-value-opt> ::= "" | "=" <expression>
<named-block-list-opt> ::= "" | <named-block> { <named-block> }
<named-block> ::= <named-block-name> <ws-opt> "{" <statement-list-opt> "}"
<named-block-name> ::= "dynamicparam" | "begin" | "process" | "end"
<statement-list-opt> ::= "" | <statement> { <statement-terminator> <statement> }
<statement-terminator-opt> ::= "" | <statement-terminator>
<statement-terminator> ::= ";" | <newline>
<statement> ::= <pipeline> | <control-statement> | <try-statement> | <function-definition>
<command> ::= <command-name> { <ws> <command-element> }
<command-element> ::= <command-parameter> | <expression> | <script-block-literal>
<command-parameter> ::= "-" <parameter-name> <parameter-value-opt>
<pipeline> ::= <command> { "|" <command> }
<parameter-value-opt> ::= "" | ":" <expression> | <ws> <expression>
<script-block-literal> ::= "{" <statement-list-opt> "}"
<control-statement> ::= "if" <ws-opt> "(" <expression> ")" <ws-opt> <script-block-literal>
                      | "foreach" <ws-opt> "(" <variable> "in" <expression> ")" <ws-opt> <script-block-literal>
                      | "return" <return-value-opt> | "throw" <return-value-opt>
<return-value-opt> ::= "" | <ws> <expression>
<try-statement> ::= "try" <ws-opt> <script-block-literal> <catch-list> <finally-opt>
<catch-list> ::= "catch" <ws-opt> <script-block-literal> { "catch" <ws-opt> <script-block-literal> }
<finally-opt> ::= "" | "finally" <ws-opt> <script-block-literal>
<expression-list-opt> ::= "" | <expression> { "," <expression> }
<expression> ::= <literal> | <variable> | <subexpression> | <array-literal> | <hashtable-literal> | <command> | "(" <expression> ")"
<subexpression> ::= "$" "(" <statement-list-opt> ")"
<array-literal> ::= "@" "(" <expression-list-opt> ")"
<hashtable-literal> ::= "@" "{" <hashtable-entry-list-opt> "}"
<hashtable-entry-list-opt> ::= "" | <hashtable-entry> { <statement-terminator> <hashtable-entry> }
<hashtable-entry> ::= <expression> "=" <expression>
<variable> ::= "$" <variable-name> | "$" "{" <variable-name> "}"
<literal> ::= <string-literal> | <number-literal> | "$true" | "$false" | "$null"
<string-literal> ::= <single-quoted-string> | <double-quoted-string>
<command-name> ::= <identifier> "-" <identifier>
<parameter-name> ::= <identifier>
<attribute-name> ::= <identifier> { "." <identifier> }
<variable-name> ::= <identifier>
<identifier> ::= <identifier-start> { <identifier-part> }
<identifier-start> ::= <letter> | "_"
<identifier-part> ::= <letter> | <digit> | "_"
<number-literal> ::= <digit> { <digit> } | "0x" <hex-digit> { <hex-digit> }
<single-quoted-string> ::= "'" { <single-quoted-character> } "'"
<double-quoted-string> ::= '"' { <double-quoted-character> } '"'
<ws-opt> ::= "" | <ws>
<ws> ::= (" " | "\t") { " " | "\t" }
```
<!-- END EMBEDDED -->

#### Composition Constraints

- A composed cmdlet has an optional `param` block followed by zero or more named blocks.
- A named block is one of `dynamicparam`, `begin`, `process`, or `end`.
- A command name is a verb-noun identifier; command parameters start with `-`.
- This profile defers full lexical, expression, and statement coverage to the PowerShell language specification.

#### Valid Expression Examples

```powershell
function Get-Example {
  [CmdletBinding()]
  param([string] $Name)
  begin { $prefix = 'Hello' }
  process { "$prefix, $Name" }
  end { }
}
```

```powershell
Get-ChildItem -Path 'C:\temp' -Recurse | Where-Object { $_.Length -gt 0 }
```

<!-- rule-grammar-end -->

---

## Part II — Rule Primitives

<!-- rule-primitives-start -->

### `<complete-powershell-cmdlet>` Rule Primitive

**Philote ID:** `"e1a2b3c4-d5e6-4f78-9012-a3b4c5d6e7f8"`

**DB record:** `ATAPUtilities.RulePrimitive`; KindId = `2`.

**Description:** Holds one complete PowerShell cmdlet as a text block.

```bnf
<complete-powershell-cmdlet> ::= <function-definition>
```

**Inputs:** A complete function definition represented as PowerShell source text.

**Output:** The exact supplied function text.

---

### `<composed-powershell-cmdlet>` Rule Primitive

**Philote ID:** `"f2b3c4d5-e6f7-4089-a123-b4c5d6e7f8a9"`

**DB record:** `ATAPUtilities.RulePrimitive`; KindId = `2`.

**Description:** Composes a cmdlet from parameter and named-block sections.

```bnf
<composed-powershell-cmdlet> ::= <function-definition>
```

**Inputs:** Command name, optional parameter block, and ordered named blocks.

**Output:** One PowerShell function definition.

<!-- rule-primitives-end -->

---

## Part III — Rule Repository

<!-- rule-repository-start -->

| Rule | Philote ID | Retained source reference | Disposition |
| --- | --- | --- | --- |
| Build-ImageFromPlantUML | `a1b2c3d4-e5f6-4a78-9012-b3c4d5e6f7a8` | `src/ATAP.Utilities.BuildTooling.PowerShell/public/Build-ImageFromPlantUML.ps1` | preserve identity |
| Test-PowerShellSyntax | `b2c3d4e5-f6a7-4b89-a123-c4d5e6f7a8b9` | `src/ATAP.Utilities.BuildTooling.PowerShell/public/check-syntax.ps1` | preserve identity; filename drift requires future alias/relocation decision |
| New-MCPServerJunction | `c3d4e5f6-a7b8-4c90-b234-d5e6f7a8b9c0` | `src/ATAP.Utilities.BuildTooling.PowerShell/public/Create-MCPJunction.ps1` | preserve identity; filename drift requires future alias/relocation decision |
| Get-RepositoryRoot | `d4e5f6a7-b8c9-4d01-c345-e6f7a8b9c0d1` | `src/ATAP.Utilities.BuildTooling.PowerShell/public/Get-RepositoryRoot.ps1` | preserve identity |
| Remove-ObjAndBinSubDirectories | `e5f6a7b8-c9d0-4e12-d456-f7a8b9c0d1e2` | `src/ATAP.Utilities.BuildTooling.PowerShell/public/Remove-ObjAndBinSubDirectories.ps1` | preserve identity |
| Sync-RulesToCSV | `f6a7b8c9-d0e1-4f23-e567-a8b9c0d1e2f3` | `src/ATAP.Utilities.BuildTooling.PowerShell/public/Sync-RulesToCSV.ps1` | preserve identity |
| Read-SourceAndCreateRules | `a7b8c9d0-e1f2-4034-f678-b9c0d1e2f3a4` | `src/ATAP.Utilities.BuildTooling.PowerShell/public/Read-SourceAndCreateRules.ps1` | preserve identity |
| Write-ArrayIndented | `fefa78dd-2291-44b1-96b7-14a0bb857a5c` | `src/ATAP.Utilities.BuildTooling.PowerShell/public/Write-ArrayIndented.ps1` | preserve identity |

No Rule composition rows are present in the retained CSV corpus. This compendium
does not infer compositions.

<!-- rule-repository-end -->

---

## Part IV — Rule Sets

<!-- rule-sets-start -->

The legacy document assigned Philote-like identifiers to documentation-only
logging, error-handling, GELF/SEQ, input-validation, and debugging sections.
They have no matching retained seed row in the inspected PowerShell CSV corpus.
Their stable-identity disposition is `retire as non-seed documentation identity`:
`9369e02d-4218-42dc-a487-4a176f9eac46`,
`3cc57c81-2fa6-408b-af37-1098ce68d51c`,
`e5e1529a-8a4d-4304-addb-0ca1225d6e67`,
`b57a4b16-293e-4938-ba7e-b809aff30066`, and
`b70ddc13-9453-4b76-9689-24460a3fc41f`.

No Rule Set or Build Set rows are present in the retained PowerShell CSV corpus.

<!-- rule-sets-end -->

---

## Sources and Boundaries

- [PowerShell language specification, Chapter 15](https://learn.microsoft.com/powershell/scripting/lang-spec/chapter-15)
- `Database/Flyway/Data/Powershell_RulePrimitives.csv`
- `Database/Flyway/Data/Powershell_Rules.csv`
- `Database/Flyway/Data/Powershell_Philote_Instantiations.csv`

RDB-180A normalizes documentation only. Executor contracts, security
classification, seed changes, and database migrations remain outside this work unit.

*Last updated: 2026-08-02 | Maintained by: RDB-180A PowerShell normalization*
