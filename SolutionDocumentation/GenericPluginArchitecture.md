# Generic Plugin Architecture for ATAP.Utilities

> **Status:** Architecture specification, April 2026
> **Related documents:** [SecretsPluginArchitecture.md](SecretsPluginArchitecture.md) - [PLugin Creation Prompt.md](PLugin%20Creation%20Prompt.md) - [architecture-overview.md](architecture-overview.md)
> **Primary source packages:** `ATAP.Utilities.Plugin`, `ATAP.Utilities.Loader`, `ATAP.Utilities.Serializer` (reference implementation)
> **Legacy reference:** [Ace PluginArchitecture.md](../../Ace/Doc/PluginArchitecture.md)

---

## 1. Goals and Non-Goals

### Goals

1. **Dual consumption** -- every plugin-capable package works both as a normal project/package reference AND as a dynamically loaded plugin at runtime.
2. **Plugin families** -- groups of interchangeable implementations behind a shared interface (Serializers, Secrets, MessageQueue, Testing, etc.).
3. **Hot-swap and collectible unload** -- plugins load into collectible `AssemblyLoadContext` instances that can be unloaded and garbage-collected.
4. **Security** -- plugins are opaque to the host; data crosses the boundary only via agreed-upon DTOs (deep-copied); sensitive data is zeroed on unload.
5. **Observable data (IData)** -- plugins expose selected internal data structures through a read-only, change-notifying interface that hosts can DI-inject and observe.
6. **Configuration layering** -- host configuration flows into the plugin, which can augment it with its own defaults and runtime overrides.
7. **PowerShell compatibility** -- plugin families can be consumed from PowerShell modules with cmdlet wrappers.

### Non-Goals

- This architecture does NOT use ServiceStack. The Ace legacy architecture used ServiceStack's `IPlugin`, `IAppHost`, and `ICacheClient`. The new architecture uses only .NET standard libraries and Microsoft.Extensions.\*.
- This architecture does NOT require Redis. Config storage is pluggable via `IPluginConfigStore`, defaulting to in-memory with JSON file persistence.
- This architecture does NOT mandate a specific UI framework. Observable data via IData can be consumed by Blazor, WPF, console, or PowerShell hosts equally.

---

## 2. Foundational Concepts

### 2.1 Plugin Family

A **plugin family** is a group of packages that implement the same abstract interface. The host codes against the family interface; the specific implementation is selected at configuration time (static reference) or discovered at runtime (dynamic loading).

```
Plugin Family: Secrets
  Interface: ISecretsAbstract
  Implementations:
    - ATAP.Utilities.Secrets.Shim.Bitwarden     (Bitwarden vault via bw CLI)
    - ATAP.Utilities.Secrets.Shim.AzureKeyVault  (future)
    - ATAP.Utilities.Secrets.Shim.HashiCorpVault  (future)

Plugin Family: Serializer
  Interface: ISerializerAbstract
  Implementations:
    - ATAP.Utilities.Serializer.Shim.SystemTextJson
    - ATAP.Utilities.Serializer.Shim.Newtonsoft
    - ATAP.Utilities.Serializer.Shim.ServiceStack
```

### 2.2 Shim

A **shim** is the bridge between a concrete implementation library and the generic plugin interface. Every plugin implementation ships a shim assembly that:

1. Implements the family interface (e.g., `ISecretsAbstract`)
2. Wraps library-specific options in the family's `IOptionsAbstract.ShimSpecificOptions` property
3. Optionally implements `IPluginShim<T>` for lifecycle management
4. Optionally implements `ILoadDynamicSubModules` for hierarchical sub-module loading

### 2.3 Dual Consumption Modes

| Mode                                   | Mechanism                                                                                                                                                        | When to use                                                                                   |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| **Static (project/package reference)** | Normal `<ProjectReference>` or `<PackageReference>` in .csproj. Implementation registered in DI via extension method (e.g., `services.AddBitwardenSecrets()`).   | Compile-time known implementation. Simplest approach.                                         |
| **Dynamic (plugin loading)**           | `Loader<TInterface>` discovers assemblies via glob patterns, loads them into a collectible `AssemblyLoadContext`, instantiates the shim, and registers it in DI. | Runtime-selectable implementation. Hot-swap scenarios. Configuration-driven plugin selection. |

