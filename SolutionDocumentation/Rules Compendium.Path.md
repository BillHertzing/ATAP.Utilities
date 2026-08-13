# Rules Compendium — Path

<!-- METADATA
  Language: Path
  Created: pre-existing; normalized 2026-08-02
  Kind Count: 1
  Primitive Count: 13
  Template version: 1.0
  Source skill: .claude/skills/new-rule-kind/SKILL.md
-->

This file contains an overview of the PATH-specific Rules used within the ATAP.Utilities databases and the Ace Commander application built from these rules.

## Philote Identity Convention

Every Primitive, Rule, Rule Set, and Build Set defined in this document carries a **Philote ID**. A Philote is a .NET generic type `IPhilote<T>` where `T` is either `GUID` or `int`. All identifiers in this document use the `GUID` variant. The GUID is allocated once when the element is defined and never changes; it is the stable key back into the Ace Commander Instantiations database.

Format: `IPhilote<GUID>` — rendered in this document as a quoted GUID string, e.g. `"a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d"`.

## Overview

This file documents PATH Rules and Rule Sets that define the Microsoft Windows filesystem path syntax.

Rules are created from Rule Primitives.

Rule Sets are created from Rules and include a directed graph that controls how execution flows from one Rule to another.

In order to define a feature or module in the ATAP.Utilities libraries or the Ace Commander application, a Rule Set is tagged with a feature identifier, which means that to implement the feature the Ace Commander Module will include that Rule Set in its Build Set.

## The purpose of Rules, Rule Sets, and Build Sets

Here is a simplifying acronym to shorten the long name "Rules, Rule Sets and Build Sets". We will refer to all of those compositely as "RRSBS".

Everything in the ATAP.Utilities libraries and the Ace Commander application, and all bolt-on modules for Ace Commander, are built from RRSBS. There are RRSBS that define the Ace Commander GUI. There are RRSBS for all visual display elements, RRSBS for composing visual elements into screens / pages, and RRSBS for stiching the screens / pages together into logical workflows. All data elements in the ecosystem are defined by RRSBS. Hardware for the computer systems that run the backend and on which the front end application runs are defined by RRSBS. Build processes for creating .dll libraries, .so libraries, .exe programs, are all defined by RRSBS. All tests for all software component are defined by RRSBS. Test Processes are defined by RRSBS. The processes to create and maintain database schemas and data are defined by RRSBS, as are the instructions how to backup and restore these databases. Documentation about how the RRSBS work are themselves defined by RRSBS. In sum, every concept, every bit of data, every software tool, the complete Ace Commander application, interfaces to third-party hardware and software are all defined by RRSBS. Specific instantiations of the Ace Commander or ATAP.Utilities libraries owned / used by owners / users are stored in the Instantiations database, and that database, and its schema and operational processes are defined by RRSBS. The API's for the backend and how the Ace Commander front-end communicates with the back-end APIs are defined by RRSBS

## Windows Path Constraints

Beyond the structural grammar, Windows imposes additional constraints that BNF alone cannot fully capture:

- **Reserved names** — `CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9` (with or without extension) are forbidden as file/folder names
- **Max path length** — 260 characters (`MAX_PATH`) by default; up to 32,767 characters with the `\\?\` long path prefix
- **Trailing characters** — Names cannot end with a period `.` or a space
- **Case insensitivity** — NTFS is case-insensitive by default (unlike Linux ext4, which is case-sensitive)

## Part I — Grammar Specification

*This section is written once when the Kind is defined. Update only on grammar revision.*
*The grammar below is authored at `grammers/Path.grammar.ebnf`; its rendered `docs/`
*copy remains deferred until grammar artifacts become database-stored.*

<!-- rule-grammar-start -->

### Kind: Path

**Philote ID:** Not allocated in the current corpus; the retained-kind decision
is recorded by GRAMMAR-01 and the baseline seed gate must allocate the Kind identity.

**Grammar file:** `grammers/Path.grammar.ebnf`

**DB record:** No authoritative current `PrimitiveLanguageKind` row is asserted by
this normalization; database conformance is a later gated baseline activity.

**Description:** Deterministic Windows path rendering from the retained Path
Rule Primitives, with filesystem-dependent validity enforced by the renderer.

#### Grammar

<!-- EMBEDDED from grammers/Path.grammar.ebnf -->
```ebnf
path = unc-path | absolute-path | relative-path | extended-path ;
unc-path = "\\\\", server, "\\", share, [ "\\", path-tail ] ;
absolute-path = drive, "\\", [ path-tail ] | "\\", path-tail ;
relative-path = path-tail ;
extended-path = "\\\\?\\", drive, "\\", [ path-tail ]
              | "\\\\?\\UNC\\", server, "\\", share, [ "\\", path-tail ] ;
