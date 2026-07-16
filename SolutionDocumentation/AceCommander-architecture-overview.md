# AceCommander Architecture Overview

> **Parked in ATAP.Utilities SolutionDocumentation on 2026-07-06** (Sprint 0012 Task 12.45.e,
> documentation reorganization per `PlanDocumentationReorganization.md`; moved from
> `_Planning/Repositories/AceCommander/AceCommander architecture-overview.md`). **Eventual home: AceCommander SolutionDocumentation** — parked here
> because AceCommander has no sprint worktree in Sprint 0012 (user decision 2026-07-06);
> relocation is tracked as a scope-creep item.

## 1. Purpose and scope

AceCommander is a .NET 10 Blazor full-stack web application for exploring, managing, and interacting with rule-based data and visual workflows. It provides:

- A browser-based UI for viewing and editing rules, primitives, and user data drawn from a SQL Server database.
- User account management with encrypted PII storage and theme/settings customization.
- A SignalR-based transaction roundtrip demonstration.
- Cross-schema querying that joins application-specific data with a shared reference database.

**Users**: Internal users who manage rules, primitives, and user accounts. The system was originally built for a small number of concurrent users; the modernization goal targets approximately 1,000.

**Repository type**: A deployable application consisting of a Blazor Server host, a Blazor WebAssembly client, shared model libraries, supporting configuration libraries, database assets, and test infrastructure.

## 2. High-level architecture

### Major runtime components

| Component | Project/Location | Role |
|---|---|---|
| **Blazor Server host** | `AceCommander.Server/` | ASP.NET Core host: serves pages, runs server-side Blazor components, exposes SignalR hub, hosts EF Core data access |
| **Blazor WebAssembly client** | `AceCommander.Client/` | Client-side interactive Blazor components loaded via `AdditionalAssemblies` |
| **Shared models** | `AceCommander.Shared/` | Domain models, DTOs, and enums shared between server and client |
| **String constants** | `AceCommander.Server.StringConstants/` | Typed configuration key constants |
| **Default configuration** | `AceCommander.Server.DefaultConfiguration/` | Compiled-in production defaults (lowest-priority config source) |
| **SQL Server databases** | External | `ATAPUtilities` database with configurable reference schema + fixed `AceCommander` schema |
| **Syncfusion Blazor** | NuGet dependency | UI component library (grids, dropdowns, buttons, theming) |

### Component interactions

```
Browser (WASM + Server-side Blazor)
    |
    |  HTTP / WebSocket (Blazor circuit)
    |  SignalR (/hubs/transactions)
    v
ASP.NET Core Host (AceCommander.Server)
    |
    |--- RuleService, PrimitivesService ---> ReferenceDbContext (read-only)
    |                                            |
    |                                            v
    |                                      SQL Server: ATAPUtilities db
    |                                      (schema: ATAPUtilities or MinimalTableSet)
    |
    |--- AuthService, UserService,
    |    UserInformationService,       ---> AceCommanderDbContext (read/write)
    |    UserPreferenceService               |
    |                                        v
    |                                   SQL Server: ATAPUtilities db
    |                                   (schema: AceCommander)
    |
    |--- ThemeService (in-memory + localStorage via JS interop)
    |
    |--- TransactionHub (SignalR)
```

### Data flow

1. **Page requests**: Browser connects via Blazor Server circuit. Server-side Razor components call scoped services, which query EF Core DbContexts against SQL Server.
2. **Theme switching**: `MainLayout.razor` theme dropdown triggers JS interop to swap CSS files and persist preference to both `localStorage` and the `UserPreference` database table.
3. **SignalR roundtrip**: The Home page sends a `TransactionRequest` to `TransactionHub`, which returns a `TransactionAcknowledgement` with a server timestamp.
4. **Cross-schema queries**: `UserInformationService.GetCrossSchemaRowsAsync()` executes raw SQL spanning the `AceCommander` and reference schemas, joined on `EmailHash`.

## 3. Repository and code organization

### Top-level layout

