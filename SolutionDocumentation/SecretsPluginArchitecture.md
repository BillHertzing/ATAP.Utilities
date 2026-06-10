# Secrets Plugin Family Architecture

> **Status:** Architecture specification, April 2026
> **Related documents:** [GenericPluginArchitecture.md](GenericPluginArchitecture.md) - [PLugin Creation Prompt.md](PLugin%20Creation%20Prompt.md)
> **Primary source packages:** `ATAP.Utilities.Secrets`, `ATAP.Utilities.Secrets.Shim.Bitwarden`, `ATAP.Utilities.Loader`
> **Existing implementations being consolidated:**
>
> - `src/ATAP.Utilities.Configuration.Secrets/` (standalone: ISecretProvider, SecretProvidersBuilder)
> - `src/ATAP.Utilities.Configuration/Secrets/Shims/` (shim-based: IConfigurationSecrets, IConfigurationSecretsShim, BitwardenSecretsShim)

---

## 1. Purpose

ATAP.Utilities.Secrets is the first plugin family (after the reference Serializer family) to be built on the new generic plugin architecture described in [GenericPluginArchitecture.md](GenericPluginArchitecture.md). It provides:

1. A **uniform interface** (`ISecretsAbstract`) for retrieving secrets from any vault provider
2. A **Bitwarden implementation** as the first concrete shim (consolidating two existing implementations)
3. **Dual consumption**: static project/package reference OR dynamic plugin loading
4. **IConfiguration integration**: secrets feed into the .NET configuration pipeline, available to all downstream services via Options pattern
5. A **template** for creating additional secret providers (Azure Key Vault, HashiCorp Vault, KeePass, etc.)

---

## 2. Current State Analysis

### 2.1 Implementation A: `src/ATAP.Utilities.Configuration.Secrets/`

**Files:**

- `ISecretProvider.cs` -- `ISecretProvider` interface with `ProviderName`, `IsAvailable()`, `GetSecretAsync()`
- `SecretMapping.cs` -- record mapping secret name + field to configuration key
- `SecretProvidersBuilder.cs` -- fluent builder: `AddBitwardenPasswordManager()`, `AddBitwardenSecretsManager()`
- `SecretProvidersConfigurationProvider.cs` -- custom `ConfigurationProvider` that queries all registered providers on `Load()`
- `SecretProvidersConfigurationSource.cs` -- `IConfigurationSource` registration point
- `ConfigurationBuilderExtensions.cs` -- `IConfigurationBuilder.AddSecretProviders()` extension
- `Providers/BitwardenPasswordManagerProvider.cs` -- BW implementation using `bw` CLI with `BW_SESSION` env var
- `Providers/BitwardenPasswordManagerOptions.cs` -- options: `SessionEnvVarName`, `BwCliPath`, `Timeout`
- `Providers/BitwardenSecretsManagerProvider.cs` -- stub (throws `NotImplementedException`)
- `Providers/BitwardenSecretsManagerOptions.cs` -- placeholder options

**Strengths:** Rich options pattern (`BwCliPath`, `Timeout`, configurable `SessionEnvVarName`), `SecretMapping` record for declarative config-key population, graceful skip on unavailable providers, custom `IConfigurationSource`/`IConfigurationProvider` integration.

**Weaknesses:** Not structured as a plugin family. No shim pattern. No facade subproject structure. Standalone package that doesn't follow the ATAP.Utilities conventions.

### 2.2 Implementation B: `src/ATAP.Utilities.Configuration/Secrets/Shims/`

**Files:**

- `Interfaces/IConfigurationSecrets.cs` -- consumer interface with `GetSecretAsync()`, `SecretExistsAsync()`
- `Interfaces/IConfigurationSecretsShim.cs` -- plugin shim contract with `ProviderName`, `GetSecretAsync()`, `SecretExistsAsync()`
- `ATAP.Utilities.Configuration.Secrets.Shims.Body.cs` -- `ConfigurationSecretsShims` router: iterates all registered shims, returns first non-null
- `Bitwarden/ATAP.Utilities.Configuration.Secrets.Shim.Bitwarden.cs` -- `BitwardenSecretsShim` implementing `IConfigurationSecretsShim`
- `Bitwarden/BitwardenConfigurationProvider.cs` -- Bitwarden-specific `ConfigurationProvider`
- `Bitwarden/BitwardenSecretMapping.cs` -- secret-to-config-key mapping
- `Bitwarden/ConfigurationBuilderExtensions.cs` -- `AddBitwardenSecrets()` for `IConfigurationBuilder`
- `Bitwarden/ServiceCollectionExtensions.cs` -- `AddConfigurationSecrets<TShim>()` for DI

**Strengths:** Follows the Shim pattern. Has router that queries multiple providers. DI extension methods. Closer to the target plugin family structure.

**Weaknesses:** Nested deep inside the Configuration package (not its own top-level family). `BitwardenSecretsShim` lacks the rich options from Implementation A (no configurable `BwCliPath`, no `Timeout`). No `SecretMapping` equivalent for declarative mapping.

### 2.3 Consolidation Strategy

The new `ATAP.Utilities.Secrets` family takes the **best of both**:

