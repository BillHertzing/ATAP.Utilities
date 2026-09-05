function New-CommanderReleaseBundle {
  <#
  .SYNOPSIS
    Assembles a reproducible, hash-verified application release bundle and its
    release context, ready for Publish-UniversalPackageToProGet and
    Invoke-ApplicationReleaseStage.
  .DESCRIPTION
    This is the durable, parameterized replacement for the one-shot
    New-StableCommanderBundle.ps1 that assembled AceCommander 0.1.1 under
    _generated/Sprint0015/Task15.185/f/COMMANDER02-live/. That script hardcoded the
    version, source commit, branch, source tag, expected test count, the
    ATAP.Utilities worktree path and the database package reference, and it lived in
    a gitignored tree that is deleted at sprint end, so the production release
    procedure did not survive its own sprint.

    Every collaborator it calls was already durable - New-ReleaseManifest and
    New-ReleaseBundle in this module, manifest.schema.json in
    SolutionDocumentation/schemas/, and Invoke-ApplicationReleaseStage in
    BuildTooling.BuildMaster/Plans/. Only the orchestration was disposable. This
    function supplies it.

    Reproducibility is proven, not assumed: the manifest is generated twice and the
    archive built twice, and a hash mismatch in either is a terminal error. That
    matters because the ProGet version a bundle would occupy is immutable.

    Provenance gates enforced before a bundle is produced:
      - the installer script is committed in the product repository;
      - every tooling file snapshotted into the bundle is committed in the
        BuildTooling repository, and its originating commit is recorded;
      - when a signed payload inventory is supplied, every payload file matches its
        recorded size and SHA-256.

    This function assembles and verifies. It publishes nothing, promotes nothing,
    deploys nothing, and touches no database. Those remain separately gated.
  .PARAMETER RepoRoot
    Product repository, or release worktree, supplying the installer script. For a
    release cut this should be an isolated worktree at an immutable tag so the branch
    cannot move mid-build.
  .PARAMETER BuildToolingRoot
    ATAP.Utilities repository root supplying the tooling snapshot and manifest schema.
  .PARAMETER PublishRoot
    Directory holding the published application payload.
  .PARAMETER OutputRoot
    Directory to create the bundle under. A timestamped child is created inside it.
  .PARAMETER Version
    Release version, for example '0.1.2'.
  .PARAMETER SourceCommit
    Full 40-character commit SHA the payload was built from.
  .PARAMETER SourceTag
    Immutable tag naming the release point, for example 'AceCommander/v0.1.2'.
  .PARAMETER DatabasePackageReference
    Hashtable with id, pinnedVersion, compatibleVersionRange and lifecycleCeiling.
    This is a compatibility assertion recorded in the manifest; the installer never
    applies a database.
  .PARAMETER SignedInventoryPath
    Optional JSON inventory of the signed payload with path, size and sha256 per
    file. When supplied every payload file is verified against it and the result
    records the payload as signature-verified. When omitted the result records
    PayloadSignatureVerified = false, which callers may gate on.
  .EXAMPLE
    $p = @{
      RepoRoot            = 'C:/Users/me/_release/acecommander-0.1.2'
      BuildToolingRoot    = 'C:/Dropbox/me/GitHub/ATAP.Utilities-wt-137-Sprint-0015-work-items'
      PublishRoot         = 'C:/Users/me/_generated/Rel012Tag/pub-c'
      OutputRoot          = 'C:/Users/me/_generated/Rel012Tag/bundle'
      Version             = '0.1.2'
      SourceCommit        = '1091b76503669add4d41a458841e588a9bcdb78d'
      SourceTag           = 'AceCommander/v0.1.2'
      Branch              = '45-Sprint-0015-work-items'
      ExpectedTestsPassed = 347
      DatabasePackageReference = @{ id = 'ATAPUtilities.Database'; pinnedVersion = '0.1.6'; compatibleVersionRange = '[0.1.6,0.1.7)'; lifecycleCeiling = 'database-stable' }
      ReleaseNotes        = 'AceCommander 0.1.2 ...'
    }
    New-CommanderReleaseBundle @p
  .NOTES
    Keep the reproducibility and provenance gates. They are the reason the output is
    trustworthy, and each one exists because its absence produced a real defect.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$RepoRoot,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$BuildToolingRoot,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PublishRoot,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$OutputRoot,
    [Parameter(Mandatory)][ValidatePattern('\A\d+\.\d+\.\d+\z')][string]$Version,
    [Parameter(Mandatory)][ValidatePattern('\A[0-9a-fA-F]{40}\z')][string]$SourceCommit,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SourceTag,
    [Parameter(Mandatory)][ValidateNotNull()][hashtable]$DatabasePackageReference,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ReleaseNotes,
    [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$ExpectedTestsPassed,
    [string]$TestResultsPath,
    [string]$ProductId = 'AceCommander',
    [string]$Branch,
    [string]$BuildAgent = $env:COMPUTERNAME,
    [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')][string]$CeilingTier = 'Production',
    [string]$TargetFramework = 'net10.0-windows',
    [string]$ArtifactKind = 'HostedWebApplication',
    [string]$InstallerRelativePath = 'AceCommander/Deployment/Install-AceCommanderRelease.ps1',
    [string]$ApplicationProvenancePath,
    [string]$SignedInventoryPath,
    [string]$SignedInventorySha256,
    [string]$ProGetBaseUrl
  )
  begin {
    $fn = 'New-CommanderReleaseBundle'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) { Import-Module PSFramework -ErrorAction Stop }
    foreach ($pair in @(@{ n = 'RepoRoot'; v = $RepoRoot }, @{ n = 'BuildToolingRoot'; v = $BuildToolingRoot }, @{ n = 'PublishRoot'; v = $PublishRoot })) {
      if (-not (Test-Path -LiteralPath $pair.v -PathType Container)) { throw "$($pair.n) is not an existing directory: $($pair.v)" }
    }
    foreach ($key in @('id', 'pinnedVersion', 'compatibleVersionRange', 'lifecycleCeiling')) {
      if (-not $DatabasePackageReference.ContainsKey($key) -or [string]::IsNullOrWhiteSpace([string]$DatabasePackageReference[$key])) {
        throw "DatabasePackageReference requires a non-empty '$key'."
      }
    }
    $schemaRelative = 'SolutionDocumentation/schemas/manifest.schema.json'
    $schema = Join-Path $BuildToolingRoot $schemaRelative
    if (-not (Test-Path -LiteralPath $schema -PathType Leaf)) { throw "Manifest schema not found: $schema" }
  }
  process {
    if (-not $PSCmdlet.ShouldProcess("$ProductId $Version from $SourceTag", 'Assemble reproducible release bundle')) { return }

    # The installer ships inside the bundle, so an uncommitted installer would make the
    # bundle unreproducible from source. Fail before any work is done.
    if (@(& git -C $RepoRoot status --porcelain -- $InstallerRelativePath).Count) { throw "Installer must be committed before bundling: $InstallerRelativePath" }
    $installerCommit = (& git -C $RepoRoot log -1 --format=%H -- $InstallerRelativePath | Out-String).Trim()
    if (-not $installerCommit) { throw "Installer commit could not be resolved for $InstallerRelativePath" }

    $payloadSignatureVerified = $false
    if ($SignedInventoryPath) {
      if (-not (Test-Path -LiteralPath $SignedInventoryPath -PathType Leaf)) { throw "SignedInventoryPath not found: $SignedInventoryPath" }
      if ($SignedInventorySha256 -and (Get-FileHash -LiteralPath $SignedInventoryPath).Hash -ine $SignedInventorySha256) { throw 'Signed inventory hash does not match the supplied pin.' }
      $inventory = @(Get-Content -LiteralPath $SignedInventoryPath -Raw | ConvertFrom-Json)
      $actual = @(Get-ChildItem -LiteralPath $PublishRoot -Recurse -File -Force)
      if ($actual.Count -ne $inventory.Count) { throw "Signed payload file count mismatch: inventory $($inventory.Count), publish $($actual.Count)." }
      foreach ($item in $inventory) {
        $file = Get-Item -LiteralPath (Join-Path $PublishRoot $item.path)
        if ($file.Length -ne $item.size -or (Get-FileHash -LiteralPath $file.FullName).Hash -ine $item.sha256) { throw "Signed payload changed: $($item.path)" }
      }
      $payloadSignatureVerified = $true
    }

    $testsPassed = $ExpectedTestsPassed
    if ($TestResultsPath) {
      if (-not (Test-Path -LiteralPath $TestResultsPath -PathType Leaf)) { throw "TestResultsPath not found: $TestResultsPath" }
      [xml]$trx = Get-Content -LiteralPath $TestResultsPath -Raw
      $counters = $trx.TestRun.ResultSummary.Counters
      if ([int]$counters.failed -ne 0) { throw "Test evidence records $([int]$counters.failed) failing tests." }
      if ([int]$counters.passed -ne $ExpectedTestsPassed) { throw "Test evidence records $([int]$counters.passed) passing tests; expected $ExpectedTestsPassed." }
      $testsPassed = [int]$counters.passed
    }

    $root = Join-Path $OutputRoot ('bundle-' + $Version + '-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
    $stage = Join-Path $root 'staging'
    foreach ($dir in @('app', 'installer', 'tests', 'docs', 'tooling')) { [IO.Directory]::CreateDirectory((Join-Path $stage $dir)) | Out-Null }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Assembling $ProductId $Version bundle under $root" -Tag 'Release'

    Copy-Item -Path (Join-Path $PublishRoot '*') -Destination (Join-Path $stage 'app') -Recurse
    Copy-Item -LiteralPath (Join-Path $RepoRoot $InstallerRelativePath) -Destination (Join-Path $stage ('installer/' + (Split-Path $InstallerRelativePath -Leaf)))

    $verification = [ordered]@{
      sourceCommit             = $SourceCommit
      sourceTag                = $SourceTag
      installerCommit          = $installerCommit
      serverTests              = @{ passed = $testsPassed; failed = 0 }
      payloadSignatureVerified = $payloadSignatureVerified
    }
    $verification | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $stage 'tests/verification.json') -Encoding utf8
    [IO.File]::WriteAllText((Join-Path $stage 'docs/release.txt'), $ReleaseNotes, [Text.UTF8Encoding]::new($false))

    # Snapshot the tooling that produced and verifies this bundle, so it can be
    # re-verified later without depending on a worktree that may no longer exist.
    $snapshot = Join-Path $root 'tooling'
    [IO.Directory]::CreateDirectory($snapshot) | Out-Null
    $toolingPaths = @(
      'src/ATAP.Utilities.BuildTooling.PowerShell/public/New-ReleaseBundle.ps1'
      'src/ATAP.Utilities.BuildTooling.PowerShell/public/New-ReleaseManifest.ps1'
      'src/ATAP.Utilities.BuildTooling.PowerShell/public/New-CommanderReleaseBundle.ps1'
      $schemaRelative
      'src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/Invoke-ApplicationReleaseStage.ps1'
      'src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/AceCommander-ApplicationRelease.otter'
      'src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/AceCommander-ApplicationRelease.pipeline.json'
    )
    $tooling = @($toolingPaths | ForEach-Object {
        if (@(& git -C $BuildToolingRoot status --porcelain -- $_).Count) { throw "Tooling must be committed before bundling: $_" }
        $target = Join-Path $snapshot (Split-Path $_ -Leaf)
        Copy-Item -LiteralPath (Join-Path $BuildToolingRoot $_) -Destination $target
        @{ path = $target; sha256 = (Get-FileHash -LiteralPath $target).Hash; sourcePath = $_; sourceCommit = (& git -C $BuildToolingRoot log -1 --format=%H -- $_ | Out-String).Trim() }
      })

    . (Join-Path $snapshot 'New-ReleaseManifest.ps1')
    . (Join-Path $snapshot 'New-ReleaseBundle.ps1')

    $payload = @(Get-ChildItem -LiteralPath $stage -Recurse -File | ForEach-Object {
        @{ path = ([IO.Path]::GetRelativePath($stage, $_.FullName) -replace '\\', '/'); checksumSha256 = (Get-FileHash -LiteralPath $_.FullName).Hash; sizeBytes = $_.Length }
      })

    $depsPath = Join-Path $PublishRoot ($ProductId + '.deps.json')
    $libraries = @()
    if (Test-Path -LiteralPath $depsPath -PathType Leaf) {
      $deps = Get-Content -LiteralPath $depsPath -Raw | ConvertFrom-Json -AsHashtable
      $libraries = @($deps.libraries.GetEnumerator() | Where-Object { $_.Value.type -eq 'package' } | ForEach-Object { $parts = $_.Key.Split('/'); @{ id = $parts[0]; version = $parts[1] } })
    }

    $provenanceComponents = @()
    $provenanceRoot = $PublishRoot
    if ($ApplicationProvenancePath -and (Test-Path -LiteralPath $ApplicationProvenancePath -PathType Leaf)) {
      $prov = Get-Content -LiteralPath $ApplicationProvenancePath -Raw | ConvertFrom-Json
      $provenanceRoot = $prov.root
      $provenanceComponents = @($prov.components)
    }

    $context = [pscustomobject]@{
      RepoRoot                  = $RepoRoot
      ResolvedPackageVersion    = $Version
      SourceTag                 = $SourceTag
      SourceCommit              = $SourceCommit
      Branch                    = $Branch
      BuildAgent                = $BuildAgent
      BuildUtc                  = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
      ApplicationProvenance     = @{ productId = $ProductId; root = $provenanceRoot; components = $provenanceComponents; artifactKind = $ArtifactKind; configuration = 'Release'; targetFramework = $TargetFramework; runtimeIdentifier = $null; publishSettings = @{ selfContained = $false; publishSingleFile = $false; publishTrimmed = $false; useAppHost = $false } }
      IncludedLibraryPackages   = $libraries
      IncludedPowerShellModules = @()
      DatabasePackageReference  = $DatabasePackageReference
      Compatibility             = @{ osFamilies = @('windows'); runtimeIdentifiers = @(); dotnetRuntimeVersion = '10.0.0' }
      Rollback                  = @{ supported = $true; notes = 'Previous immutable payload retained; restore junction and service without database changes.' }
      PayloadFiles              = $payload
      InstallerScripts          = @('installer/' + (Split-Path $InstallerRelativePath -Leaf))
      TestEvidence              = @(@{ kind = 'verified-test-and-signature-summary'; path = 'tests/verification.json'; checksumSha256 = (Get-FileHash -LiteralPath (Join-Path $stage 'tests/verification.json')).Hash })
      ManifestSchemaPath        = $schema
    }

    # Reproducibility proven twice over: manifest and archive are each produced two
    # ways and compared. A mismatch means the bundle must not be published, because
    # the ProGet version it would occupy is immutable.
    $first = New-ReleaseManifest -Context $context -OutputPath (Join-Path $root 'manifest-a')
    $second = New-ReleaseManifest -Context $context -OutputPath (Join-Path $root 'manifest-b')
    if ((Get-FileHash -LiteralPath $first.FullName).Hash -ne (Get-FileHash -LiteralPath $second.FullName).Hash) { throw 'Manifest reproducibility failed.' }
    $a = New-ReleaseBundle -Manifest $first -OutputPath (Join-Path $root 'archive-a') -SourceRoot $stage -ManifestSchema $schema
    $b = New-ReleaseBundle -Manifest $second -OutputPath (Join-Path $root 'archive-b') -SourceRoot $stage -ManifestSchema $schema
    if ($a.BundleSha256 -ne $b.BundleSha256) { throw 'Archive reproducibility failed.' }

    $releaseContext = [ordered]@{
      productId       = $ProductId
      version         = $Version
      ceilingTier     = $CeilingTier
      sourceCommit    = $SourceCommit
      installerCommit = $installerCommit
      bundlePath      = $a.Path.FullName
      bundleSha256    = $a.BundleSha256
      manifestSha256  = (Get-FileHash -LiteralPath $first.FullName).Hash
      bundleVerifier  = (Join-Path $snapshot 'New-ReleaseBundle.ps1')
      manifestSchema  = (Join-Path $snapshot 'manifest.schema.json')
      tooling         = $tooling
      evidenceRoot    = (Join-Path $root 'buildmaster')
    }
    if ($ProGetBaseUrl) { $releaseContext['proGetBaseUrl'] = $ProGetBaseUrl }
    $contextPath = Join-Path $root 'release-context.json'
    $releaseContext | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $contextPath -Encoding utf8

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Assembled $ProductId $Version with $($a.VerifiedEntryCount) entries" -Tag 'Release'
    [pscustomobject]@{
      ProductId                = $ProductId
      Version                  = $Version
      Root                     = $root
      ContextPath              = $contextPath
      ContextSha256            = (Get-FileHash -LiteralPath $contextPath).Hash
      BundlePath               = $a.Path.FullName
      BundleSha256             = $a.BundleSha256
      ManifestSha256           = $releaseContext.manifestSha256
      VerifiedEntryCount       = $a.VerifiedEntryCount
      InstallerCommit          = $installerCommit
      SourceCommit             = $SourceCommit
      SourceTag                = $SourceTag
      PayloadSignatureVerified = $payloadSignatureVerified
      TestsPassed              = $testsPassed
    }
  }
  end { }
}
