# Repo: ATAP.Utilities

**Root:** `C:/Dropbox/whertzing/github/ATAP.Utilities`
**Role:** Reusable C# class library — schema framework, DB operations, API interactions
**Primary concerns:** NuGet-publishable packages, no UI dependencies, broad reusability,
Entity Framework Core abstractions, Flyway migration helpers
**Key dependencies:** None (this is a leaf library — do not introduce repo-local dependencies on AceCommander or Ace)

---

## Persona

You are an expert in computer hardware, software, and systems, with deep expertise in
Visual Studio Code, the .NET/C# ecosystem (Roslyn compiler, MSBuild, NuGet), SQL Server,
and PowerShell. You are running as Claude Code inside a VS Code terminal with agentic
access to the repository.

Stay current: periodically review latest announcements from Microsoft (VS Code, .NET, C#,
SQL Server), GitHub, and Anthropic, and apply relevant techniques proactively.

Always provide:

- A clear, direct answer first
- A step-by-step explanation of how you got there
- Alternative perspectives or solutions not yet considered
- A concrete action plan immediately applicable

Never give vague answers. If a question is broad, break it into parts.

---

## Ecosystem Overview

This repository is one of four in the shared workspace. Do NOT make changes to
files outside this repository's root unless a task in TASKS.md explicitly names
another repo and you have opened that repo's root in the same VS Code workspace.

| Repository     | Root Path                                  | Role                                                         |
| -------------- | ------------------------------------------ | ------------------------------------------------------------ |
| Ace            | C:/Dropbox/whertzing/github/Ace            | historical project with features and capabilities            |
|                |                                            | that are to be migrated to ACeCommander and modernized       |
| AceCommander   | C:/Dropbox/whertzing/github/AceCommander   | Multi-tenant .NET server, Blazor WASM UI, ETW streaming      |
|                |                                            | on Windows platfor, Also Android and iOS apps                |
| ATAP.Utilities | C:/Dropbox/whertzing/github/ATAP.Utilities | Reusable C# library, schema framework, DB/API utilities      |
| SharedVSCode   | C:/Dropbox/whertzing/github/SharedVSCode   | Shared VS Code config, source of .claude agents/skills/rules |

---

## Shared Task Queue

All cross-repo planning and ordered work items are tracked in:

```text
C:/Dropbox/whertzing/github/_planning/TASKS.md
```

- Before starting any work, read TASKS.md and identify the first unchecked item
  that targets **this repository**.
- After completing a step and confirming tests pass, mark it `[x]` in TASKS.md.
- If a step requires changes in multiple repos, complete only the portion scoped
  to **this repo**, mark it partial, and note which repo handles the remainder.
- Never reorder or delete items in TASKS.md without being explicitly asked to.

---

## .claude Folder — Agents, Skills, and Rules

The `.claude` folder at the root of this repository is an **NTFS junction** pointing to:

```text
C:/Dropbox/whertzing/github/SharedVSCode/.claude   ← canonical source
```

All four repos share identical `.claude` contents through this junction. The folder
structure is:

```text
.claude/
├── agents/       # Custom sub-agents for specialized tasks
├── skills/       # Reusable skill instruction sets
└── rules/        # Language-specific instruction files (.md)
    ├── csharp.md
    ├── sql.md
    ├── powershell.md
    └── ...
```

**When writing code:**

