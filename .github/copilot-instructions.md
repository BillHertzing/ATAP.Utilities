# Copilot instructions for repository-wide guidance

This file was generated via an AI prompt. Changes made to this file will not be saved when it is regenerated.

## Repository Purpose

The ATAP.Utilities repository is designed to create .NET libraries, PowerShell modules/packages, Ansible Infrastructure-as-Code (IAC) components, Jenkins CI/CD pipeline assets, a SQL database schema for managing code components, and a VS Code extension. It provides shared utilities, services, and tooling that integrate via configuration, dependency injection, and standardized logging.

## Repository Structure

- **Multi-root repository** with the following key directories:
  - **src/**: Contains the primary source code, including:
    - Console Programs
    - Services (DI-based)
    - Utilities
    - Libraries (e.g., serialization, messaging, logging, persistence, configuration, strongly-typed IDs, graph, reactive, voice, security, HTTP, database, timers, file IO, ETW, etc.)
    - PowerShell projects (modules, build tooling, automation, security, speech, Neo4j, Hydrus, Ansible wrappers)
    - VS Code extension (ATAP.VSCExtension.AI) and AI assist components
    - Build tooling subtrees (Cake, Chocolatey, Jenkins, CSharp, PowerShell, AutoDoc, GenerateProgram)
    - IAC Ansible components (defaults, enumerations, models, PowerShell integration, string constants)
    - Service and interface pairing patterns (ServiceName + ServiceName.Interfaces + ServiceName.StringConstants + ServiceName.Enumerations + ServiceName.Extensions where applicable)
  - **tests/**: Contains test projects:
    - Pester tests colocated per PowerShell project (tests/ subfolder inside each PowerShell module root)
    - XUnit test projects for C# libraries (parallel namespace structure)
  - **SolutionDocumentation/**: Markdown files, prompts, design documents, and AI guidance.
  - **Databases/**: SQL or model assets supporting code component management.
  - **Profiles & Host Configuration**: PowerShell profiles, HostSettings.ps1 & fragments, ConfigRootKey files, secrets usage patterns.
  - **Root Configuration Files**:
    - ATAP.Utilities.sln
    - ATAP.Utilities.code-workspace
    - Directory.Build.\* (shared MSBuild)
    - global.json
    - .editorconfig
    - .gitignore
    - .markdownlint.yml
    - .prettierrc.yml
    - NuGet.config
    - Vault password file
    - README.md
    - Index.md
  - **.github/**: Workflows, issue templates, and instruction files guiding Copilot.

## Key Interrelationships

- **PowerShell Modules**: Depend on shared .NET libraries (DI & configuration via HostSettings and ConfigRootKey conventions).
- **Logging**: Unified via PSFramework (Write-PSFMessage) and .NET logging abstractions.
- **Ansible Assets**: Generated/maintained using PowerShell + .NET utilities.
- **Jenkins Pipeline**: Consumes build tooling scripts (Cake, PowerShell) and solution-level MSBuild props/targets.
- **SQL Schema**: Backs code component metadata; libraries expose persistence & serialization; tools update the database.
- **VS Code Extension**: Leverages repository utilities to assist development (snippets, AI prompts, configuration discovery).

## Critical Build Requirements

### NuGet Configuration Fix

The NuGet.config file resolves package sources resolution, and is used during the building of dotnet components. The configuration should point to the same package sources defined for powershell modules building, as defined $Global:settings[$global:ConfigRootKeys['PackageRepositoriesCollectionConfigRootKey']]. Both locations should specify the organization's internal approved package feeds as sources.

### Step-by-Step Build Process


- **Runtime Configuration**: Composed of environment variables, secrets vault, and profile scripts; all automation honors these sources.

## Project Structure

### Source Organization
```
src/
├── ATAP.Utilities.BuildTooling.CSharp/    # MSBuild custom tasks
├── ATAP.Utilities.BuildTooling.PowerShell/ # PowerShell build tools
├── ATAP.Utilities.*/                      # Core utility libraries
├── ATAP.Console.*/                        # Console applications
└── ATAP.VSCExtension.AI/                  # VS Code extension

tests/
├── ATAP.Utilities.*.UnitTests/            # xUnit test projects
└── Directory.Build.props                  # Test-specific build props

Build/                                     # Custom MSBuild tooling
Databases/                                 # SQL Server scripts
SolutionDocumentation/                     # Comprehensive docs
```

### Key Configuration Files

- **Directory.Build.props**: Solution-wide MSBuild properties
- **Directory.Build.targets**: Custom build targets and tasks
- **NuGet.Config**: Package sources (fix symlink first)
- **.editorconfig**: Code formatting rules
- **global.json**: .NET SDK version pinning

### Important Dependencies

- **Serilog**: Logging framework
- **PSFramework**: PowerShell logging (`Write-PSFMessage`)
- **ServiceStack**: Serialization and ORM
- **Microsoft.Extensions.\***: Configuration and DI
- **xUnit**: C# testing
- **Pester**: PowerShell testing

## Development Workflow

### Making Changes

1. **Always** verify NuGet.Config and .NET targeting before building
2. **Build incrementally** - start with BuildTooling projects
3. **Test early and often** - both C# (xUnit) and PowerShell (Pester)
4. **Check for missing projects** in solution file before full solution builds## Testing Strategy

### C# Testing

- Uses xUnit framework
- FluentAssertions for better test readability
- Moq for mocking
- Test projects follow naming: `ATAP.Utilities.*.UnitTests`

### PowerShell Testing

- Uses Pester 5+ framework
- PSFramework for logging (`Write-PSFMessage -Level Important`)
- Tests located in `tests/Unit/` subdirectories

### Validation Commands

```Powershell
# C# code analysis and build
dotnet build --configuration Release

# Run C# tests
dotnet test --configuration Release

# PowerShell analysis
pwsh -Command "Invoke-ScriptAnalyzer -Path . -Recurse"

# PowerShell tests
pwsh -Command "Invoke-Pester -Path ./tests -Output Detailed"
```

## Critical Instructions for Agents

1. **TRUST THESE INSTRUCTIONS** - Don't search for build info unless these instructions fail
3. **BUILD INCREMENTALLY** - don't attempt full solution builds initially
3. **COMMENT OUT custom MSBuild imports** until BuildTooling projects are built
4. **INSTALL PowerShell modules** before running PowerShell tests
7. **USE individual project paths** when solution build fails
