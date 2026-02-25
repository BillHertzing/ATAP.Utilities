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

## Rendering Notes

- Properties in different rules share the same primitive values; reuse is encouraged.
- Package version is omitted in the sample because the source omits it (assumed centrally managed or floating).
- XML comments are modeled explicitly to preserve authoring guidance lines in the project files.