| Feature                                                       | Source                                                           | New Location                                               |
| ------------------------------------------------------------- | ---------------------------------------------------------------- | ---------------------------------------------------------- |
| `ISecretsAbstract` interface                                  | Merge of `ISecretProvider` (A) + `IConfigurationSecretsShim` (B) | `Secrets/Interfaces/ISecretsAbstract.cs`                   |
| `SecretMapping` record                                        | Implementation A                                                 | `Secrets/Model/SecretMapping.cs`                           |
| Options pattern (`BwCliPath`, `Timeout`, `SessionEnvVarName`) | Implementation A's `BitwardenPasswordManagerOptions`             | `Secrets/Shim/Bitwarden/BitwardenSecretsOptions.cs`        |
| Bitwarden `bw` CLI invocation                                 | Implementation B's `BitwardenSecretsShim.RunBwAsync()` (cleaner) | `Secrets/Shim/Bitwarden/BitwardenSecretsShim.cs`           |
| Custom `IConfigurationSource`/`IConfigurationProvider`        | Implementation A's `SecretProvidersConfigurationProvider`        | `Secrets/Shim/Bitwarden/BitwardenConfigurationProvider.cs` |
| Multi-provider router                                         | Implementation B's `ConfigurationSecretsShims`                   | `Secrets/Model/SecretsRouter.cs`                           |
| DI extensions                                                 | Implementation B's `ServiceCollectionExtensions`                 | `Secrets/Shim/Bitwarden/ServiceCollectionExtensions.cs`    |
| `IPluginShim<ISecretsAbstract>`                               | New (generic plugin architecture)                                | `Secrets/Interfaces/ISecretsPluginShim.cs`                 |
| Dynamic loading                                               | New (ILoadDynamicSubModules)                                     | `Secrets/Shim/Plugin/SecretsPluginLoader.cs`               |

---

## 3. New Project Structure

```path
src/ATAP.Utilities.Secrets/
│
├── ATAP.Utilities.Secrets.csproj                          Facade (EnableDefaultItems=false)
│   References: Interfaces, Model, StringConstants, Enumerations, Shim
│
├── Interfaces/
│   ├── ATAP.Utilities.Secrets.Interfaces.csproj
│   ├��─ ISecretsAbstract.cs                                Family interface
│   ├── ISecretsConfigurableAbstract.cs                    Adds IConfigurationRoot support
│   ├── ISecretsOptionsAbstract.cs                         Options abstraction
│   ├── ISecretsPluginShim.cs                              Plugin lifecycle shim
│   └── Properties/AssemblyInfo.cs
│
├─�� Model/
│   ├── ATAP.Utilities.Secrets.Model.csproj
│   ├── SecretsAbstract.cs                                 Abstract base class
│   ├��─ SecretsConfigurableAbstract.cs                     Adds config root
│   ├── SecretsOptionsAbstract.cs                          Options base
│   ├── SecretMapping.cs                                   Secret-to-config-key record
│   ├── SecretsRouter.cs                                   Multi-provider aggregator
│   └── Properties/AssemblyInfo.cs
│
├── StringConstants/
│   ├── ATAP.Utilities.Secrets.StringConstants.csproj
│   ├── StringConstants.cs                                 Config keys and defaults
│   └── Properties/AssemblyInfo.cs
│
├── Enumerations/
│   ├── ATAP.Utilities.Secrets.Enumerations.csproj
│   ├── SecretsProviderKind.cs                             Provider type enum
│   └── Properties/AssemblyInfo.cs
│
└── Shim/
    ├── ATAP.Utilities.Secrets.Shim.csproj                 Shim facade (EnableDefaultItems=false)
    │
    ├── Bitwarden/
    │   ├── ATAP.Utilities.Secrets.Shim.Bitwarden.csproj
    │   ├── BitwardenSecretsShim.cs                        ISecretsConfigurableAbstract impl
    │   ├── BitwardenSecretsOptions.cs                     Options class
    │   ├── BitwardenSecretMapping.cs                      BW-specific mapping helpers
    │   ├── BitwardenConfigurationSource.cs                IConfigurationSource
    │   ├── BitwardenConfigurationProvider.cs              ConfigurationProvider
    │   ├── ServiceCollectionExtensions.cs                 AddBitwardenSecrets()
    │   ├── ConfigurationBuilderExtensions.cs              AddBitwardenSecretsToConfiguration()
    │   ├── FodyWeavers.xml
    │   └── Properties/AssemblyInfo.cs
    │
    └── Plugin/
        ├── ATAP.Utilities.Secrets.Shim.Plugin.csproj
        ├── SecretsPluginShim.cs                           IPluginShim<ISecretsAbstract> + ILoadDynamicSubModules
        ├── FodyWeavers.xml
        └── Properties/AssemblyInfo.cs
```

---

## 4. Interface Definitions

### 4.1 ISecretsAbstract (Family Interface)

```csharp
namespace ATAP.Utilities.Secrets;

/// <summary>
/// Abstract interface for all secrets providers. This is the family interface
/// that all Secrets plugin shims implement.
/// </summary>
public interface ISecretsAbstract
{
    /// <summary>Options controlling provider behavior.</summary>
    ISecretsOptionsAbstract Options { get; set; }

    /// <summary>Human-readable provider name (e.g. "Bitwarden", "AzureKeyVault").</summary>
    string ProviderName { get; }

    /// <summary>
    /// Returns true if this provider is configured and available.
    /// When false the provider is silently skipped in multi-provider routing.
    /// </summary>
    bool IsAvailable();

    /// <summary>
    /// Retrieves a secret value by name and optional field.
    /// </summary>
    /// <param name="secretName">The vault item name (e.g. "ProGet_Admin_API_Key").</param>
    /// <param name="fieldName">
    /// Optional field within the secret item. Null means the provider's default field
    /// (typically "password" for Bitwarden). Case-insensitive comparison.
    /// </param>
    /// <returns>The secret value, or null if not found.</returns>
    Task<string?> GetSecretAsync(
        string secretName,
        string? fieldName = null,
        CancellationToken cancellationToken = default);

    /// <summary>Returns true if a secret with the given name exists in the provider.</summary>
    Task<bool> SecretExistsAsync(
        string secretName,
        CancellationToken cancellationToken = default);
}
```

