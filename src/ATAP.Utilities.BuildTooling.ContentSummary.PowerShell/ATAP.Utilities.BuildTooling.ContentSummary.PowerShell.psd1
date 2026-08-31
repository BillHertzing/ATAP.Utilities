@{
  RootModule = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell.psm1'
  ModuleVersion = '0.1.3'
  CompatiblePSEditions = @('Core')
  GUID = '35c51a21-6e84-4c6d-b745-5ca83d8a7680'
  Author = 'Bill Hertzing for ATAPUtilities.org'
  CompanyName = 'ATAPUtilities.org'
  Copyright = '(c) Bill Hertzing for ATAPUtilities.org. All rights reserved.'
  Description = 'Loopback-only HTTPS client for the AceOutpost gather-content API.'
  PowerShellVersion = '7.0'
  RequiredModules = @(
    @{ ModuleName = 'PSFramework'; ModuleVersion = '1.14.457' }
  )
  FunctionsToExport = @('Get-ContentSummary')
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
  PrivateData = @{
    PSData = @{
      Tags = @('ATAP', 'AceOutpost', 'ContentSummary', 'REST')
      ReleaseNotes = 'Ship the REST02-compatible UUID Idempotency-Key client as the immutable 0.1.3 stable replacement without widening the JSON request body.'
    }
  }
}
