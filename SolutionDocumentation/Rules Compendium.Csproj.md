# Rules Compendium — C# Project Files (.csproj)

This file captures the rules for MSBuild-based C# project files used across ATAP.Utilities.

## Philote Identity Convention

Every Primitive, Rule, Rule Set, and Build Set carries a **Philote ID** (`IPhilote<GUID>`). Each GUID is stable after definition.

Format: `"a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d"`.

## Overview

Rules compose from Rule Primitives; Rule Sets aggregate Rules. A Rule here renders a complete `.csproj` file.

## Rule Primitives

Primitives map to MSBuild (XML) constructs. Inputs bind values; rendering emits XML text.

---

### `<csproj-file>` Rule Primitive

**Philote ID:** "f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d"

Description: Root project document with `Sdk` attribute and child groups.

```bnf
<csproj-file>            ::= <project-open> <new-line>? <project-body>? </Project>

<project-open>           ::= "<Project" <ws> "Sdk=\"" <sdk-name> "\"">"

<project-body>           ::= <project-element>
                           | <project-body> <project-element>

<project-element>        ::= <property-group>
                           | <item-group>
                           | <xml-comment>
                           | <new-line>
```

Inputs:

- `Sdk` (string).
- `Elements` (ordered list of `<project-element>` instances).

Output: Full `.csproj` XML.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/how-to-use-project-sdk
```

---

### `<property-group>` Rule Primitive

**Philote ID:** "5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c"

Description: Groups properties under `<PropertyGroup>`.

```bnf
<property-group>         ::= "<PropertyGroup>" <new-line>? <property-list>? "</PropertyGroup>"

<property-list>          ::= <property>
                           | <property-list> <property>
```

Inputs:

- `Properties` (ordered list of `<property>` instances).

Output: A property group block.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild-project-file-schema#propertygroup-element
```

---

### `<property>` Rule Primitive

**Philote ID:** "f5e6df38-0c63-4b3c-8a53-72d5f6ad2962"

Description: A single MSBuild property element.

```bnf
<property>               ::= "<" <identifier> ">" <property-value> "</" <identifier> ">"
```

Inputs:

- `Name` (string identifier).
- `Value` (string content).

Output: `<Name>Value</Name>` line.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild-properties
```

---

### `<item-group>` Rule Primitive

**Philote ID:** "b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6"

Description: Groups item declarations (references, analyzers, etc.).

```bnf
<item-group>             ::= "<ItemGroup>" <new-line>? <item-list>? "</ItemGroup>"

<item-list>              ::= <item>
                           | <item-list> <item>

<item>                   ::= <project-reference>
                           | <package-reference>
                           | <xml-comment>
                           | <new-line>
```

Inputs:

- `Items` (ordered list of `<item>` instances).

Output: An item group block.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild-project-file-schema#itemgroup-element
```

---

### `<project-reference>` Rule Primitive

**Philote ID:** "6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e"

Description: Reference to another project.

```bnf
<project-reference>      ::= "<ProjectReference" <ws> "Include=\"" <path> "\"" "/>"
```

Inputs:

- `Include` (path string, relative or absolute).

