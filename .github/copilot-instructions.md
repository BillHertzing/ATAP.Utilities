---
# (No applyTo: repository-wide defaults)
---

## Repository Purpose
Create .NET libraries, PowerShell modules/packages, Ansible IAC components, Jenkins CI/CD pipeline assets, a SQL database schema for managing code components, and a VS Code extension; provide shared utilities, services, and tooling that integrate via configuration, dependency injection, and standardized logging.

## Repository Structure
- Multi-root solution; primary source under src/, tests/, SolutionDocumentation/, .github/, infrastructure & tooling roots.
- src/:
  - Console Programs, Services (DI-based), Utilities, Libraries (serialization, messaging, logging, persistence, configuration, strongly-typed IDs, graph, reactive, voice, security, HTTP, database, timers, file IO, ETW, etc.).
  - PowerShell projects (modules, build tooling, automation, security, speech, Neo4j, Hydrus, Ansible wrappers).
  - VS Code extension (ATAP.VSCExtension.AI) and AI assist components.
  - Build tooling subtrees (Cake, Chocolatey, Jenkins, CSharp, PowerShell, AutoDoc, GenerateProgram).
  - IAC Ansible components (defaults, enumerations, models, PowerShell integration, string constants).
  - Service and interface pairing patterns (ServiceName + ServiceName.Interfaces + ServiceName.StringConstants where applicable).
- tests/:
  - Pester tests colocated per PowerShell project (tests/ subfolder inside each PowerShell module root).
  - XUnit test projects for C# libraries (parallel namespace structure).
- SolutionDocumentation/: Markdown, prompts, design, AI guidance.
- Databases/: SQL or model assets supporting code component management.
- Profiles & host configuration: PowerShell profiles, HostSettings.ps1 & fragments, ConfigRootKey files, secrets usage patterns.
- Root / config files: ATAP.Utilities.sln, ATAP.Utilities.code-workspace, Directory.Build.* (shared MSBuild), global.json, .editorconfig, .gitignore, .markdownlint.yml, .prettierrc.yml, NuGet.config, vault password file, README.md, Index.md.
- .github/: Workflows, issue templates, instruction files guiding Copilot.

## Key Interrelationships
- PowerShell modules depend on shared .NET libraries (DI & configuration via HostSettings and ConfigRootKey conventions).
- Logging unified via PSFramework (Write-PSFMessage) and .NET logging abstractions.
- Ansible assets generated/maintained using PowerShell + .NET utilities.
- Jenkins pipeline consumes build tooling scripts (Cake, PowerShell) and solution-level MSBuild props/targets.
- SQL schema backs code component metadata; libraries expose persistence & serialization; tools update DB.
- VS Code extension leverages repository utilities to assist development (snippets, AI prompts, configuration discovery).
- Environment variables + secrets vault + profile scripts compose runtime configuration; all automation honors these sources.

## Guidance for Copilot
- Prefer existing utilities & patterns (DI, logging, configuration wrappers) before creating new abstractions.
- Enforce coding guidelines from language-specific instruction files (.github/instructions/*).
- For cross-cutting tasks (security, persistence, serialization), search existing interfaces before generating code.
- Use approved PowerShell verbs and cmdlet design; use snippet-driven scaffolding where specified.
- Wrap external/process/network/file operations in structured try/catch/finally with logging.
- Promote secure handling of secrets (retrieve into SecureString / safe types; never echo secrets).
- Maintain parity between C# interfaces and their PowerShell exposure where patterns exist.
- When uncertain, request clarification on intent, target module, or existing reusable component.
