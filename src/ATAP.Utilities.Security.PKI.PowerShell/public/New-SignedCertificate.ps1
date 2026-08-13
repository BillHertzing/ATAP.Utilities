function New-SignedCertificate {
  <#
  .SYNOPSIS
  Issues a certificate from an OpenSSL CA database.
  .DESCRIPTION
  Initializes required CA state idempotently, selects an explicit EKU profile, signs the CSR, and restores all process environment values in a finally block.
  .PARAMETER CertificateProfile
  ServerAuthentication, CodeSigning, or DataEncryption.
  .PARAMETER CertificateRequestConfigPath
  OpenSSL configuration containing the matching profile sections.
  .OUTPUTS
  System.IO.FileInfo
  .EXAMPLE
  New-SignedCertificate -CertificateRequestPath 'C:/ca/requests/utat01.csr' -CACertificatePath 'D:/offline/root.crt' -CAEncryptedPrivateKeyPath 'D:/offline/root.key.pem' -CAEncryptionKeyPassPhrasePath 'D:/offline/root.pass' -CASigningCertificatesCertificatesIssuedDBPath 'D:/offline/index.txt' -CertificateRequestConfigPath './CertificateRequestConfigurations/AUdefault.cnf' -CertificateProfile ServerAuthentication -ValidityPeriod 397 -ValidityPeriodUnits days -CertificatePath 'C:/ca/issued/utat01.crt'
  .NOTES
  CA signing is a separately authorized live operation. The CA private key and passphrase never belong in Git or evidence.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string] $CertificateRequestPath,
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string] $CACertificatePath,
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string] $CAEncryptedPrivateKeyPath,
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string] $CAEncryptionKeyPassPhrasePath,
    [Parameter(Mandatory)] [string] $CASigningCertificatesCertificatesIssuedDBPath,
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string] $CertificateRequestConfigPath,
    [Parameter(Mandatory)] [ValidateSet('ServerAuthentication', 'CodeSigning', 'DataEncryption')] [string] $CertificateProfile,
    [Parameter(Mandatory)] [ValidateRange(1, 1000)] [int] $ValidityPeriod,
    [Parameter(Mandatory)] [ValidateSet('days', 'weeks', 'years')] [string] $ValidityPeriodUnits,
    [Parameter(Mandatory)] [string] $CertificatePath,
    [switch] $Force
  )
  begin { $fn = 'New-SignedCertificate'; $mn = 'ATAP.Utilities.Security.PKI.PowerShell' }
  process {
    $certificateParent = Split-Path -Path $CertificatePath -Parent
    $caRoot = Split-Path -Path $CASigningCertificatesCertificatesIssuedDBPath -Parent
    if (-not (Test-Path -LiteralPath $certificateParent -PathType Container)) { throw "The issued-certificate parent directory does not exist: '$certificateParent'." }
    if (-not (Test-Path -LiteralPath $caRoot -PathType Container)) { throw "The CA database parent directory does not exist: '$caRoot'." }
    if ((Test-Path -LiteralPath $CertificatePath -PathType Leaf) -and -not $Force) { throw "The certificate already exists: '$CertificatePath'. Use -Force to replace it." }
    $maximumDays = if ($CertificateProfile -eq 'ServerAuthentication') { 397 } else { 825 }
    $validityDays = ConvertTo-CertificateValidityDays -ValidityPeriod $ValidityPeriod -ValidityPeriodUnits $ValidityPeriodUnits -MaximumDays $maximumDays
    if (-not $PSCmdlet.ShouldProcess($CertificatePath, "Issue $CertificateProfile certificate from CA database '$CASigningCertificatesCertificatesIssuedDBPath'")) { return }

    $newCertificatesPath = Join-Path $caRoot 'newcerts'
    $serialPath = Join-Path $caRoot 'serial'
    $crlNumberPath = Join-Path $caRoot 'crlnumber'
    if (-not (Test-Path -LiteralPath $newCertificatesPath -PathType Container)) { New-Item -ItemType Directory -Path $newCertificatesPath -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $CASigningCertificatesCertificatesIssuedDBPath -PathType Leaf)) { Set-Content -LiteralPath $CASigningCertificatesCertificatesIssuedDBPath -Value '' -NoNewline }
    if (-not (Test-Path -LiteralPath $serialPath -PathType Leaf)) { Set-Content -LiteralPath $serialPath -Value '1000' -NoNewline }
    if (-not (Test-Path -LiteralPath $crlNumberPath -PathType Leaf)) { Set-Content -LiteralPath $crlNumberPath -Value '1000' -NoNewline }

    $profileSection = @{ ServerAuthentication = 'server_cert'; CodeSigning = 'code_signing_cert'; DataEncryption = 'data_encryption_cert' }[$CertificateProfile]
    $environmentValues = @{
      ATAP_PKI_CA_DATABASE = $env:ATAP_PKI_CA_DATABASE
      ATAP_PKI_CA_NEW_CERTS = $env:ATAP_PKI_CA_NEW_CERTS
      ATAP_PKI_CA_SERIAL = $env:ATAP_PKI_CA_SERIAL
      ATAP_PKI_CA_CRLNUMBER = $env:ATAP_PKI_CA_CRLNUMBER
      ATAP_PKI_CA_CERTIFICATE = $env:ATAP_PKI_CA_CERTIFICATE
      ATAP_PKI_CA_PRIVATE_KEY = $env:ATAP_PKI_CA_PRIVATE_KEY
    }
    try {
      $env:ATAP_PKI_CA_DATABASE = $CASigningCertificatesCertificatesIssuedDBPath
      $env:ATAP_PKI_CA_NEW_CERTS = $newCertificatesPath
      $env:ATAP_PKI_CA_SERIAL = $serialPath
      $env:ATAP_PKI_CA_CRLNUMBER = $crlNumberPath
      $env:ATAP_PKI_CA_CERTIFICATE = $CACertificatePath
      $env:ATAP_PKI_CA_PRIVATE_KEY = $CAEncryptedPrivateKeyPath
      Invoke-OpenSslCommand -Operation "issue $CertificateProfile certificate" -ArgumentList @(
        'ca', '-batch', '-config', $CertificateRequestConfigPath, '-extensions', $profileSection,
        '-in', $CertificateRequestPath, '-cert', $CACertificatePath, '-keyfile', $CAEncryptedPrivateKeyPath,
        '-passin', "file:$CAEncryptionKeyPassPhrasePath", '-days', [string]$validityDays, '-out', $CertificatePath
      ) | Out-Null
    } finally {
      foreach ($name in $environmentValues.Keys) {
        [Environment]::SetEnvironmentVariable($name, $environmentValues[$name], 'Process')
      }
    }
    Get-Item -LiteralPath $CertificatePath
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace' }
}