| Directory/File | Contents |
|---|---|
| `AceCommander.sln` | Visual Studio solution (all projects) |
| `AceCommander.Server/` | Main Blazor Server application |
| `AceCommander.Client/` | Blazor WebAssembly client project |
| `AceCommander.Shared/` | Shared models and interfaces |
| `AceCommander.Server.Tests/` | Server unit, component, and E2E tests (xUnit + bUnit) |
| `AceCommander.Client.Tests/` | Client component tests |
| `AceCommander.Shared.Tests/` | Shared model tests |
| `Database/` | Database documentation and SQL assets |
| `SolutionDocumentation/` | Architecture and design documents |
| `scripts/` | PowerShell build/test orchestration |
| `e2e/` | Playwright E2E test infrastructure |
| `.claude/` | Claude Code agent definitions |
| `.github/` | Shared Copilot instructions (symlinked from SharedVSCode) |
| `.vscode/` | VS Code workspace settings and tasks |

### Server project structure (`AceCommander.Server/`)

| Subdirectory | Contents |
|---|---|
| `Components/Layout/` | `MainLayout.razor` - app shell with nav, theme picker, auth actions |
| `Components/Pages/` | Razor pages: `Home`, `Login`, `Register`, `Logout`, `UserInformationAndSettings` |
| `Components/Login/` | `LoginForm.razor`, `RegisterForm.razor` |
| `Components/Shared/` | Reusable components: `ActionCard`, `PageHeader` |
| `Data/` | EF Core DbContexts, schema options, model cache key factory |
| `Hubs/` | `TransactionHub` (SignalR) |
| `Services/` | Business logic services (Auth, User, Rule, Primitives, Theme, UserPreference, UserInformation) |
| `wwwroot/` | Static assets: CSS themes, JS interop scripts |

### Naming conventions

- **Projects**: `AceCommander.{Layer}` pattern (Server, Client, Shared, Server.Tests, etc.)
- **Configuration keys**: `AceCommander_` prefix for environment variables; `AceCommander_Reference:SchemaName` for schema selection
- **Database schemas**: `AceCommander` (application data), `ATAPUtilities` or `MinimalTableSet` (reference data)

### Build and test tooling

- **Build**: `dotnet build` via VS Code tasks or command line
- **Test orchestration**: `pwsh ./scripts/run-tests-and-coverage.ps1` runs unit + component + E2E tests and produces a dashboard at `artifacts/test-orchestration/TestDashboard.md`
- **E2E tests**: Playwright (Node.js) in `e2e/`, targeting `http://127.0.0.1:5259`
- **Flags**: `-SkipE2E`, `-SkipCoverage`, `-SkipInstall` for selective test runs

## 4. Key architectural and design concepts

### Configuration pipeline

The application uses a layered configuration system via `ATAP.Utilities.Configuration.Extensions`:

1. **Compiled-in defaults** (`DefaultConfiguration.cs`) - lowest priority; safe defaults, blank passphrases
2. **`appsettings.json`** - base application settings
3. **`appsettings.{Environment}.json`** - environment-specific overrides
4. **User Secrets** (development only, ID: `04480560-8bff-40b5-8204-a70c15e8d457`)
5. **Environment variables** (`AceCommander_*` prefix)
6. **Command-line arguments** - highest priority

The configuration route is built, the environment is evaluated, then configuration is rebuilt based on the resolved environment before finalization. Key configuration values:

| Key | Purpose |
|---|---|
| `ConnectionStrings:ATAPUtilities` | SQL Server connection string |
| `AceCommander_Reference:SchemaName` | Reference schema selector (`ATAPUtilities` or `MinimalTableSet`) |
| `SYNCFUSION_LICENSE_KEY` | Syncfusion UI component license |
| `AceCommander_UserPii:PassphraseV1` | PII encryption passphrase |

### Dual DbContext architecture

The application registers two EF Core DbContexts against the same SQL Server database but different schemas:

