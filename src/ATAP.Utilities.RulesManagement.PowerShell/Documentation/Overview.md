# ATAP.Utilities.RulesManagement.PowerShell — Overview

Created 2026-07-07 (Sprint 0012 Task 12.46.f scaffold pass).

This module provides the PowerShell surface for the RRSBS (Rules, Rule Sets, and Build
Sets) system: reading rule-kind grammars from the four `ATAPUtilities` SQL tables
(`PrimitiveLanguageKind`, `RulePrimitive`, `RulePrimitiveInput`,
`RulePrimitiveComposition`), validating composition ordering against the canonical
`docs/grammar/<KindName>.grammar.ebnf` files, and supporting rule instantiation.
Key public functions include `Get-GrammarForKind` (typed `[GrammarModel]` from the DB)
and `Test-CompositionOrder` (mandatory before any migration that touches
`RulePrimitiveComposition.Position`).

Canonical documentation: `SolutionDocumentation\Rules Compendium.md` (START HERE for
the RRSBS & Rules Compendiums functional area) plus the per-language compendiums
(`Rules Compendium.{CSharp,SQL,PowerShell,MSBuild,...}.md`).
