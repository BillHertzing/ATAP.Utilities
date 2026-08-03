function New-PkiWindowsCodeSigningCertificate {
  <#
  .SYNOPSIS
  Issues and installs a non-exportable Windows RSA code-signing certificate.
  .DESCRIPTION
  Creates a machine-key PKCS#10 request with certreq, signs it with an ATAP OpenSSL root CA,
  accepts the issued certificate into LocalMachine My, grants selected principals read access to
  the private key, updates the canonical public certificate, and distributes TrustedPublisher
  trust. Secret values are resolved by SecretName and written only to a transient restricted file.
  .PARAMETER OrganizationName
  Publisher organization written to the certificate subject.
  .PARAMETER CARootPath
  Root CA directory containing private, public, database, config, and secrets subdirectories.
  .PARAMETER CodeSigningRootPath
  Organization code-signing directory containing requests, public, secrets, and archive data.
  .PARAMETER CAPassphraseSecretName
  SecretName resolved through Get-SecretATAP for the encrypted root CA key.
  .PARAMETER CommonName
  Publisher common name. Defaults to '<OrganizationName> PowerShell Code Signing'.
  .PARAMETER OrganizationUnit
  Optional certificate subject organization unit.
  .PARAMETER Country
  Two-letter certificate subject country code.
  .PARAMETER PrivateKeyReader
  Windows principals granted read access to the non-exportable machine private key.
  .PARAMETER TrustedPublisherComputerName
  Hosts that receive the public certificate in LocalMachine TrustedPublisher.
  .PARAMETER ValidityDays
  Requested leaf validity in days.
  .PARAMETER SecretStoreType
  Secret store selector passed to Get-SecretATAP.
  .OUTPUTS
  System.Management.Automation.PSCustomObject
  .EXAMPLE
  New-PkiWindowsCodeSigningCertificate -OrganizationName 'Example Organization' `
    -CARootPath 'C:\Security\PKI\Example Organization\RootCA' `
    -CodeSigningRootPath 'C:\Security\PKI\Example Organization\CodeSigning' `
    -CAPassphraseSecretName 'PKI.RootCA.Passphrase.ExampleOrganization' `
    -PrivateKeyReader 'SvcBuild' -TrustedPublisherComputerName 'host01', 'host02' -WhatIf
  .NOTES
  Run elevated on the signing host. This function intentionally does not export a PFX. The
  Windows machine key is created non-exportable with KeySpec Signature for Authenticode use.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[^"\r\n]+$')]
    [string] $OrganizationName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $CARootPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $CodeSigningRootPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $CAPassphraseSecretName,

    [ValidatePattern('^[^"\r\n]+$')]
    [string] $CommonName,

    [ValidatePattern('^[^"\r\n]+$')]
    [string] $OrganizationUnit = 'Software Release Engineering',

    [ValidatePattern('^[A-Z]{2}$')]
    [string] $Country = 'US',

    [string[]] $PrivateKeyReader = @(),

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]] $TrustedPublisherComputerName,

    [ValidateRange(1, 825)]
    [int] $ValidityDays = 825,

    [ValidateNotNullOrEmpty()]
    [string] $SecretStoreType = 'BitwardenSecretsManager'
  )

  begin {
    $fn = 'New-PkiWindowsCodeSigningCertificate'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
  }

  process {
    if (-not $IsWindows) {
      throw 'Windows code-signing certificate issuance is supported only on Windows.'
    }
    if ([string]::IsNullOrWhiteSpace($CommonName)) {
      $CommonName = "$OrganizationName PowerShell Code Signing"
    }

    $requiredPaths = @(
      (Join-Path $CARootPath 'private\root-ca.key.pem'),
      (Join-Path $CARootPath 'public\root-ca.crt'),
      (Join-Path $CARootPath 'database\index.txt'),
      (Join-Path $CARootPath 'config\AUdefault.cnf')
    )
    foreach ($requiredPath in $requiredPaths) {
      if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required CA file was not found: '$requiredPath'."
      }
    }
    $certReqCommand = Get-Command -Name 'certreq.exe' -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $certReqCommand) {
      throw 'certreq.exe is required but was not found.'
    }

    $timestamp = [datetime]::UtcNow.ToString('yyyyMMdd-HHmmss')
    $requestDirectory = Join-Path $CodeSigningRootPath 'requests'
    $publicDirectory = Join-Path $CodeSigningRootPath 'public'
    $secretDirectory = Join-Path $CodeSigningRootPath 'secrets'
    $archiveDirectory = Join-Path $CodeSigningRootPath 'archive'
    $requestInfPath = Join-Path $requestDirectory "CodeSigning-windows-signature-$timestamp.inf"
    $requestPath = Join-Path $requestDirectory "CodeSigning-windows-signature-$timestamp.csr"
    $issuedCertificatePath = Join-Path $publicDirectory "CodeSigning-windows-signature-$timestamp.crt"
    $canonicalCertificatePath = Join-Path $publicDirectory 'CodeSigning.crt'
    $passphrasePath = Join-Path $secretDirectory "root-ca-$timestamp.passphrase"

    if (-not $PSCmdlet.ShouldProcess($CommonName, 'Issue and install non-exportable Windows RSA code-signing certificate')) {
      return [PSCustomObject]@{
        OrganizationName = $OrganizationName
        CommonName = $CommonName
        RequestPath = $requestPath
        PublicCertificatePath = $canonicalCertificatePath
        PrivateKeyReader = @($PrivateKeyReader)
        TrustedPublisherComputerName = @($TrustedPublisherComputerName)
        Preview = $true
      }
    }

    $rootSecret = $null
    try {
      foreach ($directory in @($requestDirectory, $publicDirectory, $secretDirectory, $archiveDirectory)) {
        $null = New-Item -ItemType Directory -Path $directory -Force
      }

      $subjectParts = @("CN=$CommonName")
      if (-not [string]::IsNullOrWhiteSpace($OrganizationUnit)) { $subjectParts += "OU=$OrganizationUnit" }
      $subjectParts += "O=$OrganizationName"
      $subjectParts += "C=$Country"
      $subject = $subjectParts -join ','
      $infContent = @"
[Version]
Signature="`$Windows NT`$"

[NewRequest]
Subject="$subject"
MachineKeySet=TRUE
Exportable=FALSE
KeyLength=3072
KeySpec=2
KeyUsage=0x80
ProviderName="Microsoft Enhanced RSA and AES Cryptographic Provider"
ProviderType=24
RequestType=PKCS10
HashAlgorithm=sha256
FriendlyName="$CommonName"

[EnhancedKeyUsageExtension]
OID=1.3.6.1.5.5.7.3.3
"@
      [System.IO.File]::WriteAllText($requestInfPath, $infContent, [System.Text.UTF8Encoding]::new($false))

      $rootSecret = Get-SecretATAP -SecretName $CAPassphraseSecretName -SecretStoreType $SecretStoreType -ErrorAction Stop
      if ([string]::IsNullOrWhiteSpace([string]$rootSecret)) {
        throw "Secret '$CAPassphraseSecretName' resolved to an empty value."
      }
      [System.IO.File]::WriteAllText($passphrasePath, "$rootSecret`n", [System.Text.UTF8Encoding]::new($false))
      $null = Set-PkiRestrictedFileAcl -Path $passphrasePath
      $rootSecret = $null

      $certReqOutput = @(& $certReqCommand.Source -new -q $requestInfPath $requestPath 2>&1)
      if ($LASTEXITCODE -ne 0) {
        throw "certreq failed to create the machine Signature-key request: $(($certReqOutput | Select-Object -Last 5) -join [Environment]::NewLine)"
      }

      New-SignedCertificate `
        -CertificateRequestPath $requestPath `
        -CACertificatePath (Join-Path $CARootPath 'public\root-ca.crt') `
        -CAEncryptedPrivateKeyPath (Join-Path $CARootPath 'private\root-ca.key.pem') `
        -CAEncryptionKeyPassPhrasePath $passphrasePath `
        -CASigningCertificatesCertificatesIssuedDBPath (Join-Path $CARootPath 'database\index.txt') `
        -CertificateRequestConfigPath (Join-Path $CARootPath 'config\AUdefault.cnf') `
        -CertificateProfile CodeSigning `
        -ValidityPeriod $ValidityDays `
        -ValidityPeriodUnits days `
        -CertificatePath $issuedCertificatePath `
        -Confirm:$false | Out-Null

      $certReqOutput = @(& $certReqCommand.Source -accept -q $issuedCertificatePath 2>&1)
      if ($LASTEXITCODE -ne 0) {
        throw "certreq failed to associate the issued certificate with its machine key: $(($certReqOutput | Select-Object -Last 5) -join [Environment]::NewLine)"
      }

      $publicCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($issuedCertificatePath)
      $installedCertificate = Get-Item -LiteralPath "Cert:\LocalMachine\My\$($publicCertificate.Thumbprint)" -ErrorAction Stop
      if (-not $installedCertificate.HasPrivateKey -or $installedCertificate.PublicKey.Oid.Value -ne '1.2.840.113549.1.1.1') {
        throw 'The issued code-signing certificate is not an installed RSA certificate with a private key.'
      }

      $privateKeyAcl = $null
      if ($PrivateKeyReader.Count -gt 0) {
        $privateKeyAcl = Grant-PkiPrivateKeyReadAccess -Certificate $installedCertificate -Principal $PrivateKeyReader
      }

      if (Test-Path -LiteralPath $canonicalCertificatePath -PathType Leaf) {
        $priorCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($canonicalCertificatePath)
        $priorArchiveDirectory = Join-Path $archiveDirectory $priorCertificate.Thumbprint
        $null = New-Item -ItemType Directory -Path $priorArchiveDirectory -Force
        Copy-Item -LiteralPath $canonicalCertificatePath -Destination (Join-Path $priorArchiveDirectory 'CodeSigning.crt') -Force
      }
      Copy-Item -LiteralPath $issuedCertificatePath -Destination $canonicalCertificatePath -Force

      $publisherTrust = @(Install-PkiTrustCertificate -Path $canonicalCertificatePath `
          -CertificateRole TrustedPublisher -ComputerName $TrustedPublisherComputerName -Confirm:$false)

      $privateKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($installedCertificate)
      try {
        $keySize = $privateKey.KeySize
        if ($privateKey.GetType().FullName -eq 'System.Security.Cryptography.RSACryptoServiceProvider') {
          $keySpec = [string]$privateKey.CspKeyContainerInfo.KeyNumber
          $providerName = $privateKey.CspKeyContainerInfo.ProviderName
          $exportable = $privateKey.CspKeyContainerInfo.Exportable
          if ($privateKey.CspKeyContainerInfo.KeyNumber -ne [System.Security.Cryptography.KeyNumber]::Signature) {
            throw "Expected KeySpec Signature; found '$keySpec'."
          }
        } else {
          $keySpec = [string]$privateKey.Key.KeyUsage
          $providerName = $privateKey.Key.Provider.Provider
          $exportable = $privateKey.Key.ExportPolicy -ne [System.Security.Cryptography.CngExportPolicies]::None
          if (($privateKey.Key.KeyUsage -band [System.Security.Cryptography.CngKeyUsages]::Signing) -eq 0) {
            throw "Expected CNG signing usage; found '$keySpec'."
          }
        }
      } finally {
        $privateKey.Dispose()
      }
      if ($exportable) {
        throw 'The installed code-signing private key is exportable.'
      }

      [PSCustomObject]@{
        OrganizationName = $OrganizationName
        Subject = $installedCertificate.Subject
        Issuer = $installedCertificate.Issuer
        ThumbprintSha1 = $installedCertificate.Thumbprint
        ThumbprintSha256 = [Convert]::ToHexString(
          [System.Security.Cryptography.SHA256]::HashData($installedCertificate.RawData)
        )
        NotBefore = $installedCertificate.NotBefore
        NotAfter = $installedCertificate.NotAfter
        KeySize = $keySize
        KeySpec = $keySpec
        ProviderName = $providerName
        PrivateKeyExportable = $exportable
        PrivateKeyPath = $privateKeyAcl.PrivateKeyPath
        PrivateKeyReader = @($PrivateKeyReader)
        RequestPath = $requestPath
        PublicCertificatePath = $canonicalCertificatePath
        TrustedPublisher = @($publisherTrust)
        Preview = $false
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Code-signing certificate issuance failed: $($_.Exception.Message)"
      throw
    } finally {
      $rootSecret = $null
      Remove-Item -LiteralPath $passphrasePath -Force -ErrorAction SilentlyContinue
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Windows code-signing certificate issuance operation completed.' -Tag 'Trace'
  }
}
