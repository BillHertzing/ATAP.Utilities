function Set-AuthenticodeFileSignature {
  <#
  .SYNOPSIS
  Authenticode-signs an explicit list of files with a store-resident certificate and verifies each result.
  .DESCRIPTION
  The one signing leaf shared by the PowerShell-module stage (through Set-PSModuleFileSignature) and the
  application-release stage (Task 15.196.q). Selects the certificate by thumbprint from CurrentUser or
  LocalMachine My, requires a private key, the Code Signing EKU and current validity, signs every file
  in FilePath with SHA-256 and a timestamp, retries the transient 'No provider was specified for the
  store or object' / 'Keyset does not exist' condition, and verifies status and timestamp after signing.
  Any failure throws; there is no partial success.
  .PARAMETER FilePath
  Files to sign. Each must exist; extension is not restricted (application binaries and PowerShell files).
  .PARAMETER CertificateThumbprint
  Thumbprint of the signing certificate in CurrentUser or LocalMachine My.
  .PARAMETER TimestampServerUri
  Authenticode timestamp server URI.
  .PARAMETER ExpectedSignerThumbprint
  Optional. When supplied, every verified signature must carry exactly this signer thumbprint; defaults to
  CertificateThumbprint. Exists so an approval boundary can pass the admitted value independently.
  .OUTPUTS
  System.Management.Automation.PSCustomObject
  .EXAMPLE
  Set-AuthenticodeFileSignature -FilePath 'C:/publish/AceOutpostService.exe','C:/publish/AceCommon.dll' -CertificateThumbprint $thumbprint -TimestampServerUri 'http://timestamp.digicert.com'
  .NOTES
  The signing certificate and private key remain in the Windows certificate store and outside source control.
  .LINK
  Set-PSModuleFileSignature
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string[]] $FilePath,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{40,64}$')] [string] $CertificateThumbprint,
    [Parameter(Mandatory)] [ValidateNotNull()] [uri] $TimestampServerUri,
    [ValidatePattern('^[A-Fa-f0-9]{40,64}$')] [string] $ExpectedSignerThumbprint
  )
  begin {
    $fn = 'Set-AuthenticodeFileSignature'; $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    if (-not $IsWindows) { throw 'Authenticode signing requires Windows.' }
    $normalizedThumbprint = $CertificateThumbprint.Replace(' ', '').ToUpperInvariant()
    $expectedSigner = if ([string]::IsNullOrWhiteSpace($ExpectedSignerThumbprint)) { $normalizedThumbprint } else { $ExpectedSignerThumbprint.Replace(' ', '').ToUpperInvariant() }
    if ($expectedSigner -cne $normalizedThumbprint) { throw "ExpectedSignerThumbprint '$expectedSigner' does not equal the signing certificate '$normalizedThumbprint'." }
    $certificate = @('Cert:\CurrentUser\My', 'Cert:\LocalMachine\My') | ForEach-Object {
      Get-ChildItem -LiteralPath $_ -ErrorAction SilentlyContinue | Where-Object Thumbprint -EQ $normalizedThumbprint
    } | Select-Object -First 1
    if ($null -eq $certificate) { throw "Code-signing certificate '$normalizedThumbprint' was not found in a Windows My store." }
    $ekuOids = @($certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' } | ForEach-Object { $_.EnhancedKeyUsages | ForEach-Object Value })
    if (-not $certificate.HasPrivateKey) { throw "Certificate '$normalizedThumbprint' has no accessible private key." }
    if ('1.3.6.1.5.5.7.3.3' -notin $ekuOids) { throw "Certificate '$normalizedThumbprint' does not contain the Code Signing EKU." }
    if ($certificate.NotBefore -gt [DateTime]::Now -or $certificate.NotAfter -le [DateTime]::Now) { throw "Certificate '$normalizedThumbprint' is not currently valid." }
  }
  process {
    $files = foreach ($path in $FilePath) {
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "File to sign does not exist: '$path'." }
      Get-Item -LiteralPath $path
    }
    $results = foreach ($file in $files) {
      if (-not $PSCmdlet.ShouldProcess($file.FullName, "Apply Authenticode signature with certificate $normalizedThumbprint")) { continue }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Signing '$($file.FullName)'." -Tag 'Trace'
      # The Authenticode API is not long-path aware: a path over MAX_PATH reports
      # 'UnknownError The system cannot find the path specified' even with LongPathsEnabled.
      if ($file.FullName.Length -gt 260) {
        throw "Cannot Authenticode-sign '$($file.FullName)': the path is $($file.FullName.Length) characters, over the 260-character MAX_PATH limit the signing API enforces regardless of LongPathsEnabled. See SolutionDocumentation/Authenticode-Signing-MAX_PATH-Constraint.md."
      }
      $signature = $null
      for ($attempt = 1; $attempt -le 3; $attempt++) {
        $signature = Set-AuthenticodeSignature -FilePath $file.FullName -Certificate $certificate -HashAlgorithm SHA256 -TimestampServer $TimestampServerUri.AbsoluteUri -IncludeChain All -ErrorAction Stop
        if ($signature.Status -eq [Management.Automation.SignatureStatus]::Valid) { break }
        $providerNotReady = $signature.Status -eq [Management.Automation.SignatureStatus]::UnknownError -and
          $signature.StatusMessage -match 'No provider was specified for the store or object|Keyset does not exist'
        if (-not $providerNotReady -or $attempt -eq 3) { break }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Authenticode provider was not ready for '$($file.FullName)'; retrying attempt $($attempt + 1) of 3." -Tag 'Trace'
        Start-Sleep -Seconds 1
      }
      if ($signature.Status -ne [Management.Automation.SignatureStatus]::Valid) {
        throw "Authenticode signing failed for '$($file.FullName)': $($signature.Status) $($signature.StatusMessage)"
      }
      $verified = Get-AuthenticodeSignature -FilePath $file.FullName
      if ($verified.Status -ne [Management.Automation.SignatureStatus]::Valid) {
        throw "Post-sign verification failed for '$($file.FullName)': $($verified.Status) $($verified.StatusMessage)"
      }
      if ($verified.SignerCertificate.Thumbprint -cne $expectedSigner) {
        throw "Post-sign verification failed for '$($file.FullName)': signer '$($verified.SignerCertificate.Thumbprint)' is not the expected '$expectedSigner'."
      }
      if ($null -eq $verified.TimeStamperCertificate) {
        throw "Post-sign timestamp verification failed for '$($file.FullName)': no timestamp certificate was recorded."
      }
      [PSCustomObject]@{
        Path                = $file.FullName
        Name                = $file.Name
        Status              = [string]$verified.Status
        SignerThumbprint    = $verified.SignerCertificate.Thumbprint
        Timestamped         = $true
        TimestampThumbprint = $verified.TimeStamperCertificate.Thumbprint
        Sha256              = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
      }
    }
    [PSCustomObject]@{
      CertificateThumbprint = $normalizedThumbprint
      TimestampServerUri    = $TimestampServerUri.AbsoluteUri
      SignedCount           = @($results).Count
      Files                 = @($results)
    }
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Signing operation completed.' -Tag 'Trace' }
}