### 4.2 ISecretsConfigurableAbstract

```csharp
namespace ATAP.Utilities.Secrets;

/// <summary>
/// Extended interface adding IConfigurationRoot support for providers
/// that participate in the .NET configuration pipeline.
/// </summary>
public interface ISecretsConfigurableAbstract : ISecretsAbstract
{
    IConfigurationRoot? ConfigurationRoot { get; set; }
}
```

### 4.3 ISecretsOptionsAbstract

```csharp
namespace ATAP.Utilities.Secrets;

/// <summary>
/// Base options interface for secrets providers.
/// Concrete providers extend this with provider-specific settings
/// stored in ShimSpecificOptions (following the Serializer pattern).
/// </summary>
public interface ISecretsOptionsAbstract
{
    /// <summary>
    /// Provider-specific options object (e.g. BitwardenSecretsOptions).
    /// Cast to the concrete type in the shim implementation.
    /// </summary>
    object ShimSpecificOptions { get; }
}
```

### 4.4 ISecretsPluginShim

```csharp
namespace ATAP.Utilities.Secrets;

/// <summary>
/// Plugin shim contract for the Secrets family.
/// Extends IPluginShim with Secrets-specific IConfigurationSource creation.
/// </summary>
public interface ISecretsPluginShim : IPluginShim<ISecretsAbstract>
{
    /// <summary>
    /// Creates an IConfigurationSource that feeds secret values into
    /// the host's IConfiguration pipeline based on the provided mappings.
    /// </summary>
    IConfigurationSource CreateConfigurationSource(IEnumerable<SecretMapping> mappings);
}
```

---

## 5. Model Classes

### 5.1 SecretMapping

```csharp
namespace ATAP.Utilities.Secrets;

/// <summary>
/// Maps a secret item (by name and optional field) to a configuration key.
/// Used by IConfigurationSource implementations to feed secrets into IConfiguration.
/// </summary>
/// <param name="SecretName">The name of the secret in the vault (e.g. "ProGet_Admin_API_Key").</param>
/// <param name="FieldName">
/// Optional field within the secret. Null means the default field
/// (e.g. "password" for Bitwarden). For custom fields, use the exact vault field name.
/// </param>
/// <param name="ConfigurationKey">
/// The IConfiguration key to populate (e.g. "ConnectionStrings:ProGetDb").
/// </param>
public record SecretMapping(
    string SecretName,
    string? FieldName,
    string ConfigurationKey);
```

### 5.2 SecretsRouter (Multi-Provider Aggregator)

```csharp
namespace ATAP.Utilities.Secrets;

/// <summary>
/// Routes secret lookups across all registered providers.
/// Returns the first non-null value found, in registration order.
/// Unavailable providers are silently skipped.
/// </summary>
public class SecretsRouter : SecretsAbstract
{
    private readonly IReadOnlyList<ISecretsAbstract> _providers;

    public SecretsRouter(IEnumerable<ISecretsAbstract> providers)
    {
        _providers = providers.ToList();
    }

    public override string ProviderName => "Router";

    public override bool IsAvailable() => _providers.Any(p => p.IsAvailable());

    public override async Task<string?> GetSecretAsync(
        string secretName, string? fieldName = null, CancellationToken ct = default)
    {
        foreach (var provider in _providers)
        {
            if (!provider.IsAvailable()) continue;
            var value = await provider.GetSecretAsync(secretName, fieldName, ct);
            if (value is not null) return value;
        }
        return null;
    }

    public override async Task<bool> SecretExistsAsync(
        string secretName, CancellationToken ct = default)
    {
        foreach (var provider in _providers)
        {
            if (!provider.IsAvailable()) continue;
            if (await provider.SecretExistsAsync(secretName, ct)) return true;
        }
        return false;
    }
}
```

---

## 6. StringConstants

```csharp
namespace ATAP.Utilities.Secrets;

public static class StringConstants
{
    // Configuration root keys
    public const string SecretsProviderNameConfigRootKey = "SecretsProviderAssembly";
    public const string SecretsProviderNameDefault = "ATAP.Utilities.Secrets.Shim.Bitwarden";
    public const string SecretsProviderNamespaceConfigRootKey = "SecretsProviderNamespace";
    public const string SecretsProviderNamespaceDefault = "ATAP.Utilities.Secrets.Shim.Bitwarden";

    // Plugin probing
    public const string SecretsPluginDirectoryConfigRootKey = "SecretsPluginDirectory";
    public const string SecretsPluginDirectoryDefault = "Plugins";
    public const string SecretsPluginGlobPattern = "*Secrets.Shim.*.dll";

    // Bitwarden-specific
    public const string BitwardenSessionEnvVarDefault = "BW_SESSION";
    public const string BitwardenCliPathDefault = "bw";
    public const string BitwardenTimeoutDefault = "00:00:30";

    // Exception messages (for localization)
    public const string ExceptionNoProvidersAvailable = "No secrets providers are available. Ensure at least one provider is configured.";
    public const string ExceptionBwSessionNotSet = "BW_SESSION environment variable is not set. Run Initialize-BitwardenSession (LoginScript.ps1) before accessing secrets.";
}
```

---

## 7. Enumerations

