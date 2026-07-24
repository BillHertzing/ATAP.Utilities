$publicFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
foreach ($import in @($publicFunctions + $privateFunctions)) {
  . $import.FullName
}

Export-ModuleMember -Function @(
  'Collect-DatabasePackageEvidence'
  'Get-DatabasePackageBuildContext'
  'Initialize-ProGetSqlServiceLogin'
  'Invoke-BuildToolingSqlQuery'
  'New-DeveloperSqlServerInstances'
  'Parse-SQLFile'
  'Remove-DeveloperSqlServerInstances'
  'Remove-SprintDatabases'
  'Reset-SprintDatabases'
  'Resolve-BuildToolingDatabaseSqlConnection'
  'Resolve-DatabasePackageFeed'
  'Test-DatabasePackageCompatibility'
) -Cmdlet @() -Variable @() -Alias @()
