function Install-CodeSigningCertificate {
  <#
  .SYNOPSIS
  Idempotently installs a code-signing certificate.
  .DESCRIPTION
  Requires the Code Signing EKU and imports a non-exportable private key from PFX/P12.
  .PARAMETER Path
  PFX or P12 certificate path.
  .PARAMETER PasswordSecretName
  SecretName resolving to the PFX password.
  .PARAMETER CertStoreLocation
  Target personal certificate store.
  .OUTPUTS
  System.Management.Automation.PSCustomObject
  .EXAMPLE
  Install-CodeSigningCertificate -Path 'C:/staging/build-signing.pfx' -PasswordSecretName 'PKI.PFX.CodeSigning'
  .NOTES
  Signing authority and its private key stay outside source control.
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
  begin { $fn = 'Install-CodeSigningCertificate'; $mn = 'ATAP.Utilities.Security.PKI.PowerShell' }
  process {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Installing code-signing certificate if absent.' -Tag 'Trace'
    Install-PkiCertificate -Path $Path -CertStoreLocation $CertStoreLocation -ExpectedEkuOid '1.3.6.1.5.5.7.3.3' -PasswordSecretName $PasswordSecretName -Confirm:$false -WhatIf:$WhatIfPreference
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace' }
}
