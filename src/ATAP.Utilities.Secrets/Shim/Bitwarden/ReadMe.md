# ATAP.Utilities.Configuration.Secrets.Shim.Bitwarden

## Purpose

Provides a Bitwarden-backed implementation of the ATAP secrets shim pattern.
This assembly bridges the Bitwarden CLI (`bw`) into the ATAP secrets plugin system and into
`Microsoft.Extensions.Configuration` via a custom `IConfigurationProvider`.

Key types:

| Type                             | Description                                                                                       |
| -------------------------------- | ------------------------------------------------------------------------------------------------- |
| `BitwardenSecretsShim`           | Concrete `SecretsConfigurableAbstract` that invokes `bw` to retrieve secrets by name              |
| `BitwardenSecretsOptions`        | Configuration options — session environment variable name, default field name, CLI path, timeouts |
| `BitwardenConfigurationProvider` | `IConfigurationProvider` that exposes Bitwarden vault entries as configuration key/value pairs    |
| `BitwardenConfigurationSource`   | `IConfigurationSource` registered with `IConfigurationBuilder`                                    |
| `ConfigurationBuilderExtensions` | Extension method `AddBitwarden(…)` for `IConfigurationBuilder`                                    |
| `ServiceCollectionExtensions`    | Extension method `AddBitwardenSecrets(…)` for `IServiceCollection`                                |

## Architecture

```
IConfigurationBuilder
   └─ AddBitwarden()
         └─ BitwardenConfigurationSource
               └─ BitwardenConfigurationProvider
                     └─ BitwardenSecretsShim
                           └─ bw CLI (spawned process)
```

`BitwardenSecretsShim` derives from `SecretsConfigurableAbstract` (defined in
`ATAP.Utilities.Secrets`) and implements secret retrieval by spawning the Bitwarden CLI
with the session token read from the environment variable named in `BitwardenSecretsOptions.SessionEnvVarName`.
`IsAvailable()` returns `false` when the session token variable is absent, allowing the host
to skip Bitwarden silently in environments where it is not installed.

For DI consumers that prefer `ISecretsAbstract` over the Configuration provider, register
`BitwardenSecretsShim` directly via `ServiceCollectionExtensions.AddBitwardenSecrets()`.

## Prerequisites

- .NET 10.0 or later
- Bitwarden CLI (`bw`) installed and on `PATH`
- A valid Bitwarden session token in the environment variable specified by `BitwardenSecretsOptions.SessionEnvVarName` (default: `BW_SESSION`)
- `ATAP.Utilities.Secrets` (for `SecretsConfigurableAbstract` and `ISecretsAbstract`)

## Setup

Add the NuGet reference:

```xml
<PackageReference Include="ATAP.Utilities.Secrets.Shim.Bitwarden" Version="*" />
```

**Configuration provider** (reads vault entries into `IConfiguration`):

```csharp
builder.Configuration.AddBitwarden(options =>
{
    options.SessionEnvVarName = "BW_SESSION";
    options.DefaultFieldName  = "password";
});
```

**DI / `ISecretsAbstract`** (inject secrets service into application code):

```csharp
services.AddBitwardenSecrets();
// Then inject ISecretsAbstract where needed.
```

## Known Issues

- Session tokens are short-lived; a new token must be obtained (`bw unlock`) before each
  agent or CI run.
- Spawning the CLI is time-intensive for bulk secret lookups. Batch requests where possible.

## Release Notes

<!-- Document release history and changes -->
