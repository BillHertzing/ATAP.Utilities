# Rules Compendium — MSBuild Project Files (.csproj, .props, .targets)

This file captures the rules for MSBuild-based project files used across ATAP.Utilities, including C# project files (.csproj), property files (.props), and target files (.targets).

## Philote Identity Convention

Every Primitive, Rule, Rule Set, and Build Set carries a **Philote ID** (`IPhilote<GUID>`). Each GUID is stable after definition.

Format: `"a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d"`.

## Overview

Rules compose from Rule Primitives; Rule Sets aggregate Rules. A Rule here renders a complete MSBuild file (.csproj, .props, or .targets).

## Rule Primitives

Primitives map to MSBuild (XML) constructs. Inputs bind values; rendering emits XML text.

---

### `<msbuild-file>` Rule Primitive

**Philote ID:** "f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d"

Description: Root project document with optional `Sdk` attribute and child groups. Used for .csproj, .props, and .targets files.

```bnf
<msbuild-file>           ::= <project-open> <new-line>? <project-body>? </Project>

<project-open>           ::= "<Project" (<ws> "Sdk=\"" <sdk-name> "\"")? ">"

<project-body>           ::= <project-element>
                           | <project-body> <project-element>

<project-element>        ::= <property-group>
                           | <item-group>
                           | <import>
                           | <target>
                           | <xml-comment>
                           | <new-line>
```

Inputs:

- `Sdk` (string, optional - only for .csproj files).
- `Elements` (ordered list of `<project-element>` instances).

Output: Full MSBuild XML file.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/how-to-use-project-sdk
2. https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild-project-file-schema
```

---

### `<property-group>` Rule Primitive

**Philote ID:** "5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c"

Description: Groups properties under `<PropertyGroup>`, with optional conditional attributes.

```bnf
<property-group>         ::= "<PropertyGroup" <condition-attribute>? ">" <new-line>? <property-list>? "</PropertyGroup>"

<condition-attribute>    ::= <ws> "Condition=\"" <condition-expression> "\""

<property-list>          ::= <property>
                           | <property-list> <property>
```

Inputs:

- `Condition` (string expression, optional).
- `Properties` (ordered list of `<property>` instances).

Output: A property group block.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild-project-file-schema#propertygroup-element
2. https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild-conditions
```

---

### `<property>` Rule Primitive

**Philote ID:** "f5e6df38-0c63-4b3c-8a53-72d5f6ad2962"

Description: A single MSBuild property element, with optional conditional attribute.

```bnf
<property>               ::= "<" <identifier> <condition-attribute>? ">" <property-value> "</" <identifier> ">"

<property-value>         ::= <text>
                           | <cdata-section>
```

Inputs:

- `Name` (string identifier).
- `Value` (string content, may include MSBuild expressions `$()` or `@()`).
- `Condition` (string expression, optional).

Output: `<Name>Value</Name>` line or `<Name Condition="...">Value</Name>`.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild-properties
2. https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild-conditions
```

---

### `<item-group>` Rule Primitive

**Philote ID:** "b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6"

Description: Groups item declarations (references, analyzers, etc.), with optional conditional attributes.

```bnf
<item-group>             ::= "<ItemGroup" <condition-attribute>? ">" <new-line>? <item-list>? "</ItemGroup>"

<item-list>              ::= <item>
                           | <item-list> <item>

<item>                   ::= <project-reference>
                           | <package-reference>
                           | <package-reference-update>
                           | <compile-item>
                           | <embedded-resource>
                           | <resx-item>
                           | <xml-comment>
                           | <new-line>
```

Inputs:

- `Condition` (string expression, optional).
- `Items` (ordered list of `<item>` instances).

Output: An item group block.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild-project-file-schema#itemgroup-element
```

---

### `<import>` Rule Primitive

**Philote ID:** "a3d5f8e2-7b4c-4a9d-9f5e-6c8a3d2b1e7f"

Description: Import another MSBuild file (.props or .targets).

```bnf
<import>                 ::= "<Import" <ws> "Project=\"" <path-expression> "\"" <condition-attribute>? <ws>? "/>"

<path-expression>        ::= <text-with-msbuild-properties>
```

Inputs:

- `Project` (path expression string, typically contains MSBuild property references).
- `Condition` (string expression, optional).

