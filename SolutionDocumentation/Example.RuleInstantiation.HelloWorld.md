# HelloWorld Rule/Instantiation Example

This document provides a concrete example of using the ATAPUtilities rule tables to model and materialize a small C# executable project.

The example defines:

1. Two C# rule rows and instantiations for `Program.cs` and `HelloWorld.cs`.
2. One MSBuild rule row and instantiation for `HelloWorld.csproj`.
3. One Path rule row and instantiation for the relative folder `HelloWorld`.

The materialization target is:

- `<RepoRoot>/Database/_generated/HelloWorld`

## Data Model Mapping

- `ATAPUtilities.Rule`: logical artifact template (what file/folder this represents).
- `ATAPUtilities.RuleInstantiation`: one concrete instance of a `Rule`.
- `ATAPUtilities.RuleInstantiationBinding`: key/value data used to render the concrete artifact.

Bindings used by this example:

- `RelativePath`: folder path relative to `_generated`.
- `FileName`: output filename for file artifacts.
- `FileContent`: complete file text for file artifacts.

## Example Seed Data (T-SQL)

```sql
USE ATAPUtilities;
GO

DECLARE @CSharpProgramRule UNIQUEIDENTIFIER = '11111111-1111-1111-1111-111111111101';
DECLARE @CSharpClassRule UNIQUEIDENTIFIER   = '11111111-1111-1111-1111-111111111102';
DECLARE @MSBuildRule UNIQUEIDENTIFIER      = '11111111-1111-1111-1111-111111111103';
DECLARE @PathRule UNIQUEIDENTIFIER         = '11111111-1111-1111-1111-111111111104';

DECLARE @CSharpProgramInst UNIQUEIDENTIFIER = '22222222-2222-2222-2222-222222222201';
DECLARE @CSharpClassInst UNIQUEIDENTIFIER   = '22222222-2222-2222-2222-222222222202';
DECLARE @MSBuildInst UNIQUEIDENTIFIER       = '22222222-2222-2222-2222-222222222203';
DECLARE @PathInst UNIQUEIDENTIFIER          = '22222222-2222-2222-2222-222222222204';

INSERT INTO ATAPUtilities.Philote (PhiloteId)
SELECT v.PhiloteId
FROM (VALUES
  (@CSharpProgramRule), (@CSharpClassRule), (@MSBuildRule), (@PathRule),
  (@CSharpProgramInst), (@CSharpClassInst), (@MSBuildInst), (@PathInst)
) AS v(PhiloteId)
WHERE NOT EXISTS (
  SELECT 1
  FROM ATAPUtilities.Philote p
  WHERE p.PhiloteId = v.PhiloteId
);

INSERT INTO ATAPUtilities.[Rule] (PhiloteId, PrimitiveLanguageKindId, Name, Purpose, SourceFileReference)
SELECT v.PhiloteId, v.PrimitiveLanguageKindId, v.Name, v.Purpose, v.SourceFileReference
FROM (VALUES
  (@CSharpProgramRule, CAST(1 AS TINYINT), N'Example.HelloWorld.Program.cs', N'Generate Program.cs compilation unit', N'HelloWorld/Program.cs'),
  (@CSharpClassRule,   CAST(1 AS TINYINT), N'Example.HelloWorld.HelloWorld.cs', N'Generate HelloWorld.cs compilation unit', N'HelloWorld/HelloWorld.cs'),
  (@MSBuildRule,       CAST(4 AS TINYINT), N'Example.HelloWorld.HelloWorld.csproj', N'Generate HelloWorld project file', N'HelloWorld/HelloWorld.csproj'),
  (@PathRule,          CAST(6 AS TINYINT), N'Example.HelloWorld.Folder', N'Generate HelloWorld relative folder', N'HelloWorld')
) AS v(PhiloteId, PrimitiveLanguageKindId, Name, Purpose, SourceFileReference)
WHERE NOT EXISTS (
  SELECT 1
  FROM ATAPUtilities.[Rule] r
  WHERE r.PhiloteId = v.PhiloteId
);

INSERT INTO ATAPUtilities.RuleInstantiation (PhiloteId, RulePhiloteId, Notes)
SELECT v.PhiloteId, v.RulePhiloteId, v.Notes
FROM (VALUES
  (@CSharpProgramInst, @CSharpProgramRule, N'Program.cs instantiation'),
  (@CSharpClassInst,   @CSharpClassRule,   N'HelloWorld.cs instantiation'),
  (@MSBuildInst,       @MSBuildRule,       N'HelloWorld.csproj instantiation'),
  (@PathInst,          @PathRule,          N'HelloWorld folder instantiation')
) AS v(PhiloteId, RulePhiloteId, Notes)
WHERE NOT EXISTS (
  SELECT 1
  FROM ATAPUtilities.RuleInstantiation ri
  WHERE ri.PhiloteId = v.PhiloteId
);

-- Insert per-instantiation bindings (RelativePath, FileName, FileContent)
-- See the Pester test for a full runnable seed script including exact file content values.
```

## Query + Materialization Flow

1. Query `ATAPUtilities.Rule` + `ATAPUtilities.RuleInstantiation` + `ATAPUtilities.RuleInstantiationBinding` for the four example rule names.
2. Pivot bindings into normalized columns: `RelativePath`, `FileName`, `FileContent`.
3. Return one `Directory` artifact row and three `File` artifact rows.
4. PowerShell/Pester consumes those rows and writes:

- `Database/_generated/HelloWorld/Program.cs`
- `Database/_generated/HelloWorld/HelloWorld.cs`
- `Database/_generated/HelloWorld/HelloWorld.csproj`

## Expected Generated Contents

`Program.cs`

```csharp
using HelloWorld;
Console.WriteLine(Greeter.GetMessage());
```

`HelloWorld.cs`

```csharp
namespace HelloWorld;

public static class Greeter
{
  public static string GetMessage() => "Hello, World!";
}
```

`HelloWorld.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>
```