Output: Self-closing `ProjectReference` element.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/common-msbuild-project-items#projectreference
```

---

### `<package-reference>` Rule Primitive

**Philote ID:** "bc63c4a9-e2ab-4e6f-83b6-8f8a5f09341a"

Description: NuGet package reference.

```bnf
<package-reference>      ::= "<PackageReference" <ws> "Include=\"" <package-id> "\"" (<ws> "Version=\"" <version> "\"")? " />"
```

Inputs:

- `Include` (package ID string).
- `Version` (string, optional when restored from central management).

Output: Self-closing `PackageReference` element.

Attribution:

```text
1. https://learn.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files
```

---

### `<compile-remove>` Rule Primitive

**Philote ID:** "5c4b6d7a-3f5d-4a8d-90d6-0f3cf0f9b6aa"

Description: Removes files from the `Compile` item set.

```bnf
<compile-remove>          ::= "<Compile" <ws> "Remove=\"" <path-glob> "\"" <ws>? "/>"
```

Inputs:

- `Remove` (path glob string).

Output: Self-closing `Compile` item with `Remove` attribute.

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/common-msbuild-item-element#attributes
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

## Rule Definitions (Samples)

### Rule: ATAP.Utilities.StronglyTypedIds.Interfaces.csproj

**Philote ID:** "2f8b8c1b-3e25-44a0-9c6d-6b2f9f3f5e6c"

**Purpose:** Render the project file for the StronglyTypedIds interfaces library.

**Source:** [src/ATAP.Utilities.StronglyTypedIds.Interfaces/ATAP.Utilities.StronglyTypedIds.Interfaces.csproj](src/ATAP.Utilities.StronglyTypedIds.Interfaces/ATAP.Utilities.StronglyTypedIds.Interfaces.csproj#L1-L22)

**Primitive Composition (ordered)**

| #   | Primitive          | Philote ID                           | Bound Inputs                                                           |
| --- | ------------------ | ------------------------------------ | ---------------------------------------------------------------------- |
| 1   | `<csproj-file>`    | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3]                            |
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
| 1   | `<csproj-file>`       | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3]                                                                 |
| 2   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = [2a–2h] (same values as interfaces project)                                                    |
| 3   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [3a]                                                                                                |
| 3a  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\ATAP.Utilities.StronglyTypedIDs.Interfaces\ATAP.Utilities.StronglyTypedIDs.Interfaces.csproj" |

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/common-msbuild-project-items#projectreference
2. [src/ATAP.Utilities.StronglyTypedIds/ATAP.Utilities.StronglyTypedIds.csproj](src/ATAP.Utilities.StronglyTypedIds/ATAP.Utilities.StronglyTypedIds.csproj#L1-L26)
```

### Rule: ATAP.Utilities.Philote.Interfaces.csproj

**Philote ID:** "12df4c1d-7f30-4a3c-b0fd-83f6de6a2c38"

**Purpose:** Render the Philote interfaces project.

**Source:** [src/ATAP.Utilities.Philote.Interfaces/ATAP.Utilities.Philote.Interfaces.csproj](src/ATAP.Utilities.Philote.Interfaces/ATAP.Utilities.Philote.Interfaces.csproj#L1-L26)

**Primitive Composition (ordered)**

| #   | Primitive             | Philote ID                           | Bound Inputs                                                                                                |
| --- | --------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| 1   | `<csproj-file>`       | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3]                                                                 |
| 2   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = [2a–2h] (same values as above)                                                                 |
| 3   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [3a]                                                                                                |
| 3a  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\ATAP.Utilities.StronglyTypedIds.Interfaces\ATAP.Utilities.StronglyTypedIds.Interfaces.csproj" |

Attribution:

```text
1. https://learn.microsoft.com/en-us/visualstudio/msbuild/how-to-use-project-sdk
2. [src/ATAP.Utilities.Philote.Interfaces/ATAP.Utilities.Philote.Interfaces.csproj](src/ATAP.Utilities.Philote.Interfaces/ATAP.Utilities.Philote.Interfaces.csproj#L1-L26)
```

### Rule: ATAP.Utilities.Philote.csproj

**Philote ID:** "6c7dbe32-3c6a-4ea8-bc10-5a1b1d0584db"

**Purpose:** Render the Philote implementation project with package and project references.

**Source:** [src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/ATAP.Utilities.Philote.csproj](src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/ATAP.Utilities.Philote.csproj#L1-L34)

**Primitive Composition (ordered)**

| #   | Primitive             | Philote ID                           | Bound Inputs                                                                                                |
| --- | --------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| 1   | `<csproj-file>`       | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3,4]                                                               |
| 2   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = [2a–2h] (same values as above)                                                                 |
| 3   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [3a]                                                                                                |
| 3a  | `<package-reference>` | bc63c4a9-e2ab-4e6f-83b6-8f8a5f09341a | Include = "TimePeriodLibrary.NET"; Version = (omitted)                                                      |
| 4   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [4a,4b,4c]                                                                                          |
| 4a  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\ATAP.Utilities.Philote.Interfaces\ATAP.Utilities.Philote.Interfaces.csproj"                   |
| 4b  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\ATAP.Utilities.StronglyTypedIds.Interfaces\ATAP.Utilities.StronglyTypedIds.Interfaces.csproj" |
| 4c  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\ATAP.Utilities.StronglyTypedIds\ATAP.Utilities.StronglyTypedIds.csproj"                       |