Output: Self-closing `Import` element.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/import-element-msbuild
```

---

### `<target>` Rule Primitive

**Philote ID:** "7c4e9f1a-3b8d-4d2e-8f5c-1a9e7b6c3d5f"

Description: Defines a build target with tasks and dependencies.

```bnf
<target>                 ::= "<Target" <target-attributes> ">" <new-line>? <target-body>? "</Target>"

<target-attributes>      ::= <name-attribute> <target-attribute>*

<name-attribute>         ::= <ws> "Name=\"" <identifier> "\""

<target-attribute>       ::= <before-targets>
                           | <after-targets>
                           | <depends-on>
                           | <condition-attribute>

<before-targets>         ::= <ws> "BeforeTargets=\"" <target-list> "\""
<after-targets>          ::= <ws> "AfterTargets=\"" <target-list> "\""
<depends-on>             ::= <ws> "DependsOnTargets=\"" <target-list> "\""

<target-body>            ::= <task-or-item>*

<task-or-item>           ::= <item-group>
                           | <property-group>
                           | <msbuild-task>
                           | <message-task>
                           | <copy-task>
                           | <xml-comment>
```

Inputs:

- `Name` (target name identifier).
- `BeforeTargets` (semicolon-separated target names, optional).
- `AfterTargets` (semicolon-separated target names, optional).
- `DependsOnTargets` (semicolon-separated target names, optional).
- `Condition` (string expression, optional).
- `Body` (list of tasks and item/property groups).

Output: Complete `Target` element with attributes and children.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/target-element-msbuild
2. https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild-targets
```

---

### `<msbuild-task>` Rule Primitive

**Philote ID:** "4b8f2e6d-9c3a-4d1f-7e5c-2a9b6d3e8f1c"

Description: MSBuild task invocation to build other projects.

```bnf
<msbuild-task>           ::= "<MSBuild" <task-attributes> "/>"

<task-attributes>        ::= <projects-attr> <targets-attr>? <properties-attr>?

<projects-attr>          ::= <ws> "Projects=\"" <project-expression> "\""
<targets-attr>           ::= <ws> "Targets=\"" <target-list> "\""
<properties-attr>        ::= <ws> "Properties=\"" <property-assignments> "\""
```

Inputs:

- `Projects` (MSBuild expression for project files).
- `Targets` (semicolon-separated target names, optional).
- `Properties` (semicolon-separated property assignments, optional).

Output: Self-closing `MSBuild` task element.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild-task
```

---

### `<message-task>` Rule Primitive

**Philote ID:** "9e7c3f2d-1a8b-4d5e-6f9c-3d8a7b2e5f1c"

Description: Message task for build logging.

```bnf
<message-task>           ::= "<Message" <message-attributes> "/>"

<message-attributes>     ::= <text-attr> <condition-attribute>? <importance-attr>?

<text-attr>              ::= <ws> "Text=\"" <message-text> "\""
<importance-attr>        ::= <ws> "Importance=\"" <importance-level> "\""
<importance-level>       ::= "high" | "normal" | "low"
```

Inputs:

- `Text` (message content, may include MSBuild expressions).
- `Condition` (string expression, optional).
- `Importance` (high|normal|low, optional).

Output: Self-closing `Message` task element.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/message-task
```

---

### `<copy-task>` Rule Primitive

**Philote ID:** "2d8f3e1c-6b9a-4d5f-8e7c-1a3b5d7e9f2c"

Description: Copy task for file operations.

```bnf
<copy-task>              ::= "<Copy" <copy-attributes> "/>"

<copy-attributes>        ::= <source-files-attr> <destination-attr>

<source-files-attr>      ::= <ws> "SourceFiles=\"" <item-expression> "\""
<destination-attr>       ::= <ws> ("DestinationFolder" | "DestinationFiles") "=\"" <path-expression> "\""
```

Inputs:

- `SourceFiles` (MSBuild item expression).
- `DestinationFolder` or `DestinationFiles` (path expression).

Output: Self-closing `Copy` task element.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/copy-task
```

---

### `<project-reference>` Rule Primitive

**Philote ID:** "6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e"

Description: Reference to another project.

```bnf
<project-reference>      ::= "<ProjectReference" <ws> "Include=\"" <path> "\"" <reference-children>? "/>"
                           | "<ProjectReference" <ws> "Include=\"" <path> "\">" <new-line> <reference-metadata>* "</ProjectReference>"

