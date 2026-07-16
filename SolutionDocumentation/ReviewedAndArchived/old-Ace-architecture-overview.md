# Architecture Overview — ACE / AceCommander

> **Archived 2026-07-06** (Sprint 0012 Task 12.45.e). Historical architecture overview of the
> pre-modernization "Ace" application; superseded by `AceCommander-architecture-overview.md`
> (this folder's parent) and the AceCommander Modernization Plan. Moved from
> `_Planning/Repositories/Ace/old Ace architecture-overview.md`.

> **Status:** Current as of March 2026.
> **Related documents:** [Overview.MD](Overview.MD) · [Architecture.MD](Architecture.MD) · [BuildingNotes.MD](BuildingNotes.MD) · [Goals.md](Goals.md)
> **Architecture diagram:** [architecture-overview.drawio](architecture-overview.drawio)

---

## 1. Executive Summary

ACE (AceCommander) is a self-hosted, peer-to-peer computing agent designed to run continuously on every machine it is installed on. Each instance acts as both a server and a node in a mesh of co-operating agents. Humans interact with an agent through a Blazor WebAssembly GUI served by the agent itself. Agents expose RESTful and message-queue APIs; the set of available APIs grows as plugins are loaded.

**Key components:**

- **Agent host** — .NET Core generic host (Kestrel or IIS in-process) embedding a ServiceStack application host.
- **BaseServices** — always-present core API layer (heartbeat, geo-location, long-running-task management, authentication/authorization, computer-inventory).
- **Plugins** — drop-in domain modules (GUIServices, AMQPServices, DiskAnalysisServices, MinerServices, RealEstateServices) loaded at startup.
- **Blazor WebAssembly GUI** — browser-based UI served as static files by the GUIServices plugin.
- **External runtime services** — Redis (cache/key-value store), MySQL (relational persistence), RabbitMQ (AMQP messaging).
- **ATAP.Utilities** — shared .NET Standard/Core utility library assemblies (serialization, enumeration helpers, concurrent observable collections, typed GUIDs, HTTP gateways, and more).
- **Database artifacts** — MySQL schema scripts, Liquibase changelogs, ServiceStack OrmLite-backed auth schema.
- **Build tooling** — custom MSBuild tasks (`ATAP.Utilities.BuildTooling.CSharp`), MSBuild Community Tasks, assembled under `.build/`.

**Modernization goal:** The original design assumed a handful of simultaneous users. The target modernization state is approximately 1,000 concurrent users. Section 8 catalogs the gaps between those two operating points.

---

## 2. High-Level System Overview

### 2.1 What the system does

An ACE agent node:

1. Listens on a configured TCP port (Kestrel) and exposes HTTP/REST endpoints.
2. Optionally participates in a RabbitMQ message bus (AMQPServices plugin).
3. Periodically samples local hardware state (DiskAnalysisServices, MinerServices).
4. Integrates with external web services (Google Maps geo-coding, real-estate data APIs).
5. Serves its own Blazor WebAssembly GUI as static files.
6. Long-running background tasks are managed and monitored via a timer-driven polling loop.
7. Nodes can be extended simply by adding plugin assemblies to the working directory and restarting.

### 2.2 Major runtime components

| Component        | Technology                           | Responsibility                                                |
| ---------------- | ------------------------------------ | ------------------------------------------------------------- |
| **Agent.Host**   | .NET Core, `IHost`, Kestrel / IIS    | Process entry point, generic host, web server, DI root        |
| **SSAppHost**    | ServiceStack `AppHostBase`           | ServiceStack middleware, route registration, plugin lifecycle |
| **BaseServices** | ServiceStack services                | Core APIs always available regardless of plugin load          |
| **Plugins**      | ServiceStack `IPlugin`               | Domain-specific APIs and background work                      |
| **GUI**          | Blazor WebAssembly (preview-era SDK) | Browser SPA, communicates with agent over HTTP                |
| **Redis**        | StackExchange / ServiceStack.Redis   | Cache, runtime key-value config, long-running task state      |
| **MySQL**        | ServiceStack OrmLite                 | Relational persistence (auth, disk info, etc.)                |
| **RabbitMQ**     | ServiceStack.RabbitMq                | Async AMQP messaging between agent nodes                      |

### 2.3 Main data and control flows

```text
Browser
  │  HTTP/REST + static-file delivery
  ▼
Agent.Host (Kestrel)
  │  ASP.NET Core pipeline
  ▼
SSAppHost (ServiceStack middleware)
  ├─► BaseServices  ─────────────►  Redis (cache)
  │                                 MySQL (OrmLite)
  ├─► GUIServicesPlugin ──────────► FileSystem (static GUI files)
  ├─► AMQPServicesPlugin ─────────► RabbitMQ (IMessageService)
  ├─► DiskAnalysisServicesPlugin ─► FileSystem (disk scan)
  ├─► MinerServicesPlugin ────────► GPU / miner child processes
  └─► RealEstateServicesPlugin ───► External REST APIs
```

---

## 3. Codebase Organization

### 3.1 Repository layout

```text
AceAgent.sln                   Solution file (46 C# projects)
Ace.code-workspace             VS Code multi-root workspace
Directory.Build.props          Solution-wide MSBuild defaults
Directory.Build.targets        Custom build targets
.build/                        Custom MSBuild tasks & tooling
Agent/                         Agent host + BaseServices + all plugins
  Agent.Host/                  Entry point, host builder, SSAppHost
  Agent.BaseServices.*/        Core service DTOs, logic, data
  Agent.Host.StringConstants/  Compile-time string keys
  Plugins/
    GUIServices/               Static file serving + GUI verification API
    AMQPServices/              RabbitMQ integration
    DiskAnalysisServices/      File system analysis
    MinerServices/             GPU miner management
    RealEstateServices/        External property-search integration
GUI/                           Blazor WebAssembly client (GUI.csproj)
ATAP.Utilities/                Shared .NET Standard utility assemblies
Database/                      SQL scripts, Liquibase changelogs
Doc/                           Documentation (this file and others)
Releases/ and ProductionReleases/  Deployment artifact trees
```

### 3.2 C# project naming conventions

Each plugin domain follows a consistent six-assembly pattern:

| Suffix             | Role                                                                |
| ------------------ | ------------------------------------------------------------------- |
| `.Models`          | ServiceStack DTO request/response classes with `[Route]` attributes |
| `.Interfaces`      | ServiceStack service implementations (business logic)               |
| `.Data`            | Runtime data structures, DI-registered singletons                   |
| `.Shared`          | Types shared between the GUI client and the server                  |
| `.StringConstants` | Compile-time string constants for config keys and route strings     |
| `.Plugin`          | `IPlugin` entry point; builds config, wires DI, registers services  |

### 3.3 SQL artifacts

- `Database/CreateDiskInfoDBMaster.sql` — master DDL bootstrap script.
- `Database/Liquibase/DBChangeLog For MySQL.xml` — Liquibase change log (currently minimal scaffold).
- `Database/Liquibase/DBChangeLog For AceCommanderSQLDB.xml` — second Liquibase change log.
- `Database/SchemaDumpFiles/*.sql` — ServiceStack auth schema exports (`userauth`, `userauthdetails`, `userauthrole`, routines).
- `Database/DataDumpFiles/*.sql` — matching data dump set.

Deployment: scripts are applied manually or via Liquibase. No automated migration runner is wired into the application startup path.

### 3.4 ATAP.Utilities assemblies

These are MIT-licensed utility packages embedded directly in the monorepo:

- `ATAP.Utilities` — general helpers.
- `ATAP.Utilities.ConcurrentObservableCollections` — thread-safe reactive collections used for plugin data.
- `ATAP.Utilities.Enumerations` + `ATAP.Utilities.IJSON.*` — enumeration helpers and JSON abstractions.
- `ATAP.Utilities.ServiceStack.IInterfaces` — shared ServiceStack interface helpers.
- `ATAP.Utilities.ServiceStack.ORM.SQLServer` — SQL Server ORM helper (currently targeted at MySQL at runtime).
- `ATAP.Utilities.Shared` / `ATAP.Utilities.StringConstants` — shared constants and base types.

### 3.5 Build tooling

`Directory.Build.props` wires in:

- **MSBuild Community Tasks** from `.build/MSBuildTasks.*/`.
- **ATAP.Utilities.BuildTooling.CSharp** tasks from `.build/ATAP.Utilities.BuildTooling.0.1.0.1/build/`.
- Solution-wide `LangVersion=8.0` and `TargetFramework=netstandard2.1` defaults (overridden per project).
- Custom assembly versioning via a `VersionFile` property pointing to `properties/AssemblyInfo.cs` in each project.
- NuGet local feed path fallback to `C:\Dropbox\NuGetLocalFeed`.

---

## 4. Configuration Pipeline and Environment Routing

The configuration system uses a deliberate two-pass "extended route" pattern to handle environment-specific overrides correctly.

### 4.1 Pass 1 — Initial (environment-agnostic) configuration

In `Program.Main`, an `initialGenericHostConfigurationBuilder` is constructed with these sources, **lowest to highest priority**:

1. Compiled-in production defaults (`GenericHostDefaultConfiguration.Production` dictionary).
2. `genericHostSettings.json` from the current working directory (optional).
3. Environment variables prefixed with `ASPNETCORE_`.
4. Environment variables prefixed with the custom ACE prefix.
5. Command-line arguments (with short-form switch mappings, e.g., `-C` → `ConsoleApp`).

### 4.2 Environment evaluation

The initial configuration root is built (`.Build()`) and queried for `EnvironmentConfigRootKey`. This value identifies the runtime environment (currently `Development` or `Production`).

### 4.3 Pass 2 — Environment-specific configuration (non-Production only)

If the environment is not `Production`, the builder is reconstructed, inserting additional providers between the base JSON file and the env-var providers:

- Environment-specific JSON file: `genericHostSettings.<env>.json`.
- In `Development`, user secrets (identified by `userSecretsID = "E5D6C5E5-..."`) are added to the **web host** configuration builder.

The final `IConfigurationRoot` passes into `CreateSpecificHostBuilder(...)`.

### 4.4 Web host and app configuration

`CreateSpecificHostBuilder` layers further providers via `.ConfigureAppConfiguration`:

- Compiled-in production defaults (again).
- `webHostSettings.json` (optional).
- `webHostSettings.<env>.json` (optional).
- `ASPNETCORE_` and custom-prefix environment variables.
- Command-line arguments.

### 4.5 ServiceStack (SSAppHost) configuration — Pass 3

`SSAppHost.Configure` builds a `MultiAppSettingsBuilder` for ServiceStack's `IAppSettings`, adding (lowest to highest priority):

1. `SSAppHostDefaultConfiguration.Production` (compiled-in dictionary).
2. `BaseServicesDefaultConfiguration.Production` (compiled-in dictionary).
3. `SSAppHost.Settings.txt` (production text file, optional).
4. `SSAppHost.Settings.<env>.txt` (env-specific text file, non-Production only).
5. `Agent.Settings.txt` (production text file, optional).
6. `Agent.Settings.<env>.txt` (env-specific text file, non-Production only).
7. Environment variables (via `AddEnvironmentalVariables`).
8. The generic host `IConfiguration` (via `AddNetCore`), giving generic-host providers the highest priority in the SS layer.

### 4.6 Plugin configuration — Pass 4

Each plugin's `BeforePluginsLoaded` / `Configure` method builds its own `MultiAppSettingsBuilder`:

1. Plugin's compiled-in `DefaultConfiguration.Production` dictionary (lowest priority).
2. `<PluginName>.Settings.txt` (production text file, optional).
3. `<PluginName>.Settings.<env>.txt` (env-specific text file, non-Production only).
4. Environment variables (highest priority in the plugin layer).

Plugin configuration is then compared against Redis cache keys (`<namespace>.Config.*`). Missing cache keys are back-filled from the app settings. This allows runtime operator overrides stored in Redis to win over file-based config, but allows file defaults to populate the cache on first run.

### 4.7 Supported environments

Only `Development` and `Production` are fully handled. Any other value throws `NotImplementedException`. This is a hard constraint on environment extensibility.

### 4.8 External service connection strings (compiled-in production defaults)

| Key                                                      | Default value                    |
| -------------------------------------------------------- | -------------------------------- |
| `Ace.Agent.BaseServices.Config.RedisConnectionString`    | `localhost:6379`                 |
| `Ace.Agent.BaseServices.Config.MySqlConnectionString`    | `Server=localhost;Port=3306;...` |
| `Ace.Agent.BaseServices.Config.MSSQLConnectionString`    | `localhost:6339TBD`              |
| `Ace.Agent.BaseServices.Config.RabbitMQConnectionString` | `localhost:TBD`                  |

All defaults are `localhost`, making the system single-machine by default.

---

## 5. Plugin and Child-Process Model

### 5.1 Plugin discovery and loading

Plugin loading is **hardcoded** in `SSAppHost.Configure`:

```csharp
var plugInList = new List<IPlugin>() {
    new GUIServicesPlugin(),
    new RealEstateServicesPlugin(),
    new MinerServicesPlugin(),
    new DiskAnalysisServicesPlugin(),
};
foreach (var pl in plugInList) { Plugins.Add(pl); }
```

The AMQP plugin exists in source but is not included in the live list. There is no runtime assembly discovery or folder-scanning; plugins must be referenced at compile time. The code contains `ToDo` comments describing the intended future model: probing named folders for assemblies implementing `IPlugin`, verifying SHA-based authenticity, and loading dynamically.

### 5.2 Plugin contracts

Every plugin implements `ServiceStack.IPlugin` (`Register(IAppHost)`) and optionally `IPreInitPlugin` (`BeforePluginsLoaded`) and/or `IPostInitPlugin`. ServiceStack calls these hooks in sequence during `AppHost.Configure`.

### 5.3 Plugin lifecycle

For each plugin (pattern observed across all five current plugins):

1. **`BeforePluginsLoaded`** (or `Configure` for AMQP):
   a. Resolve `IHostEnvironment` from the ServiceStack container.
   b. Build plugin `IAppSettings` via `MultiAppSettingsBuilder` (see §4.6).
   c. Compare config keys against Redis cache; back-fill missing keys.
   d. Construct the plugin's data object.
   e. Register the data object in the ServiceStack Funq container.
   f. Register plugin-specific services and message handlers.

2. **`Register`**: ServiceStack calls `appHost.RegisterService<TService>()` to add the plugin's HTTP service to the routing table.

3. **Runtime**: The plugin data object lives as a singleton in the Funq container for the process lifetime. Concurrent observable collections in plugin data fire `NotifyCollectionChanged`/`PropertyChanged` events; event handlers (e.g., in MinerServices) log the changes and are intended to dispatch Server-Sent Events (SSE) to subscribers (SSE delivery is stubbed in current code).

### 5.4 Child processes

MinerServices is the primary plugin that manages external child processes (GPU miners). The plugin data structures include configuration for starting, stopping, listing, and tuning miners via routes `/StartMiner`, `/StopMiner`, `/ListMiner`, `/StatusMiners`, `/TuneMinerGPU`. External miner executables are launched as OS child processes from the plugin's service implementations.

DiskAnalysisServices triggers file-system walk operations (routes `/AnalyzeFileSystem`, `/AnalyzeDiskDrive`) that may run asynchronously and are tracked via the long-running tasks system.

### 5.5 Runtime data areas

The long-running-task infrastructure (in `BaseServicesData`) maintains:

- A `Dictionary<string, Timer>` for scheduled callbacks, registered in the Funq container.
- A `Dictionary<TypedGuid, ILongRunningTask>` for tracking in-flight background operations.

A polling timer fires every 10 seconds to check long-running task status. There is no explicit per-plugin working-directory or scratch-folder convention in current code; file paths are derived from the current working directory of the host process.

---

## 6. Key Architectural and Design Concepts

### 6.1 Architectural patterns

- **Plugin/extension architecture**: all domain features are isolated in plugin assemblies; the host provides only infrastructure.
- **Layered DI with IoC container hand-off**: .NET Core DI (generic host) bridges into ServiceStack's Funq container. Objects registered in Funq are available to all ServiceStack services and plugins.
- **DTO-first API design**: `[Route]` attributes live on request/response DTO classes in `.Models` projects, separated from service logic in `.Interfaces` projects. This allows the GUI to share the DTO assembly directly (`.Shared` projects compiled to `netstandard2.0`).

### 6.2 WASM client interaction with server

- **API style**: REST over HTTP using ServiceStack's routing DSL. Routes are plain-text URL patterns on request DTOs.
- **Serialization**: ServiceStack's built-in JSON serializer (backed by `ServiceStack.Text`) for HTTP responses; the GUI uses `ServiceStack.Interfaces` assembly to share DTO types.
- **Authentication/Authorization**: ServiceStack Auth (`IAuthRepository`, `UserAuth`, `UserAuthDetails`, `UserAuthRole` tables) backed by MySQL OrmLite. The `BaseServicesData` constructor calls `ConstructAuthenticationData` and `ConstructAuthorizationData`.
- **State management**: The client uses `Blazored.LocalStorage` for browser-side persistence. No server-side session state is explicitly maintained; Redis is used as a distributed cache, not a session store.
- **Client logging**: `Blazor.Extensions.Logging.BrowserConsoleLogger` writes to the browser console.

### 6.3 Data access patterns

- **ServiceStack OrmLite**: thin ORM over ADO.NET, mapping POCOs to database tables. Auth schema tables are defined by ServiceStack conventions.
- **Redis via ServiceStack.Redis**: `IRedisClientsManager` / `ICacheClient` interface used for name-value pair caching and config key storage.
- **Direct SQL**: `Database/CreateDiskInfoDBMaster.sql` uses raw DDL; no EF Core or migration CLI tooling is wired into the startup path.

### 6.4 Cross-cutting concerns

| Concern               | Mechanism                                                                                                     |
| --------------------- | ------------------------------------------------------------------------------------------------------------- |
| Logging               | Serilog (static `Log.*`) with Seq sink (development), structured log context, thread-id enrichment            |
| IL-weaving/AOP        | `MethodBoundaryAspect.Fody` — weaves method-entry/exit tracing at compile time                                |
| ETW tracing           | `ATAP.Utilities.ETW.ATAPUtilitiesETWProvider` and `[ETWLogAttribute]` custom attribute                        |
| Error handling        | Explicit `try/catch` blocks in constructor-level infrastructure code; no global exception middleware observed |
| CORS                  | Enabled via `appHost.Plugins.Add(new CorsFeature(...))` in `BaseServicesData` constructor                     |
| ServiceStack metadata | Disabled via `appHost.Plugins.RemoveAll(p => p is MetadataFeature)` to reduce attack surface                  |

### 6.5 Gateway abstraction

`BaseServicesData` constructs a `MultiGatewaysBuilder` to manage outbound HTTP gateway entries (e.g., Google Maps GeoCode). Each gateway entry records name, relative URI, request payload type, and response payload type.

---

## 7. Salient Features and Domain Concepts

### 7.1 Domain areas

| Domain                  | Plugin               | Key entities                                                  |
| ----------------------- | -------------------- | ------------------------------------------------------------- |
| Infrastructure / Health | BaseServices         | Heartbeat, computer inventory, long-running tasks, auth/authz |
| GUI delivery            | GUIServices          | Virtual-path static file serving, Blazor SPA redirect         |
| Messaging               | AMQPServices         | RabbitMQ connection, message handler registration             |
| Storage analysis        | DiskAnalysisServices | File-system tree walk, disk drive scan, monitoring            |
| Miner management        | MinerServices        | GPU miner child-process lifecycle, tuning                     |
| Real estate data        | RealEstateServices   | Property search, external API key management                  |

### 7.2 Computer inventory model

`BaseServicesData` constructs a local computer inventory on startup (CPU, memory, disks, video cards, installed software/drivers, miner programs). This snapshot is held in RAM and exposed via configuration/user-data APIs.

### 7.3 Reputation and game features

The `Overview.MD` and `Goals.md` documents describe a vision for a peer reputation system and cooperative game built on top of the agent mesh. No concrete implementation of this was observed in the current source code; these remain aspirational goals.

### 7.4 Long-running task management

BaseServices exposes `/GetLongRunningTasksStatus` and `/GetLongRunningTasksList`. Background operations initiated by any plugin register a `TypedGuid`-keyed entry in the long-running-task dictionary. The 10-second polling timer checks task state and is intended to forward status via SSE to connected GUI clients (SSE delivery is not yet implemented).

---

## 8. Legacy, Obsolete Practices, and Modernization Considerations

### 8.1 Obsolete and homegrown mechanisms

#### 8.1.1 Hand-rolled `MultiAppSettingsBuilder` / two-pass config

**What it does:** Implements a layered configuration system by manually building multiple `IAppSettings` instances (ServiceStack's abstraction), merging them in priority order. A separate two-pass pattern in `Program.Main` re-evaluates the environment before finalizing the generic-host `IConfigurationRoot`.

**Why it existed:** ServiceStack's `IAppSettings` pre-dates the `Microsoft.Extensions.Configuration` pipeline. At the time of writing, no single unified configuration abstraction was available across SS and .NET Core.

**Modern equivalent:** `Microsoft.Extensions.Configuration` with `IConfiguration` / `IOptions<T>`. The generic host already builds a fully-featured `IConfigurationRoot` before `SSAppHost.Configure` runs; the SS layer could simply call `AddNetCore(Configuration)` as the sole provider. The two-pass environment-routing logic could be replaced by `ASPNETCORE_ENVIRONMENT` (standard .NET Core env selection) or a custom configuration provider.

**Coupling:** Mostly infrastructural. Business logic is not tightly coupled to the `MultiAppSettingsBuilder` directly; plugins receive `IAppSettings` interfaces.

---

#### 8.1.2 Funq for dependency injection

**What it does:** ServiceStack's built-in Funq IoC container is used as the primary DI container for all service and plugin object registration.

**Why it existed:** Funq was ServiceStack's bundled container before .NET Core's `IServiceCollection` ecosystem matured.

**Modern equivalent:** `Microsoft.Extensions.DependencyInjection` (`IServiceCollection`) with the `UseServiceStack` integration bridge (already present for the generic host). SS v5+ supports using the host's DI container instead of Funq via `HostContext.AppHost.UseNetCoreDI()`.

**Coupling:** Moderate. All plugin constructors and `BaseServicesData` use `Container.Resolve<T>()` / `Container.Register<T>()` directly.

---

#### 8.1.3 Redis-backed configuration cache sync

**What it does:** On startup, each plugin iterates its config keys, queries Redis for matching keys (`GetKeysStartingWith`), and fills gaps. This creates a shadow copy of configuration in Redis that can be read or modified at runtime.

**Why it existed:** Provides an operator override mechanism without requiring a restart; also allows multiple agent nodes to share configuration via Redis.

**Modern equivalent:** `IOptionsMonitor<T>` with a custom configuration provider backed by Redis (e.g., `StackExchange.Redis` + a custom `IConfigurationSource`). Or a proper distributed config store (e.g., Consul, Azure App Configuration).

**Coupling:** Tightly coupled to Redis being available on startup — the `BaseServicesData` constructor throws if the Redis connection fails.

---

#### 8.1.4 Hardcoded plugin list

**What it does:** `SSAppHost.Configure` instantiates plugins with `new GUIServicesPlugin()`, etc., in a `List<IPlugin>`.

**Why it existed:** Simplest possible plugin loading; avoids assembly-scanning complexity.

**Modern equivalent:** Assembly scanning in a designated folder (e.g., using `AssemblyLoadContext` + reflection), with each candidate checked for `IPlugin` implementation and optionally verified by hash. .NET 6+ `AssemblyDependencyResolver` helps with context isolation.

**Coupling:** Every plugin must be referenced at compile time; adding a new plugin requires recompiling and redeploying the host.

---

#### 8.1.5 `MethodBoundaryAspect.Fody` IL weaving

**What it does:** Weaves method entry/exit logging at compile time across nearly all assemblies.

**Why it existed:** No AOP support existed natively in .NET at the time; Fody was a widely used compile-time weaver.

**Modern equivalent:** `Microsoft.Extensions.Logging` with `LoggerMessage` source generators, or `System.Diagnostics.Activity` / OpenTelemetry for distributed tracing.

**Coupling:** Compile-time dependency only; removing it requires updating `.csproj` and `FodyWeavers.xml` files per project.

---

#### 8.1.6 Topshelf (historical) / Windows Service via generic host

The documentation references Topshelf for Windows Service hosting. The current code uses the .NET Core `IHost` with `UseWindowsService()` or `UseSystemd()` patterns, which is the current standard.

---

#### 8.1.7 System.Timers.Timer for background work

**What it does:** A `System.Timers.Timer` fires every 10 seconds to poll long-running task status. Plugin data objects use event handlers on `ConcurrentObservableCollections` for change notification.

**Why it existed:** Background task management was not standardized before `IHostedService` / `BackgroundService`.

**Modern equivalent:** `IHostedService` / `BackgroundService` from `Microsoft.Extensions.Hosting`, with `PeriodicTimer` (available in .NET 6+) for clean, cancellation-aware polling loops.

**Coupling:** Infrastructural; polling callback references `BaseServicesData` and logs to Serilog.

---

#### 8.1.8 Preview-era Blazor WebAssembly SDK

**What it does:** `GUI/GUI.csproj` references preview-era Blazor packages (circa Blazor 0.x / early 2019).

**Why it existed:** Blazor as a production-ready framework did not exist at the time of the initial implementation.

**Modern equivalent:** Blazor WebAssembly shipped as a production feature in .NET 5 (May 2020). The GUI project should be migrated to the standard `Microsoft.AspNetCore.Components.WebAssembly` SDK targeting .NET 7 or later.

**Coupling:** The Blazor bootstrap code itself is a small shim; the component hierarchy and DTO-sharing model (`.Shared` projects) are largely compatible with the modern SDK. However, the `ILLinker` step referenced in `BuildingNotes.MD` is now the standard .NET trimmer.

---

### 8.2 Scalability and multi-user concerns

#### 8.2.1 Redis availability as a hard startup dependency

The `BaseServicesData` constructor throws immediately if Redis is unreachable. In a scaled-out deployment with multiple host processes, every process requires its own Redis connection on startup. **Risk:** Redis becomes a single point of failure and a potential bottleneck for config and caching under 1,000 users. A Redis Sentinel or Redis Cluster topology would be required; the current connection string is a single `localhost:6379`.

#### 8.2.2 `localhost`-only default service endpoints

All default connection strings point to `localhost` (Redis, MySQL, RabbitMQ). **Risk:** Horizontal scaling (multiple agent instances) is not supported by the defaults. No service-discovery or load-balancer integration exists. Modernization must externalize connection strings and introduce DNS-based or environment-variable-based service discovery.

#### 8.2.3 Synchronous I/O in Kestrel

`CreateSpecificHostBuilder` sets `options.AllowSynchronousIO = true` as a workaround for ServiceStack writing synchronously to the response body. **Risk:** Synchronous I/O blocks Kestrel I/O threads under load. At 1,000 users, this can cause thread-pool starvation. The correct fix is to update ServiceStack to its async response-writing path (SS v5.9+ uses async by default) and remove the `AllowSynchronousIO` override.

#### 8.2.4 Funq singleton data objects per process

All plugin and BaseServices data objects are registered as singletons in Funq. Plugin data includes mutable `ConcurrentObservableDictionary` instances that fire events synchronously on the writing thread. **Risk:** Under concurrent load, event-handler callbacks (even if they only log) serialize writers. At 1,000 users triggering DiskAnalysis or MinerServices concurrently, per-write event firing could become a throughput bottleneck.

#### 8.2.5 File-system paths derived from current working directory

Plugin configuration text files, gateway configuration, and static GUI files are resolved relative to `Directory.GetCurrentDirectory()`. **Risk:** Horizontal scaling with shared storage requires that all instances see the same working directory, which constrains deployment topology (shared network drive or identical local copies). Container-based deployments require explicit volume mounts.

#### 8.2.6 Long-running tasks tracked in an in-memory dictionary

`BaseServicesData` maintains the long-running task dictionary in process memory. **Risk:** If the process is restarted or if tasks are initiated on one instance and status is queried on another, the dictionary will not contain the task entry. At 1,000 users with multiple instances, this will silently lose task state. A shared backing store (e.g., Redis, a database table) is required for multi-instance deployments.

#### 8.2.7 One `System.Timers.Timer` per process for all task polling

The single 10-second timer polls all long-running tasks for all users. **Risk:** As the number of long-running tasks grows linearly with users (e.g., each DiskAnalysis request is a long-running task), the timer callback does more work per tick. Under 1,000 users this could cause the callback to take longer than 10 seconds, causing timer drift or task-check back-pressure. Moving to `IHostedService` with a `Channel<T>` or event-driven completion callbacks would decouple polling overhead from user count.

#### 8.2.8 Hardcoded plugin list requires recompile to change feature set

Adding or removing a plugin requires modifying `SSAppHost.cs`, recompiling, and redeploying. **Risk:** In a multi-node mesh, deploying a plugin update requires coordinated rolling restarts across all nodes. Dynamic/discovery-based plugin loading (see §8.1.4) would allow per-node plugin configuration without recompilation.

#### 8.2.9 No health-check or readiness endpoints

There are no standard `/health` or `/ready` endpoints that an orchestrator (Kubernetes, Azure App Service) can probe. The `/isAlive` BaseServices route exists but requires application startup to complete (including Redis) before returning. **Risk:** Orchestrators cannot distinguish between a starting, initializing, and a failed node.

#### 8.2.10 Authentication backed by MySQL with no connection pooling configuration

ServiceStack OrmLite connects to MySQL for auth. No explicit connection pooling limits are set. **Risk:** Under 1,000 concurrent authenticated users, MySQL max-connection limits (default 151 for MySQL Community) could be exhausted, causing auth failures. Connection pooling configuration and potentially a read replica for auth lookups would be required.

---

## 9. Architecture Diagram

The file [architecture-overview.drawio](architecture-overview.drawio) contains the Draw.io architecture diagram for this system. Open the `.drawio` file with the Draw.io VS Code extension or at [app.diagrams.net](https://app.diagrams.net).

### 9.1 What the diagram shows

The diagram is organized into four horizontal swim-lanes:

1. **Browser / Client lane** — the Blazor WebAssembly application running in the end-user's browser. Shows HTTP REST requests to the agent and static-file delivery from GUIServices.

2. **Agent Host lane** — the .NET Core generic host, Kestrel web server, and the ServiceStack `SSAppHost` middleware layer. Includes the `BaseServices` data singleton and the plugin host. Each plugin is shown as a separate box. The RabbitMQ IMessageService connection is shown leaving this lane to the external services lane.

3. **External Services lane** — Redis (cache + config overlay), MySQL (auth + relational persistence), and RabbitMQ (AMQP bus). These are depicted as cylinders/database icons to distinguish them from in-process components.

4. **Runtime Data lane** — shows the long-running task dictionary (in-memory, per-process), the plugin data singletons (ConcurrentObservableDictionary instances), and the local filesystem (static GUI files, config text files, miner executables).

**Scaling annotations on the diagram:**

- Agent Host instances are shown as replicable (dashed boundary), with a note that all replicas currently require the same working-directory content.
- Redis, MySQL, and RabbitMQ are shown as single nodes with a "single point of failure / bottleneck" annotation, reflecting the current `localhost`-only configuration.
- The long-running task dictionary is marked "per-process, not shared" to flag the multi-instance state isolation risk.