```csharp
namespace ATAP.Utilities.Secrets;

/// <summary>
/// Identifies the kind of secrets provider.
/// Used for logging, diagnostics, and configuration routing.
/// </summary>
public enum SecretsProviderKind
{
    /// <summary>Bitwarden Password Manager (bw CLI).</summary>
    BitwardenPasswordManager,

    /// <summary>Bitwarden Secrets Manager (bws CLI, machine-to-machine).</summary>
    BitwardenSecretsManager,

    /// <summary>Azure Key Vault.</summary>
    AzureKeyVault,

    /// <summary>HashiCorp Vault.</summary>
    HashiCorpVault,

    /// <summary>KeePass database file.</summary>
    KeePass,

    /// <summary>Environment variables as secret source.</summary>
    EnvironmentVariable,

    /// <summary>Custom or third-party provider.</summary>
    Custom
}
```

---

## 8. Bitwarden Shim Implementation

### 8.1 BitwardenSecretsOptions

```csharp
namespace ATAP.Utilities.Secrets.Shim.Bitwarden;

/// <summary>
/// Configuration options for the Bitwarden secrets provider.
/// Consolidates BitwardenPasswordManagerOptions (Implementation A)
/// with the simpler options from Implementation B.
/// </summary>
public class BitwardenSecretsOptions
{
    /// <summary>
    /// Environment variable name containing the Bitwarden session token.
    /// Default: "BW_SESSION".
    /// </summary>
    public string SessionEnvVarName { get; set; } = StringConstants.BitwardenSessionEnvVarDefault;

    /// <summary>
    /// Path or command name for the Bitwarden CLI.
    /// Default: "bw" (must be on PATH).
    /// </summary>
    public string BwCliPath { get; set; } = StringConstants.BitwardenCliPathDefault;

    /// <summary>
    /// Maximum time to wait for the bw CLI to respond.
    /// Default: 30 seconds.
    /// </summary>
    public TimeSpan Timeout { get; set; } = TimeSpan.Parse(StringConstants.BitwardenTimeoutDefault);

    /// <summary>
    /// Default field name when fieldName is null.
    /// Default: "password".
    /// </summary>
    public string DefaultFieldName { get; set; } = "password";
}
```

### 8.2 BitwardenSecretsShim

The core implementation consolidates the `bw` CLI invocation from Implementation B's `RunBwAsync` (cleaner process management) with Implementation A's rich options:

```csharp
namespace ATAP.Utilities.Secrets.Shim.Bitwarden;

/// <summary>
/// Retrieves secrets from the Bitwarden vault via the bw CLI.
/// Requires a valid Bitwarden session key in the configured environment variable
/// (default: BW_SESSION), populated at login by Initialize-BitwardenSession.
///
/// For the "password" field: uses "bw get password {secretName}".
/// For custom fields: uses "bw get item {secretName}" and parses the JSON.
/// </summary>
public class BitwardenSecretsShim : SecretsConfigurableAbstract
{
    private readonly BitwardenSecretsOptions _options;

    public BitwardenSecretsShim() : this(new BitwardenSecretsOptions()) { }

    public BitwardenSecretsShim(BitwardenSecretsOptions options)
    {
        _options = options;
        Options = new SecretsOptions(options);
    }

    public override string ProviderName => "Bitwarden";

    public override bool IsAvailable()
    {
        var sessionKey = Environment.GetEnvironmentVariable(_options.SessionEnvVarName);
        return !string.IsNullOrEmpty(sessionKey);
    }

    public override async Task<string?> GetSecretAsync(
        string secretName, string? fieldName = null, CancellationToken ct = default)
    {
        var effectiveField = fieldName ?? _options.DefaultFieldName;

        if (effectiveField.Equals("password", StringComparison.OrdinalIgnoreCase))
        {
            var (output, exitCode) = await RunBwAsync(["get", "password", secretName], ct);
            return exitCode == 0 ? output : null;
        }

        // Custom field: retrieve full item JSON and extract
        var (json, itemExitCode) = await RunBwAsync(["get", "item", secretName], ct);
        if (itemExitCode != 0 || string.IsNullOrWhiteSpace(json))
            return null;

        return ExtractCustomField(json, effectiveField);
    }

    public override async Task<bool> SecretExistsAsync(
        string secretName, CancellationToken ct = default)
    {
        var (_, exitCode) = await RunBwAsync(["get", "item", secretName], ct);
        return exitCode == 0;
    }

    // RunBwAsync and ExtractCustomField methods preserved from
    // existing BitwardenSecretsShim implementation (Implementation B)
    // with addition of _options.BwCliPath and _options.Timeout support
    // from Implementation A
}
```

### 8.3 DI Registration

```csharp
namespace ATAP.Utilities.Secrets.Shim.Bitwarden;

public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Registers the Bitwarden secrets provider as the ISecretsAbstract implementation.
    /// For static (project/package reference) consumption.
    /// </summary>
    public static IServiceCollection AddBitwardenSecrets(
        this IServiceCollection services,
        Action<BitwardenSecretsOptions>? configure = null)
    {
        var options = new BitwardenSecretsOptions();
        configure?.Invoke(options);
        services.AddSingleton<ISecretsAbstract>(new BitwardenSecretsShim(options));
        return services;
    }
}

public static class ConfigurationBuilderExtensions
{
    /// <summary>
    /// Adds Bitwarden secrets to the configuration pipeline.
    /// Secrets are fetched once at startup and injected as IConfiguration values.
    /// </summary>
    public static IConfigurationBuilder AddBitwardenSecrets(
        this IConfigurationBuilder builder,
        IEnumerable<SecretMapping> mappings,
        Action<BitwardenSecretsOptions>? configure = null)
    {
        var options = new BitwardenSecretsOptions();
        configure?.Invoke(options);
        builder.Add(new BitwardenConfigurationSource(options, mappings));
        return builder;
    }
}
```

---

## 9. Plugin Shim (Dynamic Loading)

