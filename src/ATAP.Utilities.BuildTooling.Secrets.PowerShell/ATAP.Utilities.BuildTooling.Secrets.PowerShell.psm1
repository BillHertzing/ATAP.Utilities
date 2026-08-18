# Dot-source every function file, then let the manifest govern what is exported.
# There is deliberately no Export-ModuleMember call: this module follows the pattern in
# ATAP.Utilities.PowerShell\ATAP.Utilities.Powershell.psm1, where the .psd1 FunctionsToExport
# and AliasesToExport are the single list that has to be maintained. A hardcoded export list
# here would silently drop any newly added public function that the manifest already names.
# Aliases come from the [Alias()] attributes on the function definitions themselves
# (Get-BWSAccessToken, Initialize-BWSAccessToken) and are filtered by AliasesToExport.
$publicFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
foreach ($import in @($publicFunctions + $privateFunctions)) {
  try {
    Write-Verbose "Importing $($import.FullName)"
    . $import.FullName
  } catch {
    Write-Error "Failed to import function $($import.FullName): $_"
  }
}