Both modes result in the same `TInterface` being available in the DI container. Consuming code is identical regardless of how the implementation was loaded.

---

## 3. Core Interfaces

### 3.1 Package: ATAP.Utilities.Plugin.Interfaces

```csharp
namespace ATAP.Utilities.Plugin;

/// <summary>
/// Metadata describing a discovered or loaded plugin.
/// </summary>
public interface IPluginMetadata
{
    /// <summary>Reverse-DNS identifier, e.g. "atap.secrets.bitwarden".</summary>
    string PluginId { get; }

    /// <summary>Human-readable display name.</summary>
    string DisplayName { get; }

    /// <summary>Plugin assembly version.</summary>
    Version Version { get; }

    /// <summary>The family interface this plugin implements (e.g. typeof(ISecretsAbstract)).</summary>
    Type FamilyInterface { get; }
}

/// <summary>
/// Plugin lifecycle state machine.
/// </summary>
public enum PluginState
{
    Discovered,
    Loaded,
    Configured,
    Active,
    Deactivating,
    Unloaded
}

/// <summary>
/// Lifecycle management for a loaded plugin instance.
/// </summary>
public interface IPluginLifecycle
{
    PluginState State { get; }
    Task InitializeAsync(IConfiguration pluginConfiguration, CancellationToken cancellationToken = default);
    Task ActivateAsync(CancellationToken cancellationToken = default);
    Task DeactivateAsync(CancellationToken cancellationToken = default);
    Task UnloadAsync(CancellationToken cancellationToken = default);
}

/// <summary>
/// Generic plugin shim contract. TFamilyInterface is the family's abstract interface
/// (e.g. ISecretsAbstract, ISerializerAbstract).
/// </summary>
public interface IPluginShim<TFamilyInterface> : IPluginMetadata, IPluginLifecycle
{
    /// <summary>Returns the concrete service implementing TFamilyInterface.</summary>
    TFamilyInterface GetService();

    /// <summary>Registers the plugin's services into the host DI container.</summary>
    void RegisterServices(IServiceCollection services);
}

/// <summary>
/// Read-only, observable view of plugin internal data.
/// Wraps ConcurrentObservableDictionary with deep-copy semantics across ALC boundaries.
/// </summary>
public interface IPluginData
{
    /// <summary>Read-only snapshot of the plugin's exposed data.</summary>
    IReadOnlyDictionary<string, object> DataStore { get; }

    /// <summary>Observable stream of data change notifications.</summary>
    IObservable<PluginDataChangedEventArgs> DataChanged { get; }
}

/// <summary>
/// Event args for plugin data changes. Contains deep-copied values.
/// </summary>
public class PluginDataChangedEventArgs : EventArgs
{
    public string Key { get; init; }
    public object? OldValue { get; init; }
    public object? NewValue { get; init; }
    public PluginDataChangeKind ChangeKind { get; init; }
}

public enum PluginDataChangeKind
{
    Added,
    Updated,
    Removed,
    Cleared
}

/// <summary>
/// Manages a plugin family: discovery, loading, activation, and unloading.
/// </summary>
public interface IPluginFamily<TInterface>
{
    string FamilyName { get; }
    IReadOnlyList<IPluginMetadata> DiscoveredPlugins { get; }
    IPluginShim<TInterface>? ActivePlugin { get; }

    Task DiscoverAsync(CancellationToken cancellationToken = default);
    Task<IPluginShim<TInterface>> LoadAsync(string pluginId, CancellationToken cancellationToken = default);
    Task UnloadAsync(string pluginId, CancellationToken cancellationToken = default);
}

/// <summary>
/// Abstraction over a key-value configuration store for plugin settings.
/// Replaces the Ace-era Redis ICacheClient dependency.
/// </summary>
public interface IPluginConfigStore
{
    Task<T?> GetAsync<T>(string key, CancellationToken cancellationToken = default);
    Task SetAsync<T>(string key, T value, CancellationToken cancellationToken = default);
    Task<IEnumerable<string>> GetKeysAsync(string prefix, CancellationToken cancellationToken = default);
    Task RemoveAsync(string key, CancellationToken cancellationToken = default);
}
```

