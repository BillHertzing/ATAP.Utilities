$moduleRoot = $PSScriptRoot
$allFunctions = @(Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'private') -Filter '*.ps1' -File) + @(Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'public') -Filter '*.ps1' -File)
foreach ($import in $allFunctions) { . $import.FullName }