Attribution:

```text
1. https://learn.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files
2. [src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/ATAP.Utilities.Philote.csproj](src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/ATAP.Utilities.Philote.csproj#L1-L34)
```

### Rule: ATAP.Utilities.StronglyTypedId.csproj (aggregator)

**Philote ID:** "1c8b8c57-0d64-4e4a-8e60-5f8a3f7f7d3a"

**Purpose:** Aggregate child StronglyTypedId projects without compiling their sources.

**Source:** [src/ATAP.Utilities.StronglyTypedId/ATAP.Utilities.StronglyTypedId.csproj](src/ATAP.Utilities.StronglyTypedId/ATAP.Utilities.StronglyTypedId.csproj#L1-L26)

**Primitive Composition (ordered)**

| #   | Primitive             | Philote ID                           | Bound Inputs                                                                                                                                                                         |
| --- | --------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `<csproj-file>`       | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3,4,5]                                                                                                                                      |
| 2   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = OutputType=Library, GeneratePackageOnBuild=true, IsPackable=true, MajorVersion=0, MinorVersion=1, PatchVersion=0, PackageLifeCycleStage=Development, PackageLabel=Alpha |
| 3   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = EnableDefaultItems=false                                                                                                                                                |
| 4   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [4a]                                                                                                                                                                         |
| 4a  | `<compile-remove>`    | 5c4b6d7a-3f5d-4a8d-90d6-0f3cf0f9b6aa | Remove = "\*_/_.cs"                                                                                                                                                                  |
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

### Rule: ATAP.Utilities.StronglyTypedId.Interfaces.csproj

**Philote ID:** "54bfa6f5-7be2-4a5b-94a4-3f4c2b5e6a1d"

**Purpose:** Interfaces project for StronglyTypedId.

**Source:** [src/ATAP.Utilities.StronglyTypedId/Interfaces/ATAP.Utilities.StronglyTypedId.Interfaces.csproj](src/ATAP.Utilities.StronglyTypedId/Interfaces/ATAP.Utilities.StronglyTypedId.Interfaces.csproj#L1-L25)

**Primitive Composition (ordered)**

| #   | Primitive          | Philote ID                           | Bound Inputs                                                                                                                                                                         |
| --- | ------------------ | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `<csproj-file>`    | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3,4]                                                                                                                                        |
| 2   | `<property-group>` | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = OutputType=Library, GeneratePackageOnBuild=true, IsPackable=true, MajorVersion=0, MinorVersion=1, PatchVersion=0, PackageLifeCycleStage=Development, PackageLabel=Alpha |
| 3   | `<item-group>`     | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = []                                                                                                                                                                           |
| 4   | `<item-group>`     | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = []                                                                                                                                                                           |

Attribution:

```text
1. Source file linked above
```

### Rule: ATAP.Utilities.StronglyTypedId.Models.csproj

**Philote ID:** "c2cbb8dd-2a7a-4c2e-9e31-3bc8d2db1f44"

**Purpose:** Models project for StronglyTypedId.

**Source:** [src/ATAP.Utilities.StronglyTypedId/Models/ATAP.Utilities.StronglyTypedId.Models.csproj](src/ATAP.Utilities.StronglyTypedId/Models/ATAP.Utilities.StronglyTypedId.Models.csproj#L1-L22)

**Primitive Composition (ordered)**

| #   | Primitive             | Philote ID                           | Bound Inputs                                                                                                                                                                         |
| --- | --------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `<csproj-file>`       | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3,4]                                                                                                                                        |
| 2   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = OutputType=Library, GeneratePackageOnBuild=true, IsPackable=true, MajorVersion=0, MinorVersion=1, PatchVersion=0, PackageLifeCycleStage=Development, PackageLabel=Alpha |
| 3   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = []                                                                                                                                                                           |
| 4   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [4a]                                                                                                                                                                         |
| 4a  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\Interfaces\\ATAP.Utilities.StronglyTypedId.Interfaces.csproj"                                                                                                         |