### 3.2 Package: ATAP.Utilities.Plugin.Model

Base implementations:

| Class                            | Implements           | Purpose                                                                                                                                               |
| -------------------------------- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PluginShimBase<T>`              | `IPluginShim<T>`     | Abstract base with lifecycle state machine, config binding, DI registration helpers                                                                   |
| `PluginFamilyBase<T>`            | `IPluginFamily<T>`   | Discovery via glob + predicate, manages active plugin, coordinates load/unload                                                                        |
| `PluginDataBase`                 | `IPluginData`        | Wraps `ConcurrentObservableDictionary`, provides deep-copy on `DataStore` access, converts change events to `IObservable<PluginDataChangedEventArgs>` |
| `InMemoryPluginConfigStore`      | `IPluginConfigStore` | `ConcurrentDictionary` backed, with optional JSON file persistence on dispose                                                                         |
| `CollectibleAssemblyLoadContext` | (internal)           | `AssemblyLoadContext` subclass with `isCollectible: true`, shared type resolution, `.deps.json` parsing                                               |

---

## 4. Plugin Lifecycle

### 4.1 State Machine

```
                         +-----------+
                         | Discovered|  (assembly found on disk via glob)
                         +-----+-----+
                               |
                        LoadAsync(pluginId)
                               |
                         +-----v-----+
                         |  Loaded   |  (assembly loaded into CollectibleALC)
                         +-----+-----+
                               |
                    InitializeAsync(config)
                               |
                         +-----v-----+
                         | Configured|  (plugin read its config, built internal state)
                         +-----+-----+
                               |
                       ActivateAsync()
                               |
                         +-----v------+
                         |   Active   |  (serving requests, exposing IPluginData)
                         +-----+------+
                               |
                      DeactivateAsync()
                               |
                       +-------v--------+
                       | Deactivating   |  (flushing state, detaching events)
                       +-------+--------+
                               |
                        UnloadAsync()
                               |
                        +------v------+
                        |  Unloaded   |  (ALC unloaded, sensitive data zeroed)
                        +------+------+
                               |
                          (GC collects)
                               |
                        +------v------+
                        | (Collected) |
                        +-------------+
```

### 4.2 Hot-Swap Sequence

1. `DeactivateAsync()` on current active plugin
2. `UnloadAsync()` on current active plugin (ALC released)
3. `LoadAsync(newPluginId)` for the replacement
4. `InitializeAsync(config)` on the replacement
5. `ActivateAsync()` on the replacement

The `IPluginFamily<T>` base implementation coordinates this atomically.

---

## 5. Assembly Loading Architecture

### 5.1 IAssemblyLoader Abstraction

The existing `Loader<IType>` is tightly coupled to McMaster.NETCore.Plugins. The new design abstracts the assembly loading mechanism:

```csharp
namespace ATAP.Utilities.Loader;

/// <summary>
/// Represents a loaded assembly in an isolated context.
/// </summary>
public interface ILoadedAssemblyContext : IDisposable
{
    Assembly LoadedAssembly { get; }
    bool IsCollectible { get; }
    WeakReference WeakReference { get; }
    void Unload();
}

/// <summary>
/// Abstraction over the mechanism that loads assemblies into isolated contexts.
/// </summary>
public interface IAssemblyLoader
{
    ILoadedAssemblyContext LoadAssembly(
        string assemblyPath,
        Type[] sharedTypes,
        bool isCollectible = true);

    Task UnloadAsync(ILoadedAssemblyContext context);
}
```

### 5.2 Default Implementation: CollectibleAssemblyLoadContext

Uses .NET's built-in `System.Runtime.Loader.AssemblyLoadContext` with `isCollectible: true`:

```csharp
internal class CollectibleAssemblyLoadContext : AssemblyLoadContext
{
    private readonly AssemblyDependencyResolver _resolver;
    private readonly HashSet<string> _sharedTypeAssemblyNames;

    public CollectibleAssemblyLoadContext(string pluginPath, Type[] sharedTypes)
        : base(isCollectible: true)
    {
        _resolver = new AssemblyDependencyResolver(pluginPath);
        _sharedTypeAssemblyNames = sharedTypes
            .Select(t => t.Assembly.GetName().Name!)
            .ToHashSet();
    }

