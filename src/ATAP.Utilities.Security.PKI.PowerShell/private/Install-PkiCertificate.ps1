function Install-PkiCertificate {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $Path,

    [Parameter(Mandatory)]
    [ValidatePattern('^Cert:\\(CurrentUser|LocalMachine)\\(Root|My|TrustedPeople|TrustedPublisher)$')]
    [string] $CertStoreLocation,

    [string] $ExpectedEkuOid,

    [string] $PasswordSecretName
  )

  begin {
    $fn = 'Install-PkiCertificate'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Preparing certificate installation into '$CertStoreLocation'." -Tag 'Trace'
  }

  process {
    if (-not $IsWindows) {
      throw 'Certificate-store installation is supported only on Windows.'
    }

    $extension = [IO.Path]::GetExtension($Path)
    $isPfx = $extension -in @('.pfx', '.p12')
    $password = $null
    $store = $null
    try {
      if ($isPfx) {
        if ([string]::IsNullOrWhiteSpace($PasswordSecretName)) {
          throw 'A PasswordSecretName is required to install a PFX/P12 certificate.'
        }
        $password = Get-SecretATAP -SecretName $PasswordSecretName -ErrorAction Stop
        $certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new(
          (Resolve-Path -LiteralPath $Path).ProviderPath,
          [string]$password,
          [Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
        )
      } else {
        $certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new((Resolve-Path -LiteralPath $Path).ProviderPath)
      }

      if ($null -eq $certificate) {
        throw "No end-entity certificate was found in '$Path'."
      }
      if ($ExpectedEkuOid) {
        $ekuOids = @($certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' } | ForEach-Object {
            $_.EnhancedKeyUsages | ForEach-Object Value
          })
        if ($ExpectedEkuOid -notin $ekuOids) {
          throw "Certificate '$Path' does not contain required EKU '$ExpectedEkuOid'."
        }
      }

      $storeMatch = [regex]::Match($CertStoreLocation, '^Cert:\\(?<Location>CurrentUser|LocalMachine)\\(?<Store>Root|My|TrustedPeople|TrustedPublisher)$')
      if (-not $storeMatch.Success) {
        throw "Unsupported certificate-store location '$CertStoreLocation'."
      }
      $storeLocation = [Security.Cryptography.X509Certificates.StoreLocation]::$($storeMatch.Groups['Location'].Value)
      $storeName = [Security.Cryptography.X509Certificates.StoreName]::$($storeMatch.Groups['Store'].Value)
      $store = [Security.Cryptography.X509Certificates.X509Store]::new($storeName, $storeLocation)
      $store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
      $existing = $store.Certificates.Find(
        [Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint,
        $certificate.Thumbprint,
        $false
      ) | Select-Object -First 1
      if ($existing) {
        $store.Close()
        return [PSCustomObject]@{
          Path = (Resolve-Path -LiteralPath $Path).ProviderPath
          CertStoreLocation = $CertStoreLocation
          Thumbprint = $certificate.Thumbprint
          Changed = $false
          Certificate = $existing
        }
      }

      if (-not $PSCmdlet.ShouldProcess($CertStoreLocation, "Install certificate $($certificate.Thumbprint)")) {
        return [PSCustomObject]@{
          Path = (Resolve-Path -LiteralPath $Path).ProviderPath
          CertStoreLocation = $CertStoreLocation
          Thumbprint = $certificate.Thumbprint
          Changed = $false
          Certificate = $null
        }
      }

      if ($isPfx) {
        $keyStorageFlags = [Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet
        $keyStorageFlags = $keyStorageFlags -bor $(if ($storeLocation -eq [Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine) {
            [Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet
          } else {
            [Security.Cryptography.X509Certificates.X509KeyStorageFlags]::UserKeySet
          })
        $installed = [Security.Cryptography.X509Certificates.X509Certificate2]::new(
          (Resolve-Path -LiteralPath $Path).ProviderPath,
          [string]$password,
          $keyStorageFlags
        )
      } else {
        $installed = $certificate
      }
      $store.Add($installed)
      $store.Close()
      [PSCustomObject]@{
        Path = (Resolve-Path -LiteralPath $Path).ProviderPath
        CertStoreLocation = $CertStoreLocation
        Thumbprint = $certificate.Thumbprint
        Changed = $true
        Certificate = $installed
      }
    } finally {
      if ($null -ne $store) { $store.Close() }
      $password = $null
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Certificate installation operation completed.' -Tag 'Trace'
  }
}
