---
---

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
    - Service and interface pairing patterns (ServiceName + ServiceName.Interfaces + ServiceName.StringConstants where applicable)
  - **tests/**: Contains test projects:
    - Pester tests colocated per PowerShell project (tests/ subfolder inside each PowerShell module root)
    - XUnit test projects for C# libraries (parallel namespace structure)
  - **SolutionDocumentation/**: Markdown files, prompts, design documents, and AI guidance.
  - **Databases/**: SQL or model assets supporting code component management.
  - **Profiles & Host Configuration**: PowerShell profiles, HostSettings.ps1 & fragments, ConfigRootKey files, secrets usage patterns.
  - **Root Configuration Files**:
    - ATAP.Utilities.sln
    - ATAP.Utilities.code-workspace
    - Directory.Build.* (shared MSBuild)
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
- **Runtime Configuration**: Composed of environment variables, secrets vault, and profile scripts; all automation honors these sources.