    protected override Assembly? Load(AssemblyName assemblyName)
    {
        // Shared types resolve from the host's default context
        if (_sharedTypeAssemblyNames.Contains(assemblyName.Name!))
            return null; // fallback to Default context

        string? assemblyPath = _resolver.ResolveAssemblyToPath(assemblyName);
        return assemblyPath != null ? LoadFromAssemblyPath(assemblyPath) : null;
    }
}
```

**Key differences from McMaster.NETCore.Plugins:**

- `isCollectible: true` -- assemblies can be GC'd after unload (McMaster did not support this)
- Direct use of `AssemblyDependencyResolver` for `.deps.json` parsing
- Shared types resolved by returning `null` from `Load()` (falls through to default ALC)
- No external NuGet dependency

### 5.3 McMaster Backward Compatibility

An optional `ATAP.Utilities.Loader.Shim.McMaster` package wraps the McMaster `PluginLoader` behind `IAssemblyLoader` for projects that need the old behavior during migration. This is not the recommended path.

### 5.4 Retained Patterns from Existing Loader

The following existing abstractions are retained as-is:

- `IDynamicGlobAndPredicate` -- glob pattern + type predicate pair for assembly/type discovery
- `IDynamicSubModulesInfo` -- glob + action function for sub-module loading
- `ILoadDynamicSubModules` -- interface for types that need to load their own sub-modules (e.g., Serializer.Shim.Plugin loading JsonConverters)

The `Loader<IType>` class retains its three core methods but delegates to `IAssemblyLoader` instead of calling McMaster directly:

| Method                                                       | Purpose                                                         |
| ------------------------------------------------------------ | --------------------------------------------------------------- |
| `LoadExactlyOneInstanceOfITypeFromAssemblyGlob()`            | Load exactly one matching type from discovered assemblies       |
| `LoadExactlyOneInstanceOfITypeFromAssemblyGlobAsSingleton()` | Same, but registers as singleton in IServiceCollection          |
| `LoadAndProcessZeroOrMoreInstanceOfITypeFromAssemblyGlob()`  | Load zero or more matching types, apply action delegate to each |

New method added:
| `LoadAndRegister<TInterface>(glob, services, lifetime)` | Discover, load, and register in DI with specified lifetime |

---

## 6. Security Model

### 6.1 Isolation

Each dynamically loaded plugin runs in its own `CollectibleAssemblyLoadContext`. The host's default ALC contains only:

- The family's Interfaces assembly (shared type)
- The Plugin framework assemblies
- The Loader

Plugin implementation assemblies load in the collectible ALC. They can reference the shared interfaces (which resolve from the default ALC) but cannot access host internals.

### 6.2 Data Exchange

| Direction                        | Mechanism                             | Copy semantics                                |
| -------------------------------- | ------------------------------------- | --------------------------------------------- |
| Host -> Plugin                   | `IConfiguration` section (read-only)  | Immutable config values                       |
| Plugin -> Host (method returns)  | Family interface method return values | Deep-copy via serialization at ALC boundary   |
| Plugin -> Host (observable data) | `IPluginData.DataStore`               | Read-only dictionary with deep-copied values  |
| Plugin -> Host (events)          | `IPluginData.DataChanged`             | Event args contain deep-copied old/new values |

### 6.3 Zero-on-Unload

When `UnloadAsync()` is called:

1. Plugin's `DeactivateAsync()` detaches all event handlers from `ConcurrentObservableDictionary` instances
2. Sensitive fields (byte arrays, strings containing secrets) are zeroed using `CryptographicOperations.ZeroMemory`
3. `IDisposable.Dispose()` is called on the plugin instance
4. The `CollectibleAssemblyLoadContext.Unload()` is called
5. A `WeakReference` tracks the ALC; a subsequent GC.Collect + WaitForPendingFinalizers confirms collection

### 6.4 SHA Verification (Future)

The Ace legacy included TODO comments about verifying plugin assembly SHA hashes against an external registry. This is planned as a future enhancement:

```csharp
public interface IPluginVerifier
{
    Task<bool> VerifyAssemblyAsync(string assemblyPath, CancellationToken ct = default);
}
```

---

## 7. Configuration Flow

### 7.1 Layered Configuration

Configuration follows a priority model (highest wins):

```
1. Runtime overrides via IPluginConfigStore
2. Environment variables
3. Environment-specific settings file (appsettings.{PluginId}.{env}.json)
4. Plugin-specific settings file (appsettings.{PluginId}.json)
5. Host application settings (appsettings.json)
6. Plugin's compiled-in DefaultConfiguration
7. Family StringConstants defaults
```

This mirrors the Ace `MultiAppSettingsBuilder` pattern but uses Microsoft.Extensions.Configuration throughout.

### 7.2 Plugin Config Section Naming

Each plugin reads from a well-known configuration section:

```json
{
  "Plugins": {
    "atap.secrets.bitwarden": {
      "BwCliPath": "bw",
      "SessionEnvVarName": "BW_SESSION",
      "Timeout": "00:00:30"
    }
  }
}
```

The section path is: `Plugins:{PluginId}`.

### 7.3 IPluginConfigStore

For scenarios requiring runtime-mutable configuration (the Ace Redis-backed property pattern), `IPluginConfigStore` provides a key-value abstraction:

| Implementation                     | Backing                | Persistence                           | Multi-process    |
| ---------------------------------- | ---------------------- | ------------------------------------- | ---------------- |
| `InMemoryPluginConfigStore`        | `ConcurrentDictionary` | Volatile (+ optional JSON on dispose) | No               |
| `SqlitePluginConfigStore` (future) | SQLite file            | Durable                               | Via file locking |
| `LiteDbPluginConfigStore` (future) | LiteDB file            | Durable                               | Via file locking |
| `RedisPluginConfigStore` (future)  | Redis                  | Durable                               | Yes              |

The default is `InMemoryPluginConfigStore`. This avoids the Ace-era hard dependency on Redis while preserving the same access pattern.

---

## 8. IData Pattern

### 8.1 Background (from Ace)

In Ace, each plugin exposed a "Data object" registered as a singleton in the DI container. This object held:

- `ConfigurationData` and `UserData` POCOs
- `ConcurrentObservableDictionary` instances for operational data
- Redis-backed properties for configuration values
- Event handlers for collection change notifications

The new architecture formalizes this as the `IPluginData` interface.

### 8.2 PluginDataBase Implementation

```csharp
public class PluginDataBase : IPluginData, IDisposable
{
    private readonly ConcurrentObservableDictionary<string, object> _store;
    private readonly Subject<PluginDataChangedEventArgs> _changeSubject;

