# Rules Compendium — MSBuild

<!-- METADATA
  Language: MSBuild
  Created: pre-existing; normalized 2026-08-02
  Kind Count: 1
  Primitive Count: 8
  Rule Count: 14
  Instantiation Count: 14
  Template version: 1.0
  Authority: GRAMMAR-01; retained CSV corpus
-->

This normalized compendium describes the retained MSBuild corpus. It records
source identity and grammar coverage only; it does not authorize a migration,
seed change, executor, package/feed, or live-system action.

## Philote Identity Convention

A Philote is a stable, table-specific GUID for a durable or versioned
first-class RRSBS row. It is not a permission, mutable display name, or generic
table/key reference. The retained `PrimitiveLanguageKind` row has numeric Id
`4` and no Philote column; this document does not invent one.

## Overview

MSBuild Rules render XML project, props, and targets files from Rule Primitives.
The grammar authority is `SolutionDocumentation/grammers/MSBuild.grammar.ebnf`.
The retained CSV corpus contains eight primitives, fourteen Rules, fourteen
instantiations, and twenty-eight input bindings.

## Language / Tooling Version

The grammar is a bounded profile of MSBuild XML. It does not set an MSBuild SDK,
runtime, NuGet, or executor-version policy; those decisions are outside RDB-180A.

## Part I — Grammar Specification

<!-- rule-grammar-start -->

### Kind: MSBuild

**Philote ID:** Not present in the retained `PrimitiveLanguageKind` schema.

**Grammar file:** `SolutionDocumentation/grammers/MSBuild.grammar.ebnf`

**DB record:** `ATAPUtilities.PrimitiveLanguageKind` Id = `4`; retained name
`MSBuild`.

**Description:** Deterministic XML project-file rendering from the retained
MSBuild Rule Primitives.

#### Grammar

<!-- EMBEDDED from SolutionDocumentation/grammers/MSBuild.grammar.ebnf -->
```ebnf
msbuild-artifact = project-document ;
project-document = project-open, { project-element }, project-close ;
project-element = property-group | item-group | project-reference |
                  package-reference | compile-remove | xml-comment | xml-node |
                  new-line ;
```
<!-- END EMBEDDED -->

#### Composition Constraints

- A rendered artifact has exactly one `Project` root element.
- Child order is preserved; `PropertyGroup` and `ItemGroup` may contain their
  respective ordered child elements.
- The retained corpus supports the eight primitives in Part II. Other XML
  nodes are represented only as bounded `xml-node` text until a later gated
  primitive decision.
- XML escaping remains the renderer's responsibility; the grammar does not
  permit raw quote, ampersand, or comment-delimiter violations.

#### Valid Expression Examples

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="PSFramework" />
  </ItemGroup>