<reference-children>     ::= <ws>?

<reference-metadata>     ::= <private-assets>
                           | <include-assets>
```

Inputs:

- `Include` (path string, relative or absolute).
- `Metadata` (optional child elements like PrivateAssets, IncludeAssets).

Output: Self-closing or container `ProjectReference` element.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/common-msbuild-project-items#projectreference
```

---

### `<package-reference>` Rule Primitive

**Philote ID:** "bc63c4a9-e2ab-4e6f-83b6-8f8a5f09341a"

Description: NuGet package reference.

```bnf
<package-reference>      ::= "<PackageReference" <ws> "Include=\"" <package-id> "\"" (<ws> "Version=\"" <version> "\"")? <package-children>? "/>"
                           | "<PackageReference" <ws> "Include=\"" <package-id> "\">" <new-line> <package-metadata>* "</PackageReference>"

<package-metadata>       ::= <private-assets>
                           | <include-assets>
```

Inputs:

- `Include` (package ID string).
- `Version` (string, optional when restored from central management).
- `Metadata` (optional child elements).

Output: Self-closing or container `PackageReference` element.

Attribution:

```text
1. https://learn.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files
```

---

### `<package-reference-update>` Rule Primitive

**Philote ID:** "3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c"

Description: Central package version management using Update attribute.

```bnf
<package-reference-update> ::= "<PackageReference" <ws> "Update=\"" <package-id> "\"" <ws> "Version=\"" <version> "\"" <ws>? "/>"
```

Inputs:

- `Update` (package ID string - defines version for all projects).
- `Version` (version string).

Output: Self-closing `PackageReference` element with Update attribute.

Attribution:

```text
1. https://learn.microsoft.com/en-us/nuget/consume-packages/central-package-management
2. https://www.strathweb.com/2018/07/solution-wide-nuget-package-version-handling-with-msbuild-15/
```

---

### `<compile-item>` Rule Primitive

**Philote ID:** "8d6f3c2e-1b5a-4d9f-7e8c-3a6b9d2e5f1c"

Description: Compile item specification, supports Include and Remove.

```bnf
<compile-item>           ::= <compile-include> | <compile-remove>

<compile-include>        ::= "<Compile" <ws> "Include=\"" <path-glob> "\"" <compile-children>? "/>"

<compile-remove>         ::= "<Compile" <ws> "Remove=\"" <path-glob> "\"" <ws>? "/>"

<compile-children>       ::= ">" <new-line> <compile-metadata>* "</Compile>"

<compile-metadata>       ::= <auto-gen> | <design-time> | <dependent-upon>
```

Inputs:

- `Action` (Include or Remove).
- `PathGlob` (file path or glob pattern).
- `Metadata` (optional: AutoGen, DesignTime, DependentUpon).

Output: Self-closing or container `Compile` element.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/common-msbuild-item-element#attributes
```

---

### `<embedded-resource>` Rule Primitive

**Philote ID:** "5a7d9e2f-3c8b-4d1e-6f9c-2a8d5b3e7f1c"

Description: Embedded resource item specification.

```bnf
<embedded-resource>      ::= "<EmbeddedResource" <ws> "Include=\"" <path-glob> "\"" <ws>? "/>"
```

Inputs:

- `Include` (file path or glob pattern).

Output: Self-closing `EmbeddedResource` element.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/common-msbuild-project-items#embeddedresource
```

---

### `<resx-item>` Rule Primitive

**Philote ID:** "7c9e2f3d-1b8a-4d5e-6f8c-3d5a9b2e7f1c"

Description: Resource file (.resx) item specification.

```bnf
<resx-item>              ::= "<Resx" <ws> "Include=\"" <path-glob> "\"" <ws>? "/>"
```

Inputs:

- `Include` (file path or glob pattern).