    public PluginDataBase()
    {
        _store = new ConcurrentObservableDictionary<string, object>(isMultithreaded: true);
        _changeSubject = new Subject<PluginDataChangedEventArgs>();

        _store.CollectionChanged += OnCollectionChanged;
    }

    /// <summary>
    /// Returns a deep-copied read-only snapshot of the data store.
    /// </summary>
    public IReadOnlyDictionary<string, object> DataStore
    {
        get
        {
            // Deep copy via round-trip serialization
            var snapshot = new Dictionary<string, object>();
            foreach (var kvp in _store.CollectionView)
            {
                snapshot[kvp.Key] = DeepCopy(kvp.Value);
            }
            return snapshot;
        }
    }

    public IObservable<PluginDataChangedEventArgs> DataChanged => _changeSubject;

    private void OnCollectionChanged(object? sender, NotifyCollectionChangedEventArgs e)
    {
        // Convert to PluginDataChangedEventArgs with deep-copied values
        // and push to _changeSubject
    }

    protected void Set(string key, object value) => _store[key] = value;
    protected T? Get<T>(string key) => _store.TryGetValue(key, out var val) ? (T)val : default;

    private static object DeepCopy(object obj)
    {
        var json = JsonSerializer.Serialize(obj);
        return JsonSerializer.Deserialize<object>(json)!;
    }

