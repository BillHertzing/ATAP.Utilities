function Install-DataEncryptionCertificate {
  <#
  .SYNOPSIS
  Idempotently installs a document-encryption certificate.
  .DESCRIPTION
  Requires the Microsoft Document Encryption EKU and imports a non-exportable private key from PFX/P12.
  .PARAMETER Path
  PFX or P12 certificate path.
  .PARAMETER PasswordSecretName
  SecretName resolving to the PFX password.
  .PARAMETER CertStoreLocation
  Target personal certificate store.
  .OUTPUTS
  System.Management.Automation.PSCustomObject
  .EXAMPLE
  Install-DataEncryptionCertificate -Path 'C:/staging/user-dec.pfx' -PasswordSecretName 'PKI.PFX.DataEncryption.User'
  .NOTES
  The legacy certreq parameter names are replaced by explicit certificate-install parameters.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)] [Alias('DataEncryptionCertificatePath')] [string] $Path,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $PasswordSecretName,
    [ValidateSet('Cert:\CurrentUser\My', 'Cert:\LocalMachine\My')] [string] $CertStoreLocation = 'Cert:\CurrentUser\My'
  )
  begin { $fn = 'Install-DataEncryptionCertificate'; $mn = 'ATAP.Utilities.Security.PKI.PowerShell' }
  process {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Installing data-encryption certificate if absent.' -Tag 'Trace'
    Install-PkiCertificate -Path $Path -CertStoreLocation $CertStoreLocation -ExpectedEkuOid '1.3.6.1.4.1.311.80.1' -PasswordSecretName $PasswordSecretName -Confirm:$false -WhatIf:$WhatIfPreference
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace' }
}
