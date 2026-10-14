@{
  RootModule = 'ATAP.Utilities.BuildTooling.Secrets.PowerShell.psm1'
  ModuleVersion = '0.1.0'
  GUID = 'FC569DA2-E693-4E23-946E-2EE9F82BA43E'
  Author = 'Bill Hertzing for ATAPUtilities.org'
  CompanyName = 'ATAPUtilities.org'
  Copyright = '(c) Bill Hertzing for ATAPUtilities.org. All rights reserved.'
  Description = 'BuildTooling secrets-provider and Bitwarden Secrets Manager child module.'
  PowerShellVersion = '7.0'
  CompatiblePSEditions = @('Core')
  RequiredModules = @(
    @{ ModuleName = 'ATAP.Utilities.BuildTooling.Common.PowerShell'; ModuleVersion = '0.1.5' },
    @{ ModuleName = 'PSFramework'; ModuleVersion = '1.14.457' }
  )
  FunctionsToExport = @(
    'Get-BWSAccessToken',
    'Get-DbConnectionStringSecretDescriptor',
    'Get-SecretATAP',
    'Get-SecretATAPBitwarden',
    'Get-SecretATAPBitwardenSecretsManager',
    'Initialize-BWSAccessToken',
    'Initialize-BWSApplicationAccessToken',
    'Initialize-BWSCredentialDirectory',
    'Invoke-BWSReadOnlyTokenBootstrap',
    'New-BWSReadOnlyBootstrapEnvelope',
    'New-SprintBitwardenSecrets',
    'Remove-SprintBitwardenSecrets'
  )
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @(
    'Get-ServiceAccountBWSAccessToken',
    'Initialize-ServiceAccountBWSAccessToken'
  )
  PrivateData = @{ PSData = @{ Tags = @('ATAP', 'BuildTooling', 'Secrets', 'Bitwarden') } }
}
