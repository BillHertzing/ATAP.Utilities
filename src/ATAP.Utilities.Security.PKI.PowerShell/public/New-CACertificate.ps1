function New-CACertificate {
  <#
  .SYNOPSIS
  Creates a self-signed root CA certificate from an existing encrypted private key.
  .DESCRIPTION
  Requires an explicit subject descriptor, applies the v3_ca profile, and never exports or logs private-key material.
  .PARAMETER DistinguishedNameHash
  CA subject object returned by New-DistinguishedNameHash.
  .PARAMETER EncryptedPrivateKeyPath
  Existing encrypted CA private key.
  .PARAMETER EncryptionKeyPassPhrasePath
  Existing CA passphrase file.
  .PARAMETER ValidityPeriod
  Numeric validity period.
  .PARAMETER ValidityPeriodUnits
  days, weeks, or years.
  .PARAMETER CertificatePath
  Destination CA certificate path.
  .PARAMETER CertificateRequestConfigPath
  OpenSSL CA configuration path.
  .PARAMETER Force
  Allows replacement of an existing CA certificate file.
  .OUTPUTS
  System.IO.FileInfo
  .EXAMPLE
  New-CACertificate -DistinguishedNameHash $caDn -EncryptedPrivateKeyPath 'D:/offline/root.key.pem' -EncryptionKeyPassPhrasePath 'D:/offline/root.pass' -ValidityPeriod 15 -ValidityPeriodUnits years -CertificatePath 'D:/offline/root.crt' -CertificateRequestConfigPath './CertificateRequestConfigurations/AUdefault.cnf'
  .NOTES
  Root CA key creation and use require explicit human authorization and an offline, ACL-restricted location.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [PSObject] $DistinguishedNameHash,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string] $EncryptedPrivateKeyPath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string] $EncryptionKeyPassPhrasePath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [ValidateRange(1, 1000)] [int] $ValidityPeriod,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [ValidateSet('days', 'weeks', 'years')] [string] $ValidityPeriodUnits,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $CertificatePath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string] $CertificateRequestConfigPath,
    [switch] $Force
  )
  begin { $fn = 'New-CACertificate'; $mn = 'ATAP.Utilities.Security.PKI.PowerShell' }
  process {
    $parentPath = Split-Path -Path $CertificatePath -Parent
    if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) { throw "The CA certificate parent directory does not exist: '$parentPath'." }
    if ((Test-Path -LiteralPath $CertificatePath -PathType Leaf) -and -not $Force) { throw "The CA certificate already exists: '$CertificatePath'. Use -Force to replace it." }
    if ([string]::IsNullOrWhiteSpace($DistinguishedNameHash.DNAsParameter)) { throw 'DistinguishedNameHash must contain DNAsParameter.' }
    $validityDays = ConvertTo-CertificateValidityDays -ValidityPeriod $ValidityPeriod -ValidityPeriodUnits $ValidityPeriodUnits
    if (-not $PSCmdlet.ShouldProcess($CertificatePath, "Create self-signed CA certificate for '$($DistinguishedNameHash.CN)'")) { return }
    Invoke-OpenSslCommand -Operation 'create self-signed CA certificate' -ArgumentList @(
      'req', '-x509', '-new', '-batch', '-sha384', '-config', $CertificateRequestConfigPath,
      '-extensions', 'v3_ca', '-subj', [string]$DistinguishedNameHash.DNAsParameter,
      '-days', [string]$validityDays, '-key', $EncryptedPrivateKeyPath,
      '-passin', "file:$EncryptionKeyPassPhrasePath", '-out', $CertificatePath
    ) | Out-Null
    Get-Item -LiteralPath $CertificatePath
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace' }
}
