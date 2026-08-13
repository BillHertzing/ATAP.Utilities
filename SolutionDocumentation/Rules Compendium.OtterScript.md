# Rules Compendium — OtterScript

<!-- METADATA
  Language: OtterScript
  Created: pre-existing; normalized 2026-08-02
  Kind Count: 1
  Primitive Count: 9
  Rule Count: 0
  Instantiation Count: 0
  Template version: 1.0
  Authority: GRAMMAR-01; V00.01.000070 retained seed corpus
-->

This normalized compendium describes the retained OtterScript primitive corpus.
It records source identity and grammar coverage only; it does not authorize a
migration, seed change, executor, package/feed, or live-system action.

## Philote Identity Convention

A Philote is a stable, table-specific GUID for a durable or versioned
first-class RRSBS row. It is not a permission, a mutable display name, or a
generic table/key reference. The retained `PrimitiveLanguageKind` row has
numeric Id `7` and no Philote column; this document does not invent one.

## Overview

OtterScript Rules render bounded BuildMaster plan fragments from Rule
Primitives. The retained source corpus consists of nine primitives and their
input metadata in `V00.01.000070__Add_OtterScript_Rule_Kind.sql`. It contains
no retained OtterScript Rule, Rule Set, Build Set, or Instantiation seed rows.

## Language / Tooling Version

The grammar is a bounded profile of OtterScript. It does not set a BuildMaster
version, executor policy, package/feed policy, credential policy, or deployment
policy. Those decisions are outside RDB-180B.

## Part I — Grammar Specification

<!-- rule-grammar-start -->

### Kind: OtterScript

**Philote ID:** Not present in the retained `PrimitiveLanguageKind` schema.

**Grammar file:** `SolutionDocumentation/grammers/OtterScript.grammar.ebnf`

**DB record:** `ATAPUtilities.PrimitiveLanguageKind` Id = `7`; retained name
`OtterScript`.

**Description:** Deterministic BuildMaster plan-fragment rendering from the
retained OtterScript Rule Primitives.

#### Grammar

<!-- EMBEDDED from SolutionDocumentation/grammers/OtterScript.grammar.ebnf -->
```ebnf
otter-artifact = otter-plan ;
otter-plan = { otter-statement } ;
otter-statement = set-variable | if-block | foreach-block | exec-step |
                  dotnet-pack-step | proget-nuget-push-step |
                  create-artifact-step | log-step | comment | new-line ;
```
<!-- END EMBEDDED -->

#### Composition Constraints

- Statement order is preserved from the owning `otter-plan` binding.
- Blocks preserve their nested statement order and require balanced braces.
- The profile covers the nine seeded primitives only; monitor, pipeline, and
  full-operation syntax remain outside this grammar until separately decided.
- The `proget-nuget-push-step` renders only a PowerShell executor handoff with
  a `SecretName` argument. It never renders an API key, `$Decrypt(...)`, or a
  direct authenticated package-push command.

#### Valid Expression Examples

```otterscript
set $PackageSlug = $RegexReplace($ProjectPath, `^.*\\([^\\]+)\.(csproj|sln)$`, `$1`);

if $Tier == Experimental {
  Exec pwsh (
    File: Invoke-CSharpPackageBuildMasterStage.ps1,
    SecretName: ProGet.BuildMaster.API.Key
  );
}
```

<!-- rule-grammar-end -->

## Part II — Rule Primitives

<!-- rule-primitives-start -->

| Rule Primitive | Philote ID | DB record | Grammar non-terminal | Description | Disposition |
| --- | --- | --- | --- | --- | --- |
| `<otter-plan>` | `99bdfd9a-f48a-4398-add4-003dc1877751` | `ATAPUtilities.RulePrimitive`; KindId `7` | `otter-plan` | Top-level ordered OtterScript plan containing statements and blocks. | preserve identity |
| `<otter-set-variable>` | `416f4f37-2f36-4a60-b90a-a41e4407bab3` | `ATAPUtilities.RulePrimitive`; KindId `7` | `set-variable` | Variable assignment using OtterScript `set` syntax. | preserve identity |
| `<otter-if-block>` | `db4c13a8-90d9-4413-b817-dcb38613de5c` | `ATAPUtilities.RulePrimitive`; KindId `7` | `if-block` | Conditional execution block for tier-specific pipeline stages. | preserve identity |
| `<otter-foreach-block>` | `d7f33ea3-fb8d-4394-b281-2696e13e815b` | `ATAPUtilities.RulePrimitive`; KindId `7` | `foreach-block` | Foreach loop over a collection expression. | preserve identity |
| `<otter-exec-step>` | `0fdc4fcc-7434-4160-baa6-db89e530044a` | `ATAPUtilities.RulePrimitive`; KindId `7` | `exec-step` | Generic `Exec` operation invoking an external command. | preserve identity |
| `<dotnet-pack-step>` | `5283f51b-1b3e-48b2-baed-d42e57979603` | `ATAPUtilities.RulePrimitive`; KindId `7` | `dotnet-pack-step` | `dotnet pack` `Exec` operation producing NuGet packages. | preserve identity |
| `<proget-nuget-push-step>` | `25c22691-48da-4f46-a4ea-ac0b5b5f50bc` | `ATAPUtilities.RulePrimitive`; KindId `7` | `proget-nuget-push-step` | Safe executor handoff for a ProGet package-push operation. | preserve identity; direct API-key rendering deferred |
| `<create-artifact-step>` | `77ecc33b-bf1b-434b-b972-6371dbc09f37` | `ATAPUtilities.RulePrimitive`; KindId `7` | `create-artifact-step` | BuildMaster `Create-Artifact` operation publishing generated files. | preserve identity |
| `<otter-log-step>` | `c12eeb76-53ad-45dd-8d05-8ab773c30a22` | `ATAPUtilities.RulePrimitive`; KindId `7` | `log-step` | BuildMaster diagnostic logging statement. | preserve identity |

<!-- rule-primitives-end -->

## Part III — Rule Repository

<!-- rule-repository-start -->

No retained OtterScript `Rule` seed rows are present. The source migration adds
only `PrimitiveLanguageKind`, `Philote`, `RulePrimitive`, and
`RulePrimitiveInput` rows. No Rule identity, source-path alias, or retirement
is inferred.

<!-- rule-repository-end -->

## Part IV — Instantiations and Rule Sets

<!-- rule-sets-start -->

No retained OtterScript Rule Set, Build Set, or Instantiation seed rows are
present. The nine primitive identities remain preserved without inventing
future composition identities.

The legacy `ProGetApiKey` input of `<proget-nuget-push-step>` is preserved as
source metadata, but its default `$Decrypt($ProGetApiKey)` is not a rendering
contract. Any conversion to a `SecretName`-only executor boundary requires a
later approved migration and renderer mapping.

<!-- rule-sets-end -->

## Sources and Boundaries

- `Database/Flyway/SQL/V00.01.000070__Add_OtterScript_Rule_Kind.sql`
- `SolutionDocumentation/BuildMaster-Pipeline-Topology.md`
- `SolutionDocumentation/PowerShellModule-Pipeline-NoProfile-Runbook.md`

RDB-180B normalizes documentation only. Executor contracts, security
classification, seed changes, database migrations, package/feed actions, and
live-system actions remain outside this work unit.

*Last updated: 2026-08-02 | Maintained by: RDB-180B OtterScript normalization*
