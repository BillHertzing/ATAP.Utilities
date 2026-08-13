# RDB-180 — Retained-Grammar Reconciliation

Status: **complete for the ten retained grammar kinds** (2026-08-03).

## Authority and boundary

RDB-180 is bounded by the final RRSBS plan's ten-kind list: CSharp,
PowerShell, SQL, MSBuild, Snippet, Path, OtterScript, AgentText, Markdown,
and ManimScene. Each has an EBNF grammar under
`SolutionDocumentation/grammers/`, a normalized rules compendium, and a
dedicated generated evidence directory under `_generated/RRSBS-V2/RDB-180*/`.

| Group | Kind | Grammar | Compendium | Evidence directory |
| --- | --- | --- | --- | --- |
| RDB-180A | CSharp | `CSharp.grammar.ebnf` | `Rules Compendium.CSharp.md` | `RDB-180A-CSharp` |
| RDB-180A | PowerShell | `PowerShell.grammar.ebnf` | `Rules Compendium.Powershell.md` | `RDB-180A-PowerShell` |
| RDB-180A | SQL | `SQL.grammar.ebnf` | `Rules Compendium.SQL.md` | `RDB-180A-SQL` |
| RDB-180A | MSBuild | `MSBuild.grammar.ebnf` | `Rules Compendium.MSBuild.md` | `RDB-180A-MSBuild` |
| RDB-180A | Snippet | `Snippet.grammar.ebnf` | `Rules Compendium.Snippet.md` | `RDB-180A-Snippet` |
| RDB-180B | Path | `Path.grammar.ebnf` | `Rules Compendium.Path.md` | `RDB-180B-Path` |
| RDB-180B | OtterScript | `OtterScript.grammar.ebnf` | `Rules Compendium.OtterScript.md` | `RDB-180B-OtterScript` |
| RDB-180B | AgentText | `AgentText.grammar.ebnf` | `Rules Compendium.AgentText.md` | `RDB-180B-AgentText` |
| RDB-180B | Markdown | `Markdown.grammar.ebnf` | `Rules Compendium.Markdown.md` | `RDB-180B-Markdown` |
| RDB-180C | ManimScene | `ManimScene.grammar.ebnf` | `Rules Compendium.Manim.md` | `RDB-180C-ManimScene` |

## Corrected boundary

The grouped sprint-board wording previously included ContentSummary and
PKIArtifact in RDB-180C. That would conflict with the final plan and with the
approved Wave 2 ownership:

- RDB-190 owns ContentSummary's first-class lifecycle/provenance reconciliation.
  Its future model is intentionally not a grammar deliverable in RDB-180.
- RDB-185 owns PKIArtifact's metadata-only kind design and explicitly authorizes
  neither grammar implementation nor seed, migration, key, certificate, or
  live-system behavior.

Accordingly, neither absent grammar is an RDB-180 defect. Any future grammar
for those design-owned kinds must follow their separate approval and model
gates. This reconciliation does not allocate Kind GUIDs, create seed data, or
authorize SQL or live-tier actions.

## Verification

The ten grammar filenames, ten compendium filenames, and ten generated
evidence directories were enumerated on 2026-08-03. Every listed kind has all
three artifacts; no other kind is claimed by this RDB-180 completion.