    public void Dispose()
    {
        _store.CollectionChanged -= OnCollectionChanged;
        _changeSubject.Dispose();
    }
}
```

### 8.3 Typed Data Access

Plugin families define domain-specific data interfaces that extend `IPluginData`:

```csharp
// In ATAP.Utilities.Secrets.Interfaces
public interface ISecretsPluginData : IPluginData
{
    IReadOnlyDictionary<string, SecretAccessRecord> RecentAccesses { get; }
    int TotalSecretsRetrieved { get; }
}
```

This preserves the Ace pattern where each plugin's data object exposed domain-specific structures, but through a standardized interface.

---

## 9. Project Structure Convention

### 9.1 Standard Plugin Family Layout

Every plugin family follows the established ATAP.Utilities facade pattern, extended for plugin support:

```
src/ATAP.Utilities.{FamilyName}/
  ATAP.Utilities.{FamilyName}.csproj           (Facade, EnableDefaultItems=false)

  Interfaces/
    ATAP.Utilities.{FamilyName}.Interfaces.csproj
    I{FamilyName}Abstract.cs                    (family interface)
    I{FamilyName}OptionsAbstract.cs             (options interface)
    I{FamilyName}PluginShim.cs                  (extends IPluginShim<T>)
    Properties/AssemblyInfo.cs

  Model/
    ATAP.Utilities.{FamilyName}.Model.csproj
    {FamilyName}Abstract.cs                     (abstract base)
    {FamilyName}OptionsAbstract.cs              (options base)
    Properties/AssemblyInfo.cs

  StringConstants/
    ATAP.Utilities.{FamilyName}.StringConstants.csproj
    StringConstants.cs
    Properties/AssemblyInfo.cs

  Enumerations/
    ATAP.Utilities.{FamilyName}.Enumerations.csproj
    {FamilyName}ProviderKind.cs
    Properties/AssemblyInfo.cs

  Shim/
    ATAP.Utilities.{FamilyName}.Shim.csproj     (Shim facade)

    {ImplementationName}/                        (one per concrete implementation)
      ATAP.Utilities.{FamilyName}.Shim.{ImplementationName}.csproj
      {ImplementationName}{FamilyName}Shim.cs
      {ImplementationName}{FamilyName}Options.cs
      ServiceCollectionExtensions.cs
      Properties/AssemblyInfo.cs

    Plugin/                                      (dynamic loading shim)
      ATAP.Utilities.{FamilyName}.Shim.Plugin.csproj
      {FamilyName}PluginLoader.cs               (implements ILoadDynamicSubModules)
      Properties/AssemblyInfo.cs