Attribution:

```text
1. Source file linked above
```

### Rule: ATAP.Utilities.StronglyTypedId.JsonConverter.Shim.SystemTextJson.csproj

**Philote ID:** "9f4b5a1c-2d71-4d8c-87d2-7d7ab6e9c2c1"

**Purpose:** System.Text.Json shim converters for StronglyTypedId.

**Source:** [src/ATAP.Utilities.StronglyTypedId/JsonConverter.Shim.SystemTextJson/ATAP.Utilities.StronglyTypedId.JsonConverter.Shim.SystemTextJson.csproj](src/ATAP.Utilities.StronglyTypedId/JsonConverter.Shim.SystemTextJson/ATAP.Utilities.StronglyTypedId.JsonConverter.Shim.SystemTextJson.csproj#L1-L25)

**Primitive Composition (ordered)**

| #   | Primitive             | Philote ID                           | Bound Inputs                                                                                                                                                                         |
| --- | --------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `<csproj-file>`       | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3,4,5]                                                                                                                                      |
| 2   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = OutputType=Library, GeneratePackageOnBuild=true, IsPackable=true, MajorVersion=0, MinorVersion=1, PatchVersion=0, PackageLifeCycleStage=Development, PackageLabel=Alpha |
| 3   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = []                                                                                                                                                                           |
| 4   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [4a,4b]                                                                                                                                                                      |
| 4a  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\Interfaces\\ATAP.Utilities.StronglyTypedId.Interfaces.csproj"                                                                                                         |
| 4b  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\Models\\ATAP.Utilities.StronglyTypedId.Models.csproj"                                                                                                                 |
| 5   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [5a]                                                                                                                                                                         |
| 5a  | `<package-reference>` | bc63c4a9-e2ab-4e6f-83b6-8f8a5f09341a | Include = "System.Text.Json"                                                                                                                                                         |

Attribution:

```text
1. Source file linked above
```

### Rule: ATAP.Utilities.Philote.csproj (aggregator)

**Philote ID:** "f5a4f28a-2f21-4d0c-9939-6a9d5e6b7c3f"

**Purpose:** Aggregate Philote child projects.

**Source:** [src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.csproj](src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.csproj#L1-L24)

**Primitive Composition (ordered)**

| #   | Primitive             | Philote ID                           | Bound Inputs                                                                                                                                                                         |
| --- | --------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `<csproj-file>`       | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3]                                                                                                                                          |
| 2   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = OutputType=Library, GeneratePackageOnBuild=true, IsPackable=true, MajorVersion=0, MinorVersion=1, PatchVersion=0, PackageLifeCycleStage=Development, PackageLabel=Alpha |
| 3   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [3a,3b,3c,3d]                                                                                                                                                                |
| 3a  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "DefaultConfiguration/ATAP.Utilities.Philote.DefaultConfiguration.csproj"                                                                                                  |
| 3b  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "Interfaces/ATAP.Utilities.Philote.Interfaces.csproj"                                                                                                                      |
| 3c  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "Models/ATAP.Utilities.Philote.Models.csproj"                                                                                                                              |
| 3d  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "JsonConverter.Shim.SystemTextJson/ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson.csproj"                                                                        |

Attribution:

```text
1. Source file linked above
```

### Rule: ATAP.Utilities.Philote.DefaultConfiguration.csproj

**Philote ID:** "7a3f1d5c-9c14-4df5-8a6b-3f1a4b2c7d9e"

**Purpose:** Default configuration project for Philote.

**Source:** [src/ATAP.Utilities.Philote/DefaultConfiguration/ATAP.Utilities.Philote.DefaultConfiguration.csproj](src/ATAP.Utilities.Philote/DefaultConfiguration/ATAP.Utilities.Philote.DefaultConfiguration.csproj#L1-L23)

**Primitive Composition (ordered)**

| #   | Primitive             | Philote ID                           | Bound Inputs                                                                                                                                                                         |
| --- | --------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `<csproj-file>`       | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3]                                                                                                                                          |
| 2   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = OutputType=Library, GeneratePackageOnBuild=true, IsPackable=true, MajorVersion=0, MinorVersion=1, PatchVersion=0, PackageLifeCycleStage=Development, PackageLabel=Alpha |
| 3   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [3a,3b,3c]                                                                                                                                                                   |
| 3a  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\..\\ATAP.Utilities.StronglyTypedId\\Interfaces\\ATAP.Utilities.StronglyTypedId.Interfaces.csproj"                                                                     |
| 3b  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\Interfaces\\ATAP.Utilities.Philote.Interfaces.csproj"                                                                                                                 |
| 3c  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\Models\\ATAP.Utilities.Philote.Models.csproj"                                                                                                                         |