Output: Self-closing `Resx` element.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/common-msbuild-project-items
```

---

### `<xml-comment>` Rule Primitive

**Philote ID:** "0d7df833-9bdb-4f4b-a2c8-9e27863cfe26"

Description: XML comment node.

```bnf
<xml-comment>            ::= "<!--" <comment-text> "-->"
```

Inputs:

- `CommentText` (string).

Output: An XML comment line.

Attribution:

```text
1. https://www.w3.org/TR/xml/#sec-comments
```

---

## Rule Definitions (Instantiations from ATAP.Utilities)

### Rule: Directory.Build.props

**Philote ID:** "1a8f3d2e-5c9b-4d7f-8e6c-2a9b7d3e5f1c"

**Purpose:** Solution-wide property definitions and package version management.

**Source:** [Directory.Build.props](../Directory.Build.props)

**Primitive Composition (ordered)**

This rule defines a complex MSBuild .props file with multiple property groups and central package management. Key sections:

#### Section 1: Version File Configuration

| #   | Primitive          | Philote ID                           | Bound Inputs                                                                       |
| --- | ------------------ | ------------------------------------ | ---------------------------------------------------------------------------------- |
| 1   | `<msbuild-file>`   | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = (none); Elements = [2-23]                                                    |
| 2   | `<property-group>` | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = [GenerateAssemblyInfo, VersionFile, UpdatePackageVersionLockFilePath] |

#### Section 2: Build Configuration

| #   | Primitive          | Philote ID                           | Bound Inputs                                                                    |
| --- | ------------------ | ------------------------------------ | ------------------------------------------------------------------------------- |
| 3   | `<property-group>` | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = [Configurations, TargetFramework, RuntimeIdentifiers, LangVersion] |

Property values:

- `Configurations` = "Debug;Release;ReleaseWithTrace;"
- `TargetFramework` = "net9.0"
- `RuntimeIdentifiers` = "win-x64;linux-x64"
- `LangVersion` = "latest"

#### Section 3: Nullable Reference Types

| #   | Primitive          | Philote ID                           | Bound Inputs                     |
| --- | ------------------ | ------------------------------------ | -------------------------------- |
| 4   | `<property-group>` | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = [Nullable="enable"] |

#### Section 4: Solution Structure

| #   | Primitive          | Philote ID                           | Bound Inputs                                                                                                                  |
| --- | ------------------ | ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| 5   | `<property-group>` | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = [SolutionDir, SolutionBuildToolsBaseDir, MSBuildCommunityTasksPath, ATAPUtilitiesBuildTooling paths and configs] |

Key properties:

- `SolutionDir` = "$(MSBuildThisFileDirectory)"
- `ATAPBuildToolingConfiguration` = "Debug"
- `ATAPBuildToolingDebugVerbosity` = "Trace"

#### Section 5: NuGet Package Metadata

| #   | Primitive          | Philote ID                           | Bound Inputs                                                             |
| --- | ------------------ | ------------------------------------ | ------------------------------------------------------------------------ |
| 6   | `<property-group>` | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = [Company, Copyright, Authors, Product, RepositoryUrl, etc.] |

#### Section 6: Compiler Configuration

| #   | Primitive          | Philote ID                           | Bound Inputs                                                                                                                               |
| --- | ------------------ | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| 7   | `<property-group>` | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = [AllowedOutputExtensionsInPackageBuildOutputFolder, EmbedUntrackedSources, AutoGenerateBindingRedirects, maxcpucount, NoWarn] |

Key suppressions:

- `NoWarn` = "$(NoWarn);8600;8601;8602;8603;8604;8605;8618;8625;8629"

#### Section 7: Configuration-Specific Compilation Symbols

| #   | Primitive          | Philote ID                           | Bound Inputs                                                                                              |
| --- | ------------------ | ------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| 8   | `<property-group>` | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Condition = "'$(Configuration)\|$(Platform)'=='Release\|AnyCPU'"; Properties = [DefineConstants]          |
| 9   | `<property-group>` | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Condition = "'$(Configuration)\|$(Platform)'=='ReleaseWithTrace\|AnyCPU'"; Properties = [DefineConstants] |
| 10  | `<property-group>` | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Condition = "'$(Configuration)\|$(Platform)'=='Debug\|AnyCPU'"; Properties = [DefineConstants]            |

#### Section 8: Framework-Specific Compilation Symbols

Multiple conditional property groups for NETCORE, NETDESKTOP, NETSTANDARD, and specific versions (net47, net471, net472, net48, netcoreapp2.0-3.1, etc.).

#### Section 9: Central Package Version Management

| #     | Primitive                    | Philote ID                           | Package Identity                                | Version |
| ----- | ---------------------------- | ------------------------------------ | ----------------------------------------------- | ------- |
| 15    | `<item-group>`               | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [15a-15zz] (100+ package version specs) |         |
| 15a   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | System.Text.RegularExpressions                  | 5.0.0   |
| 15b   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | System.Private.URI                              | 4.3.4   |
| 15c   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | System.Net.HTTP                                 | 4.8.1   |
| 15d   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | Stateless                                       | 5.1.2   |
| 15e   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | YC.QuickGraph                                   | 3.7.4   |
| 15f   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | FSharp.Core                                     | 4.3.4   |
| 15g   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | System.Reactive                                 | 5.0.0   |
| 15h   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | System.Speech                                   | 5.0.0   |
| 15i   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | ServiceStack                                    | 5.12.0  |
| 15j   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | ServiceStack.Text                               | 5.12.0  |
| 15k   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | ServiceStack.OrmLite                            | 5.12.0  |
| 15l   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | TimePeriodLibrary.NET                           | 2.1.5   |
| 15m   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | Microsoft.Extensions.Configuration              | 9.0.0   |
| 15n   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | Microsoft.Extensions.Hosting                    | 9.0.0   |
| 15o   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | Microsoft.Extensions.Logging                    | 9.0.0   |
| 15p   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | Microsoft.Extensions.DependencyInjection        | 9.0.0   |
| 15q   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | Polly                                           | 8.5.0   |
| 15r   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | System.IO.Abstractions                          | 21.1.3  |
| 15s   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | RabbitMQ.Client                                 | 7.0.0   |
| 15t   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | Microsoft.Build.Framework                       | 17.12.6 |
| 15u   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | Microsoft.SourceLink.GitHub                     | 8.0.0   |
| 15v   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | Serilog                                         | 4.1.0   |
| 15w   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | Serilog.Settings.Configuration                  | 8.0.4   |
| 15x   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | xunit                                           | 2.4.1   |
| 15y   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | FluentAssertions                                | 6.2.0   |
| 15z   | `<package-reference-update>` | 3c7f9e2a-5d8b-4a1e-9f6c-2e8a3d5b7f1c | Moq                                             | 4.16.1  |
| (etc) | ...                          | ...                                  | ... (80+ more package updates)                  | ...     |

#### Section 10: Framework-Specific Package Versions

| #   | Primitive      | Philote ID                           | Bound Inputs                                                                                                 |
| --- | -------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| 16  | `<item-group>` | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Condition = "$(TargetFramework) matches net472/net48/standard/core/net5+"; Items = [System.Text.Json v5.0.0] |
| 17  | `<item-group>` | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Condition = "standard                                                                                        | core                                                    | net[56789]"; Items = [System.Collections.Immutable v5.0.0, Newtonsoft.Json v12.0.3] |
| 18  | `<item-group>` | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Condition = "^net4"; Items = [System.Collections.Immutable v1.7.1, Newtonsoft.Json v12.0.3]                  |
| 19  | `<item-group>` | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Condition = "^(core                                                                                          | net[56789])"; Items = [McMaster.NETCore.Plugins v1.4.0] |

#### Section 11: Build Demonstration Target

| #   | Primitive  | Philote ID                           | Bound Inputs                                                                                                                            |
| --- | ---------- | ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| 20  | `<target>` | 7c4e9f1a-3b8d-4d2e-8f5c-1a9e7b6c3d5f | Name = "HighlightDifferencesBetweenMSBuild"; BeforeTargets = "Never"; Body = [Message tasks showing MSBuildRuntimeType and SolutionDir] |

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/customize-your-build
2. https://www.strathweb.com/2018/07/solution-wide-nuget-package-version-handling-with-msbuild-15/
3. [Directory.Build.props](../Directory.Build.props)
```

