$publicFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
foreach ($import in @($publicFunctions + $privateFunctions)) {
  . $import.FullName
}

Export-ModuleMember -Function @(
  'Get-BWSAccessToken',
  'Get-DbConnectionStringSecretDescriptor',
  'Get-SecretATAP',
  'Get-SecretATAPBitwarden',
  'Get-SecretATAPBitwardenSecretsManager',
  'Initialize-BWSAccessToken',
  'Initialize-BWSCredentialDirectory',
  'Invoke-BWSReadOnlyTokenBootstrap',
  'New-BWSReadOnlyBootstrapEnvelope',
  'New-SprintBitwardenSecrets',
  'Remove-SprintBitwardenSecrets'
) -Cmdlet @() -Variable @() -Alias @(
  'Get-ServiceAccountBWSAccessToken',
  'Initialize-ServiceAccountBWSAccessToken'
)