```
<!-- END EMBEDDED -->

#### Composition Constraints

- A `path` selects exactly one path form; a renderer must not infer the form.
- `path-tail` is an ordered, non-empty sequence of `name` values separated by `\\`.
- `extended-path` renders either a drive-rooted local path or an UNC path.
- `namechar` validation rejects prohibited characters, terminal periods/spaces,
  and reserved device names; these checks are semantic constraints, not EBNF tokens.

#### Valid Expression Examples

```text
C:\\Repository\\SolutionDocumentation\\Rules Compendium.Path.md
\\\\server\\share\\folder\\file.txt
..\\_generated\\RRSBS-V2
\\\\?\\C:\\LongPath\\artifact.txt
```

<!-- rule-grammar-end -->

## Part II — Rule Primitives

Rule Primitives are the atomic building blocks from which a Rule is constructed.
The twelve grammar primitives each map to a single BNF non-terminal in the
Windows Path EBNF Grammar. When a grammar primitive is instantiated, its inputs
are bound to specific values; the rendered output is the exact PATH text that
corresponds to that non-terminal node in the parse tree. The thirteenth retained
primitive is the zero-input specialized
`<atap-utilities-secrets-csproj-path>` identity documented below.

<!-- rule-primitives-start -->

---

### `<path>` Rule Primitive

**Philote ID:** `"d1e2f3a4-5b6c-7d8e-9f0a-1b2c3d4e5f6a"`

Description: Top-level path primitive representing any valid Windows filesystem path. A path can be a UNC network path, an absolute local path, or a relative path.

```ebnf
<path> ::= <unc-path>
         | <absolute-path>
         | <relative-path>
         | <extended-path>
```

Body: The complete rendered path string.

Inputs:

- `PathType` (enum: `UNC`, `Absolute`, `Relative`, `Extended`) — determines which path variant to use.
- `PathContent` (instance of the selected path type primitive) — the actual path structure.

Output: The rendered path string (e.g., `\\server\share\folder\file.txt`, `C:\Windows\System32`, `..\..\data\file.dat`, `\\?\C:\VeryLong\Path\...`).

Processing: Routes to the appropriate path type primitive based on `PathType` input.

Attribution:

```text
1. https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file
2. https://learn.microsoft.com/en-us/dotnet/standard/io/file-path-formats
```

---

### `<unc-path>` Rule Primitive

**Philote ID:** `"e2f3a4b5-6c7d-8e9f-0a1b-2c3d4e5f6a7b"`

Description: Universal Naming Convention (UNC) path for accessing network resources. UNC paths begin with `\\` followed by a server name, share name, and optional path tail.

```ebnf
<unc-path> ::= "\\" <server> "\" <share> ["\" <path-tail>]
```

Body: A UNC network path string.

Inputs:

- `Server` (string, `<server>` instance) — the network server name or IP address.
- `Share` (string, `<share>` instance) — the shared resource name on the server.
- `PathTail` (optional `<path-tail>` instance) — the directory/file path within the share.

Output: Rendered UNC path (e.g., `\\FileServer\Documents\Reports\2024\Q1.xlsx`).

Processing: Concatenates `\\`, server, `\`, share, and optionally `\` followed by path tail.

Attribution:

```text
1. https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file#unc
2. https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dtyp/62e862f4-2a51-452e-8eeb-dc4ff5ee33cc
```

---

### `<absolute-path>` Rule Primitive

**Philote ID:** `"f3a4b5c6-7d8e-9f0a-1b2c-3d4e5f6a7b8c"`

Description: An absolute path starting from a root location. Can begin with a drive letter (e.g., `C:\`) or a root directory separator (`\`).

```ebnf
<absolute-path> ::= <drive> "\" [<path-tail>]
                  | "\" <path-tail>
