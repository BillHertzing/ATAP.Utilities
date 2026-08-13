function New-PkiCertificatePfx {
  <#
  .SYNOPSIS
  Creates an ACL-restricted PKCS#12 file without placing its password on the command line.
  .DESCRIPTION
  Exports an encrypted PEM private key, its issued certificate, and an optional CA certificate to
  PKCS#12. The output password is resolved by SecretName and sent to OpenSSL over standard input.
  The function refuses to overwrite an existing PFX and returns metadata only.
  .PARAMETER PrivateKeyPath
  Encrypted PEM private-key path.
  .PARAMETER PrivateKeyPassphrasePath
  ACL-restricted transient file containing the PEM private-key passphrase.
  .PARAMETER CertificatePath
  Issued public leaf certificate path.
  .PARAMETER CACertificatePath
  Optional public CA certificate included in the PKCS#12 chain.
  .PARAMETER PfxPath
  New PKCS#12 output path. Existing files are never overwritten.
  .PARAMETER FriendlyName
  Friendly name stored with the PKCS#12 certificate.
  .PARAMETER PasswordSecretName
  SecretName resolved through Get-SecretATAP for the PKCS#12 output password.
  .PARAMETER SecretStoreType
  Secret store selector passed to Get-SecretATAP.
  .OUTPUTS
  System.Management.Automation.PSCustomObject
  .EXAMPLE
  New-PkiCertificatePfx -PrivateKeyPath 'C:\Security\PKI\Example Organization\Hosts\host01\private\host01.key.pem' `
    -PrivateKeyPassphrasePath 'C:\Security\PKI\Example Organization\Hosts\host01\secrets\host01.passphrase' `
    -CertificatePath 'C:\Security\PKI\Example Organization\Hosts\host01\public\host01.crt' `
    -CACertificatePath 'C:\Security\PKI\Example Organization\RootCA\public\root-ca.crt' `
    -PfxPath 'C:\Security\PKI\Example Organization\Hosts\host01\pfx\host01.pfx' `
    -FriendlyName 'host01' -PasswordSecretName 'PKI.PFX.Password.ExampleOrganization.host01' -WhatIf
  .NOTES
  Treat the generated PFX as a transient exportable artifact. Import it non-exportably with the
  matching installation command, then remove it after installation and validation.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $PrivateKeyPath,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $PrivateKeyPassphrasePath,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $CertificatePath,

    [ValidateScript({ [string]::IsNullOrWhiteSpace($_) -or (Test-Path -LiteralPath $_ -PathType Leaf) })]
    [string] $CACertificatePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $PfxPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $FriendlyName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $PasswordSecretName,

    [ValidateNotNullOrEmpty()]
    [string] $SecretStoreType = 'BitwardenSecretsManager'
  )

  begin {
    $fn = 'New-PkiCertificatePfx'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
  }

  process {
    if (Test-Path -LiteralPath $PfxPath) {
      throw "Refusing to overwrite existing PKCS#12 file '$PfxPath'."
    }
    $openSslCommand = Get-Command -Name 'openssl' -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $openSslCommand) {
      throw 'OpenSSL is required but was not found on PATH.'
    }

    $resolvedPfxPath = [System.IO.Path]::GetFullPath($PfxPath)
    if (-not $PSCmdlet.ShouldProcess($resolvedPfxPath, 'Create an encrypted PKCS#12 certificate file')) {
      return [PSCustomObject]@{
        Path = $resolvedPfxPath
        FriendlyName = $FriendlyName
        PasswordSecretName = $PasswordSecretName
        Changed = $false
        Preview = $true
      }
    }

    $password = $null
    $process = $null
    $succeeded = $false
    try {
      $password = Get-SecretATAP -SecretName $PasswordSecretName -SecretStoreType $SecretStoreType -ErrorAction Stop
      if ([string]::IsNullOrWhiteSpace([string]$password)) {
        throw "Secret '$PasswordSecretName' resolved to an empty value."
      }

      $outputDirectory = Split-Path -Parent $resolvedPfxPath
      if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $outputDirectory -Force
      }

      $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
      $startInfo.FileName = $openSslCommand.Source
      $startInfo.UseShellExecute = $false
      $startInfo.RedirectStandardInput = $true
      $startInfo.RedirectStandardOutput = $true
      $startInfo.RedirectStandardError = $true
      $arguments = @(
        'pkcs12', '-export',
        '-inkey', (Resolve-Path -LiteralPath $PrivateKeyPath).ProviderPath,
        '-passin', "file:$((Resolve-Path -LiteralPath $PrivateKeyPassphrasePath).ProviderPath)",
        '-in', (Resolve-Path -LiteralPath $CertificatePath).ProviderPath,
        '-out', $resolvedPfxPath,
        '-passout', 'stdin',
        '-name', $FriendlyName
      )
      if (-not [string]::IsNullOrWhiteSpace($CACertificatePath)) {
        $arguments += @('-certfile', (Resolve-Path -LiteralPath $CACertificatePath).ProviderPath)
      }
      foreach ($argument in $arguments) { $null = $startInfo.ArgumentList.Add($argument) }

      $process = [System.Diagnostics.Process]::new()
      $process.StartInfo = $startInfo
      if (-not $process.Start()) {
        throw 'OpenSSL PKCS#12 process did not start.'
      }
      $stdoutTask = $process.StandardOutput.ReadToEndAsync()
      $stderrTask = $process.StandardError.ReadToEndAsync()
      $process.StandardInput.WriteLine([string]$password)
      $process.StandardInput.Close()
      $password = $null
      $process.WaitForExit()
      $stdout = $stdoutTask.GetAwaiter().GetResult()
      $stderr = $stderrTask.GetAwaiter().GetResult()
      if ($process.ExitCode -ne 0) {
        throw "OpenSSL PKCS#12 export failed with exit code $($process.ExitCode): $stderr $stdout"
      }

      $null = Set-PkiRestrictedFileAcl -Path $resolvedPfxPath
      $succeeded = $true
      $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        (Resolve-Path -LiteralPath $CertificatePath).ProviderPath
      )
      [PSCustomObject]@{
        Path = $resolvedPfxPath
        FriendlyName = $FriendlyName
        PasswordSecretName = $PasswordSecretName
        ThumbprintSha1 = $certificate.Thumbprint
        Changed = $true
        Preview = $false
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "PKCS#12 export failed: $($_.Exception.Message)"
      throw
    } finally {
      $password = $null
      if ($null -ne $process) { $process.Dispose() }
      if (-not $succeeded) {
        Remove-Item -LiteralPath $resolvedPfxPath -Force -ErrorAction SilentlyContinue
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'PKCS#12 export operation completed.' -Tag 'Trace'
  }
}
