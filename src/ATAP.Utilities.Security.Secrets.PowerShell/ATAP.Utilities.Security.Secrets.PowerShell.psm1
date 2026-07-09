$moduleRoot = $PSScriptRoot

$privateFunctions = Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'private') -Filter '*.ps1' -ErrorAction SilentlyContinue
$publicFunctions = Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'public') -Filter '*.ps1' -ErrorAction SilentlyContinue

foreach ($import in @($privateFunctions + $publicFunctions)) {
  . $import.FullName
}

# Command aliases. Module .ps1 files define only functions, so aliases live here in the
# .psm1. Export is governed by AliasesToExport in the .psd1.
Set-Alias -Name New-BWSecret          -Value Set-BitWardenSecret
Set-Alias -Name Add-BitWardenLogin    -Value Set-BitWardenSecret
Set-Alias -Name Sync-DedicatedSecrets -Value Sync-BitWardenDedicatedSecrets

Export-ModuleMember -Function @(
  'Get-BitWardenCredential',
  'Invoke-RotateSecretsATAP',
  'List-BitwardenSecrets',
  'Load-BitwardenBackup',
  'New-BitwardenBackup',
  'Set-BitWardenSecret',
  'Sync-BitWardenDedicatedSecrets'
) -Alias @(
  'New-BWSecret',
  'Add-BitWardenLogin',
  'Sync-DedicatedSecrets'
)