---

### Rule: Directory.Build.targets

**Philote ID:** "9c8f5d3a-2e7b-4d1f-6f8c-3a9d2b5e7f1c"

**Purpose:** Solution-wide target definitions, build tasks, and multi-framework publishing.

**Source:** [Directory.Build.targets](../Directory.Build.targets)

**Primitive Composition (ordered)**

#### Section 1: Import Statements

| #   | Primitive        | Philote ID                           | Bound Inputs                                                                             |
| --- | ---------------- | ------------------------------------ | ---------------------------------------------------------------------------------------- |
| 1   | `<msbuild-file>` | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = (none); Elements = [2-12]                                                          |
| 2   | `<import>`       | a3d5f8e2-7b4c-4a9d-9f5e-6c8a3d2b1e7f | Project = "$(MSBuildCommunityTasksPath)\\MSBuildTasks.Targets"                           |
| 3   | `<import>`       | a3d5f8e2-7b4c-4a9d-9f5e-6c8a3d2b1e7f | Project = "$(ATAPUtilitiesBuildToolingTargetsPath)\\ATAP.Utilities.BuildTooling.targets" |

#### Section 2: Resource File Handling

| #   | Primitive             | Philote ID                           | Bound Inputs                                                                  |
| --- | --------------------- | ------------------------------------ | ----------------------------------------------------------------------------- |
| 4   | `<xml-comment>`       | 0d7df833-9bdb-4f4b-a2c8-9e27863cfe26 | Comment about automatically generating Designer files and embedding resources |
| 5   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [5a, 5b]                                                              |
| 5a  | `<resx-item>`         | 7c9e2f3d-1b8a-4d5e-6f8c-3d5a9b2e7f1c | Include = "\*_\\_.resx"                                                       |
| 5b  | `<embedded-resource>` | 5a7d9e2f-3c8b-4d1e-6f9c-2a8d5b3e7f1c | Include = "\*_\\_.resource"                                                   |

