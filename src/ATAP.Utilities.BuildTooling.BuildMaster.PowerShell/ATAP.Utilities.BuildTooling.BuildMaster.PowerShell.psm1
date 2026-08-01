$moduleRoot = $PSScriptRoot
$privatePath = Join-Path $moduleRoot 'private'
$privateFunctions = @(if (Test-Path -LiteralPath $privatePath -PathType Container) {
  Get-ChildItem -LiteralPath $privatePath -Filter '*.ps1' -File
})
$publicFunctions = @(Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'public') -Filter '*.ps1' -File)
$allFunctions = $privateFunctions + $publicFunctions
foreach ($import in $allFunctions) { . $import.FullName }
