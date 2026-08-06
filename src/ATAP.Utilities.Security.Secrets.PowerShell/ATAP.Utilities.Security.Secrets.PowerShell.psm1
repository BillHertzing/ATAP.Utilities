$moduleRoot = $PSScriptRoot

$privateFunctions = Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'private') -Filter '*.ps1' -ErrorAction SilentlyContinue
$publicFunctions = Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'public') -Filter '*.ps1' -ErrorAction SilentlyContinue

foreach ($import in @($privateFunctions + $publicFunctions)) {
  . $import.FullName
}

# Command aliases are declared with function-level [Alias()] attributes in public\, NOT with
# Set-Alias here. Build-PSModulePsm1 regenerates the shipped .psm1 by concatenating public\ and
# private\ and discards this file, so a Set-Alias here works when running from source and then
# silently vanishes from the published package -- leaving AliasesToExport naming aliases that
# nothing defines. A contract test asserts every exported alias is backed by an [Alias()] attribute.

Export-ModuleMember -Function @(
  'Get-CredentialFile',
  'Get-BitWardenCredential',
  'Invoke-RotateSecretsATAP',
  'List-BitwardenSecrets',
  'Load-BitwardenBackup',
  'New-BitwardenBackup',
  'Set-CredentialFile',
  'Set-BitWardenSecret',
  'Sync-BitWardenDedicatedSecrets'
) -Alias @(
  'New-BWSecret',
  'Add-BitWardenLogin',
  'Sync-DedicatedSecrets'
)
