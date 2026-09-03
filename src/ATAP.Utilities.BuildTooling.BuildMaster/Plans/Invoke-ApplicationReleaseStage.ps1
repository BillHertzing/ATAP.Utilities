#Requires -Version 7.0
# Executable BuildMaster adapter; dot-sourcing defines functions only.
[CmdletBinding()]
param(
  [string]$ContextPath,
  [string]$ExpectedContextSha256,
  [string]$Stage,
  [string]$BuildId
)

function Invoke-ApplicationReleaseStage {
  <#
  .SYNOPSIS
    Publishes or promotes a previously prepared, hash-approved application bundle.
  .DESCRIPTION
    Verifies the immutable context, tooling, v2 archive, pinned database package,
    preceding stage evidence, and downloaded destination bytes. Never builds,
    applies a database, installs a service, or publishes external distributions.
  .PARAMETER ContextPath
    Operator-approved nonsecret release context JSON.
  .PARAMETER ExpectedContextSha256
    Exact approved context hash bound by the BuildMaster build.
  .PARAMETER Stage
    One stage of the ordered five-tier release ladder.
  .PARAMETER BuildId
    BuildMaster build identity used to isolate stage evidence.
  .OUTPUTS
    PSCustomObject with the verified destination feed and immutable bundle hash.
  .EXAMPLE
    Invoke-ApplicationReleaseStage -ContextPath ./context.json -ExpectedContextSha256 $hash -Stage Experimental -BuildId 42
  .NOTES
    Caller must separately authorize feed mutation; WhatIf performs no I/O mutation.
  .LINK
    New-ReleaseBundle
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)][string]$ContextPath,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedContextSha256,
    [Parameter(Mandatory)][ValidateSet('Experimental','Development','Integration','QA','Production')][string]$Stage,
    [Parameter(Mandatory)][ValidatePattern('^[0-9]+$')][string]$BuildId
  )
  begin {
    $fn = 'Invoke-ApplicationReleaseStage'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    $tiers = @('Experimental','Development','Integration','QA','Production')
    if ((Get-FileHash -LiteralPath $ContextPath -Algorithm SHA256).Hash -ine $ExpectedContextSha256) { throw 'Release context hash mismatch.' }
    $context = Get-Content -LiteralPath $ContextPath -Raw | ConvertFrom-Json
    if ($context.productId -cne 'AceCommander' -or $context.ceilingTier -cne 'Production' -or $context.version -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') { throw 'Expected a stable AceCommander Production-ceiling context.' }
    if ([string]$context.bundleSha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid bundle hash.' }
    if ((Get-FileHash -LiteralPath $context.bundlePath -Algorithm SHA256).Hash -ine $context.bundleSha256) { throw 'Approved bundle hash mismatch.' }
    if ([string]$context.evidenceRoot -notmatch '[\\/]_generated[\\/]') { throw 'Stage evidence must be under _generated.' }
    foreach ($item in @($context.tooling)) {
      if ((Get-FileHash -LiteralPath $item.path -Algorithm SHA256).Hash -ine $item.sha256) { throw 'Release tooling hash mismatch.' }
    }
    if (@($context.tooling | Where-Object { $_.path -eq $context.bundleVerifier }).Count -ne 1 -or
        @($context.tooling | Where-Object { $_.path -eq $context.manifestSchema }).Count -ne 1) { throw 'Verifier and schema must be hash-bound.' }
    $uri = [uri]$context.proGetBaseUrl
    if ($uri.Scheme -cne 'https' -or $uri.UserInfo -or $uri.Query) { throw 'ProGet must have a credential-free HTTPS base URL.' }
    $position = $tiers.IndexOf($Stage)
    $feed = 'releasebundle-' + $Stage.ToLowerInvariant()
    $runRoot = Join-Path $context.evidenceRoot $BuildId
    if ($position -gt 0) {
      $priorPath = Join-Path $runRoot ($tiers[$position - 1] + '.json')
      $prior = Get-Content -LiteralPath $priorPath -Raw | ConvertFrom-Json
      if (-not $prior.success -or $prior.contextSha256 -ine $ExpectedContextSha256 -or $prior.bundleSha256 -ine $context.bundleSha256 -or $prior.buildId -cne $BuildId -or $prior.stage -cne $tiers[$position - 1]) { throw 'Preceding stage evidence does not match this approved build.' }
    }
  }
  process {
    if (-not $PSCmdlet.ShouldProcess("$($context.productId) $($context.version) -> $feed", 'Verify and advance immutable application bundle')) { return }
    Import-Module PSFramework -ErrorAction Stop
    $null = Get-Command Get-SecretATAP -ErrorAction Stop
    $null = Get-Command Promote-ProGetPackage -ErrorAction Stop
    . $context.bundleVerifier
    [IO.Directory]::CreateDirectory($runRoot) | Out-Null
    $attemptRoot = Join-Path $runRoot ($Stage + '-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($attemptRoot) | Out-Null
    Start-Transcript -LiteralPath (Join-Path $attemptRoot 'stage.log') | Out-Null
    try {
      $verified = New-ReleaseBundle -BundlePath $context.bundlePath -VerificationPath (Join-Path $attemptRoot 'local') -ManifestSchema $context.manifestSchema
      if ($verified.ProductId -cne $context.productId -or $verified.BundleVersion -cne $context.version) { throw 'Bundle identity disagrees with context.' }
      $manifest = Get-Content -LiteralPath (Join-Path $verified.VerificationPath.FullName 'manifest.json') -Raw | ConvertFrom-Json
      if ($manifest.databasePackageReference.id -cne 'ATAPUtilities.Database' -or $manifest.databasePackageReference.pinnedVersion -cne '0.1.6') { throw 'Database reference is outside the approved Commander release.' }
      foreach ($component in @($manifest.applicationProvenance.root) + @($manifest.applicationProvenance.components)) {
        if ($component.qualityTier -cne 'Production' -or $component.version -notmatch '^\d+\.\d+\.\d+(\.\d+)?(\+[A-Za-z0-9.-]+)?$') { throw 'Prerelease or non-Production application provenance is prohibited.' }
      }
      $placement = $global:settings[$global:configRootKeys['ServicePlacementMapConfigRootKey']]
      $serviceHost = [string]$placement['ProGet']
      if (-not $serviceHost -or $uri.Host -ine $serviceHost) { throw 'ProGet placement does not match release context.' }
      $secretName = "ProGet.BuildMaster.API.Key.$serviceHost"
      function Get-VerifiedReleaseDownload {
        param([string]$Url,[string]$Path,[string]$Hash,[switch]$AllowMissing)
        $key = $null
        try {
          $key = [string](Get-SecretATAP -SecretName $secretName -SecretStoreType BitwardenSecretsManager -ErrorAction Stop)
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Reading $Url" -Tag RestCall
          Invoke-WebRequest -Uri $Url -Headers @{'X-ApiKey'=$key} -OutFile $Path -TimeoutSec 120 -ErrorAction Stop | Out-Null
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Download completed.' -Tag RestCall
        } catch {
          if ($AllowMissing -and [int]$_.Exception.Response.StatusCode -eq 404) { return $false }
          throw "Release download failed ($($_.Exception.GetType().Name)); no response body logged."
        } finally { $key = $null }
        if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ine $Hash) { throw 'Downloaded artifact hash conflicts with the approved immutable identity.' }
        return $true
      }
      $baseUrl = $context.proGetBaseUrl.TrimEnd('/')
      $databaseUrl = "$baseUrl/nuget/database-stable/v3/flatcontainer/ataputilities.database/0.1.6/ataputilities.database.0.1.6.nupkg"
      $null = Get-VerifiedReleaseDownload -Url $databaseUrl -Path (Join-Path $attemptRoot 'database-reference.nupkg') -Hash 'E9CA804EFF2A25735CB3AC22B08D1F6A790C5E241BA54F3437FE82D9F41ACCCA'
      $downloadUrl = "$baseUrl/upack/$feed/download/$($context.productId)/$($context.version)"
      $alreadyPresent = Get-VerifiedReleaseDownload -Url $downloadUrl -Path (Join-Path $attemptRoot 'destination-before.upack') -Hash $context.bundleSha256 -AllowMissing
      if (-not $alreadyPresent) {
        if ($position -eq 0) {
          $key = $null
          try {
            $key = [string](Get-SecretATAP -SecretName $secretName -SecretStoreType BitwardenSecretsManager -ErrorAction Stop)
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Publishing approved bytes to $feed" -Tag RestCall
            Invoke-RestMethod -Uri "$baseUrl/upack/$feed/" -Method Put -InFile $context.bundlePath -ContentType 'application/octet-stream' -Headers @{'X-ApiKey'=$key} -TimeoutSec 180 -ErrorAction Stop | Out-Null
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Publication returned.' -Tag RestCall
          } catch { throw "Experimental publication failed ($($_.Exception.GetType().Name)); verify destination before retry." }
          finally { $key = $null }
        } else {
          $sourceFeed = 'releasebundle-' + $tiers[$position - 1].ToLowerInvariant()
          $null = Get-VerifiedReleaseDownload -Url "$baseUrl/upack/$sourceFeed/download/$($context.productId)/$($context.version)" -Path (Join-Path $attemptRoot 'source.upack') -Hash $context.bundleSha256
          Promote-ProGetPackage -Name $context.productId -Version $context.version -FromFeed $sourceFeed -ToFeed $feed -CeilingTier Production -ProGetBaseUrl $baseUrl -ProGetApiKeySecretName $secretName -Reason "COMMANDER02 approved stable release; BuildMaster build $BuildId" | Out-Null
        }
      }
      $downloadPath = Join-Path $attemptRoot 'destination-verified.upack'
      $null = Get-VerifiedReleaseDownload -Url $downloadUrl -Path $downloadPath -Hash $context.bundleSha256
      $remoteVerified = New-ReleaseBundle -BundlePath $downloadPath -VerificationPath (Join-Path $attemptRoot 'remote') -ManifestSchema $context.manifestSchema
      $result = [pscustomobject]@{ success=$true; stage=$Stage; buildId=$BuildId; contextSha256=$ExpectedContextSha256; bundleSha256=$context.bundleSha256; version=$context.version; feed=$feed; downloadedPath=$downloadPath; verifiedEntryCount=$remoteVerified.VerifiedEntryCount; databaseReferenceVerified=$true; databaseApplied=$false; completedUtc=[DateTime]::UtcNow.ToString('o') }
      $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runRoot ($Stage + '.json')) -Encoding utf8
      $result
    } finally { Stop-Transcript | Out-Null }
  }
  end { }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  try { Invoke-ApplicationReleaseStage @PSBoundParameters | ConvertTo-Json -Depth 6; exit 0 }
  catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }
}