```

Body: An absolute path string.

Inputs:

- `Drive` (optional `<drive>` instance) — drive letter with colon (e.g., `C:`). If omitted, path is rooted but drive-relative.
- `PathTail` (optional `<path-tail>` instance) — the directory/file hierarchy.

Output: Rendered absolute path (e.g., `C:\Program Files\MyApp\config.ini`, `\Windows\System32`).

Processing: If `Drive` is present, concatenates drive, `\`, and path tail. Otherwise, concatenates `\` and path tail.

Attribution:

```text
1. https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file#fully-qualified-vs-relative-paths
```

---

### `<relative-path>` Rule Primitive

**Philote ID:** `"a4b5c6d7-8e9f-0a1b-2c3d-4e5f6a7b8c9d"`

Description: A relative path specifying a location relative to the current working directory. Does not begin with `\`, `\\`, or a drive letter.

```ebnf
<relative-path> ::= <path-tail>
```

Body: A relative path string.

Inputs:

- `PathTail` (`<path-tail>` instance) — the relative directory/file hierarchy.

Output: Rendered relative path (e.g., `docs\readme.txt`, `..\config\app.settings`, `..\..\data\input.csv`).

Processing: Renders the path tail directly without any prefix.

Attribution:

```text
1. https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file#relative-paths
```

---

### `<extended-path>` Rule Primitive

**Philote ID:** `"b5c6d7e8-9f0a-1b2c-3d4e-5f6a7b8c9d0e"`

Description: Extended-length path syntax using the `\\?\` prefix to bypass the 260-character `MAX_PATH` limitation. Supports paths up to 32,767 characters.

```ebnf
<extended-path> ::= "\\?\" <absolute-path>
                  | "\\?\" "UNC\" <server> "\" <share> ["\" <path-tail>]
