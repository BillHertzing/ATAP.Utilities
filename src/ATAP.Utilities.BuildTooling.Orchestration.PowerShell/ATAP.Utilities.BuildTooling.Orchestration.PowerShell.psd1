@{
  RootModule = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psm1'
  ModuleVersion = '0.1.7'
  GUID = '01131809-7fd2-4b6d-8a34-f584b55ad4fa'
  Author = 'ATAP'
  CompanyName = 'ATAP'
  Copyright = '(c) Bill Hertzing for ATAPUtilities.org. All rights reserved.'
  Description = 'Bounded existing-task coordination with protected custody, durable requests, drain and export.'
  PowerShellVersion = '7.4'
  CompatiblePSEditions = @('Core')
  RequiredModules = @(@{ ModuleName = 'PSFramework'; ModuleVersion = '1.14.457' })
  FunctionsToExport = @('Get-CoordTask', 'Get-CoordResult', 'Get-CoordClaims', 'Stop-CoordClerk', 'Submit-CoordRequest', 'Invoke-CoordClerk', 'Export-CoordState', 'Update-CoordWitness')
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
}
