function Install-CACertificate {
  <#
  .SYNOPSIS
  Idempotently installs a CA certificate into a Windows trust store.
  .DESCRIPTION
  Validates the certificate's CA basic constraint and skips installation when its thumbprint is already trusted.
  .PARAMETER Path
  DER or PEM CA certificate path.
  .PARAMETER CertStoreLocation
  Target Root store.
  .OUTPUTS
  System.Management.Automation.PSCustomObject
  .EXAMPLE
  Install-CACertificate -Path 'C:/staging/ATAP-Root-CA.crt' -WhatIf
  .NOTES
  LocalMachine trust changes require elevation and separate authorization.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $Path,
    [ValidateSet('Cert:\CurrentUser\Root', 'Cert:\LocalMachine\Root')]
    [string] $CertStoreLocation = 'Cert:\LocalMachine\Root'
  )
  begin { $fn = 'Install-CACertificate'; $mn = 'ATAP.Utilities.Security.PKI.PowerShell' }
  process {
    $certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new((Resolve-Path -LiteralPath $Path).ProviderPath)
    $basicConstraints = $certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.19' } | Select-Object -First 1
    if ($null -eq $basicConstraints -or -not $basicConstraints.CertificateAuthority) {
      throw "Certificate '$Path' is not a certificate authority certificate."
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Installing CA certificate $($certificate.Thumbprint) if absent." -Tag 'Trace'
    Install-PkiCertificate -Path $Path -CertStoreLocation $CertStoreLocation -Confirm:$false -WhatIf:$WhatIfPreference
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace' }
}
