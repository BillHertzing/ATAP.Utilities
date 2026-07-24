@{
  RootModule = 'ATAP.Utilities.BuildTooling.BuildMaster.PowerShell.psm1'
  ModuleVersion = '0.1.0'
  GUID = '4196bc5e-7545-42a1-8bfd-cf3d0c5fd72e'
  Author = 'Bill Hertzing for ATAPUtilities.org'
  CompanyName = 'ATAPUtilities.org'
  Copyright = '(c) ATAPUtilities.org'
  Description = 'BuildMaster automation child module for ATAP.Utilities BuildTooling.'
  PowerShellVersion = '7.0'
  CompatiblePSEditions = @('Core')
  RequiredModules = @(
    @{ ModuleName = 'ATAP.Utilities.BuildTooling.Common.PowerShell'; ModuleVersion = '0.1.7' },
    @{ ModuleName = 'ATAP.Utilities.BuildTooling.Secrets.PowerShell'; ModuleVersion = '0.1.0' }
  )
  FunctionsToExport = @(
    'Approve-BuildMasterStage','Assert-BuildMasterReady','Clear-BuildMasterSprintVariables',
    'New-BuildMasterApplication','New-BuildMasterRelease','New-BuildMasterScript',
    'Remove-BuildMasterApplication','Remove-BuildMasterApplicationVariable','Remove-BuildMasterRelease','Remove-BuildMasterScript',
    'Set-BuildMasterApplicationVariables','Set-BuildMasterPipelineStageDeploymentStep','Set-BuildMasterSprintVariables','Set-BuildMasterStableVariables',
    'Start-BuildMasterDeployment','Start-BuildMasterModulePipelineBatch','Start-BuildMasterPackagePipeline','Start-BuildMasterPipeline','Sync-BuildMasterPlans'
  )
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
}
