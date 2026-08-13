function Install-TrustedPublisherCertificate {
  <#
  .SYNOPSIS
  Idempotently trusts a code-signing publisher certificate.
  .DESCRIPTION
  Requires the Code Signing EKU and installs the public certificate into TrustedPublisher without private-key material.
  .PARAMETER Path
  DER or PEM code-signing certificate path.
  .PARAMETER CertStoreLocation
  Target TrustedPublisher store.
  .OUTPUTS
  System.Management.Automation.PSCustomObject
  .EXAMPLE
  Install-TrustedPublisherCertificate -Path 'C:/staging/atap-foundation-code-signing.crt' -WhatIf
  .NOTES
  TrustedPublisher distribution is required for non-interactive AllSigned execution without publisher prompts.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $Path,

    [ValidateSet('Cert:\CurrentUser\TrustedPublisher', 'Cert:\LocalMachine\TrustedPublisher')]
    [string] $CertStoreLocation = 'Cert:\LocalMachine\TrustedPublisher'
  )

  begin {
    $fn = 'Install-TrustedPublisherCertificate'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
  }

  process {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Installing trusted publisher certificate if absent.' -Tag 'Trace'
    Install-PkiCertificate -Path $Path -CertStoreLocation $CertStoreLocation `
      -ExpectedEkuOid '1.3.6.1.5.5.7.3.3' -Confirm:$false -WhatIf:$WhatIfPreference
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace'
  }
}