```

### 9.2 Key Differences from Standard ATAP Facade

| Standard Facade                                                        | Plugin Family Extension                          |
| ---------------------------------------------------------------------- | ------------------------------------------------ |
| Only Interfaces, Model, StringConstants, Enumerations, DefaultSettings | + Shim/ directory with implementation shims      |
| No runtime loading concern                                             | Shim/Plugin/ project with ILoadDynamicSubModules |
| Single implementation                                                  | Multiple interchangeable implementations         |
| Direct DI registration                                                 | Plugin lifecycle management                      |

### 9.3 NuGet Package Mapping

Each sub-project produces a NuGet package:

| Package                               | Contents                             | When to reference                   |
| ------------------------------------- | ------------------------------------ | ----------------------------------- |
| `ATAP.Utilities.{Family}`             | Facade (references all sub-packages) | Full static consumption             |
| `ATAP.Utilities.{Family}.Interfaces`  | Interfaces only                      | Host projects (minimal dependency)  |
| `ATAP.Utilities.{Family}.Shim.{Impl}` | One concrete implementation          | Static consumption of specific impl |
| `ATAP.Utilities.{Family}.Shim.Plugin` | Dynamic loader shim                  | Dynamic/runtime consumption         |

---

## 10. Existing Plugin Families and Migration Status

| Family           | Current State                                                                                   | Target State                                                                                   |
| ---------------- | ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| **Serializer**   | Most mature. Facade + 3 static shims + 1 plugin shim. Uses McMaster.                            | Update Plugin shim to use IAssemblyLoader. Template for other families.                        |
| **Secrets**      | Two competing implementations (Configuration.Secrets standalone + Configuration/Secrets/Shims). | Consolidate into new `ATAP.Utilities.Secrets` facade family. See SecretsPluginArchitecture.md. |
| **MessageQueue** | Basic MessageQueue.Shim.RabbitMQ and MessageQueue.Shim.TPL exist.                               | Future: apply plugin family pattern.                                                           |
| **Testing**      | Testing.Fixture.Serialization has shim variants.                                                | Future: apply plugin family pattern.                                                           |

---

## 11. Technology Evaluations

### 11.1 McMaster.NETCore.Plugins

| Aspect                      | Assessment                                   |
| --------------------------- | -------------------------------------------- |
| **Last release**            | v1.4.0, August 2021                          |
| **GitHub status**           | Archived / maintenance-only                  |
| **.NET 10 compatibility**   | Untested                                     |
| **Collectible ALC support** | None                                         |
| **Core value**              | Shared types bridging, .deps.json resolution |
| **Code complexity**         | ~200-300 LOC for the critical path features  |

**Decision:** Replace with native `AssemblyLoadContext`. The critical features are straightforward to implement natively and we gain collectible context support.

### 11.2 ConcurrentObservableDictionary

| Alternative                                                 | Pros                                                                              | Cons                                             |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------ |
| **Existing ATAP.Utilities.ConcurrentObservableCollections** | Already integrated, thread-safe, serializable, raises standard .NET change events | No Rx integration, 20ms throttle is hardcoded    |
| **DynamicData (ReactiveUI)**                                | Powerful Rx query operators (Filter, Sort, Transform), actively maintained        | Heavy Rx dependency, different programming model |
| **Cysharp/ObservableCollections**                           | High performance, modern .NET                                                     | No dictionary variant                            |
| **System.Collections.ObjectModel.ObservableCollection**     | Built-in                                                                          | Not concurrent, not dictionary-typed             |

**Decision:** Keep existing implementation. It meets all IData requirements. Add an optional `IObservable<T>` adapter for consumers who want Rx integration (implemented in `PluginDataBase`).

### 11.3 Config Storage Alternatives to Redis

| Option                 | Persistence | Multi-process | Dependencies             | Complexity |
| ---------------------- | ----------- | ------------- | ------------------------ | ---------- |
| **In-memory + JSON**   | On shutdown | No            | None                     | Low        |
| **SQLite**             | Durable     | File locking  | Microsoft.Data.Sqlite    | Medium     |
| **LiteDB**             | Durable     | File locking  | LiteDB                   | Medium     |
| **SQL Server LocalDB** | Durable     | Full SQL      | Microsoft.Data.SqlClient | High       |
| **Redis**              | Durable     | Yes           | StackExchange.Redis      | Medium     |

**Decision:** Default to in-memory + JSON. Provide `IPluginConfigStore` interface for consumers who need SQLite, LiteDB, or Redis. This eliminates the hard Redis dependency that Ace had while preserving the pass-through property pattern.

---

## 12. PowerShell Integration

### 12.1 Design Principles

- All plugin family interfaces should be consumable from PowerShell without modification
- Async methods are called via `.GetAwaiter().GetResult()` (PowerShell does not natively support `await`)
- Plugin discovery and loading wrapped in cmdlets for ergonomic use

### 12.2 Module Structure

```
ATAP.Utilities.Plugin.Powershell/
  ATAP.Utilities.Plugin.psd1          (module manifest, requires .NET assemblies)
  ATAP.Utilities.Plugin.psm1          (script module)
  Cmdlets/
    New-PluginFamily.ps1              (wraps IPluginFamily<T> construction)
    Get-PluginMetadata.ps1            (wraps DiscoverAsync)
    Import-Plugin.ps1                 (wraps LoadAsync + InitializeAsync + ActivateAsync)
    Remove-Plugin.ps1                 (wraps DeactivateAsync + UnloadAsync)
  FamilySpecific/
    Get-Secret.ps1                    (convenience wrapper for Secrets family)
```

### 12.3 Usage Example

```powershell
# Import the plugin module
Import-Module ATAP.Utilities.Plugin.Powershell

# Discover secrets plugins in a directory
$family = New-PluginFamily -InterfaceType ([ATAP.Utilities.Secrets.ISecretsAbstract]) `
                           -ProbingPath "./Plugins"
$family | Get-PluginMetadata | Format-Table PluginId, DisplayName, Version

# Load and use Bitwarden plugin
$bwPlugin = $family | Import-Plugin -PluginId "atap.secrets.bitwarden"
$secret = Get-Secret -Plugin $bwPlugin -SecretName "ProGet_Admin_API_Key" -FieldName "password"

# Unload when done
$bwPlugin | Remove-Plugin
```