- **`ReferenceDbContext`** (read-only): Targets a configurable schema containing rules, primitives, and language kinds. All `SaveChanges` paths throw `InvalidOperationException`. Uses `ReferenceModelCacheKeyFactory` to support runtime schema switching.
- **`AceCommanderDbContext`** (read/write): Fixed `AceCommander` schema for user accounts, information, settings, and preferences.

This separation enforces a clear boundary between shared reference data and application-specific mutable data.

### Authentication and security

**Current implementation** (stub/transitional):
- `StubAuthenticationStateProvider` - in-memory authentication state
- `InMemoryUserRepository` - hardcoded user store
- `PasswordHasher` - Argon2id via `Konscious.Security.Cryptography`
- `AuthService` - SQL-backed authentication with SHA-256 email hash lookup

**PII protection**:
- User email, name, phone, and role are encrypted at rest via SQL `ENCRYPTBYPASSPHRASE()`
- `EncryptionKeyVersion` column supports passphrase rotation
- Cross-schema grids display encrypted fields as `[encrypted]`

**Planned**: Replace stub auth with ASP.NET Core Identity + cookie authentication; integrate OAuth2 (Google).

### Theming system

Detailed in [Theming in AceCommander](./Theming%20in%20AceCommander.md).

- Syncfusion Material 3 base theme with CSS overlay system (ocean, sunset, forest)
- `ThemeService` manages page intent via `PageMode` enum (Default, CallToAction, Reflect)
- Persistence: `UserPreference` database table + `localStorage` fallback via JS interop
- Runtime switching: `MainLayout.razor` dropdown triggers JS interop to swap `<link>` elements

### Cross-cutting concerns

- **Logging**: ASP.NET Core built-in logging; `ATAP.Utilities.ETW` (Event Tracing for Windows) referenced
- **Data access**: EF Core with LINQ for standard queries; raw SQL (`FromSqlRaw`) for cross-schema joins
- **Error handling**: Standard ASP.NET Core middleware; startup validation fails fast if reference schema doesn't exist
- **Dependency injection**: All services registered as `Scoped` (per-circuit); `InMemoryUserRepository` and `ReferenceSchemaOptions` as `Singleton`

## 5. Existing documentation and references

| Document | Location | Covers |
|---|---|---|
| Repository ReadMe | [ReadMe.md](../ReadMe.md) | Solution structure, build/run instructions, test orchestration |
| Documentation Index | [Index.md](./Index.md) | Navigation hub with suggested reading order |
| Theming guide | [Theming in AceCommander.md](./Theming%20in%20AceCommander.md) | End-user theming instructions and developer implementation details |
| Testing guide | [Testing in AceCommander.md](./Testing%20in%20AceCommander.md) | Test infrastructure, orchestration script, Playwright setup |
| Test Orchestration Skill | [AI Agent Skills/Test Orchestration Skill.md](./AI%20Agent%20Skills/Test%20Orchestration%20Skill.md) | AI agent guidance for running test orchestration |
| Test Dashboard Prompt | [AI Agent Skills/Agent Runner Prompt - Test Dashboard.md](./AI%20Agent%20Skills/Agent%20Runner%20Prompt%20-%20Test%20Dashboard.md) | Prompt template for test dashboard generation |
| Server ReadMe | [AceCommander.Server/ReadMe.md](../AceCommander.Server/ReadMe.md) | Server project purpose, key folders |
| Client ReadMe | [AceCommander.Client/ReadMe.md](../AceCommander.Client/ReadMe.md) | Client project purpose and build notes |
| User Info & Settings spec | [Database/documentation/User Information and Settings viewing and editing.md](../Database/documentation/User%20Information%20and%20Settings%20viewing%20and%20editing.md) | Dual-grid feature specification, database views, security model |
| E2E ReadMe | [e2e/README.md](../e2e/README.md) | Playwright infrastructure and baseline scenarios |
| ASCII tree | [AScii TreeView ACeCommander Repository.txt](./AScii%20TreeView%20ACeCommander%20Repository.txt) | Full repository directory tree |

Information in sections 1-4 was derived from exploring the code and configuration files. Terminology and feature descriptions align with the existing documentation listed above.

