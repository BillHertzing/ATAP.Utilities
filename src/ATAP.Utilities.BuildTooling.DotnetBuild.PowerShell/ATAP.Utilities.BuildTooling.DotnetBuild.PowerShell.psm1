$publicFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
foreach ($import in @($publicFunctions + $privateFunctions)) {
  . $import.FullName
}

Export-ModuleMember -Function @(
  'Build-ImageFromPlantUML'
  'Build-PSModuleManifest'
  'Build-PSModulePsm1'
  'Clear-NuGetCaches'
  'Compress-PSModuleArtifacts'
  'Get-BuildContext'
  'Get-PSModuleVersionFromNBGV'
  'Install-DabGlobalTool'
  'Initialize-DabMcpConfiguration'
  'Initialize-DabMcpServer'
  'Add-DabMcpEntity'
  'Invoke-DotnetBuildWithRetry'
  'Invoke-DotnetNuGetPush'
  'Invoke-ModuleBuildWithRetry'
  'Invoke-MSBuildWithLists'
  'Invoke-PSModulePSScriptAnalyzer'
  'New-PSModuleNupkg'
  'Parse-MSBuildFile'
  'Resolve-FeatureSlug'
  'Resolve-PSModuleMetadata'
  'Start-DabMcpServer'
  'Test-DabInstallation'
  'Test-DabMcpConfiguration'
) -Cmdlet @() -Variable @() -Alias @()
