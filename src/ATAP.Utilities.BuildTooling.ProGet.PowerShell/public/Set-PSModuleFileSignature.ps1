function Set-PSModuleFileSignature {
  <#
  .SYNOPSIS
  Authenticode-signs staged PowerShell module files.
  .DESCRIPTION
  Selects a non-expired Code Signing certificate with a private key by thumbprint, signs every signable file under Path, timestamps each signature, and verifies the result before returning.
  .PARAMETER Path
  Staged module directory or one signable PowerShell file.
  .PARAMETER CertificateThumbprint
  Thumbprint of the signing certificate in CurrentUser or LocalMachine My.
  .PARAMETER TimestampServerUri
  Authenticode timestamp server URI.
  .OUTPUTS
  System.Management.Automation.PSCustomObject
  .EXAMPLE
  Set-PSModuleFileSignature -Path 'C:/repo/_generated/package-src' -CertificateThumbprint $thumbprint -TimestampServerUri 'http://timestamp.example.test'
  .NOTES
  The signing certificate and private key remain in the Windows certificate store and outside source control.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ })] [string] $Path,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{40,64}$')] [string] $CertificateThumbprint,
    [Parameter(Mandatory)] [ValidateNotNull()] [uri] $TimestampServerUri
  )
  begin { $fn = 'Set-PSModuleFileSignature'; $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell' }
  process {
    if (-not $IsWindows) { throw 'Authenticode module signing requires Windows.' }
    $normalizedThumbprint = $CertificateThumbprint.Replace(' ', '').ToUpperInvariant()
    $certificate = @('Cert:\CurrentUser\My', 'Cert:\LocalMachine\My') | ForEach-Object {
      Get-ChildItem -LiteralPath $_ -ErrorAction SilentlyContinue | Where-Object Thumbprint -EQ $normalizedThumbprint
    } | Select-Object -First 1
    if ($null -eq $certificate) { throw "Code-signing certificate '$normalizedThumbprint' was not found in a Windows My store." }
    $ekuOids = @($certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' } | ForEach-Object { $_.EnhancedKeyUsages | ForEach-Object Value })
    if (-not $certificate.HasPrivateKey) { throw "Certificate '$normalizedThumbprint' has no accessible private key." }
    if ('1.3.6.1.5.5.7.3.3' -notin $ekuOids) { throw "Certificate '$normalizedThumbprint' does not contain the Code Signing EKU." }
    if ($certificate.NotBefore -gt [DateTime]::Now -or $certificate.NotAfter -le [DateTime]::Now) { throw "Certificate '$normalizedThumbprint' is not currently valid." }

    $item = Get-Item -LiteralPath $Path
    $files = if ($item.PSIsContainer) {
      @(Get-ChildItem -LiteralPath $item.FullName -File -Recurse | Where-Object Extension -In @('.ps1', '.psm1', '.psd1', '.ps1xml'))
    } elseif ($item.Extension -in @('.ps1', '.psm1', '.psd1', '.ps1xml')) {
      @($item)
    } else { @() }
    if ($files.Count -eq 0) { throw "No signable PowerShell files were found under '$Path'." }

    $results = foreach ($file in $files) {
      if (-not $PSCmdlet.ShouldProcess($file.FullName, "Apply Authenticode signature with certificate $normalizedThumbprint")) { continue }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Signing '$($file.FullName)'." -Tag 'Trace'
      # The Authenticode API is not long-path aware, so it reports a path over MAX_PATH as
      # 'UnknownError The system cannot find the path specified' even though the file
      # exists and LongPathsEnabled is set. Diagnose that here instead of surfacing the
      # misleading native message.
      if ($file.FullName.Length -gt 260) {
        throw "Cannot Authenticode-sign '$($file.FullName)': the path is $($file.FullName.Length) characters, over the 260-character MAX_PATH limit the signing API enforces regardless of LongPathsEnabled. Shorten the build staging path. See SolutionDocumentation/Authenticode-Signing-MAX_PATH-Constraint.md."
      }
      $signature = $null
      for ($attempt = 1; $attempt -le 3; $attempt++) {
        $signature = Set-AuthenticodeSignature -FilePath $file.FullName -Certificate $certificate -HashAlgorithm SHA256 -TimestampServer $TimestampServerUri.AbsoluteUri -ErrorAction Stop
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
      if ($null -eq $verified.TimeStamperCertificate) {
        throw "Post-sign timestamp verification failed for '$($file.FullName)': no timestamp certificate was recorded."
      }
      [PSCustomObject]@{
        Path = $file.FullName
        Status = [string]$verified.Status
        SignerThumbprint = $verified.SignerCertificate.Thumbprint
        Timestamped = $true
        TimestampThumbprint = $verified.TimeStamperCertificate.Thumbprint
      }
    }
    [PSCustomObject]@{
      RootPath = $item.FullName
      CertificateThumbprint = $normalizedThumbprint
      TimestampServerUri = $TimestampServerUri.AbsoluteUri
      SignedCount = @($results).Count
      Files = @($results)
    }
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Signing operation completed.' -Tag 'Trace' }
}
