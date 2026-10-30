@{
  RootModule = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psm1'
  ModuleVersion = '0.1.0'
  GUID = '01131809-7fd2-4b6d-8a34-f584b55ad4fa'
  Author = 'ATAP'
  Description = 'Source-stage orchestration module scaffold.'
  PowerShellVersion = '7.4'
  CompatiblePSEditions = @('Core')
  RequiredModules = @(@{ ModuleName = 'PSFramework'; ModuleVersion = '1.14.457' })
  FunctionsToExport = @('Get-CoordTask')
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
}
