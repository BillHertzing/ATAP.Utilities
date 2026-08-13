function Install-PkiTrustCertificate {
  <#
  .SYNOPSIS
  Idempotently distributes a public root CA or TrustedPublisher certificate to Windows hosts.
  .DESCRIPTION
  Validates a public certificate and optional SHA-256 fingerprint before transferring only its
  public DER bytes to each target. Local and PowerShell-remoting installations use the same
  certificate-role checks and return per-host change metadata.
  .PARAMETER Path
  Public DER or PEM certificate path.
  .PARAMETER CertificateRole
  RootCA installs into LocalMachine Root; TrustedPublisher installs into LocalMachine
  TrustedPublisher and requires Code Signing EKU.
  .PARAMETER ComputerName
  One or more local or PowerShell-remoting target computer names.
  .PARAMETER ExpectedSha256
  Optional 64-character SHA-256 fingerprint pin for the public certificate.
  .PARAMETER SessionConfigurationName
  PowerShell 7 remoting endpoint used for remote hosts. Defaults to the managed ATAP profiled
  endpoint so machine and connecting-identity profiles establish the ATAP command environment.
  .OUTPUTS
  System.Management.Automation.PSCustomObject
  .EXAMPLE
  Install-PkiTrustCertificate -Path 'C:\Security\PKI\Example Organization\RootCA\public\root-ca.crt' `
    -CertificateRole RootCA -ComputerName 'host01', 'host02' -ExpectedSha256 $fingerprint -WhatIf
  .NOTES
  LocalMachine trust changes require elevation and explicit authorization. Remote targets use the
  caller's existing PowerShell remoting authentication; no private key or secret is transferred.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $Path,

    [Parameter(Mandatory)]
    [ValidateSet('RootCA', 'TrustedPublisher')]
    [string] $CertificateRole,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]] $ComputerName,

    [ValidatePattern('^[A-Fa-f0-9]{64}$')]
    [string] $ExpectedSha256,

    [ValidateNotNullOrEmpty()]
    [string] $SessionConfigurationName = 'ATAP.PS7.Profiled'
  )

  begin {
    $fn = 'Install-PkiTrustCertificate'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
  }

  process {
    if (-not $IsWindows) {
      throw 'Windows trust-store distribution is supported only on Windows.'
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).ProviderPath
    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($resolvedPath)
    $sha256 = [Convert]::ToHexString(
      [System.Security.Cryptography.SHA256]::HashData($certificate.RawData)
    )
    if ($ExpectedSha256 -and $sha256 -ne $ExpectedSha256.ToUpperInvariant()) {
      throw "Certificate SHA-256 fingerprint does not match ExpectedSha256 for '$resolvedPath'."
    }

    if ($CertificateRole -eq 'RootCA') {
      $basicConstraints = $certificate.Extensions |
        Where-Object { $_.Oid.Value -eq '2.5.29.19' } |
        Select-Object -First 1
      if ($null -eq $basicConstraints -or -not $basicConstraints.CertificateAuthority) {
        throw "Certificate '$resolvedPath' is not a certificate authority certificate."
      }
      $storeName = 'Root'
    } else {
      $ekuOids = @($certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' } | ForEach-Object {
          $_.EnhancedKeyUsages | ForEach-Object Value
        })
      if ('1.3.6.1.5.5.7.3.3' -notin $ekuOids) {
        throw "Certificate '$resolvedPath' does not contain the Code Signing EKU."
      }
      $storeName = 'TrustedPublisher'
    }

    $rawDataBase64 = [Convert]::ToBase64String($certificate.RawData)
    foreach ($target in $ComputerName) {
      $isLocal = $target -in @('.', 'localhost', $env:COMPUTERNAME)
      if (-not $PSCmdlet.ShouldProcess("$target LocalMachine/$storeName", "Install certificate $($certificate.Thumbprint)")) {
        [PSCustomObject]@{
          ComputerName = $target
          CertificateRole = $CertificateRole
          Store = "LocalMachine/$storeName"
          ThumbprintSha1 = $certificate.Thumbprint
          ThumbprintSha256 = $sha256
          Changed = $false
          Preview = $true
        }
        continue
      }

      if ($isLocal) {
        $installResult = if ($CertificateRole -eq 'RootCA') {
          Install-CACertificate -Path $resolvedPath -CertStoreLocation 'Cert:\LocalMachine\Root' -Confirm:$false
        } else {
          Install-TrustedPublisherCertificate -Path $resolvedPath -CertStoreLocation 'Cert:\LocalMachine\TrustedPublisher' -Confirm:$false
        }
        [PSCustomObject]@{
          ComputerName = $env:COMPUTERNAME
          CertificateRole = $CertificateRole
          Store = "LocalMachine/$storeName"
          ThumbprintSha1 = $installResult.Thumbprint
          ThumbprintSha256 = $sha256
          Changed = $installResult.Changed
          Preview = $false
        }
        continue
      }

      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling Invoke-Command on $target." -Tag 'InvokeCommandCall'
        $remoteResult = Invoke-Command -ComputerName $target -ConfigurationName $SessionConfigurationName `
          -ArgumentList $rawDataBase64, $sha256, $CertificateRole -ScriptBlock {
          param($RawDataBase64, $ExpectedSha256, $CertificateRole)

          $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
            [Convert]::FromBase64String($RawDataBase64)
          )
          $actualSha256 = [Convert]::ToHexString(
            [System.Security.Cryptography.SHA256]::HashData($certificate.RawData)
          )
          if ($actualSha256 -ne $ExpectedSha256) {
            throw 'Transferred certificate SHA-256 fingerprint mismatch.'
          }

          if ($CertificateRole -eq 'RootCA') {
            $basicConstraints = $certificate.Extensions |
              Where-Object { $_.Oid.Value -eq '2.5.29.19' } |
              Select-Object -First 1
            if ($null -eq $basicConstraints -or -not $basicConstraints.CertificateAuthority) {
              throw 'Transferred certificate is not a certificate authority certificate.'
            }
            $storeName = [System.Security.Cryptography.X509Certificates.StoreName]::Root
          } else {
            $ekuOids = @($certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' } | ForEach-Object {
                $_.EnhancedKeyUsages | ForEach-Object Value
              })
            if ('1.3.6.1.5.5.7.3.3' -notin $ekuOids) {
              throw 'Transferred certificate does not contain the Code Signing EKU.'
            }
            $storeName = [System.Security.Cryptography.X509Certificates.StoreName]::TrustedPublisher
          }

          $store = [System.Security.Cryptography.X509Certificates.X509Store]::new(
            $storeName,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
          )
          try {
            $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
            $existing = $store.Certificates.Find(
              [System.Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint,
              $certificate.Thumbprint,
              $false
            )
            $changed = $existing.Count -eq 0
            if ($changed) { $store.Add($certificate) }
          } finally {
            $store.Close()
          }

          [PSCustomObject]@{
            ComputerName = $env:COMPUTERNAME
            ThumbprintSha1 = $certificate.Thumbprint
            Changed = $changed
          }
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from Invoke-Command on $target." -Tag 'InvokeCommandCall'
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Trust installation failed on '$target': $($_.Exception.Message)"
        throw
      }

      [PSCustomObject]@{
        ComputerName = $remoteResult.ComputerName
        CertificateRole = $CertificateRole
        Store = "LocalMachine/$storeName"
        ThumbprintSha1 = $remoteResult.ThumbprintSha1
        ThumbprintSha256 = $sha256
        Changed = $remoteResult.Changed
        Preview = $false
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Trust distribution operation completed.' -Tag 'Trace'
  }
}
