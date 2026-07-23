@{
  RootModule            = 'ATAP.Utilities.Security.Secrets.PowerShell.psm1'
  ModuleVersion         = '0.1.0'
  GUID                  = '13091621-f83d-416f-b809-047049a799fa'
  Author                = 'Bill Hertzing for ATAPUtilities.org'
  CompanyName           = 'ATAPUtilities.org'
  Copyright             = '(c) 2018 - 2026 Bill Hertzing. All rights reserved. All code is under the MIT license'
  Description           = 'Bitwarden and secrets-vault functions for ATAP. Extracted from ATAP.Utilities.Security.Powershell as the pilot child of the Security module family (Sprint 0012 Task 12.55.b).'

  PowerShellVersion     = '7.0'
  CompatiblePSEditions  = @('Core')

  # Invoke-RotateSecretsATAP calls Get-BWSAccessToken / Initialize-BWSAccessToken with
  # -TokenPurpose, which first ships in BuildTooling 0.1.29 (Sprint 0012 Stream I, Tasks
  # 12.50-12.54). The minimum is declared, not an exact version, so a later BuildTooling
  # satisfies it. No edge on the PKI child -- design decision D1.
  RequiredModules       = @(
    'PSFramework',
    'Microsoft.PowerShell.SecretManagement',
    @{ ModuleName = 'ATAP.Utilities.BuildTooling.Secrets.PowerShell'; ModuleVersion = '0.1.0' }
  )

  FunctionsToExport     = @(
    'Get-BitWardenCredential',
    'Invoke-RotateSecretsATAP',
    'List-BitwardenSecrets',
    'Load-BitwardenBackup',
    'New-BitwardenBackup',
    'Set-BitWardenSecret',
    'Sync-BitWardenDedicatedSecrets'
  )

  CmdletsToExport       = @()
  VariablesToExport     = @()

  AliasesToExport       = @(
    'New-BWSecret',
    'Add-BitWardenLogin',
    'Sync-DedicatedSecrets'
  )

  PrivateData           = @{
    PSData = @{
      Tags       = @('ATAP', 'Security', 'Secrets', 'Bitwarden')
      ProjectUri = 'https://github.com/whertzing/ATAP.Utilities'
    }
  }
}
