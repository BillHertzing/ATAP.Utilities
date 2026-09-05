@{
  RootModule = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell.psm1'
  ModuleVersion = '0.1.8'
  CompatiblePSEditions = @('Core')
  GUID = '35c51a21-6e84-4c6d-b745-5ca83d8a7680'
  Author = 'Bill Hertzing for ATAPUtilities.org'
  CompanyName = 'ATAPUtilities.org'
  Copyright = '(c) Bill Hertzing for ATAPUtilities.org. All rights reserved.'
  Description = 'Validated ContentSummary harvesting and loopback-only AceOutpost retrieval.'
  PowerShellVersion = '7.0'
  RequiredModules = @(
    @{ ModuleName = 'PSFramework'; ModuleVersion = '1.14.457' }
  )
  FunctionsToExport = @(
    'Get-ContentSummary',
    'Invoke-ContentSummaryHarvest',
    'New-ContentSummarySqlAdapterSet',
    'Read-ContentSummaryRepositoryInventory',
    'Invoke-ContentSummaryRepositoryInventory',
    'New-ContentSummaryDeterministicSafeSummaryGenerator'
  )
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
  PrivateData = @{
    PSData = @{
      Tags = @('ATAP', 'AceOutpost', 'ContentSummary', 'REST', 'SqlClient')
      ReleaseNotes = 'Preserve capture SHA-256 parameters as exact 32-byte arrays through the packaged SqlClient adapter boundary.'
    }
  }
}
