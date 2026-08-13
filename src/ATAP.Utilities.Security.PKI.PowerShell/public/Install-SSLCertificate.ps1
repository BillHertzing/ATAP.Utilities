function Install-SSLCertificate {
  <#
  .SYNOPSIS
  Idempotently installs a TLS server certificate.
  .DESCRIPTION
  Requires the Server Authentication EKU and imports a non-exportable private key from PFX/P12.
  .PARAMETER Path
  PFX or P12 certificate path.
  .PARAMETER PasswordSecretName
  SecretName resolving to the PFX password.
  .PARAMETER CertStoreLocation
  Target personal certificate store.
  .OUTPUTS
  System.Management.Automation.PSCustomObject
  .EXAMPLE
  Install-SSLCertificate -Path 'C:/staging/utat01.pfx' -PasswordSecretName 'PKI.PFX.utat01'
  .NOTES
  Raw passwords are intentionally unsupported.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)] [string] $Path,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $PasswordSecretName,
    [ValidateSet('Cert:\CurrentUser\My', 'Cert:\LocalMachine\My')] [string] $CertStoreLocation = 'Cert:\LocalMachine\My'
  )
  begin { $fn = 'Install-SSLCertificate'; $mn = 'ATAP.Utilities.Security.PKI.PowerShell' }
  process {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Installing TLS certificate if absent.' -Tag 'Trace'
    Install-PkiCertificate -Path $Path -CertStoreLocation $CertStoreLocation -ExpectedEkuOid '1.3.6.1.5.5.7.3.1' -PasswordSecretName $PasswordSecretName -Confirm:$false -WhatIf:$WhatIfPreference
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace' }
}