#### Section 3: Plugin Directory Configuration

| #   | Primitive          | Philote ID                           | Bound Inputs                                  |
| --- | ------------------ | ------------------------------------ | --------------------------------------------- |
| 6   | `<xml-comment>`    | 0d7df833-9bdb-4f4b-a2c8-9e27863cfe26 | Comment about Plugin subdirectory definition  |
| 7   | `<property-group>` | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = [PluginsRelativeDir, PluginsDir] |

Property values:

- `PluginsRelativeDir` = "Plugins\\" (if undefined)
- `PluginsDir` = "$(OutputPath)$(PluginsRelativeDir)" (if undefined)

#### Section 4: JSON Settings File Copying

| #   | Primitive          | Philote ID                           | Bound Inputs                                                                         |
| --- | ------------------ | ------------------------------------ | ------------------------------------------------------------------------------------ |
| 8   | `<property-group>` | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = [PrepareForRunDependsOn appends CopyJSONSettingsFilesToOutputDirectory] |
| 9   | `<item-group>`     | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [JsonSettingsFiles with regex condition]                                     |
| 10  | `<target>`         | 7c4e9f1a-3b8d-4d2e-8f5c-1a9e7b6c3d5f | Name = "CopyJSONSettingsFilesToOutputDirectory"; Body = [Copy task]                  |
| 10a | `<copy-task>`      | 2d8f3e1c-6b9a-4d5f-8e7c-1a3b5d7e9f2c | SourceFiles = "@(JsonSettingsFiles)"; DestinationFolder = "$(OutDir)"                |

#### Section 5: Multi-Framework Publishing

| #   | Primitive       | Philote ID                           | Bound Inputs                                                                                                                                                                   |
| --- | --------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 11  | `<xml-comment>` | 0d7df833-9bdb-4f4b-a2c8-9e27863cfe26 | Comment about multi-framework and multiple RID publishing pattern                                                                                                              |
| 12  | `<target>`      | 7c4e9f1a-3b8d-4d2e-8f5c-1a9e7b6c3d5f | Name = "PublishProjectForAllRIDsIfTargetFrameworkSet"; Condition = "TargetFramework set, RuntimeIdentifiers set, RuntimeIdentifier not set"; Body = [ItemGroup + MSBuild task] |
| 13  | `<target>`      | 7c4e9f1a-3b8d-4d2e-8f5c-1a9e7b6c3d5f | Name = "PublishProjectForAllFrameworksIfFrameworkUnset"; Condition = "TargetFramework not set"; Body = [ItemGroup + MSBuild task]                                              |
| 14  | `<target>`      | 7c4e9f1a-3b8d-4d2e-8f5c-1a9e7b6c3d5f | Name = "PublishAll"; DependsOnTargets = "PublishProjectIfFrameworkSet;PublishProjectForAllRIDsIfTargetFrameworkSet;PublishProjectForAllFrameworksIfFrameworkUnset"             |
| 15  | `<target>`      | 7c4e9f1a-3b8d-4d2e-8f5c-1a9e7b6c3d5f | Name = "PublishProjectIfFrameworkSet"; DependsOnTargets = "Publish"; Condition = "TargetFramework set"                                                                         |

