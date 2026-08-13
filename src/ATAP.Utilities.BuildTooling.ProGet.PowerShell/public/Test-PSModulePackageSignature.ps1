function Test-PSModulePackageSignature {
  <#
  .SYNOPSIS
  Verifies every signable PowerShell file inside a module package.
  .DESCRIPTION
  Expands the nupkg into a unique evidence directory, requires at least one signable file, and rejects every unsigned, unknown-error, hash-mismatch, untrusted, expired, or otherwise invalid Authenticode result.
  .PARAMETER NupkgPath
  PowerShell module package to inspect.
  .PARAMETER ResultsPath
  Optional evidence root. Defaults beside the package under signature-verification.
  .PARAMETER RequireTimestamp
  Rejects valid signatures that do not carry a timestamp certificate.
  .OUTPUTS
  System.Management.Automation.PSCustomObject
  .EXAMPLE
  Test-PSModulePackageSignature -NupkgPath './_generated/Foo.1.0.0.nupkg' -RequireTimestamp
  .NOTES
  The report contains paths, signature states, and public certificate thumbprints only.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string] $NupkgPath,
    [string] $ResultsPath,
    [switch] $RequireTimestamp
  )
  begin { $fn = 'Test-PSModulePackageSignature'; $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell' }
  process {
    if ([IO.Path]::GetExtension($NupkgPath) -ne '.nupkg') { throw "NupkgPath must have a .nupkg extension: '$NupkgPath'." }
    $resolvedPackage = (Resolve-Path -LiteralPath $NupkgPath).ProviderPath
    if ([string]::IsNullOrWhiteSpace($ResultsPath)) {
      $ResultsPath = Join-Path (Split-Path -Parent $resolvedPackage) 'signature-verification'
    }
    $inspectionPath = Join-Path $ResultsPath ([guid]::NewGuid().ToString('N').Substring(0, 12))
    New-Item -ItemType Directory -Path $inspectionPath -Force | Out-Null
    try {
      [IO.Compression.ZipFile]::ExtractToDirectory($resolvedPackage, $inspectionPath)
    } catch {
      throw "NupkgPath is not a readable package archive: '$resolvedPackage'. $($_.Exception.Message)"
    }
    $files = @(Get-ChildItem -LiteralPath $inspectionPath -File -Recurse | Where-Object Extension -In @('.ps1', '.psm1', '.psd1', '.ps1xml'))
    if ($files.Count -eq 0) { throw "Package '$resolvedPackage' contains no signable PowerShell files." }

    $fileResults = foreach ($file in $files) {
      $signature = Get-AuthenticodeSignature -FilePath $file.FullName
      [PSCustomObject]@{
        RelativePath = [IO.Path]::GetRelativePath($inspectionPath, $file.FullName)
        Status = [string]$signature.Status
        StatusMessage = $signature.StatusMessage
        SignerThumbprint = $signature.SignerCertificate.Thumbprint
        Timestamped = $null -ne $signature.TimeStamperCertificate
        TimestampThumbprint = $signature.TimeStamperCertificate.Thumbprint
      }
    }
    $invalid = @($fileResults | Where-Object { $_.Status -ne 'Valid' -or ($RequireTimestamp -and -not $_.Timestamped) })
    $report = [PSCustomObject]@{
      NupkgPath = $resolvedPackage
      InspectionPath = $inspectionPath
      RequireTimestamp = [bool]$RequireTimestamp
      SignableFileCount = $files.Count
      Valid = $invalid.Count -eq 0
      Files = @($fileResults)
    }
    $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $inspectionPath 'signature-report.json') -Encoding utf8
    if ($invalid.Count -gt 0) {
      $summary = ($invalid | ForEach-Object { "$($_.RelativePath)=$($_.Status),Timestamped=$($_.Timestamped)" }) -join '; '
      throw "PowerShell package signature verification failed for '$resolvedPackage': $summary"
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Verified $($files.Count) signed package files." -Tag 'Trace'
    $report
  }
  end {}
}
