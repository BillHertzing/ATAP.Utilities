@{
  RootModule           = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell.psm1'
  ModuleVersion        = '0.1.1'
  GUID                 = 'A2B1C552-FD36-4DCE-92B8-0A76BD4FA92F'
  Author               = 'Bill Hertzing for ATAPUtilities.org'
  CompanyName          = 'ATAPUtilities.org'
  Copyright            = '(c) 2018 - 2026 Bill Hertzing. All rights reserved. All code is under the MIT license'
  Description          = 'BuildTooling .NET and PowerShell build child module.'

  PowerShellVersion    = '7.0'
  CompatiblePSEditions = @('Core')
  RequiredModules      = @(
    @{ ModuleName = 'ATAP.Utilities.BuildTooling.Common.PowerShell'; ModuleVersion = '0.1.7' }
    @{ ModuleName = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'; ModuleVersion = '0.1.1' }
  )

  FunctionsToExport    = @(
    'Build-ImageFromPlantUML'
    'Build-PSModuleManifest'
    'Build-PSModulePsm1'
    'Clear-NuGetCaches'
    'Compress-PSModuleArtifacts'
    'Get-BuildContext'
    'Get-PSModuleVersionFromNBGV'
    'Invoke-DotnetBuildWithRetry'
    'Invoke-DotnetNuGetPush'
    'Invoke-ModuleBuildWithRetry'
    'Invoke-MSBuildWithLists'
    'Invoke-PSModulePSScriptAnalyzer'
    'New-PSModuleNupkg'
    'Parse-MSBuildFile'
    'Resolve-FeatureSlug'
    'Resolve-PSModuleMetadata'
  )
  CmdletsToExport      = @()
  VariablesToExport    = @()
  AliasesToExport      = @()

  PrivateData          = @{
    PSData = @{
      Tags       = @('ATAP', 'BuildTooling', 'Dotnet', 'MSBuild', 'PowerShell')
      ProjectUri = 'https://github.com/whertzing/ATAP.Utilities'
    }
  }
}
