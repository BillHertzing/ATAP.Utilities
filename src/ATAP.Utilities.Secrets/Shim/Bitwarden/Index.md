# Obsolete Bitwarden Password Manager compatibility index

## Contents

Every API listed below is obsolete, non-default Password Manager compatibility.
It must not be used by application hosts and must never be a fallback from the
supported `bws` plus DPAPI `ReadOnly` provider.

| File | Obsolete compatibility responsibility |
| --- | --- |
| [ReadMe.md](ReadMe.md) | Migration warning and supported replacement |
| [BitwardenSecretsShim.cs](BitwardenSecretsShim.cs) | Obsolete Password Manager CLI invocation |
| [BitwardenSecretsOptions.cs](BitwardenSecretsOptions.cs) | Obsolete session-variable, field, CLI-path, and timeout options |
| [BitwardenConfigurationProvider.cs](BitwardenConfigurationProvider.cs) | Obsolete synchronous Password Manager configuration provider |
| [BitwardenConfigurationSource.cs](BitwardenConfigurationSource.cs) | Obsolete configuration source |
| [ConfigurationBuilderExtensions.cs](ConfigurationBuilderExtensions.cs) | Obsolete `AddBitwarden(...)` registration |
| [ServiceCollectionExtensions.cs](ServiceCollectionExtensions.cs) | Obsolete `AddBitwardenSecrets(...)` registration |

See the [supported Bitwarden Secrets Manager provider](../../BitwardenSecretsManager/ReadMe.md).
