# Secrets module index

## Public commands

- `Get-BWSAccessToken`
- `Get-DbConnectionStringSecretDescriptor`
- `Get-SecretATAP`
- `Get-SecretATAPBitwarden`
- `Get-SecretATAPBitwardenSecretsManager`
- `Initialize-BWSAccessToken`
- `Initialize-BWSCredentialDirectory`
- `Invoke-BWSReadOnlyTokenBootstrap`
- `New-BWSReadOnlyBootstrapEnvelope`
- `New-SprintBitwardenSecrets`
- `Remove-SprintBitwardenSecrets`

## Verification

- `tests/Unit/BWSReadOnlyBootstrap.Tests.ps1` uses real in-memory ScheduledTasks
  CIM definitions for the fail-closed cleanup fixture. PowerShell 7.6 validates
  CIM-typed parameters before Pester command proxies can accept a
  `PSCustomObject`, so only registration/start/info/cleanup operations are
  mocked.
- The Task 13.41 bootstrap and secret-free parity focused suites pass 33/33.
