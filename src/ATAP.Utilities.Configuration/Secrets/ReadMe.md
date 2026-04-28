# ATAP.Utilities.Configuration.Secrets

## Purpose

Provides DI registration helpers that wire an `IConfigurationSecrets` implementation into the
`Microsoft.Extensions.DependencyInjection` container. The two extension methods support two
back-end choices:

| Method                                                 | Back-end                                                                                                  |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| `AddConfigurationSecrets<TShim>()`                     | Any `IConfigurationSecretsShim` implementation injected directly                                          |
| `AddConfigurationSecretsFromProvider(secretsProvider)` | An `ISecretsAbstract` instance (e.g. from the ATAP plugin system) wrapped by `SecretsAbstractShimAdapter` |

> **Obsolescence notice:** This assembly and its types are marked `[Obsolete]`.
> New code should use `ATAP.Utilities.Secrets` and its plugin / shim pattern directly.
> This assembly remains for backward compatibility and will be removed in a future release.

## Architecture

```
IServiceCollection
   └─ AddConfigurationSecrets<TShim>()
         ├─ registers IConfigurationSecretsShim → TShim (singleton)
         └─ registers IConfigurationSecrets    → ConfigurationSecretsShims (singleton)

   └─ AddConfigurationSecretsFromProvider(ISecretsAbstract)
         ├─ wraps provider in SecretsAbstractShimAdapter
         ├─ registers IConfigurationSecretsShim → SecretsAbstractShimAdapter (singleton)
         └─ registers IConfigurationSecrets    → ConfigurationSecretsShims (singleton)
```

The `Shims/` subfolder contains `IConfigurationSecretsShim`, `ConfigurationSecretsShims`,
and `SecretsAbstractShimAdapter` — the bridging types between the legacy
`IConfigurationSecrets` surface and the newer `ISecretsAbstract` / plugin pattern.

## Prerequisites

- .NET 10.0 or later
- `Microsoft.Extensions.DependencyInjection.Abstractions`
- `ATAP.Utilities.Secrets` (for `ISecretsAbstract` used by `AddConfigurationSecretsFromProvider`)

## Setup

Add the NuGet reference:

```xml
<PackageReference Include="ATAP.Utilities.Configuration.Secrets" Version="*" />
```

**Option A — direct shim** (e.g. for testing with a mock shim):

```csharp
services.AddConfigurationSecrets<MyCustomSecretsShim>();
```

**Option B — plugin-provided secrets** (recommended for production):

```csharp
// secretsProvider is an ISecretsAbstract resolved via the plugin system
services.AddConfigurationSecretsFromProvider(secretsProvider);
```

Then inject `IConfigurationSecrets` wherever secrets lookups are needed.

## Known Issues

- The entire `ATAP.Utilities.Configuration.Secrets` namespace is deprecated.
  Prefer `ATAP.Utilities.Secrets` for all new development.

## Release Notes

<!-- Document release history and changes -->
