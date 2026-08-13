$securityChildModules = @(
  [PSCustomObject]@{
    Name = 'ATAP.Utilities.Security.PKI.PowerShell'
    Functions = @(
      'Get-DistinguishedNameQualifiedFilePath'
      'Install-CACertificate'
      'Install-CodeSigningCertificate'
      'Install-DataEncryptionCertificate'
      'Install-SSLCertificate'
      'List-CodeSigningCertificates'
      'New-CACertificate'
      'New-CertificateRequest'
      'New-DataEncryptionCertificateRequest'
      'New-DistinguishedNameHash'
      'New-EncryptedPasswordFile'
      'New-EncryptedPrivateKey'
      'New-RandomEncryptionKeyToFile'
      'New-RandomPassPhraseToFile'
      'New-SignedCertificate'
      'New-SSLCertificateRequest'
      'Update-KeySecurestringFile'
      'Update-MasterPasswordSecureStringFile'
    )
  }
  [PSCustomObject]@{
    Name = 'ATAP.Utilities.Security.Secrets.PowerShell'
    Functions = @(
      'Get-BitWardenCredential'
      'Invoke-RotateSecretsATAP'
      'List-BitwardenSecrets'
      'Load-BitwardenBackup'
      'New-BitwardenBackup'
      'Set-BitWardenSecret'
      'Sync-BitWardenDedicatedSecrets'
    )
  }
)

$securityChildFunctions = @()
foreach ($child in $securityChildModules) {
  $sourceManifest = Join-Path $PSScriptRoot '..' $child.Name "$($child.Name).psd1"
  if (Get-Module -ListAvailable -Name $child.Name -ErrorAction SilentlyContinue) {
    Import-Module -Name $child.Name -ErrorAction Stop
  } elseif (Test-Path -LiteralPath $sourceManifest -PathType Leaf) {
    Import-Module -Name $sourceManifest -ErrorAction Stop
  } else {
    throw "Required Security child module '$($child.Name)' was not found on PSModulePath or at '$sourceManifest'."
  }
  $securityChildFunctions += $child.Functions
}