### 9.1 SecretsPluginShim

```csharp
namespace ATAP.Utilities.Secrets.Shim.Plugin;

/// <summary>
/// Dynamic loading entry point for the Secrets plugin family.
/// Implements ILoadDynamicSubModules to allow the Loader to discover
/// and load secrets provider assemblies from a Plugins directory.
///
/// Follows the same pattern as ATAP.Utilities.Serializer.Shim.Plugin.
/// </summary>
public class SecretsPluginShim : PluginShimBase<ISecretsAbstract>, ILoadDynamicSubModules
{
    private ISecretsAbstract? _loadedProvider;

    public override string PluginId => "atap.secrets.plugin";
    public override string DisplayName => "Secrets Plugin Loader";
    public override Version Version => GetType().Assembly.GetName().Version!;
    public override Type FamilyInterface => typeof(ISecretsAbstract);

    public override ISecretsAbstract GetService()
        => _loadedProvider ?? throw new InvalidOperationException("No secrets provider loaded.");

    public override void RegisterServices(IServiceCollection services)
    {
        if (_loadedProvider != null)
            services.AddSingleton<ISecretsAbstract>(_loadedProvider);
    }

    /// <summary>
    /// Returns discovery information for dynamically loading secrets providers.
    /// The Loader uses this to find matching assemblies in the Plugins directory.
    /// </summary>
    public IDictionary<Type, IDynamicSubModulesInfo> GetDynamicSubModulesInfo()
    {
        return new Dictionary<Type, IDynamicSubModulesInfo>
        {
            [typeof(ISecretsAbstract)] = new DynamicSubModulesInfo
            {
                DynamicGlobAndPredicate = new DynamicGlobAndPredicate
                {
                    Glob = new Glob
                    {
                        Pattern = $".\\{StringConstants.SecretsPluginDirectoryDefault}\\{StringConstants.SecretsPluginGlobPattern}"
                    },
                    Predicate = new Predicate<Type>(type =>
                        typeof(ISecretsAbstract).IsAssignableFrom(type)
                        && !type.IsAbstract
                        && !type.IsInterface)
                },
                Function = new Action<object>(instance =>
                {
                    _loadedProvider = (ISecretsAbstract)instance;
                })
            }
        };
    }
}
```

---

## 10. Configuration Flow

### 10.1 How Secrets Feed Into IConfiguration

```
Application startup
    |
    v
ConfigurationBuilder
    .AddJsonFile("appsettings.json")
    .AddJsonFile("appsettings.{env}.json")
    .AddBitwardenSecrets(mappings: [           <-- Secrets injected here
        new("ProGet_Admin_API_Key", "password", "ConnectionStrings:ProGetApiKey"),
        new("SQL_Server_Password", "password", "ConnectionStrings:SqlPassword"),
        new("GitHub_PAT", "token", "GitHub:PersonalAccessToken")
    ])
    .AddEnvironmentVariables()                 <-- Env vars still override
    .Build()
    |
    v
IConfiguration now contains secret values at the mapped keys
    |
    v
services.AddOptions<ProGetOptions>()
    .Bind(configuration.GetSection("ConnectionStrings"))
    .ValidateOnStart()                         <-- Fails fast if secrets are missing
```

### 10.2 BitwardenConfigurationProvider

```csharp
/// <summary>
/// Loads secrets from Bitwarden into the configuration system at startup.
/// Each SecretMapping defines which vault item and field maps to which config key.
/// Unavailable providers are silently skipped (missing secrets surface
/// at ValidateOnStart if required).
/// </summary>
internal class BitwardenConfigurationProvider : ConfigurationProvider
{
    private readonly BitwardenSecretsShim _shim;
    private readonly IEnumerable<SecretMapping> _mappings;

    public BitwardenConfigurationProvider(
        BitwardenSecretsOptions options,
        IEnumerable<SecretMapping> mappings)
    {
        _shim = new BitwardenSecretsShim(options);
        _mappings = mappings;
    }

    public override void Load()
    {
        if (!_shim.IsAvailable())
            return; // Silently skip; missing keys detected by ValidateOnStart

        var data = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);

        foreach (var mapping in _mappings)
        {
            // Synchronous wrapper for ConfigurationProvider.Load()
            var value = _shim.GetSecretAsync(
                mapping.SecretName,
                mapping.FieldName).GetAwaiter().GetResult();

            if (value is not null)
                data[mapping.ConfigurationKey] = value;
        }

        Data = data!;
    }
}
```

---

## 11. Consumption Examples

### 11.1 Static Consumption (Project/Package Reference)

```csharp
// In Program.cs
var builder = Host.CreateApplicationBuilder(args);

// Add Bitwarden secrets to configuration
builder.Configuration.AddBitwardenSecrets(
    mappings:
    [
        new SecretMapping("ProGet_Admin_API_Key", "password", "ProGet:ApiKey"),
        new SecretMapping("SQL_Server_SA", "password", "ConnectionStrings:DefaultConnection"),
    ]);

// Register for DI injection
builder.Services.AddBitwardenSecrets(options =>
{
    options.Timeout = TimeSpan.FromSeconds(15);
});

// Consume via DI
builder.Services.AddHostedService<MyService>();

// In MyService:
public class MyService(ISecretsAbstract secrets) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        var apiKey = await secrets.GetSecretAsync("ProGet_Admin_API_Key", cancellationToken: ct);
        // Use apiKey...
    }
}
```

### 11.2 Dynamic Consumption (Plugin Loading)

