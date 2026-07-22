$moduleRoot = $PSScriptRoot

$privateFunctions = @(Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'private') -Filter '*.ps1' -ErrorAction SilentlyContinue)
$publicFunctions = @(Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'public') -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($import in @($privateFunctions + $publicFunctions)) {
  . $import.FullName
}

Export-ModuleMember -Function @(
  'Assert-GitAvailable',
  'Get-WorkspaceJson',
  'Initialize-ATAPConfigurationGlobals',
  'Resolve-WorkspaceFiles'
) -Cmdlet @() -Variable @() -Alias @()
