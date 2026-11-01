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
- `tests/Unit/SecretReadPrivacy.Tests.ps1` covers handled secret-read error
  payloads with fake providers and inputs. Task 17.68.f postcheck 1100 records
  11 source-only cases across four suites.
- `tests/Unit/BWSAccessToken.Privacy.Tests.ps1` covers token-reader error payloads
  and per-record pipeline inputs with fake credential operations. Task 17.68.f
  postcheck 1116 records 14 source-only cases across four suites.
- Task 17.68.f postcheck 1103 records 13 existing fake regression cases across
  five suites. Together these are 38 source-only cases across 13 suites; they do
  not verify an installed package, real PSFramework sinks, or deployment.
