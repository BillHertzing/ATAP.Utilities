# Rules Compendium - OtterScript

This file documents OtterScript Rule Primitives used to compose BuildMaster
deployment plans from the ATAPUtilities rule database.

## Philote Identity Convention

Every Primitive, Rule, Rule Set, and Build Set carries an `IPhilote<GUID>`.
Each GUID is stable after definition and is used as the database key.

## Overview

OtterScript rules render BuildMaster plan fragments. The first primitive set is
focused on the `CSharpPackage-PerProject` pipeline: variable assignment,
conditional tier blocks, foreach blocks, generic Exec calls, dotnet pack,
ProGet package push, artifact publication, and diagnostic logging.

## Part I - Grammar Specification

### Kind: OtterScript

**DB record:** `ATAPUtilities.PrimitiveLanguageKind` Id = 7

**Grammar file:** `docs/grammar/OtterScript.grammar.ebnf`

**Description:** BuildMaster OtterScript primitives and rules for deployment
plan composition.

```ebnf
<otter-plan>              ::= <otter-statement>+
<otter-statement>         ::= <otter-set-variable>
                            | <otter-if-block>
                            | <otter-foreach-block>
                            | <otter-exec-step>
                            | <dotnet-pack-step>
                            | <proget-nuget-push-step>
                            | <create-artifact-step>
                            | <otter-log-step>
```

## Part II - Rule Primitives

| Philote ID | Primitive | Purpose |
|---|---|---|
| `99bdfd9a-f48a-4398-add4-003dc1877751` | `<otter-plan>` | Top-level ordered statement list. |
| `416f4f37-2f36-4a60-b90a-a41e4407bab3` | `<otter-set-variable>` | OtterScript `set` assignment. |
| `db4c13a8-90d9-4413-b817-dcb38613de5c` | `<otter-if-block>` | Conditional tier-specific stage block. |
| `d7f33ea3-fb8d-4394-b281-2696e13e815b` | `<otter-foreach-block>` | Loop over a collection expression. |
| `0fdc4fcc-7434-4160-baa6-db89e530044a` | `<otter-exec-step>` | Generic external command step. |
| `5283f51b-1b3e-48b2-baed-d42e57979603` | `<dotnet-pack-step>` | `dotnet pack` step for NuGet package creation. |
| `25c22691-48da-4f46-a4ea-ac0b5b5f50bc` | `<proget-nuget-push-step>` | `dotnet nuget push` step targeting ProGet. |
| `77ecc33b-bf1b-434b-b972-6371dbc09f37` | `<create-artifact-step>` | BuildMaster artifact publication step. |
| `c12eeb76-53ad-45dd-8d05-8ab773c30a22` | `<otter-log-step>` | BuildMaster logging statement. |

### Inputs

The Flyway migration `V00.01.000070__Add_OtterScript_Rule_Kind.sql` seeds the
input metadata for each primitive. The inputs cover:

- variable name and expression binding for assignments
- condition expression and ordered body for `if` blocks
- item variable, collection expression, and ordered body for `foreach` blocks
- executable name, arguments, working directory, and success exit code for Exec
- project path, configuration, output path, and working directory for pack
- package glob, ProGet base URL, feed name, API-key expression, and duplicate handling for push
- artifact name, source folder, and include pattern for artifact publishing
- log level and message for diagnostic statements

## Valid Expression Examples

```otter
set $PackageSlug = $RegexReplace($ProjectPath, `^.*\\([^\\]+)\.(csproj|sln)$`, `$1`);
```

```otter
if $Tier == Development
{
    Exec dotnet (
        Arguments: "pack $ProjectPath --configuration $Configuration --no-build --output _generated\nuget\$Tier\$PackageSlug",
        WorkingDirectory: $SourcePath,
        SuccessExitCode: 0
    );
    # Delegate publishing to the source-controlled C# stage runner. The plan
    # passes ProGet.BuildMaster.API.Key as ProGetApiKeySecretName; the
    # authenticated BuildTooling leaf resolves it immediately before push.
}
```

Never construct a direct authenticated package-push command in OtterScript.
The durable `CSharpPackage-5Stage.otter` plan invokes
`Invoke-CSharpPackageBuildMasterStage.ps1`, which owns the SecretName-only
handoff.

<!-- rule-compendium-end -->
