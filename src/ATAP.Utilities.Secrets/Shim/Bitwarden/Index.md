# Index — ATAP.Utilities.Configuration.Secrets.Shim.Bitwarden

## Contents

| File                                                                   | Description                                                                                |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| [ReadMe.md](ReadMe.md)                                                 | Project documentation                                                                      |
| [BitwardenSecretsShim.cs](BitwardenSecretsShim.cs)                     | Concrete `SecretsConfigurableAbstract` that invokes the Bitwarden CLI to retrieve secrets  |
| [BitwardenSecretsOptions.cs](BitwardenSecretsOptions.cs)               | Configuration options — session env var, default field name, CLI path, timeouts            |
| [BitwardenConfigurationProvider.cs](BitwardenConfigurationProvider.cs) | `IConfigurationProvider` exposing Bitwarden vault entries as configuration key/value pairs |
| [BitwardenConfigurationSource.cs](BitwardenConfigurationSource.cs)     | `IConfigurationSource` registered with `IConfigurationBuilder`                             |
| [ConfigurationBuilderExtensions.cs](ConfigurationBuilderExtensions.cs) | `AddBitwarden(…)` extension method for `IConfigurationBuilder`                             |
| [ServiceCollectionExtensions.cs](ServiceCollectionExtensions.cs)       | `AddBitwardenSecrets(…)` extension method for `IServiceCollection`                         |