#### Section 6: Microsoft Source Link Package

| #   | Primitive             | Philote ID                           | Bound Inputs                                                                                                                       |
| --- | --------------------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| 16  | `<xml-comment>`       | 0d7df833-9bdb-4f4b-a2c8-9e27863cfe26 | Comment about Microsoft Source Link for every project                                                                              |
| 17  | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [17a]                                                                                                                      |
| 17a | `<package-reference>` | bc63c4a9-e2ab-4e6f-83b6-8f8a5f09341a | Include = "Microsoft.SourceLink.GitHub"; Metadata = [PrivateAssets=all, IncludeAssets=runtime;build;native;contentfiles;analyzers] |

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/customize-your-build
2. https://stackoverflow.com/questions/43947599/how-to-publish-for-all-target-frameworks
3. https://gist.github.com/dasMulli/b14026437468ce4b56ef93e010f24a36
4. https://github.com/dotnet/sdk/issues/9363
5. [Directory.Build.targets](../Directory.Build.targets)
```

---

### Rule: ATAP.Utilities.StronglyTypedIds.Interfaces.csproj

**Philote ID:** "2f8b8c1b-3e25-44a0-9c6d-6b2f9f3f5e6c"

**Purpose:** Render the project file for the StronglyTypedIds interfaces library.

**Source:** [src/ATAP.Utilities.StronglyTypedIds.Interfaces/ATAP.Utilities.StronglyTypedIds.Interfaces.csproj](src/ATAP.Utilities.StronglyTypedIds.Interfaces/ATAP.Utilities.StronglyTypedIds.Interfaces.csproj#L1-L22)

**Primitive Composition (ordered)**

| #   | Primitive          | Philote ID                           | Bound Inputs                                                           |
| --- | ------------------ | ------------------------------------ | ---------------------------------------------------------------------- |
| 1   | `<msbuild-file>`   | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3]                            |
| 2   | `<property-group>` | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = [2a–2h]                                                   |
| 2a  | `<property>`       | f5e6df38-0c63-4b3c-8a53-72d5f6ad2962 | Name=OutputType; Value=Library                                         |
| 2b  | `<property>`       | f5e6df38-0c63-4b3c-8a53-72d5f6ad2962 | Name=GeneratePackageOnBuild; Value=true                                |
| 2c  | `<property>`       | f5e6df38-0c63-4b3c-8a53-72d5f6ad2962 | Name=IsPackable; Value=true                                            |
| 2d  | `<xml-comment>`    | 0d7df833-9bdb-4f4b-a2c8-9e27863cfe26 | Comment about assembly/package info                                    |
| 2e  | `<property>`       | f5e6df38-0c63-4b3c-8a53-72d5f6ad2962 | Name=MajorVersion; Value=0                                             |
| 2f  | `<property>`       | f5e6df38-0c63-4b3c-8a53-72d5f6ad2962 | Name=MinorVersion; Value=1                                             |
| 2g  | `<property>`       | f5e6df38-0c63-4b3c-8a53-72d5f6ad2962 | Name=PatchVersion; Value=0                                             |
| 2h  | `<property>`       | f5e6df38-0c63-4b3c-8a53-72d5f6ad2962 | Name=PackageLifeCycleStage; Value=Development; plus PackageLabel=Alpha |
| 3   | `<item-group>`     | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [] (none)                                                      |

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/how-to-use-project-sdk
2. https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild-project-file-schema
3. [src/ATAP.Utilities.StronglyTypedIds.Interfaces/ATAP.Utilities.StronglyTypedIds.Interfaces.csproj](src/ATAP.Utilities.StronglyTypedIds.Interfaces/ATAP.Utilities.StronglyTypedIds.Interfaces.csproj#L1-L22)
```

### Rule: ATAP.Utilities.StronglyTypedIds.csproj

**Philote ID:** "8d6a0bf9-4ed6-4a4d-8e9d-7f1f0cfad3e3"

**Purpose:** Render the StronglyTypedIds implementation project.