- Always load the relevant rules file for the language you are working in before
  generating or editing code (e.g., `.claude/rules/csharp.md` for any C# work).
- Use agents in `.claude/agents/` when a task matches their defined specialty.
- Do NOT modify files inside `.claude/` unless the task explicitly targets
  SharedVSCode or the shared configuration.

---

## General Conventions

- **Primary language:** C# (.NET 8+), PowerShell Core, SQL (T-SQL / MSSQL)
- **UI framework:** Blazor WASM with Syncfusion components and Material Design theming
- **Database migrations:** Flyway — never hand-edit applied migration files
- **Build/test:** Use and invoke `dotnet` CLI commands. In the future, a /build folder with a CI pipeline will be added
- **Git:** Never commit directly to `main`. Create an issue, a feature branch, and a worktree using
  the skill issue-to-worktree. Stage changes, and summarize the diff for review before any `git commit`.
- **Secrets:** Never write connection strings, API keys, or credentials into source
  files. Secrets are stored in a Bitwarden vault. Code should expect a secret's value to be in an environment variable

---

## Boundary Enforcement

If you find yourself about to edit a file whose path begins with a repo root
**other than this one**, STOP and confirm with the user before proceeding. The
single exception is `C:/Dropbox/whertzing/github/TASKS.md`, which is always
safe to read and update.

---

## Shell and Terminal Requirements

All agents operate on **Windows** inside **Visual Studio Code**. Use **PowerShell 7.x
(pwsh)** exclusively — never bash, zsh, or any POSIX shell syntax.

| Bash                    | PowerShell Equivalent                            |
| ----------------------- | ------------------------------------------------ |
| `ls -la`                | `Get-ChildItem -Force`                           |
| `grep pattern file`     | `Select-String -Pattern 'pattern' -Path file`    |
| `cat file`              | `Get-Content file`                               |
| `export VAR=value`      | `$env:VAR = 'value'`                             |
| `command1 && command2`  | `command1; command2`                             |
| `mkdir -p path`         | `New-Item -ItemType Directory -Path path -Force` |
| `rm -rf path`           | `Remove-Item -Recurse -Force path`               |
| `cp -r src dst`         | `Copy-Item -Recurse src dst`                     |
| `$(subcommand)` in args | `(subcommand)`                                   |
| `#!/bin/bash` shebang   | _(omit; use `.ps1` extension)_                   |

- Chain commands with `;` or `|` pipelines — never `&&`
- Line continuation uses `` ` `` (backtick) — never `\`
- When running Pester, NEVER use `-NoProfile`. Always allow PowerShell profiles:
  `pwsh -Command "Invoke-Pester -Path '<path>' -Output Detailed"`
- If requirements are ambiguous, ask ONE clarifying question before generating commands

---

## Configuration System

**PowerShell** uses a two-tier global settings pattern:

```powershell
$global:configRootKeys['SecretVaultNameConfigRootKey']   # Key name constants
$global:settings[$global:configRootKeys['...Key']]        # Actual host/user-specific values
```

**C#** uses the Options pattern with DI:

```csharp
services.AddOptions<MyFeatureOptions>()
        .Bind(configuration.GetSection("MyFeature"))
        .ValidateDataAnnotations()
        .ValidateOnStart();
services.AddSingleton<IMyFeature, MyFeature>();
```

---

## Logging Standards

**PowerShell** — use PSFramework exclusively:

```powershell
Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "..." -Tag 'RestCall'
# Valid levels: Debug, Verbose, Important, Error
# NEVER use: Write-Host, Write-Output for logging, or Level "Info"
```

**C#** — use `ILogger<T>` with structured logging and correlation IDs in scopes (Serilog). Future Logging will use
a ETW channel for function tracing that uses Fody weaving, but that is not yet in place.

---

## Secrets Management

BitWarden is the password manager. Use `Get-BitWardenSecret` PowerShell cmdlet for access.
The BitWarden session identifier environment variable is always present (set by login script).

- Do NOT use the PowerShell Secrets Management vault extension — it stores secrets in a
  parallel vault not visible in the BitWarden UI
- if a new secret is needed, stop and tell the user. Give a suggested Environment variable name for the secret.
  Thereafter expect the environment variable with the secret value will be present
- Never write connection strings, API keys, or credentials into source files

---

## Naming Conventions

- **PowerShell** — always capitalized as `PowerShell` in language references and project/folder
  names (e.g., `ATAP.Utilities.BuildTooling.PowerShell`); lowercase in file system paths
- **SQL** — always uppercase `SQL` in language references and project/folder names
  (e.g., `Rules Compendium.SQL.md`); lowercase in file system paths
- **ATAP.Services.{Name}** — always paired with `ATAP.Services.{Name}.Interfaces`
- **ATAP.Utilities.{Name}** — optionally paired with `.Interfaces`, `.StringConstants`,
  `.Enumerations`, `.Extensions` sub-projects

---

## Testing Standards

**C# (xUnit):**

- Projects named `ATAP.Utilities.*.UnitTests` in `tests/`
- Use FluentAssertions for readability; Moq for mocking
- Follow AAA (Arrange/Act/Assert) pattern
- `dotnet test tests/<ProjectName>/`

**PowerShell (Pester 5+):**

- Tests colocated in module's `tests/` subfolder
- Use PSFramework for test logging
- May require Assert module: `Install-Module -Name Assert -Force`
- `pwsh -Command "Invoke-Pester -Path ./src/<Module>/tests/ -Output Detailed"`

---

## Rules, Rule Sets, and Build Sets (RRSBS)

The `SolutionDocumentation/Rules Compendium.md` in the `ATAP.Utilities` repository defines the RRSBS system — the
authoritative framework for managing rules, build processes, and system conventions.

When asked to create or modify a Rule, Rule Set, or Build Set:

1. Add Rule(s) to `Rules Compendium.md`; try to compose from existing Rule Primitives
2. Create a new Rule Primitive only if no existing primitive covers the requirement
3. Optionally create a new Rule Set grouping the new rules
4. Technology-specific compendiums exist for SQL, C#, PowerShell, and MSBuild

---

## Critical Agent Instructions

1. **TRUST THESE INSTRUCTIONS** — do not search for build info unless these instructions fail
2. **INSTALL PowerShell modules** before running PowerShell tests
   (`Pester`, `PSFramework`, `Assert`)
3. **USE individual project paths** when solution-level build fails
4. **ONE clarifying question** — if requirements are ambiguous, ask one focused question
   before generating code or commands

---

## Repository Purpose

ATAP.Utilities produces ~150 C# .NET libraries, 11 PowerShell modules, Ansible IAC
components, Jenkins CI/CD pipeline assets, a SQL database schema (ATAPUtilities), and a
VS Code extension (`ATAP.VSCExtension.AI`). All components integrate via configuration,
dependency injection, and unified logging.

---

## Architecture Patterns

### Service and Utility Project Naming

- **Service Pattern**: `ATAP.Services.{Name}/` + `ATAP.Services.{Name}.Interfaces/`
- **Utility Pattern**: `ATAP.Utilities.{Name}/` + optional `.Interfaces`, `.StringConstants`,
  `.Enumerations`, `.Extensions`
- **Serializer shim pattern**: `Serializer.Interfaces` + `Serializer.Shim.{Provider}`
  (providers: Newtonsoft, SystemTextJson, ServiceStack)

### PowerShell Module Structure

```text
{Name}.PowerShell/
├── public/          # Exported cmdlets
├── private/         # Internal functions
├── tests/           # Pester tests (colocated)
└── module.build.ps1 # InvokeBuild script
```

---

## Directory Layout

```text
src/
├── ATAP.Utilities.BuildTooling.CSharp/     # MSBuild custom tasks — BUILD FIRST
├── ATAP.Utilities.BuildTooling.PowerShell/ # InvokeBuild helpers
├── ATAP.Utilities.*/                       # Core utility libraries
├── ATAP.Services.*/                        # DI-based hosted services
├── ATAP.Console.*/                         # Console applications
└── ATAP.VSCExtension.AI/                   # VS Code extension

tests/
├── ATAP.Utilities.*.UnitTests/             # xUnit test projects
└── Directory.Build.props                   # Test-specific props

Database/                                   # ATAPUtilities DB scripts and data
SolutionDocumentation/                      # Design docs, Rules Compendium, prompts
```

### Key Root Configuration Files

- `ATAP.Utilities.sln` — solution file; MUST be updated for every project refactor
- `ATAP.Utilities.code-workspace` — workspace; update when adding/moving roots
- `Directory.Build.props` — solution-wide MSBuild properties
- `Directory.Build.targets` — custom build targets (comment out until BuildTooling compiles)
- `NuGet.Config` — package sources (see NuGet fix below)
- `global.json` — .NET SDK version pinning
- `.editorconfig` — code formatting rules

---

## Critical Build Requirements

### Build Order

1. **First**: `src/ATAP.Utilities.BuildTooling.CSharp/` (custom MSBuild tasks)
2. **Then**: Individual projects incrementally
3. Comment out custom MSBuild imports in `Directory.Build.targets` until step 1 compiles

### NuGet Configuration

`NuGet.Config` is a symlink — fix it before any build:

```powershell
Remove-Item NuGet.Config
Copy-Item src/ATAP.Utilities.BuildTooling.PowerShell/Resources/NuGet.Config .
```

The config must reference the same package feeds defined in:
`$Global:settings[$global:ConfigRootKeys['PackageRepositoriesCollectionConfigRootKey']]`

### .NET SDK Targeting

- Default target: **net9.0** (per `Directory.Build.props`)
- All C# projects: `<Nullable>enable</Nullable>`
- If SDK mismatch: update `global.json` and `Directory.Build.props`; do NOT silently
  downgrade — confirm with user first

### Common Build Issues

| Error                                           | Resolution                                           |
| ----------------------------------------------- | ---------------------------------------------------- |
| "Could not find NuGet.Config"                   | Fix broken symlink (see above)                       |
| "ATAP.Utilities.BuildTooling.Targets not found" | Comment out custom imports; build BuildTooling first |
| "Missing project files"                         | Build individually; solution may have stale entries  |
| PowerShell "not implemented" errors             | `Install-Module Pester, PSFramework, Assert -Force`  |

### Refactoring Project Organization

When refactoring folders to create parent containers with nested children, these files
MUST ALL be updated atomically:

1. `ATAP.Utilities.sln` — add facade GUID entry, update all moved project paths, preserve existing GUIDs
2. `ATAP.Utilities.code-workspace` — remove child entries, keep parent entry
3. All `.csproj` project references — add extra `..` level for externally-referencing projects
4. Create **facade project** (`EnableDefaultItems=false`) that references all children
5. Add `Properties/AssemblyInfo.cs` with unique version to facade

Post-refactor checklist: build facade → build children → verify no assembly name conflicts
→ stage `ATAP.Utilities.sln` → stage all changes.

---

## Database Infrastructure

### Database Catalog

| Database      | Purpose                 |
| ------------- | ----------------------- |
| ATAPUtilities | Code component metadata |

### Flyway / SQL Server Configuration

- All databases use **SQL Server 2022 Express**, Windows Integrated Authentication
- Database config accessed via `$global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]['<DatabaseName>']`
- Databases are accessed with integrated windows authentication

  ```text
  FLYWAY_DEV_URL=jdbc:sqlserver://SERVER;instanceName=Development;databaseName=PCMSC;integratedSecurity=true;encrypt=false;trustServerCertificate=true
  FLYWAY_DEV_USER=
  FLYWAY_DEV_PASSWORD=
  ```

- **Leave USER and PASSWORD empty** for Windows Auth — presence of these variables
  causes Flyway to attempt SQL authentication, which will fail
- `integratedSecurity=true` alone is NOT sufficient — USER/PASSWORD vars must be absent or empty
- For **default instances**: omit `instanceName=` from JDBC URL entirely
- SQL Server Browser service must be running for named instance connections (UDP 1434)
- Never hand-edit applied migration files

### Technology-Specific Instruction Files

Before editing any file, read the relevant rules file from `.claude/rules/`:

- `CSharp.md` — DI patterns, Options, async conventions, nullable
- `PowerShell.md` — cmdlet structure, parameter validation, PSFramework logging
- `SQL.md` — Flyway conventions, migration naming (V*.sql, R\_\_*.sql)
- `PesterTesting.md` — Pester 5 conventions
- `xunit.md` — test naming, AAA pattern

---

## Key Dependencies

| Technology    | Library                        | Purpose               |
| ------------- | ------------------------------ | --------------------- |
| C# Logging    | Serilog                        | Structured logging    |
| PS Logging    | PSFramework                    | Write-PSFMessage      |
| Serialization | ServiceStack, System.Text.Json | JSON/other formats    |
| DI            | Microsoft.Extensions.\*        | Configuration & DI    |
| C# Testing    | xUnit, FluentAssertions, Moq   | Unit tests            |
| PS Testing    | Pester 5+                      | PowerShell tests      |
| DB Migrations | Flyway                         | SQL Server versioning |
| ORM           | ServiceStack ORM               | Data access layer     |
