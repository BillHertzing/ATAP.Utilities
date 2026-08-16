# Bitwarden Secrets Manager provider

This is the supported application path: Bitwarden Secrets Manager `bws`, a
Bitwarden Project, exact individual SecretNames, and an identity-bound DPAPI
`ReadOnly` access-token source on Windows.

## Scope

This package resolves individual secrets through the Bitwarden Secrets Manager
`bws` CLI. There are no secret sets. An application owns a group of individual
secrets organized as a Bitwarden Project; another vault product may express the
same grouping through its own provider-neutral grouping mechanism.

AceCommander and AceOutpost use distinct Bitwarden Projects. The options bind one
application ID to exactly one Project ID and grouping ID. SecretNames are compared
with `StringComparison.Ordinal`; zero matches is missing and multiple exact matches
fail closed.

## Packages

- `ATAP.Utilities.Secrets.BitwardenSecretsManager` contains the portable provider,
  bounded process runner, typed failures, and asynchronous mapping loader.
- `ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows` contains the Windows
  identity-bound DPAPI `ReadOnly` token reader and composition registration.
- `ATAP.Utilities.Secrets.Shim.Bitwarden` is obsolete, warning-only Password Manager
  compatibility. It uses `bw`, `BW_SESSION`, and `--session`; it is never a default
  or fallback and emits `ATAPSECRETS001`.

## Application configuration

Configure `ApplicationId`, `ProjectId`, `ProjectName`, `VaultGroupingId`, an
absolute local `BwsExecutablePath`, and the approved executable's
`TrustedBwsSha256`. Configure required SecretNames explicitly. Values and tokens
must not appear in configuration, logs, exceptions, caches, or parent-process
environment variables.

The following values are synthetic. Replace IDs, names, paths, mappings, and the
approved executable digest with deployment-owned metadata; never place an access
token or secret value in configuration.

```json
{
  "Secrets": {
    "BitwardenSecretsManager": {
      "ApplicationId": "acecommander",
      "ProjectId": "11111111-1111-1111-1111-111111111111",
      "ProjectName": "AceCommander",
      "VaultGroupingId": "11111111-1111-1111-1111-111111111111",
      "BwsExecutablePath": "C:\\Program Files\\Bitwarden Secrets Manager CLI\\bws.exe",
      "TrustedBwsSha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
      "TimeoutSeconds": 30,
      "TokenPurpose": "ReadOnly",
      "RequiredSecretNames": ["Database.Primary.ConnectionString"]
    }
  }
}
```

Register the portable provider and Windows DPAPI token source with matching IDs:

```csharp
var providerOptions = new BitwardenSecretsManagerOptions
{
  ApplicationId = "acecommander",
  ProjectId = "11111111-1111-1111-1111-111111111111",
  ProjectName = "AceCommander",
  VaultGroupingId = "11111111-1111-1111-1111-111111111111",
  BwsExecutablePath = @"C:\Program Files\Bitwarden Secrets Manager CLI\bws.exe",
  TrustedBwsSha256 =
    "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  TokenPurpose = BwsTokenPurpose.ReadOnly,
  RequiredSecretNames = new HashSet<string>(StringComparer.Ordinal)
  {
    "Database.Primary.ConnectionString",
  },
};

var tokenSourceOptions = new WindowsBwsTokenSourceOptions
{
  ApplicationId = providerOptions.ApplicationId,
  VaultGroupingId = providerOptions.VaultGroupingId,
  AllowLegacyPowerShellCliXml = false,
};

services.AddBitwardenSecretsManager(providerOptions);
services.AddWindowsDpapiBwsReadOnlyAccessTokenSource(tokenSourceOptions);
```

Load mapped values asynchronously during host startup:

```csharp
var loader = host.Services
  .GetRequiredService<BitwardenSecretsManagerConfigurationLoader>();
await configurationBuilder.AddBitwardenSecretsManagerConfigurationAsync(
  loader,
  new[]
  {
    new BwsSecretMapping(
      "ConnectionStrings:Primary",
      "Database.Primary.ConnectionString"),
  },
  cancellationToken);
```

Use `BitwardenSecretsManagerConfigurationLoader.LoadAsync` during asynchronous
host startup. It lists the Project once and maps the returned individual secrets
to application configuration keys. Required missing values and duplicate keys
fail startup; optional missing values are omitted. There is no synchronous
configuration-source adapter and no sync-over-async bridge.

## Windows token binding

The canonical token slot is per host, effective Windows identity, application,
Project/grouping, and `ReadOnly` purpose. Development uses the developer identity;
automated unit, integration, end-to-end, and performance runs use
`SvcBuildMaster`. Each identity decrypts only its own DPAPI `CurrentUser` token.

The version 1 `AtapBwsDpapiEnvelope` repeats its binding metadata inside the DPAPI
plaintext. Additional entropy is a length-prefixed UTF-8 sequence containing the
protocol label, format version, canonical host, SID, application ID, provider,
grouping ID, and `ReadOnly`. The reader validates outer metadata, decrypts, and
then validates the inner binding before returning a bounded, zeroed lease.

Legacy PowerShell PSCredential CLIXML is available only when
`AllowLegacyPowerShellCliXml` is explicitly enabled. Recognized canonical and
legacy candidates are enumerated first; more than one fails as ambiguous, and an
envelope never falls through to CLIXML parsing.

The default Windows ACL validator requires protected (non-inherited) ACLs,
permits only the effective identity, LocalSystem, and Builtin Administrators,
rejects deny and inherited rules, restricts ownership to that allowlist, and
requires explicit read access for the effective identity. Applications may
replace the validator only with a stricter ratified policy. Deployment and
production acceptance remain outside this implementation task.

## Process boundary

`BwsProcessRunner` rejects a parent `BWS_ACCESS_TOKEN`, verifies the configured
local non-reparse executable and SHA-256 digest, passes the token only to the
direct child environment, uses `UseShellExecute=false` and `ArgumentList`, drains
stdout and stderr before waiting, bounds capture, kills the process tree on
timeout or cancellation, and suppresses CLI output from logs and exceptions.