## 6. Observations, risks, and areas to investigate

### Confirmed observations

- **Stub authentication is not production-ready.** `StubAuthenticationStateProvider` and `InMemoryUserRepository` are placeholder implementations. The codebase contains `AuthService` with real Argon2id password verification, indicating migration is in progress.

- **Single database instance, dual schema.** Both DbContexts target the same SQL Server instance. The reference schema is read-only and the application schema is read/write, which is a sound separation but means all load hits one database server.

- **Raw SQL for cross-schema queries.** `UserInformationService.GetCrossSchemaRowsAsync()` uses `FromSqlRaw` to join across schemas. This bypasses EF Core change tracking (appropriate for read-only) but means these queries are not validated at compile time.

- **Syncfusion dependency is pervasive.** Grids, dropdowns, buttons, and theming all depend on Syncfusion Blazor. The licensing key is a required runtime configuration value.

- **Configuration pipeline uses external ATAP library.** The `ATAP.Utilities.Configuration.Extensions` package is referenced as a local binary (`..\..\ATAP.Utilities\`), creating a build-time dependency on a sibling repository.

### Potential risks for ~1,000 users

- **Blazor Server circuit scalability.** Each connected user maintains a persistent WebSocket circuit with server-side component state. At 1,000 concurrent users, this creates significant memory pressure and connection overhead. *Mitigation direction*: evaluate Blazor WebAssembly-first or Auto render mode to offload rendering to clients.

- **Scoped services per circuit.** Services like `UserInformationService` and `PrimitivesService` are scoped per circuit. If they hold large result sets in memory, this multiplies with user count. *Mitigation direction*: audit service memory profiles; consider pagination and streaming.

- **SignalR connection limits.** `TransactionHub` and Blazor circuits both use SignalR. Default ASP.NET Core limits may need tuning for 1,000 concurrent WebSocket connections. *Mitigation direction*: configure connection limits, consider sticky sessions or Azure SignalR Service.

- **Single SQL Server instance.** No read replicas or connection pooling configuration is visible beyond the default. Cross-schema raw SQL queries could become bottlenecks under load. *Mitigation direction*: add connection pool tuning, consider read replicas for the reference schema.

- **In-memory singleton state.** `InMemoryUserRepository` is a singleton holding user state in memory. This is acknowledged as a stub, but any production replacement must support concurrent access. *Mitigation direction*: replace with database-backed repository (already planned).

### Hypotheses (need verification)

- **ATAP.Utilities.ETW usage extent.** The ETW tracing package is referenced but the extent of instrumentation in the codebase is unclear. If minimal, adding structured logging/tracing for production observability would be valuable.

- **Plugin model intent.** The agent instructions reference a plugin and child-process model, but the current codebase does not implement one. This may be a planned feature or may describe a related system in the broader ATAP ecosystem. The configurable reference schema could be considered a lightweight extensibility point.

- **Database migration strategy.** No EF Core migrations or SQL migration scripts were found. It is unclear whether schema changes are managed via scripts, a separate tool, or manual DDL.

## 7. Architecture diagram

The architecture diagram is saved as [architecture-overview.drawio](./architecture-overview.drawio) in this directory.

The diagram depicts:

- **Browser tier**: The Blazor WebAssembly client running in the user's browser, connected to the server via Blazor Server circuit (WebSocket) and SignalR.
- **Server tier**: The ASP.NET Core host containing Blazor Server components, business services (Auth, Rules, Primitives, UserInformation, Theme), SignalR TransactionHub, and EF Core data access.
- **Data tier**: SQL Server with two schemas - the configurable reference schema (ATAPUtilities/MinimalTableSet) accessed read-only, and the AceCommander schema accessed read/write.
- **Configuration sources**: The layered configuration pipeline feeding into the server at startup.
- **Static assets**: CSS themes and JS interop scripts served from wwwroot.

Scaling annotations highlight the Blazor Server circuit as a per-user resource and the single SQL Server instance as a potential bottleneck.
