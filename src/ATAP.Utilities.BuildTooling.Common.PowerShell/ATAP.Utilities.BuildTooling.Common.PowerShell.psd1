@{
  RootModule           = 'ATAP.Utilities.BuildTooling.Common.PowerShell.psm1'
  ModuleVersion        = '0.1.5'
  GUID                 = 'e5188e6b-f4de-451b-9ec1-d8e5dd15a6fd'
  Author               = 'Bill Hertzing for ATAPUtilities.org'
  CompanyName          = 'ATAPUtilities.org'
  Copyright            = '(c) 2018 - 2026 Bill Hertzing. All rights reserved. All code is under the MIT license'
  Description          = 'Shared PowerShell helpers for the ATAP BuildTooling module family.'

  PowerShellVersion    = '7.0'
  CompatiblePSEditions = @('Core')
  RequiredModules      = @(
    @{ ModuleName = 'PSFramework'; ModuleVersion = '1.14.457'; MaximumVersion = '1.999.999' }
  )

  FunctionsToExport    = @(
    'Assert-GitAvailable',
    'Get-RepositoryRoot',
    'Get-WorkspaceJson',
    'Initialize-ATAPConfigurationGlobals',
    'Resolve-WorkspaceFiles'
  )
  CmdletsToExport      = @()
  VariablesToExport    = @()
  AliasesToExport      = @()

  PrivateData          = @{
    PSData = @{
      Tags       = @('ATAP', 'BuildTooling', 'Common', 'PowerShell')
      ProjectUri = 'https://github.com/whertzing/ATAP.Utilities'
    }
  }
}