```csharp
// In Program.cs
var builder = Host.CreateApplicationBuilder(args);

// Configure the Loader
builder.Services.AddSingleton<IAssemblyLoader, NativeAssemblyLoader>();

builder.Services.AddHostedService<PluginDemoService>();

// In PluginDemoService:
public class PluginDemoService(IAssemblyLoader assemblyLoader) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        // Discover and load
        var loader = new Loader<ISecretsAbstract>();
        var glob = new DynamicGlobAndPredicate
        {
            Glob = new Glob { Pattern = "./Plugins/*Secrets.Shim.Bitwarden.dll" },
            Predicate = type => typeof(ISecretsAbstract).IsAssignableFrom(type) && !type.IsAbstract
        };

        var secretsProvider = loader.LoadExactlyOneInstanceOfITypeFromAssemblyGlob(glob);

        // Use exactly like static reference
        var apiKey = await secretsProvider.GetSecretAsync("ProGet_Admin_API_Key", cancellationToken: ct);
        Console.WriteLine($"Secret retrieved: {apiKey?[..4]}****");

        // Demonstrate unload
        // (ALC reference tracked internally by Loader for cleanup)
    }
}
```

### 11.3 PowerShell Consumption

```powershell
# Load assemblies
Add-Type -Path "./bin/ATAP.Utilities.Secrets.Interfaces.dll"
Add-Type -Path "./bin/ATAP.Utilities.Secrets.Shim.Bitwarden.dll"

# Create provider
$options = [ATAP.Utilities.Secrets.Shim.Bitwarden.BitwardenSecretsOptions]::new()
$options.Timeout = [TimeSpan]::FromSeconds(15)
$bw = [ATAP.Utilities.Secrets.Shim.Bitwarden.BitwardenSecretsShim]::new($options)

# Check availability
if ($bw.IsAvailable()) {
    $secret = $bw.GetSecretAsync("ProGet_Admin_API_Key", "password").GetAwaiter().GetResult()
    Write-Host "Secret: $($secret.Substring(0, 4))****"
} else {
    Write-Warning "Bitwarden session not available. Run Initialize-BitwardenSession."
}
```

---

## 12. Migration Plan

### Phase 1: Create New Package Structure

1. Create all projects listed in Section 3
2. Implement interfaces and model classes
3. Implement `BitwardenSecretsShim` (consolidated from both implementations)
4. Implement `BitwardenConfigurationProvider` and `BitwardenConfigurationSource`
5. Implement `SecretsPluginShim` with `ILoadDynamicSubModules`
6. Implement DI extension methods

### Phase 2: Test

7. Unit tests for `BitwardenSecretsShim` (mock `bw` CLI process)
8. Unit tests for `SecretsRouter` multi-provider routing
9. Integration tests with actual Bitwarden vault

### Phase 3: Deprecate Old Implementations

10. Add `[Obsolete]` attributes to classes in `src/ATAP.Utilities.Configuration.Secrets/`
11. Add `[Obsolete]` attributes to classes in `src/ATAP.Utilities.Configuration/Secrets/Shims/`
12. Update consuming code to reference new `ATAP.Utilities.Secrets` packages
13. Remove deprecated code in a future release

---

## 13. Future Providers

The architecture supports adding new providers by creating a new Shim subproject:

| Provider                   | Package                                           | Status                                     |
| -------------------------- | ------------------------------------------------- | ------------------------------------------ |
| Bitwarden Password Manager | `ATAP.Utilities.Secrets.Shim.Bitwarden`           | Implementing (this document)               |
| Bitwarden Secrets Manager  | `ATAP.Utilities.Secrets.Shim.BitwardenSM`         | Planned (machine-to-machine via `bws` CLI) |
| KeePass                    | `ATAP.Utilities.Secrets.Shim.KeePass`             | Planned                                    |
| Azure Key Vault            | `ATAP.Utilities.Secrets.Shim.AzureKeyVault`       | Future                                     |
| HashiCorp Vault            | `ATAP.Utilities.Secrets.Shim.HashiCorpVault`      | Future                                     |
| Environment Variables      | `ATAP.Utilities.Secrets.Shim.EnvironmentVariable` | Future (simple wrapper)                    |

Each provider creates:

1. A `.csproj` under `Shim/{ProviderName}/`
2. A class implementing `ISecretsConfigurableAbstract` (or `ISecretsAbstract` for simple providers)
3. A provider-specific options class
4. `ServiceCollectionExtensions.cs` with `Add{Provider}Secrets()`
5. `ConfigurationBuilderExtensions.cs` with `Add{Provider}SecretsToConfiguration()`

---

## 14. Concrete Shims

`ISecretsAbstract` is for retrieving secret values. That means only backends that can
actually return a password, token, or field value should be modeled as Secrets-family
shims. Bitwarden's Public API is useful for organisation administration, but because it
cannot return vault contents it should not be treated as an `ISecretsAbstract`
implementation.

### 14.1 Backend Comparison