**Source:** [src/ATAP.Utilities.StronglyTypedIds/ATAP.Utilities.StronglyTypedIds.csproj](src/ATAP.Utilities.StronglyTypedIds/ATAP.Utilities.StronglyTypedIds.csproj#L1-L26)

**Primitive Composition (ordered)**

| #   | Primitive             | Philote ID                           | Bound Inputs                                                                                                |
| --- | --------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| 1   | `<msbuild-file>`      | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3]                                                                 |
| 2   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = [2a–2h] (same values as interfaces project)                                                    |
| 3   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [3a]                                                                                                |
| 3a  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\ATAP.Utilities.StronglyTypedIDs.Interfaces\ATAP.Utilities.StronglyTypedIDs.Interfaces.csproj" |

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/common-msbuild-project-items#projectreference
2. [src/ATAP.Utilities.StronglyTypedIds/ATAP.Utilities.StronglyTypedIds.csproj](src/ATAP.Utilities.StronglyTypedIds/ATAP.Utilities.StronglyTypedIds.csproj#L1-L26)
```

_(Note: Additional .csproj rules from the original compendium continue below with same structure...)_

### Rule: ATAP.Utilities.StronglyTypedId.csproj (aggregator)

**Philote ID:** "1c8b8c57-0d64-4e4a-8e60-5f8a3f7f7d3a"

**Purpose:** Aggregate child StronglyTypedId projects without compiling their sources.

**Source:** [src/ATAP.Utilities.StronglyTypedId/ATAP.Utilities.StronglyTypedId.csproj](src/ATAP.Utilities.StronglyTypedId/ATAP.Utilities.StronglyTypedId.csproj#L1-L26)

**Primitive Composition (ordered)**

| #   | Primitive             | Philote ID                           | Bound Inputs                                                                                                                                                                         |
| --- | --------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `<msbuild-file>`      | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3,4,5]                                                                                                                                      |
| 2   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = OutputType=Library, GeneratePackageOnBuild=true, IsPackable=true, MajorVersion=0, MinorVersion=1, PatchVersion=0, PackageLifeCycleStage=Development, PackageLabel=Alpha |
| 3   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = EnableDefaultItems=false                                                                                                                                                |
| 4   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [4a]                                                                                                                                                                         |
| 4a  | `<compile-item>`      | 8d6f3c2e-1b5a-4d9f-7e8c-3a6b9d2e5f1c | Action=Remove; PathGlob = "\*_/_.cs"                                                                                                                                                 |
| 5   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [5a,5b,5c]                                                                                                                                                                   |
| 5a  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "Interfaces/ATAP.Utilities.StronglyTypedId.Interfaces.csproj"                                                                                                              |
| 5b  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "Models/ATAP.Utilities.StronglyTypedId.Models.csproj"                                                                                                                      |
| 5c  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "JsonConverter.Shim.SystemTextJson/ATAP.Utilities.StronglyTypedId.JsonConverter.Shim.SystemTextJson.csproj"                                                                |

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/how-to-use-project-sdk
2. https://learn.microsoft.com/en-us/visualstudio/msbuild/common-msbuild-item-element#attributes
3. Source file linked above
```

## MSBuild Expression Patterns

Common MSBuild expression patterns used throughout the files:

### Property References

- `$(PropertyName)` - References a property value
- `$(MSBuildThisFileDirectory)` - Directory containing current file
- `$(MSBuildRuntimeType)` - Core or Full framework runtime

### Conditional Expressions

- `'$(Property)' == 'Value'` - Equality comparison
- `'$(Property)' == '' Or '$(Property)' == '*Undefined*'` - Undefined check
- `$([System.Text.RegularExpressions.Regex]::IsMatch($(TargetFramework), 'pattern'))` - Regex matching

### Item References

- `@(ItemName)` - References all items in a collection
- `@(ItemName -> '%(Identity)')` - Item transformation

### String Functions

- `$([System.String]::Copy('text').Replace('old', 'new'))` - String manipulation

## Rendering Notes

- Properties in different rules share the same primitive values; reuse is encouraged.
- Package version is omitted in many samples because centrally managed via Directory.Build.props.
- XML comments are modeled explicitly to preserve authoring guidance lines in the project files.
- Conditional PropertyGroups and ItemGroups enable framework-specific configurations.
- The `Update` attribute on PackageReference enables central package version management across the solution.
