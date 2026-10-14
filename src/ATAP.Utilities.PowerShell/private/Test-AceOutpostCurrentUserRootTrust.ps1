function Test-AceOutpostCurrentUserRootTrust {
  <#
  .SYNOPSIS
    Tests whether an exact certificate is trusted in the current user's root store.
  .DESCRIPTION
    Matches both the SHA-1 thumbprint used to locate a candidate and the SHA-256 digest
    of its complete DER encoding. This prevents a thumbprint-only match from weakening
    the desktop launch preflight.
  .PARAMETER Thumbprint
    Expected 40-character SHA-1 certificate thumbprint.
  .PARAMETER CertificateSha256
    Expected 64-character SHA-256 digest of the complete DER certificate.
  .OUTPUTS
    Boolean.
  #>
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9A-Fa-f]{40}$')]
    [string]$Thumbprint,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9A-Fa-f]{64}$')]
    [string]$CertificateSha256
  )

  begin {
    $fn = 'Test-AceOutpostCurrentUserRootTrust'
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $normalizedThumbprint = $Thumbprint.ToUpperInvariant()
    $normalizedSha256 = $CertificateSha256.ToUpperInvariant()
    $candidates = @(Get-ChildItem -LiteralPath 'Cert:\CurrentUser\Root' -ErrorAction Stop |
        Where-Object { $_.Thumbprint -eq $normalizedThumbprint })

    foreach ($candidate in $candidates) {
      $candidateSha256 = [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData([byte[]]$candidate.RawData))
      if ($candidateSha256 -eq $normalizedSha256) {
        return $true
      }
    }
    return $false
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