</Project>
```

<!-- rule-grammar-end -->

## Part II — Rule Primitives

<!-- rule-primitives-start -->

| Rule Primitive | Philote ID | DB record | Grammar non-terminal | Description | Disposition |
| --- | --- | --- | --- | --- | --- |
| `<csproj-file>` | `f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d` | `ATAPUtilities.RulePrimitive`; KindId `4` | `project-document` | Root project document with SDK attribute and child groups. | preserve identity |
| `<property-group>` | `5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c` | `ATAPUtilities.RulePrimitive`; KindId `4` | `property-group` | Groups properties under `PropertyGroup`. | preserve identity |
| `<property>` | `f5e6df38-0c63-4b3c-8a53-72d5f6ad2962` | `ATAPUtilities.RulePrimitive`; KindId `4` | `property` | A single MSBuild property element. | preserve identity |
| `<item-group>` | `b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6` | `ATAPUtilities.RulePrimitive`; KindId `4` | `item-group` | Groups item declarations. | preserve identity |
| `<project-reference>` | `6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e` | `ATAPUtilities.RulePrimitive`; KindId `4` | `project-reference` | Reference to another project. | preserve identity |
| `<package-reference>` | `bc63c4a9-e2ab-4e6f-83b6-8f8a5f09341a` | `ATAPUtilities.RulePrimitive`; KindId `4` | `package-reference` | NuGet package reference. | preserve identity |
| `<xml-comment>` | `0d7df833-9bdb-4f4b-a2c8-9e27863cfe26` | `ATAPUtilities.RulePrimitive`; KindId `4` | `xml-comment` | XML comment node. | preserve identity |
| `<compile-remove>` | `5c4b6d7a-3f5d-4a8d-90d6-0f3cf0f9b6aa` | `ATAPUtilities.RulePrimitive`; KindId `4` | `compile-remove` | Removes files from the Compile item set. | preserve identity |

<!-- rule-primitives-end -->

## Part III — Rule Repository

<!-- rule-repository-start -->

| Rule | Philote ID | Retained source reference | Disposition |
| --- | --- | --- | --- |
| ATAP.Utilities.StronglyTypedIds.Interfaces.csproj | `2f8b8c1b-3e25-44a0-9c6d-6b2f9f3f5e6c` | `src/ATAP.Utilities.StronglyTypedIds.Interfaces/ATAP.Utilities.StronglyTypedIds.Interfaces.csproj` | preserve identity; source is absent, no alias or retirement inferred |
| ATAP.Utilities.StronglyTypedIds.csproj | `8d6a0bf9-4ed6-4a4d-8e9d-7f1f0cfad3e3` | `src/ATAP.Utilities.StronglyTypedIds/ATAP.Utilities.StronglyTypedIds.csproj` | preserve identity; source is absent, no alias or retirement inferred |
| ATAP.Utilities.Philote.Interfaces.csproj | `12df4c1d-7f30-4a3c-b0fd-83f6de6a2c38` | `src/ATAP.Utilities.Philote.Interfaces/ATAP.Utilities.Philote.Interfaces.csproj` | preserve identity; alias to `src/ATAP.Utilities.Philote/Interfaces/ATAP.Utilities.Philote.Interfaces.csproj` |
| ATAP.Utilities.Philote.csproj | `6c7dbe32-3c6a-4ea8-bc10-5a1b1d0584db` | `src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/ATAP.Utilities.Philote.csproj` | preserve identity; alias to `src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.csproj` |
| ATAP.Utilities.StronglyTypedId.csproj (aggregator) | `1c8b8c57-0d64-4e4a-8e60-5f8a3f7f7d3a` | `src/ATAP.Utilities.StronglyTypedId/ATAP.Utilities.StronglyTypedId.csproj` | preserve identity |
| ATAP.Utilities.StronglyTypedId.Interfaces.csproj | `54bfa6f5-7be2-4a5b-94a4-3f4c2b5e6a1d` | `src/ATAP.Utilities.StronglyTypedId/Interfaces/ATAP.Utilities.StronglyTypedId.Interfaces.csproj` | preserve identity |
| ATAP.Utilities.StronglyTypedId.Models.csproj | `c2cbb8dd-2a7a-4c2e-9e31-3bc8d2db1f44` | `src/ATAP.Utilities.StronglyTypedId/Models/ATAP.Utilities.StronglyTypedId.Models.csproj` | preserve identity |
| ATAP.Utilities.StronglyTypedId.JsonConverter.Shim.SystemTextJson.csproj | `9f4b5a1c-2d71-4d8c-87d2-7d7ab6e9c2c1` | `src/ATAP.Utilities.StronglyTypedId/JsonConverter.Shim.SystemTextJson/ATAP.Utilities.StronglyTypedId.JsonConverter.Shim.SystemTextJson.csproj` | preserve identity |
| ATAP.Utilities.Philote.csproj (aggregator) | `f5a4f28a-2f21-4d0c-9939-6a9d5e6b7c3f` | `src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.csproj` | preserve identity |
| ATAP.Utilities.Philote.DefaultConfiguration.csproj | `7a3f1d5c-9c14-4df5-8a6b-3f1a4b2c7d9e` | `src/ATAP.Utilities.Philote/DefaultConfiguration/ATAP.Utilities.Philote.DefaultConfiguration.csproj` | preserve identity |
| ATAP.Utilities.Philote.Models.csproj | `f6b8c8d2-9c91-4a1c-9f5e-2e7b5c2d6a1f` | `src/ATAP.Utilities.Philote/Models/ATAP.Utilities.Philote.Models.csproj` | preserve identity |
| ATAP.Utilities.Philote.Interfaces.csproj (sub-folder) | `2a5d8b1c-7e6f-4c0b-b2d4-9b2c5e1d7f4a` | `src/ATAP.Utilities.Philote/Interfaces/ATAP.Utilities.Philote.Interfaces.csproj` | preserve identity |
| ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson.csproj | `4f6c9e5d-1b62-4a42-8a8c-7e4f3c6a9d1e` | `src/ATAP.Utilities.Philote/JsonConverter.Shim.SystemTextJson/ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson.csproj` | preserve identity |
| ATAP.Utilities.Philote.Converters.Interfaces.csproj | `b5c9d7f1-1c8f-4d1e-8bba-2f7b2e6d5a10` | `src/ATAP.Utilities.Philote/Converters.Interfaces.Save/ATAP.Utilities.Philote.Converters.Interfaces.csproj` | preserve identity |

<!-- rule-repository-end -->

## Part IV — Instantiations and Rule Sets

<!-- rule-sets-start -->

Each retained Rule has one retained instantiation. The identity pair is preserved
without asserting that the current file contents still reconstruct the legacy
artifact:

| Rule Philote ID | Instantiation Philote ID | Disposition |
| --- | --- | --- |
| `2f8b8c1b-3e25-44a0-9c6d-6b2f9f3f5e6c` | `9e75e55e-6214-4f2f-94c1-e2bd89722e5d` | preserve identity |
| `8d6a0bf9-4ed6-4a4d-8e9d-7f1f0cfad3e3` | `12ff5708-3c77-4f14-afd5-a5af865a9f6f` | preserve identity |
| `12df4c1d-7f30-4a3c-b0fd-83f6de6a2c38` | `177f5b16-b693-4a63-89ae-f732fad91265` | preserve identity |
| `6c7dbe32-3c6a-4ea8-bc10-5a1b1d0584db` | `d6f31996-1d7c-4350-a94b-bc525c87dace` | preserve identity |
| `1c8b8c57-0d64-4e4a-8e60-5f8a3f7f7d3a` | `95204ea0-ed40-45db-81f5-0feb1eb31736` | preserve identity |
| `54bfa6f5-7be2-4a5b-94a4-3f4c2b5e6a1d` | `12ea4297-d74f-44fd-b245-2cfbfe48d80d` | preserve identity |
| `c2cbb8dd-2a7a-4c2e-9e31-3bc8d2db1f44` | `d4b19694-38e0-40f3-8947-2e17b88a1f33` | preserve identity |
| `9f4b5a1c-2d71-4d8c-87d2-7d7ab6e9c2c1` | `69653f08-b533-4cbd-967f-68d1493a8017` | preserve identity |
| `f5a4f28a-2f21-4d0c-9939-6a9d5e6b7c3f` | `857f59b0-c734-4a28-975b-3c9799b323f5` | preserve identity |
| `7a3f1d5c-9c14-4df5-8a6b-3f1a4b2c7d9e` | `bb3ea83d-1f5a-4300-b8bc-9cbaaf97cb8d` | preserve identity |
| `f6b8c8d2-9c91-4a1c-9f5e-2e7b5c2d6a1f` | `54f34812-5b42-4638-932c-72d0fae1e432` | preserve identity |
| `2a5d8b1c-7e6f-4c0b-b2d4-9b2c5e1d7f4a` | `5edf1de7-ebd8-42f9-abe5-54598785fe7d` | preserve identity |
| `4f6c9e5d-1b62-4a42-8a8c-7e4f3c6a9d1e` | `b0e79a86-60a7-4947-b467-0cce93c01040` | preserve identity |
| `b5c9d7f1-1c8f-4d1e-8bba-2f7b2e6d5a10` | `d22dcd35-5699-4c89-82fb-d40d8d1e5064` | preserve identity |

No Rule Set or Build Set rows are present in the retained MSBuild CSV corpus.

The prior document-only identifiers are retired as non-seed documentation
identities because no retained MSBuild CSV row maps to them:
`1a8f3d2e-5c9b-4d7f-8e6c-2a9b7d3e5f1c`,
`2d8f3e1c-6b9a-4d5f-8e7c-1a3b5d7e9f2c`,
`3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c`,
`4b8f2e6d-9c3a-4d1f-7e5c-2a9b6d3e8f1c`,
`5a7d9e2f-3c8b-4d1e-6f9c-2a8d5b3e7f1c`,
`7c4e9f1a-3b8d-4d2e-8f5c-1a9e7b6c3d5f`,
`7c9e2f3d-1b8a-4d5e-6f8c-3d5a9b2e7f1c`,
`8d6f3c2e-1b5a-4d9f-7e8c-3a6b9d2e5f1c`,
`9c8f5d3a-2e7b-4d1f-6f8c-3a9d2b5e7f1c`,
`9e7c3f2d-1a8b-4d5e-6f9c-3d8a7b2e5f1c`, and
`a3d5f8e2-7b4c-4a9d-9f5e-6c8a3d2b1e7f`.

<!-- rule-sets-end -->

## Sources and Boundaries

- `Database/Flyway/Data/MSBuild_Philote_Primitives.csv`
- `Database/Flyway/Data/MSBuild_RulePrimitives.csv`
- `Database/Flyway/Data/MSBuild_Philote_Rules.csv`
- `Database/Flyway/Data/MSBuild_Rules.csv`
- `Database/Flyway/Data/MSBuild_Philote_Instantiations.csv`
- `Database/Flyway/Data/MSBuild_Instantiations.csv`
- `Database/Flyway/Data/MSBuild_InstantiationBindings.csv`

RDB-180A normalizes documentation only. Executor contracts, security
classification, seed changes, database migrations, package/feed actions, and
live-system actions remain outside this work unit.

*Last updated: 2026-08-02 | Maintained by: RDB-180A MSBuild normalization*