| Backend                    | Primary tool / protocol                                 | Best fit                                                                | Planned ATAP implementation                                     | `ISecretsAbstract` mapping                      | Output shape                                         | Notes                                                                                                                              |
| -------------------------- | ------------------------------------------------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------- | ----------------------------------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Bitwarden Password Manager | `bw` CLI                                                | Developer workstations and interactive automation                       | `ATAP.Utilities.Secrets.Shim.Bitwarden`                         | Yes. This is the current concrete shim.         | JSON for `bw get item`; string for `bw get password` | Uses a human vault. Supports email plus master-password login or personal API key, but still requires vault unlock before reads.   |
| Bitwarden Secrets Manager  | `bws` CLI or Secrets Manager REST API / SDK             | CI/CD, headless servers, Docker / Kubernetes secret injection           | `ATAP.Utilities.Secrets.Shim.BitwardenSM`                       | Yes. Planned machine-to-machine shim.           | JSON or direct secret value depending on client      | Uses scoped machine tokens and does not depend on a human vault session. This is the preferred service-account backend.            |
| Bitwarden Public API       | HTTPS admin API                                         | Organisation administration, metadata, membership, groups, audit events | Separate admin client if needed; not part of the Secrets family | No. It should not implement `ISecretsAbstract`. | JSON metadata only                                   | Cannot return secret contents. If used at all, it belongs in an administrative abstraction rather than the secrets retrieval path. |
| KeePass                    | `keepassxc-cli` or `kpcli` against a local `.kdbx` file | Offline laptops, air-gapped labs, zero-server environments              | `ATAP.Utilities.Secrets.Shim.KeePass`                           | Yes. Planned file-backed shim.                  | Plain text or line-based key/value output            | Local database model only. No central sync, no built-in per-secret RBAC, and no remote session service.                            |

### 14.2 Session Lifecycle Differences

| Backend              | Session / credential material                                                                               | Unlock step                                                                                  | Lifetime model                                                                             | Shutdown / cleanup expectation                                                                                               |
| -------------------- | ----------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| `bw`                 | `BW_SESSION`, plus login material such as `BW_CLIENTID` / `BW_CLIENTSECRET` or interactive user credentials | Required. `bw login` authenticates and `bw unlock` decrypts the vault.                       | Session key is transient and tied to the current unlocked vault state.                     | Clear transient credential env vars and run `bw lock` or `bw logout` when work completes.                                    |
| `bws`                | `BWS_ACCESS_TOKEN` or equivalent service-account token                                                      | Not required in the human-vault sense. Authentication is the token.                          | Token-scoped, machine-oriented, revocable server-side.                                     | Remove the token from process scope after use and rotate it through the backing platform or CI secret store.                 |
| Bitwarden Public API | Bearer token or client credentials for admin endpoints                                                      | No vault unlock because no vault decryption occurs.                                          | Standard API-token lifetime, unrelated to personal vault sessions.                         | Revoke or rotate the admin token according to org policy.                                                                    |
| KeePass              | Database path plus master password and/or key file                                                          | Required for each process invocation unless the calling tool caches an already-open database | Local-process lifetime only. There is no shared service session analogous to `BW_SESSION`. | Dispose the CLI process, protect the `.kdbx` file and key file, and avoid persisting plaintext credentials in shell history. |

### 14.3 Routing Rules

- `SecretsRouter` should aggregate only providers that can satisfy `GetSecretAsync()` and `SecretExistsAsync()`.
- On developer machines, `bw` is the expected first-class backend because it aligns with the existing `BW_SESSION` bootstrap pattern.
- On CI runners and other unattended hosts, prefer `bws` over `bw` because machine tokens avoid interactive unlock and keep human vault state out of service processes.
- KeePass is a valid fallback for disconnected or air-gapped scenarios, but it should be modeled as a local file-backed provider with different operational guarantees from Bitwarden.
- Bitwarden Public API calls should bypass `SecretsRouter` entirely and live in a separate administration-oriented client, because returning metadata is not the same contract as returning secret values.

---

## 15. Bitwarden Secrets Manager Adoption and Licensing Notes

This section is an architecture-planning appendix rather than a runtime contract. The
pricing snapshot below comes from the source research captured in `AI on Feeds and
Secrets.md` and should be revalidated against Bitwarden's current commercial terms
before purchase or renewal decisions are made.

### 15.1 Pricing Snapshot and Capacity Shape

| Plan       | Indicative price from source research | Included machine accounts | Operational fit                                                                 |
| ---------- | ------------------------------------- | ------------------------- | ------------------------------------------------------------------------------- |
| Free       | `$0`                                  | `3`                       | Two-person orgs, early CI experiments, a handful of unattended runners          |
| Teams      | `$6` per named user per month         | `20`, then `$1` each      | Small production teams that need more machine identities, RBAC, and event logs  |
| Enterprise | `$12` per named user per month        | `50`, then `$1` each      | SSO-first or regulated environments needing SCIM, granular admin roles, and SLA |

Additional points from the source material:

- Free tier was described as supporting up to two human users and three projects.
- Pricing was presented as including Bitwarden-hosted service, with self-hosting still
  requiring the same product tier but shifting infrastructure ownership to the user.
- User licensing is per named human user, while machine accounts are the non-interactive
  identities intended for CI/CD, servers, containers, and other unattended agents.

### 15.2 Upgrade Path from a Free Two-Person Organisation

- Start with the free two-person Password Manager organisation for shared human-facing
  credentials and collections.
- When unattended workloads appear, enable Secrets Manager as an additional product on
  the same organisation rather than creating a separate Bitwarden tenant.
- The expected activation path is organisational: an owner enables Secrets Manager under
  the organisation's product settings, after which a new Secrets Manager area becomes
  available alongside the existing vault features.
- Keep human vault access and machine access conceptually separate even when both products
  live in the same organisation. Human operators use `bw`; CI and service identities
  should use `bws` machine tokens.
- The free tier is sufficient only while the team stays within the small-capacity limits.
  Once machine-account growth, additional projects, or shared operational governance is
  needed, move to Teams or Enterprise instead of trying to overload human-vault workflows.

### 15.3 Decision Criteria for Migrating from `bw` to Secrets Manager