Attribution:

```text
1. Source file linked above
```

### Rule: ATAP.Utilities.Philote.Models.csproj

**Philote ID:** "f6b8c8d2-9c91-4a1c-9f5e-2e7b5c2d6a1f"

**Purpose:** Models project for Philote.

**Source:** [src/ATAP.Utilities.Philote/Models/ATAP.Utilities.Philote.Models.csproj](src/ATAP.Utilities.Philote/Models/ATAP.Utilities.Philote.Models.csproj#L1-L26)

**Primitive Composition (ordered)**

| #   | Primitive             | Philote ID                           | Bound Inputs                                                                                                                                                                         |
| --- | --------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `<csproj-file>`       | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3,4]                                                                                                                                        |
| 2   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = OutputType=Library, GeneratePackageOnBuild=true, IsPackable=true, MajorVersion=0, MinorVersion=1, PatchVersion=0, PackageLifeCycleStage=Development, PackageLabel=Alpha |
| 3   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [3a]                                                                                                                                                                         |
| 3a  | `<package-reference>` | bc63c4a9-e2ab-4e6f-83b6-8f8a5f09341a | Include = "TimePeriodLibrary.NET"                                                                                                                                                    |
| 4   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [4a,4b,4c]                                                                                                                                                                   |
| 4a  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\Interfaces\\ATAP.Utilities.Philote.Interfaces.csproj"                                                                                                                 |
| 4b  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\..\\ATAP.Utilities.StronglyTypedId\\Interfaces\\ATAP.Utilities.StronglyTypedId.Interfaces.csproj"                                                                     |
| 4c  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\..\\ATAP.Utilities.StronglyTypedId\\Models\\ATAP.Utilities.StronglyTypedId.Models.csproj"                                                                             |

Attribution:

```text
1. Source file linked above
```

### Rule: ATAP.Utilities.Philote.Interfaces.csproj

**Philote ID:** "2a5d8b1c-7e6f-4c0b-b2d4-9b2c5e1d7f4a"

**Purpose:** Interfaces project for Philote.

**Source:** [src/ATAP.Utilities.Philote/Interfaces/ATAP.Utilities.Philote.Interfaces.csproj](src/ATAP.Utilities.Philote/Interfaces/ATAP.Utilities.Philote.Interfaces.csproj#L1-L26)

**Primitive Composition (ordered)**

| #   | Primitive             | Philote ID                           | Bound Inputs                                                                                                                                                                         |
| --- | --------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `<csproj-file>`       | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3,4]                                                                                                                                        |
| 2   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = OutputType=Library, GeneratePackageOnBuild=true, IsPackable=true, MajorVersion=0, MinorVersion=1, PatchVersion=0, PackageLifeCycleStage=Development, PackageLabel=Alpha |
| 3   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [3a]                                                                                                                                                                         |
| 3a  | `<package-reference>` | bc63c4a9-e2ab-4e6f-83b6-8f8a5f09341a | Include = "TimePeriodLibrary.NET"                                                                                                                                                    |
| 4   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [4a]                                                                                                                                                                         |
| 4a  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\..\\ATAP.Utilities.StronglyTypedId\\Interfaces\\ATAP.Utilities.StronglyTypedId.Interfaces.csproj"                                                                     |

Attribution:

```text
1. Source file linked above
```

### Rule: ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson.csproj

**Philote ID:** "4f6c9e5d-1b62-4a42-8a8c-7e4f3c6a9d1e"

**Purpose:** System.Text.Json shim converters for Philote.

