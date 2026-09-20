#Requires -Version 7.0
# Executable BuildMaster stage runner for ApplicationBuild-1Stage.otter (Task 15.196.q, unit q.2).
# Dot-sourcing defines functions only; `pwsh -File` runs the guarded block at the bottom.
#
# One stage, 'Build': deterministic publish of an admitted application from the Ace worktree,
# Authenticode signing of exactly the allowlisted owned files AS THE BUILDMASTER SERVICE IDENTITY
# with the leaf admitted for this host, bundle construction through the product's own bundle
# entry point, upload of the immutable .upack to releasebundle-experimental, and a nonsecret
# release context for the promotion adapter. Nothing here installs, promotes past Experimental,
# applies a database, or touches live configuration.
[CmdletBinding()]
param(
  [string]$BuildToolingModulePath,
  [string]$SourcePath,
  [string]$BuildMasterBuildId,
  [string]$BuildNumber,
  [string]$ExecutionId,
  [string]$ApplicationName,
  [string]$ProductId,
  [string]$Branch,
  [string]$Stage,
  [string]$ArtifactsRoot,
  [string]$ReleaseVersion,
  [string]$SourceTag,
  [string]$ProGetUrl,
  [string]$ProGetApiKeySecretName,
  [string]$CodeSigningCertificateThumbprint,
  [string]$TimestampServerUri,
  [string]$ReleaseNotes,
  [string]$ExpectedTestsPassed,
  [string]$ConversationId,
  [string]$DatabasePackageId,
  [string]$DatabasePackagePinnedVersion,
  [string]$DatabasePackageCompatibleVersionRange,
  [string]$DatabasePackageLifecycleCeiling,
  [string]$DatabaseEvidencePath,
  [string]$DatabaseEvidenceSha256,
  [string]$ExperimentalFeed,
  [string]$EvidenceRoot,
  [string]$ExpectedHostName
)