| Condition                                                                   | Recommended backend choice                          | Rationale                                                                  |
| --------------------------------------------------------------------------- | --------------------------------------------------- | -------------------------------------------------------------------------- |
| Interactive developer workstation with an existing `BW_SESSION` bootstrap   | Stay on `bw`                                        | Reuses the human-vault workflow already documented in this repository      |
| CI runner, Windows service, container, or other unattended host             | Move that workload to `bws`                         | Machine tokens remove the need for interactive unlock and human vault use  |
| Two humans, three or fewer machine accounts, minimal governance             | Free Secrets Manager is enough for initial adoption | Lowest-friction way to add headless access without redesigning the org     |
| More than three machine identities or more than two named operators         | Upgrade to Teams                                    | Expands machine-account capacity and adds RBAC and audit-oriented features |
| SSO, SCIM, granular admin roles, or formal operational support are required | Upgrade to Enterprise                               | Those controls are the dividing line between Teams and Enterprise          |

Architecture implications:

- Adding Secrets Manager does not replace the Bitwarden Password Manager shim for
  developer machines. It introduces an additional concrete shim aimed at unattended
  workloads.
- The trigger for implementing `ATAP.Utilities.Secrets.Shim.BitwardenSM` is not merely
  price, but the moment CI/CD and service processes become first-class consumers of the
  Secrets family.
- When both backends are present, `SecretsRouter` should route by workload boundary:
  `bw` for interactive user sessions, `bws` for service-account paths.

---

## Appendix: Shim Implementation Notes

_Migrated from `_Planning/Explainers/0012-Configuration-Secrets-shim-loading.md`. Captures the current `ATAP.Utilities.Configuration.Secrets` implementation, the live consumer wiring in AceCommander, and known stub limitations._

### Package Graph (As Implemented)

```text
ATAP.Utilities.Configuration          NuGet aggregator
├── Extensions/                       ATAPStandardConfigurationBuilder + IConfigurationBuilder helpers
└── Secrets/                          IConfigurationSecrets interface + AddConfigurationSecrets<TShim>()
                                      ServiceCollectionExtensions.SecretsAdapter (private bridge)
    └── Shims/                        IConfigurationSecretsShim interface + ConfigurationSecretsShims router
        └── Bitwarden/ (opt-in)       BitwardenSecretsShim — calls bw CLI
```

Compile-time dependency direction: `Configuration → Configuration.Extensions`,
`Configuration → Configuration.Secrets → Configuration.Secrets.Shims`,
`Configuration.Secrets.Shim.Bitwarden → Configuration.Secrets` (transitively gets `Shims`).
Shim packages are opt-in; the aggregator does **not** reference any shim.

### Consumer Wiring (AceCommander)

AceCommander's `Program.cs` registers Bitwarden with one of two equivalent calls:

```csharp
// Option A — generic
builder.Services.AddConfigurationSecrets<BitwardenSecretsShim>();

// Option B — Bitwarden-native (no generic arg needed)
builder.Services.AddBitwardenSecrets();
```

Both register the same three singletons:
`IConfigurationSecretsShim → BitwardenSecretsShim`,
`ConfigurationSecretsShims` (router),
`IConfigurationSecrets → SecretsAdapter`.

Callers inject only `IConfigurationSecrets` — never the shim or router types.

### Why `SecretsAdapter` Lives In `Secrets` (Not `Shims`)

```text
Secrets  →  Secrets.Shims          ✓  (ProjectReference)
Shims   →×→ Secrets                ✗  would create a cycle
```

`ConfigurationSecretsShims` structurally matches `IConfigurationSecrets` but cannot
formally implement it due to this cycle. `SecretsAdapter` in `Secrets` is the permanent
workaround until a dedicated `Secrets.Shims.Interfaces` project is introduced.

### Runtime Prerequisite: `BW_SESSION`

`BitwardenSecretsShim` invokes the `bw` Bitwarden CLI. It requires:

1. `bw` on `PATH`.
2. `BW_SESSION` env var set to a valid vault session key.

`BW_SESSION` is populated automatically at user login by `Initialize-BitwardenSession`
in `LoginScript.ps1`. If `BW_SESSION` is absent, `BitwardenSecretsShim` throws
`InvalidOperationException` immediately.

For agent-spawned shells that do not inherit interactive session env vars, read from
User scope:

```powershell
[System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User')
```

### `GetSecretAsync(secretName, fieldName)` Semantics

| `fieldName`              | How retrieved                                                                | Example                            |
| ------------------------ | ---------------------------------------------------------------------------- | ---------------------------------- |
| `"password"` _(default)_ | `bw get password <name> --session <BW_SESSION>`                              | login passwords                    |
| Any other string         | `bw get item <name>` → parse JSON → match `fields[].name` case-insensitively | `"token"`, `"key"`, `"Passphrase"` |

### Error Conditions

| Condition                      | Behaviour                                                  |
| ------------------------------ | ---------------------------------------------------------- |
| `BW_SESSION` not set           | `InvalidOperationException` thrown inside `GetSecretAsync` |
| `bw` not on PATH               | Process start failure propagates from `GetSecretAsync`     |
| Item name not found            | Returns `null` (exit code non-zero from `bw`)              |
| Vault locked (session expired) | `bw` exits non-zero; returns `null` — no exception         |

### Known Stub Limitations

- Selection of the active shim is currently compile-time via the generic type argument
  (`AddConfigurationSecrets<TShim>()`). A future `ConfigurationRootTree`-driven
  selection (reading e.g. `ConfigurationSecrets:Provider` from `IConfiguration`) is
  designed but not yet active.
- The router (`ConfigurationSecretsShims`) supports multiple registered shims but the
  iteration ordering / first-non-null-wins rule is not yet test-covered for multi-shim
  scenarios.
- Vault-locked condition silently returns `null`; consumers must treat `null` as
  "not found OR vault-locked" until a dedicated lock-state exception is added.
