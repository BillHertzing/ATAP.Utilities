$publicFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
foreach ($import in @($publicFunctions + $privateFunctions)) {
  . $import.FullName
}

Export-ModuleMember -Function @(
  'Get-MergedPesterConfigurations',
  'Merge-PesterConfiguration',
  'New-MockTestFileStructure',
  'New-PesterBasicUnitTestTemplate',
  'New-PesterContextBlock',
  'New-PesterDataDrivenTestTemplate',
  'New-PesterDescribeBlock',
  'New-PesterFileModel',
  'New-PesterItBlock',
  'New-PesterTestFile'
) -Cmdlet @() -Variable @() -Alias @()