### 12.4 Dynamic Binding at Runtime

```powershell
# Low-level dynamic binding (equivalent of C# Loader<ISecretsAbstract>)
Add-Type -Path "./ATAP.Utilities.Loader.dll"
Add-Type -Path "./ATAP.Utilities.Secrets.Interfaces.dll"

$loader = New-Object "ATAP.Utilities.Loader.Loader``1[ATAP.Utilities.Secrets.ISecretsAbstract]"
$glob = New-Object ATAP.Utilities.Loader.DynamicGlobAndPredicate -Property @{
    Glob = New-Object ATAP.Utilities.FileIO.Glob -Property @{ Pattern = "./Plugins/*Secrets.Shim.Bitwarden.dll" }
    Predicate = [Predicate[Type]]{ param($t) [ATAP.Utilities.Secrets.ISecretsAbstract].IsAssignableFrom($t) -and -not $t.IsAbstract }
}
$secretsProvider = $loader.LoadExactlyOneInstanceOfITypeFromAssemblyGlob($glob)
$result = $secretsProvider.GetSecretAsync("MyItem", "password").GetAwaiter().GetResult()
Write-Host "Secret: $result"
```

---

## 13. Relationship to Ace Legacy

This architecture replaces and modernizes the Ace plugin system:

| Ace Concept                                                                               | New Equivalent                                                                    |
| ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| ServiceStack `IPlugin` / `IPreInitPlugin` / `IPostInitPlugin`                             | `IPluginLifecycle` (Discovered -> Active states)                                  |
| Hardcoded plugin list in `SSAppHost.Configure()`                                          | `IPluginFamily<T>.DiscoverAsync()` with glob probing                              |
| `MultiAppSettingsBuilder` (env vars, text files, compiled defaults)                       | `IConfiguration` layering (env vars, JSON files, compiled defaults)               |
| `ICacheClient` (Redis) for config storage                                                 | `IPluginConfigStore` (in-memory default, Redis optional)                          |
| Redis-backed pass-through properties                                                      | `IPluginConfigStore.GetAsync<T>` / `SetAsync<T>`                                  |
| Plugin Data object in Funq container                                                      | `IPluginData` registered in `IServiceCollection`                                  |
| `ConcurrentObservableDictionary` with event handlers                                      | Same, wrapped by `PluginDataBase` with `IObservable<T>` adapter                   |
| Six-assembly convention (.Plugin, .Models, .Interfaces, .Data, .Shared, .StringConstants) | Facade family convention (Interfaces, Model, StringConstants, Enumerations, Shim) |
| ServiceStack `[Route]` attribute routing                                                  | Not applicable (no HTTP requirement; host defines its own API surface)            |
| Server-Sent Events for data push (never implemented in Ace)                               | `IPluginData.DataChanged` observable stream (host can wire to SSE, SignalR, etc.) |

---

## 14. Glossary

| Term                 | Definition                                                                                 |
| -------------------- | ------------------------------------------------------------------------------------------ |
| **Plugin Family**    | A group of interchangeable implementations behind a shared interface                       |
| **Shim**             | A bridge assembly connecting a concrete library to the generic plugin interface            |
| **Plugin Shim**      | A shim that also implements `ILoadDynamicSubModules` for dynamic loading                   |
| **ALC**              | `AssemblyLoadContext` -- .NET's isolation boundary for loaded assemblies                   |
| **Collectible ALC**  | An `AssemblyLoadContext` created with `isCollectible: true`, enabling unload and GC        |
| **IData**            | The pattern where plugins expose observable data structures to the host                    |
| **Deep-copy**        | Serialization round-trip to prevent cross-ALC object references                            |
| **Facade**           | An aggregator .csproj with `EnableDefaultItems=false` that references sub-projects         |
| **Family Interface** | The abstract interface all members of a plugin family implement (e.g., `ISecretsAbstract`) |
| **ConfigStore**      | Pluggable key-value store for runtime plugin configuration (replaces Ace's Redis)          |