**Source:** [src/ATAP.Utilities.Philote/JsonConverter.Shim.SystemTextJson/ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson.csproj](src/ATAP.Utilities.Philote/JsonConverter.Shim.SystemTextJson/ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson.csproj#L1-L28)

**Primitive Composition (ordered)**

| #   | Primitive             | Philote ID                           | Bound Inputs                                                                                                                                                                         |
| --- | --------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `<csproj-file>`       | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3,4,5]                                                                                                                                      |
| 2   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = OutputType=Library, GeneratePackageOnBuild=true, IsPackable=true, MajorVersion=0, MinorVersion=1, PatchVersion=0, PackageLifeCycleStage=Development, PackageLabel=Alpha |
| 3   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [3a]                                                                                                                                                                         |
| 3a  | `<package-reference>` | bc63c4a9-e2ab-4e6f-83b6-8f8a5f09341a | Include = "TimePeriodLibrary.NET"                                                                                                                                                    |
| 4   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [4a,4b,4c,4d]                                                                                                                                                                |
| 4a  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\Interfaces\\ATAP.Utilities.Philote.Interfaces.csproj"                                                                                                                 |
| 4b  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\..\\ATAP.Utilities.Serializer.Interfaces\\ATAP.Utilities.Serializer.Interfaces.csproj"                                                                                |
| 4c  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\..\\ATAP.Utilities.StronglyTypedId\\Interfaces\\ATAP.Utilities.StronglyTypedId.Interfaces.csproj"                                                                     |
| 4d  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\..\\ATAP.Utilities.StronglyTypedId\\Models\\ATAP.Utilities.StronglyTypedId.Models.csproj"                                                                             |
| 5   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [5a]                                                                                                                                                                         |
| 5a  | `<package-reference>` | bc63c4a9-e2ab-4e6f-83b6-8f8a5f09341a | Include = "System.Text.Json"                                                                                                                                                         |

Attribution:

```text
1. Source file linked above
```

### Rule: ATAP.Utilities.Philote.Converters.Interfaces.csproj

**Philote ID:** "b5c9d7f1-1c8f-4d1e-8bba-2f7b2e6d5a10"

**Purpose:** Converter interfaces for Philote serializers.

**Source:** [src/ATAP.Utilities.Philote/Converters.Interfaces.Save/ATAP.Utilities.Philote.Converters.Interfaces.csproj](src/ATAP.Utilities.Philote/Converters.Interfaces.Save/ATAP.Utilities.Philote.Converters.Interfaces.csproj#L1-L26)

**Primitive Composition (ordered)**

| #   | Primitive             | Philote ID                           | Bound Inputs                                                                                                                                                                     |
| --- | --------------------- | ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `<csproj-file>`       | f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d | Sdk = "Microsoft.NET.Sdk"; Elements = [2,3,4]                                                                                                                                    |
| 2   | `<property-group>`    | 5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c | Properties = OutputType=Library, GeneratePackageOnBuild=true, IsPackable=true, MajorVersion=1, MinorVersion=0, PatchVersion=0, PackageLifeCycleStage=Production, PackageLabel=NA |
| 3   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [3a]                                                                                                                                                                     |
| 3a  | `<package-reference>` | bc63c4a9-e2ab-4e6f-83b6-8f8a5f09341a | Include = "TimePeriodLibrary.NET"                                                                                                                                                |
| 4   | `<item-group>`        | b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6 | Items = [4a,4b,4c]                                                                                                                                                               |
| 4a  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\ATAP.Utilities.StronglyTypedId\\Interfaces\\ATAP.Utilities.StronglyTypedId.Interfaces.csproj"                                                                     |
| 4b  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\ATAP.Utilities.Philote\\Interfaces\\ATAP.Utilities.Philote.Interfaces.csproj"                                                                                     |
| 4c  | `<project-reference>` | 6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e | Include = "..\\ATAP.Utilities.Serializer.Interfaces\\ATAP.Utilities.Serializer.Interfaces.csproj"                                                                                |

Attribution:

```text
1. Source file linked above
```

## Rendering Notes

- Properties in different rules share the same primitive values; reuse is encouraged.
- Package version is omitted in the sample because the source omits it (assumed centrally managed or floating).
- XML comments are modeled explicitly to preserve authoring guidance lines in the project files.