```

Body: An extended-length path string.

Inputs:

- `PathVariant` (enum: `Local`, `UNC`) — determines whether this is an extended local path or extended UNC path.
- `AbsolutePath` (for `Local`: `<absolute-path>` instance) — the absolute path following `\\?\`.
- `Server`, `Share`, `PathTail` (for `UNC`: server, share, and optional path tail) — UNC components.

Output: Rendered extended path (e.g., `\\?\C:\VeryLongPath\...`, `\\?\UNC\Server\Share\Path`).

Processing: Concatenates `\\?\` with either the absolute path or `UNC\` followed by server, share, and path tail.

Attribution:

```text
1. https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation
2. https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file#win32-file-namespaces
```

---

### `<drive>` Rule Primitive

**Philote ID:** `"c6d7e8f9-0a1b-2c3d-4e5f-6a7b8c9d0e1f"`

Description: Drive letter followed by a colon, identifying a Windows logical drive.

```ebnf
<drive> ::= <letter> ":"
```

Body: A drive specification (e.g., `C:`, `D:`, `Z:`).

Inputs:

- `Letter` (`<letter>` instance) — a single alphabetic character A–Z or a–z.

Output: Rendered drive string (e.g., `C:`, `d:`).

Processing: Concatenates the letter with `:`.

Attribution:

```text
1. https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file#naming-conventions
```

---

### `<path-tail>` Rule Primitive

**Philote ID:** `"d7e8f9a0-1b2c-3d4e-5f6a-7b8c9d0e1f2a"`

Description: Recursive structure representing a sequence of directory or file names separated by backslashes.

```ebnf
<path-tail> ::= <name> ["\" <path-tail>]
```

Body: A sequence of path components separated by `\`.

Inputs:

- `Name` (`<name>` instance) — the first path component (directory or file name).
- `RestOfPath` (optional `<path-tail>` instance) — the remainder of the path hierarchy.

Output: Rendered path tail (e.g., `Windows\System32`, `Program Files\App\bin\Debug`, `file.txt`).

Processing: Concatenates `Name`, and if `RestOfPath` exists, appends `\` followed by the recursive path tail.

Attribution:

```text
1. https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file
```

---

### `<name>` Rule Primitive

**Philote ID:** `"e8f9a0b1-2c3d-4e5f-6a7b-8c9d0e1f2a3b"`

Description: A single file or directory name consisting of one or more valid name characters. Must not be a reserved name or end with a period or space.

```ebnf
<name> ::= <namechar> {<namechar>}
```

Body: A valid file or directory name.

Inputs:

- `NameChars` (list of `<namechar>` instances) — the characters composing the name.

Output: Rendered name string (e.g., `MyFolder`, `report_2024.docx`, `config`).

Processing: Concatenates all name characters. Validates against reserved names (`CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9`) and ensures name does not end with `.` or space.

Attribution:

```text
1. https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file#naming-conventions
```

---

### `<namechar>` Rule Primitive

**Philote ID:** `"f9a0b1c2-3d4e-5f6a-7b8c-9d0e1f2a3b4c"`

Description: A single valid character in a Windows path name. Excludes characters that have special meaning or are disallowed: `\`, `/`, `:`, `*`, `?`, `"`, `<`, `>`, `|`.

```ebnf
<namechar> ::= <any-character-except-invalid-chars>

; Invalid characters: \ / : * ? " < > |
; Valid characters: A–Z, a–z, 0–9, space, and most punctuation except those listed above
```

Body: A single valid path character.

Inputs:

- `Character` (char) — the character to validate and render.

Output: The character itself if valid.

Processing: Validates that the character is not in the disallowed set: `\ / : * ? " < > |`. Returns the character if valid; otherwise throws a validation error.

Attribution:

```text
1. https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file#naming-conventions
```

---

### `<server>` Rule Primitive

**Philote ID:** `"a0b1c2d3-4e5f-6a7b-8c9d-0e1f2a3b4c5d"`

Description: Server name in a UNC path. Can be a hostname, fully qualified domain name (FQDN), or IP address.

```ebnf
<server> ::= <name>
```

Body: A valid server identifier.

Inputs:

- `ServerIdentifier` (`<name>` instance or IP address string) — the server name or IP.

Output: Rendered server name (e.g., `FileServer`, `srv01.contoso.com`, `192.168.1.100`).

Processing: Validates that the server identifier conforms to DNS hostname rules or is a valid IP address.

Attribution:

```text
1. https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file#unc
```

---

### `<share>` Rule Primitive

**Philote ID:** `"b1c2d3e4-5f6a-7b8c-9d0e-1f2a3b4c5d6e"`

Description: Share name in a UNC path. Identifies a shared resource on the server.

```ebnf
<share> ::= <name>
```

Body: A valid share name.

Inputs:

- `ShareName` (`<name>` instance) — the name of the shared resource.

Output: Rendered share name (e.g., `Documents`, `Public`, `Backup$`).

Processing: Renders the share name as provided. Share names ending with `$` are hidden shares.

Attribution:

```text
1. https://learn.microsoft.com/en-us/windows-server/storage/file-server/file-server-smb-overview
```

---

### `<letter>` Rule Primitive

**Philote ID:** `"c2d3e4f5-6a7b-8c9d-0e1f-2a3b4c5d6e7f"`

Description: A single alphabetic character used in drive letters.

```ebnf
<letter> ::= "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J"
           | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T"
           | "U" | "V" | "W" | "X" | "Y" | "Z"
           | "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j"
           | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t"
           | "u" | "v" | "w" | "x" | "y" | "z"
```

Body: A single letter character.

Inputs:

- `LetterChar` (char) — an alphabetic character A–Z or a–z.

Output: The letter character (e.g., `C`, `d`, `Z`).

Processing: Validates that the character is alphabetic and returns it.

Attribution:

```text
1. https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file
```

---

### `<atap-utilities-secrets-csproj-path>` Rule Primitive

**Philote ID:** `"8c3d6e7f-5a4b-4c9d-0e12-3c4d5e6f7081"`

Description: Specialized absolute-path primitive for the
`ATAP.Utilities.Secrets.csproj` file instantiation. This retained primitive is
not a Path grammar production and does not amend the twelve-primitive grammar.

Body: The complete rendered absolute path to `ATAP.Utilities.Secrets.csproj`.

Inputs: None. The primitive has zero structured `RulePrimitiveInput` rows.

Output: The rendered absolute path to the `ATAP.Utilities.Secrets.csproj` file.

Processing: Resolves the specialized project-file path for its instantiation;
the twelve grammar primitives remain responsible for general Path composition.

Attribution:

```text
1. Retained RPRRSBSI Path catalog identity
```

---

<!-- rule-primitives-end -->

## Part III — Rule Repository

<!-- rule-repository-start -->

No formal Path Rules are present in the normalized corpus. The thirteen retained
Rule Primitives are documented above: twelve grammar primitives and the
zero-input specialized `<atap-utilities-secrets-csproj-path>` primitive. Rule
composition remains a later baseline and database-conformance activity.

<!-- rule-repository-end -->

## Part IV — Rule Sets

<!-- rule-sets-start -->

No formal Path Rule Sets are present in the normalized corpus.

<!-- rule-sets-end -->