function Invoke-ApplicationBuildMasterStage {
  <#
  .SYNOPSIS
    Builds, signs and bundles one admitted application as the BuildMaster service identity.
  .DESCRIPTION
    Runs the single Build stage of ApplicationBuild-1Stage. Every input that decides WHAT is
    signed or WITH WHAT comes from Plans/ApplicationReleaseAuthenticodeSigning.ps1 (the approval
    boundary), never from this runner's parameters: the parameters only say which admitted
    product, which source coordinates, and which BuildMaster build. The signer thumbprint the
    application variable supplies is checked against the boundary's admitted leaf for this host
    and refused otherwise. Retry-safe: an .upack already present on the Experimental feed with
    the same bytes is accepted; different bytes under the same version fail closed.
  .PARAMETER BuildToolingModulePath
    Path to ATAP.Utilities.BuildTooling.PowerShell.psd1 in the committed ATAP.Utilities worktree;
    the worktree root (bundle primitives, Plans, evidence root) is derived from it.
  .PARAMETER SourcePath
    Committed Ace worktree whose HEAD must equal the commit SourceTag peels to.
  .PARAMETER ProductId
    Admitted product id (AceOutpost or AceCommander).
  .PARAMETER ArtifactsRoot
    Host artifact root (C:\ATAPArtifacts on utat01, D:\ATAPArtifacts on utat022); must be outside
    the repository and outside Dropbox, which the publisher itself enforces.
  .PARAMETER ReleaseVersion
    Immutable release version, e.g. 0.1.3+abcdef1234 (AceOutpost) or 0.1.2 (AceCommander).
  .PARAMETER SourceTag
    Git tag that peels exactly to the Ace worktree HEAD, e.g. AceOutpost/v0.1.3+abcdef1.
  .PARAMETER CodeSigningCertificateThumbprint
    Signer leaf from the BuildMaster application variable; refused unless admitted for this host.
  .OUTPUTS
    PSCustomObject describing the signed publish, the bundle, the feed state and the context path.
  .EXAMPLE
    Invoke-ApplicationBuildMasterStage -BuildToolingModulePath ... -SourcePath ... -ProductId AceOutpost ...
  .NOTES
    Task 15.196.q / SC-0443. Signing happens under whichever identity runs this script; under
    BuildMaster that is SvcBuildMaster, which is the entire point.
  .LINK
    Plans/ApplicationReleaseAuthenticodeSigning.ps1
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$BuildToolingModulePath,
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })][string]$SourcePath,
    [Parameter(Mandatory)][ValidatePattern('^[0-9]+$')][string]$BuildMasterBuildId,
    [Parameter(Mandatory)][ValidatePattern('^[0-9]+$')][string]$BuildNumber,
    [Parameter(Mandatory)][ValidatePattern('^[0-9]+$')][string]$ExecutionId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApplicationName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ProductId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Branch,
    [Parameter(Mandatory)][ValidateSet('Build', 'Experimental')][string]$Stage,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ArtifactsRoot,
    [Parameter(Mandatory)][ValidatePattern('^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$')][string]$ReleaseVersion,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SourceTag,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ProGetUrl,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ProGetApiKeySecretName,
    [Parameter(Mandatory)][ValidatePattern('^[0-9A-Fa-f]{40}$')][string]$CodeSigningCertificateThumbprint,
    [AllowEmptyString()][string]$TimestampServerUri = '',
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ReleaseNotes,
    [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$ExpectedTestsPassed,
    [Parameter(Mandatory)][ValidatePattern('\A(?-i:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\z')][string]$ConversationId,
    [string]$DatabasePackageId = 'ATAPUtilities.Database',
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DatabasePackagePinnedVersion,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DatabasePackageCompatibleVersionRange,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DatabasePackageLifecycleCeiling,
    [Parameter(Mandatory)][AllowEmptyString()][string]$DatabaseEvidencePath,
    [Parameter(Mandatory)][AllowEmptyString()][string]$DatabaseEvidenceSha256,
    [string]$ExperimentalFeed = 'releasebundle-experimental',
    [AllowEmptyString()][string]$EvidenceRoot = '',
    [AllowEmptyString()][string]$ExpectedHostName = ''
  )

  BEGIN {
    $fn = 'Invoke-ApplicationBuildMasterStage'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn for BuildId='$BuildMasterBuildId'; Product='$ProductId'; Version='$ReleaseVersion'; Stage='$Stage'"

    $plansRoot = $PSScriptRoot
    $buildToolingRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $BuildToolingModulePath))
    if (-not (Test-Path -LiteralPath (Join-Path $buildToolingRoot 'src') -PathType Container)) {
      throw "BuildToolingModulePath '$BuildToolingModulePath' does not sit under <worktree>\src\<module>\; cannot derive the ATAP.Utilities worktree root."
    }

    # The approval boundary and the shared signer are read from the SAME source tree as this
    # runner, never from an installed module, so the boundary that ships with the plan is the
    # boundary that runs.
    . (Join-Path $plansRoot 'ApplicationReleaseAuthenticodeSigning.ps1')
    . (Join-Path $buildToolingRoot 'src\ATAP.Utilities.BuildTooling.ProGet.PowerShell\public\Set-AuthenticodeFileSignature.ps1')
    if (-not (Get-Command -Name Get-SecretATAP -ErrorAction SilentlyContinue)) {
      . (Join-Path $buildToolingRoot 'src\ATAP.Utilities.BuildTooling.Secrets.PowerShell\public\Get-SecretATAP.ps1')
    }

    $hostName = if ([string]::IsNullOrWhiteSpace($ExpectedHostName)) { $env:COMPUTERNAME } else { $ExpectedHostName }
    if ($hostName -ine $env:COMPUTERNAME) { throw "This stage is bound to host '$hostName' but is running on '$env:COMPUTERNAME'." }

    $contract = Get-ApplicationReleaseAuthenticodeContract -ProductId $ProductId
    # Repository-owned bundle entry points may require database release evidence that is not
    # part of the product-neutral BuildToolingFunction contract. Validate it before any
    # publish, compile, or signing work, then forward it only to the repository script.
    if ($contract.BundleEntryPointKind -eq 'RepositoryScript') {
      if ([string]::IsNullOrWhiteSpace($DatabaseEvidencePath)) {
        throw "DatabaseEvidencePath is required for product '$ProductId'."
      }
      if ($DatabaseEvidencePath -notmatch '[\\/]_generated[\\/]') {
        throw "DatabaseEvidencePath '$DatabaseEvidencePath' must be under a _generated folder (SC-0033)."
      }
      if (-not (Test-Path -LiteralPath $DatabaseEvidencePath -PathType Leaf)) {
        throw "DatabaseEvidencePath '$DatabaseEvidencePath' does not identify an existing file."
      }
      if ($DatabaseEvidenceSha256 -notmatch '\A[0-9A-Fa-f]{64}\z') {
        throw 'DatabaseEvidenceSha256 must be exactly 64 hexadecimal characters.'
      }
      $actualDatabaseEvidenceSha256 = (Get-FileHash -LiteralPath $DatabaseEvidencePath -Algorithm SHA256).Hash
      if ($actualDatabaseEvidenceSha256 -ine $DatabaseEvidenceSha256) {
        throw "Database evidence SHA-256 '$actualDatabaseEvidenceSha256' does not match DatabaseEvidenceSha256 '$DatabaseEvidenceSha256'."
      }
    }
    $signer = Test-ApplicationReleaseSignerAdmitted -HostName $hostName -Thumbprint $CodeSigningCertificateThumbprint
    $tsa = if ([string]::IsNullOrWhiteSpace($TimestampServerUri)) { Get-ApplicationReleaseTimestampServerUri } else { [uri]$TimestampServerUri }
    if ($tsa.AbsoluteUri -cne (Get-ApplicationReleaseTimestampServerUri).AbsoluteUri) {
      throw "Timestamp authority '$($tsa.AbsoluteUri)' is not the pinned authority '$((Get-ApplicationReleaseTimestampServerUri).AbsoluteUri)'."
    }

    if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
      $EvidenceRoot = Join-Path $buildToolingRoot "_generated\Sprint0015\Task15.196\q\$ProductId"
    }
    if ($EvidenceRoot -notmatch '[\\/]_generated[\\/]') { throw "EvidenceRoot '$EvidenceRoot' must be under a _generated folder (SC-0033)." }
    $buildEvidence = Join-Path $EvidenceRoot $BuildMasterBuildId

    function Invoke-ApplicationStageProcess {
      param([Parameter(Mandatory)][string]$FilePath, [Parameter(Mandatory)][string[]]$ArgumentList, [string]$WorkingDirectory)
      $startInfo = [Diagnostics.ProcessStartInfo]::new()
      $startInfo.FileName = $FilePath
      $startInfo.UseShellExecute = $false
      $startInfo.CreateNoWindow = $true
      $startInfo.RedirectStandardOutput = $true
      $startInfo.RedirectStandardError = $true
      if ($WorkingDirectory) { $startInfo.WorkingDirectory = $WorkingDirectory }
      foreach ($a in $ArgumentList) { [void]$startInfo.ArgumentList.Add($a) }
      $process = [Diagnostics.Process]::new()
      $process.StartInfo = $startInfo
      try {
        if (-not $process.Start()) { throw "Failed to start '$FilePath'." }
        # R-34: drain both streams before waiting.
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        [void]$process.WaitForExitAsync().GetAwaiter().GetResult()
        [pscustomobject]@{ ExitCode = $process.ExitCode; StdOut = $stdoutTask.GetAwaiter().GetResult(); StdErr = $stderrTask.GetAwaiter().GetResult() }
      } finally { $process.Dispose() }
    }

    function Write-StageJson {
      param([Parameter(Mandatory)]$Object, [Parameter(Mandatory)][string]$Path)
      [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
      # -InputObject keeps a one-element array an array (piping would unwrap it to an object).
      [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Object -Depth 12), [Text.UTF8Encoding]::new($false))
      (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
  }

  PROCESS {
    if (-not $PSCmdlet.ShouldProcess("$ProductId $ReleaseVersion", "Build, sign as $signer, bundle and upload to $ExperimentalFeed")) { return }
    [IO.Directory]::CreateDirectory($buildEvidence) | Out-Null

    # 1. Source identity - fail before any compile if the coordinates are not exact.
    $head = (& git -C $SourcePath rev-parse HEAD | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $head -notmatch '^[0-9a-f]{40}$') { throw "Cannot resolve HEAD of '$SourcePath'." }
    $tagCommit = (& git -C $SourcePath rev-parse "$SourceTag^{commit}" 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $tagCommit -ine $head) { throw "SourceTag '$SourceTag' does not peel to HEAD '$head' of '$SourcePath'." }
    $sourceCommit = $head.ToLowerInvariant()

    # 2. Deterministic publish, as a child process so the publisher's own guards apply unchanged.
    $publishRecord = Join-Path $SourcePath $contract.ProductRecordPath
    $publishScript = Join-Path $SourcePath $contract.PublishEntryPoint
    $publishExecutionId = "bm$BuildMasterBuildId-$ExecutionId"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Publishing '$ProductId' from '$SourcePath' (execution '$publishExecutionId')."
    $publish = Invoke-ApplicationStageProcess -FilePath 'pwsh' -WorkingDirectory $SourcePath -ArgumentList @(
      '-NoLogo', '-NonInteractive', '-File', $publishScript,
      '-ProductRecord', $publishRecord, '-ExecutionId', $publishExecutionId, '-ArtifactsRoot', $ArtifactsRoot, '-WorktreeId', 'sprint0015-ace')
    Set-Content -LiteralPath (Join-Path $buildEvidence 'publish.stdout.txt') -Value $publish.StdOut
    Set-Content -LiteralPath (Join-Path $buildEvidence 'publish.stderr.txt') -Value $publish.StdErr
    if ($publish.ExitCode -ne 0) { throw "Deterministic publish failed (exit $($publish.ExitCode)): $($publish.StdErr)" }
    $publishResult = $publish.StdOut.Substring($publish.StdOut.IndexOf('{')) | ConvertFrom-Json -Depth 12
    if (-not $publishResult.success -or $publishResult.planned) { throw 'Deterministic publish did not report a completed publish.' }
    $publishRoot = [string]$publishResult.publishPath
    $provenancePath = [string]$publishResult.provenancePath

    # 3. Sign exactly the allowlisted owned files, on a copy, as the running identity.
    $signedRoot = Join-Path (Split-Path -Parent (Split-Path -Parent $publishRoot)) "signed\$ProductId"
    if (Test-Path -LiteralPath $signedRoot) { Remove-Item -LiteralPath $signedRoot -Recurse -Force }
    [IO.Directory]::CreateDirectory($signedRoot) | Out-Null
    Copy-Item -Path (Join-Path $publishRoot '*') -Destination $signedRoot -Recurse -Force
    $toSign = Get-ApplicationReleaseSignedFileContract -ProductId $ProductId -PublishRoot $signedRoot
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Signing $($toSign.Count) owned files as '$signer' ($env:USERNAME)."
    $signing = Set-AuthenticodeFileSignature -FilePath @($toSign.Path) -CertificateThumbprint $signer -TimestampServerUri $tsa -ExpectedSignerThumbprint $signer -Confirm:$false
    if ($signing.SignedCount -ne $toSign.Count) { throw "Signed $($signing.SignedCount) of $($toSign.Count) allowlisted files." }
    # Independent re-verification of every file in the signed tree that we own.
    foreach ($f in $toSign) {
      $v = Get-AuthenticodeSignature -FilePath $f.Path
      if ($v.Status -ne 'Valid' -or $v.SignerCertificate.Thumbprint -cne $signer -or $null -eq $v.TimeStamperCertificate) { throw "Post-sign check failed for '$($f.Name)'." }
    }
    $inventory = @(Get-ChildItem -LiteralPath $signedRoot -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
      [ordered]@{ path = [IO.Path]::GetRelativePath($signedRoot, $_.FullName).Replace('\', '/'); size = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
    $inventoryPath = Join-Path $buildEvidence 'signed-publish-inventory.json'
    $inventorySha = Write-StageJson -Path $inventoryPath -Object ([ordered]@{ schemaVersion = '1.0'; releaseVersion = $ReleaseVersion; files = $inventory; taskId = '15.196.q'; buildId = $BuildMasterBuildId })
    $signaturesPath = Join-Path $buildEvidence 'signatures.json'
    $null = Write-StageJson -Path $signaturesPath -Object ([ordered]@{
      schemaVersion = '1.0'; signerThumbprint = $signer; signedBy = "$env:USERDOMAIN\$env:USERNAME"; timestampAuthority = $tsa.AbsoluteUri; taskId = '15.196.q'; buildId = $BuildMasterBuildId
      files = @($signing.Files | ForEach-Object { [ordered]@{ name = $_.Name; sha256 = $_.Sha256.ToLowerInvariant(); signerThumbprint = $_.SignerThumbprint; timestamperThumbprint = $_.TimestampThumbprint; timestamped = $true } })
    })

    # 4. Bundle through the product's own entry point.
    $outputRoot = Join-Path (Split-Path -Parent (Split-Path -Parent $publishRoot)) "bundles\$ProductId"
    $databaseReference = @{ id = $DatabasePackageId; pinnedVersion = $DatabasePackagePinnedVersion; compatibleVersionRange = $DatabasePackageCompatibleVersionRange; lifecycleCeiling = $DatabasePackageLifecycleCeiling }
    $bundleParameters = @{
      RepoRoot = $SourcePath; BuildToolingRoot = $buildToolingRoot; PublishRoot = $signedRoot; OutputRoot = $outputRoot
      Version = $ReleaseVersion; SourceCommit = $sourceCommit; SourceTag = $SourceTag; Branch = $Branch
      DatabasePackageReference = $databaseReference; ReleaseNotes = $ReleaseNotes; ExpectedTestsPassed = $ExpectedTestsPassed; ConversationId = $ConversationId
      SignedInventoryPath = $inventoryPath; SignedInventorySha256 = $inventorySha
      ApplicationProvenancePath = $provenancePath
    }
    switch ($contract.BundleEntryPointKind) {
      'RepositoryScript' {
        . (Join-Path $SourcePath $contract.BundleEntryPoint)
        $bundleParameters.DatabaseEvidencePath = $DatabaseEvidencePath
        $bundleParameters.DatabaseEvidenceSha256 = $DatabaseEvidenceSha256
        $bundleParameters.ApplicationProvenanceSha256 = (Get-FileHash -LiteralPath $provenancePath -Algorithm SHA256).Hash
        $bundleParameters.BuildUtc = [DateTime]::UtcNow.ToString('o')
        $bundleParameters.ExpectedSignerThumbprint = $signer
        $bundleCommand = "New-$ProductId" + 'ReleaseBundle'
        if (-not (Get-Command -Name $bundleCommand -ErrorAction SilentlyContinue)) { throw "Bundle entry point '$($contract.BundleEntryPoint)' did not define '$bundleCommand'." }
        $bundle = & $bundleCommand @bundleParameters -Confirm:$false
      }
      'BuildToolingFunction' {
        . (Join-Path $buildToolingRoot "src\ATAP.Utilities.BuildTooling.PowerShell\public\$($contract.BundleFunctionName).ps1")
        $bundleParameters.ProGetBaseUrl = $ProGetUrl
        # New-CommanderReleaseBundle reads SignedInventoryPath as a bare array of
        # { path, size, sha256 } — one element per file under PublishRoot — not the
        # wrapped { files = [...] } document written above (execution 246 failed
        # 'inventory 1, publish 1349'). Hand it the flat form on its own file.
        $flatInventoryPath = Join-Path $buildEvidence 'signed-publish-inventory.flat.json'
        $flatInventorySha = Write-StageJson -Path $flatInventoryPath -Object $inventory
        $bundleParameters.SignedInventoryPath = $flatInventoryPath
        $bundleParameters.SignedInventorySha256 = $flatInventorySha
        $bundle = & $contract.BundleFunctionName @bundleParameters -Confirm:$false
      }
      default { throw "Unknown bundle entry point kind '$($contract.BundleEntryPointKind)'." }
    }
    $bundlePath = [string]$bundle.BundlePath
    $bundleSha = (Get-FileHash -LiteralPath $bundlePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($bundle.PSObject.Properties['BundleSha256'] -and ([string]$bundle.BundleSha256).ToLowerInvariant() -cne $bundleSha) { throw 'Bundle hash reported by the bundler disagrees with the file on disk.' }
    $null = Write-StageJson -Path (Join-Path $buildEvidence 'bundle-result.json') -Object $bundle

    # 5. Upload to the Experimental feed, retry-safe on identical bytes.
    $baseUrl = $ProGetUrl.TrimEnd('/')
    # ProGet universal feeds key a package by its base version: '0.1.2+7cf4be82e0' uploads
    # with the full string but is addressed and made immutable as '0.1.2'. Two releases that
    # differ only in build metadata therefore COLLIDE on the feed; the probe below is what
    # turns that into a fail-closed refusal instead of a silent overwrite.
    $feedVersion = ($ReleaseVersion -split '\+', 2)[0]
    $downloadUrl = "$baseUrl/upack/$ExperimentalFeed/download/$ProductId/$feedVersion"
    $existingPath = Join-Path $buildEvidence 'feed-existing.upack'
    $feedState = 'uploaded'
    $apiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName -SecretStoreType BitwardenSecretsManager -ErrorAction Stop)
    try {
      $headers = @{ 'X-ApiKey' = $apiKey }
      # -OutFile still throws on a 404 even with -SkipHttpErrorCheck, so probe into memory.
      $probe = Invoke-WebRequest -Uri $downloadUrl -Headers $headers -SkipHttpErrorCheck -ErrorAction Stop
      if ($probe.StatusCode -eq 200) {
        [IO.File]::WriteAllBytes($existingPath, [byte[]]$probe.Content)
        $existingSha = (Get-FileHash -LiteralPath $existingPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($existingSha -cne $bundleSha) { throw "Feed '$ExperimentalFeed' already holds $ProductId $feedVersion (feed versions ignore '+' build metadata) with different bytes ($existingSha); versions are immutable. Bump the base version or have the operator remove the orphaned package." }
        $feedState = 'already-present-identical'
      } elseif ($probe.StatusCode -ne 404) {
        throw "Feed probe of '$downloadUrl' returned HTTP $($probe.StatusCode)."
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $baseUrl/upack/$ExperimentalFeed/upload" -Tag 'RestCall'
        Invoke-RestMethod -Uri "$baseUrl/upack/$ExperimentalFeed/upload" -Method Post -InFile $bundlePath -ContentType 'application/zip' -Headers $headers -MaximumRedirection 0 -TimeoutSec 300 -ErrorAction Stop | Out-Null
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $baseUrl/upack/$ExperimentalFeed/upload" -Tag 'RestCall'
        $verifyPath = Join-Path $buildEvidence 'feed-verified.upack'
        Invoke-WebRequest -Uri $downloadUrl -Headers $headers -OutFile $verifyPath -ErrorAction Stop | Out-Null
        if ((Get-FileHash -LiteralPath $verifyPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $bundleSha) { throw 'Bytes downloaded from the feed do not equal the uploaded bundle.' }
        Remove-Item -LiteralPath $verifyPath -Force
      }
    } finally { $apiKey = $null; $headers = $null }

    # 6. Nonsecret release context + stage evidence for the promotion adapter.
    $context = [ordered]@{
      schemaVersion = '1.0'; productId = $ProductId; version = $ReleaseVersion; artifactKind = $contract.ArtifactKind
      sourceCommit = $sourceCommit; sourceTag = $SourceTag; branch = $Branch
      bundlePath = $bundlePath; bundleSha256 = $bundleSha; bundleContextPath = [string]$bundle.ContextPath
      signerThumbprint = $signer; signedBy = "$env:USERDOMAIN\$env:USERNAME"; signedFiles = @($toSign.Name); timestampAuthority = $tsa.AbsoluteUri
      signedInventoryPath = $inventoryPath; signedInventorySha256 = $inventorySha.ToLowerInvariant()
      proGetBaseUrl = $baseUrl; experimentalFeed = $ExperimentalFeed; feedVersion = $feedVersion; feedState = $feedState
      databasePackageReference = $databaseReference; ceilingTier = 'Production'
      installerRelativePath = $contract.InstallerRelativePath; evidenceRoot = $EvidenceRoot
      buildMaster = @{ applicationName = $ApplicationName; buildId = $BuildMasterBuildId; buildNumber = $BuildNumber; executionId = $ExecutionId; host = $env:COMPUTERNAME }
      builtUtc = [DateTime]::UtcNow.ToString('o')
    }
    $contextPath = Join-Path $buildEvidence 'release-context.json'
    $contextSha = Write-StageJson -Path $contextPath -Object $context
    $null = Write-StageJson -Path (Join-Path $buildEvidence 'Experimental.json') -Object ([ordered]@{ success = $true; stage = 'Experimental'; buildId = $BuildMasterBuildId; contextSha256 = $contextSha.ToLowerInvariant(); bundleSha256 = $bundleSha; feed = $ExperimentalFeed; feedState = $feedState })

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Built, signed and $feedState : $ProductId $ReleaseVersion ($bundleSha) on $ExperimentalFeed; context $contextPath"
    [pscustomobject]@{
      Succeeded = $true; ProductId = $ProductId; Version = $ReleaseVersion; SourceCommit = $sourceCommit; SourceTag = $SourceTag
      Signer = $signer; SignedBy = "$env:USERDOMAIN\$env:USERNAME"; SignedCount = $signing.SignedCount
      PublishRoot = $publishRoot; SignedRoot = $signedRoot; BundlePath = $bundlePath; BundleSha256 = $bundleSha
      Feed = $ExperimentalFeed; FeedState = $feedState; ContextPath = $contextPath; ContextSha256 = $contextSha; EvidenceRoot = $buildEvidence
    }
  }

  END { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Leaving $fn" }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  $ErrorActionPreference = 'Stop'
  $ConfirmPreference = 'None'
  Import-Module PSFramework -ErrorAction Stop
  try {
    # BuildMaster runs this with -NoProfile: bootstrap $global:settings from the ATAP.Utilities
    # worktree exactly as the other stage runners do, so Get-SecretATAP can resolve the vault.
    if ([string]::IsNullOrWhiteSpace($BuildToolingModulePath)) { throw 'BuildToolingModulePath is required.' }
    $bootstrapRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $BuildToolingModulePath))
    . (Join-Path -Path $PSScriptRoot -ChildPath 'BuildMasterRunContext.Common.ps1')
    Initialize-LocalHostSettings -SourcePath $bootstrapRoot
    $bound = @{}
    foreach ($name in $PSBoundParameters.Keys) { $bound[$name] = $PSBoundParameters[$name] }
    if ($bound.ContainsKey('ExpectedTestsPassed')) { $bound['ExpectedTestsPassed'] = [int]$bound['ExpectedTestsPassed'] }
    $result = Invoke-ApplicationBuildMasterStage @bound -Confirm:$false
    $result | ConvertTo-Json -Depth 6
    exit 0
  } catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    [Console]::Error.WriteLine($_.ScriptStackTrace)
    exit 1
  }
}
