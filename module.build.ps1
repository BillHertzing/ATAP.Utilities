# module.build.ps1 — 5-Tier PowerShell module build script (Invoke-Build)
# Canonical source: SharedVSCode repository; symlinked into every PS module folder
# via Set-WorktreeJunctions.  See 5Tier Implementation plan.md for the full spec.

param(
  # The publish tier for this build.
  [ValidateSet('Sprint', 'Alpha', 'Beta', 'QA', 'Production')]
  [string] $Tier = 'Alpha',

  # Build configuration forwarded to downstream tools.
  [string] $Configuration = 'Debug',

  # When set the Publish task logs the plan but does not push to ProGet (T-44).
  [switch] $SkipPublish,

  # Folder containing the PowerShell module being built (must hold <Name>.psm1
  # and <Name>.psd1 whose BaseName matches the folder name). Defaults to
  # $BuildRoot for legacy callers that symlink module.build.ps1 into the module
  # folder. Modern callers (Invoke-ModuleBuildWithRetry) pass this explicitly so
  # the source-of-truth module.build.ps1 at the repo root can resolve the right
  # module per invocation.
  [string] $ModuleRoot
)

# ---------------------------------------------------------------------------
# Bootstrap — dot-source required cmdlets when the BuildTooling module is not
# yet installed (e.g. when building the module itself for the first time).
# ---------------------------------------------------------------------------
$script:_bootstrapCmdlets = @(
  'Resolve-PSModuleMetadata'
  'Get-PSModuleVersionFromNBGV'
  'Build-PSModuleManifest'
  'Build-PSModulePsm1'
  'Invoke-PSModulePesterTests'
  'Invoke-PSModulePSScriptAnalyzer'
  'Test-FailureAcknowledgedGate'
  'Test-CodeCoverageGate'
  'Publish-PSModuleToProGetFeed'
  'Compress-PSModuleArtifacts'
)

# HARDCODED: BuildTooling module is not yet installed; dot-source any missing
# bootstrap cmdlet from the sprint-branch worktree's BuildTooling public folder.
# Replace with proper module install / Import-Module once the BuildTooling module
# is publishable from this build pipeline.
$script:_bootstrapPublicDir = `
  'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.BuildTooling.PowerShell\public'

foreach ($cmdletName in $script:_bootstrapCmdlets) {
  if (-not (Get-Command $cmdletName -ErrorAction SilentlyContinue)) {
    $candidatePath = Join-Path $script:_bootstrapPublicDir "$cmdletName.ps1"
    if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
      . $candidatePath
    } else {
      throw "Bootstrap cmdlet '$cmdletName' not found at '$candidatePath'."
    }
  }
}

# Script-scope list of PSResource repositories temporarily removed by the HermeticFeed
# task (T3/T4 only). Exit-Build restores them whether the build succeeds or fails.
$script:_savedHermeticRepos = @()

# ---------------------------------------------------------------------------
# Enter-Build — resolve all metadata and set script-scope variables
# ---------------------------------------------------------------------------
Enter-Build {
  # Resolve effective module root: explicit -ModuleRoot wins; otherwise fall
  # back to $BuildRoot (legacy symlink-into-module-folder layout).
  if ([string]::IsNullOrEmpty($ModuleRoot)) {
    $script:EffectiveModuleRoot = $BuildRoot
  } else {
    $script:EffectiveModuleRoot = $ModuleRoot
  }

  # T-41: Resolve module metadata (read-only; OutputRoot is never created here)
  $script:meta = Resolve-PSModuleMetadata -StartPath $script:EffectiveModuleRoot
  $script:ModuleName = $script:meta.ModuleName
  $script:ModuleRoot = $script:meta.ModuleRoot
  $script:RepoRoot = $script:meta.RepoRoot
  $script:OutputRoot = $script:meta.OutputRoot

  # T-42: Resolve NBGV-derived version once per build
  $script:verInfo = Get-PSModuleVersionFromNBGV -ModuleRoot $script:ModuleRoot

  # Derived output sub-directory paths (T-41, T-43, T-45, T-46, T-48, T-49)
  $script:PackagesDir = Join-Path $script:OutputRoot 'packages'
  $script:PackageSrcDir = Join-Path $script:PackagesDir $script:ModuleName
  $script:TestResultsDir = Join-Path $script:OutputRoot 'test-results'
  $script:CoverageDir = Join-Path $script:OutputRoot 'coverage'
  $script:ArtifactsDir = Join-Path $script:OutputRoot 'artifacts'

  # Derived file paths
  $script:GeneratedPsm1Path = Join-Path $script:PackageSrcDir "$($script:ModuleName).psm1"
  $script:GeneratedManifestPath = Join-Path $script:PackageSrcDir "$($script:ModuleName).psd1"
  $script:TestResultsXmlPath = Join-Path $script:TestResultsDir 'TestResults.xml'
  $script:CoverageXmlPath = Join-Path $script:CoverageDir 'Coverage.xml'
  $script:AnalyzerResultsPath = Join-Path $script:TestResultsDir 'PSScriptAnalyzerResults.xml'
  $script:AcknowledgedFilePath = Join-Path $script:ModuleRoot 'FailureAcknowledged.json'
  $script:BuildSummaryPath = Join-Path $script:ArtifactsDir 'BuildSummary.json'

  # Populated by the Package task; consumed by the Publish task
  $script:NupkgPath = $null

  # Runtime placeholders for gate results (T-46, T-49)
  $script:TestResult = $null
  $script:AnalyzerResult = $null
  $script:GateAckResult = $null
  $script:GateCoverageResult = $null

  # Ensure output directories exist (idempotent)
  foreach ($dirPath in @($script:PackageSrcDir, $script:TestResultsDir, $script:CoverageDir, $script:ArtifactsDir)) {
    if (-not (Test-Path -Path $dirPath -PathType Container)) {
      $null = New-Item -ItemType Directory -Force -Path $dirPath
    }
  }

  Write-PSFMessage -Level Important -Message `
    "Enter-Build — $($script:ModuleName) v$($script:verInfo.FullNuGetVersion)  Tier=$Tier  OutputRoot=$($script:OutputRoot)"
}

# ---------------------------------------------------------------------------
# T-47  Task chains
# ---------------------------------------------------------------------------

# Default task — fast inner loop: build PSM1 + manifest + package
Task . Short

# Short — quick build without any test or quality gates
Task Short BuildPSM1, BuildManifest, Package

# Verify — full quality-gate chain (no publish, no compression)
# HermeticFeed is a no-op at Sprint / Alpha / Production; at Beta and QA it
# removes all powershellget-* repos except the tier-appropriate one so that
# no test or dependency can fall back to a lower-tier feed.
Task Verify Short, HermeticFeed, Test, Analyze, GateAck, GateCoverage, BuildSummary

# All — verify, then compress artifacts and publish
Task All Verify, Compress, Publish

# CI — alias for All, suitable for pipeline use
Task CI All

# Local — alias for Verify (local developer run, no publish)
Task Local Verify

# Clean — wipe the module's output tree under _generated/
Task Clean {
  if (Test-Path -Path $script:OutputRoot -PathType Container) {
    if ($script:OutputRoot -notmatch '[\\/]_generated[\\/]') {
      $msg = "OutputRoot '$($script:OutputRoot)' does not contain '_generated'; refusing to delete."
      Write-PSFMessage -Level Error -Message $msg
      throw $msg
    }
    Remove-Item -Recurse -Force -Path $script:OutputRoot
    Write-PSFMessage -Level Important -Message "Clean — removed '$($script:OutputRoot)'"
  } else {
    Write-PSFMessage -Level Important -Message "Clean — OutputRoot '$($script:OutputRoot)' does not exist; nothing to clean."
  }
}

# ---------------------------------------------------------------------------
# HermeticFeed — restrict PSResource repos to the tier-appropriate feed at
# Beta (T3) and QA (T4); no-op at Sprint, Alpha, and Production.
# Saved repos are restored by Exit-Build even if the build fails mid-way.
# ---------------------------------------------------------------------------
Task HermeticFeed {
  $script:_savedHermeticRepos = @()

  # Map: only Beta and QA require feed isolation
  $tierFeedMap = @{
    'Beta' = 'powershellget-integration'
    'QA'   = 'powershellget-qa'
  }

  if (-not $tierFeedMap.ContainsKey($Tier)) {
    Write-PSFMessage -Level Important -Message `
      "HermeticFeed — Tier=$Tier does not require feed isolation; no repositories changed."
    return
  }

  $targetFeed = $tierFeedMap[$Tier]

  # Save and unregister all powershellget-* repos other than the tier-appropriate one
  $otherRepos = Get-PSResourceRepository -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'powershellget-*' -and $_.Name -ne $targetFeed }

  foreach ($repo in $otherRepos) {
    $script:_savedHermeticRepos += [PSCustomObject]@{
      Name    = $repo.Name
      Uri     = [string]$repo.Uri
      Trusted = [bool]$repo.Trusted
    }
    Unregister-PSResourceRepository -Name $repo.Name -ErrorAction SilentlyContinue
    Write-PSFMessage -Level Important -Message `
      "HermeticFeed — unregistered '$($repo.Name)' to isolate feed for Tier=$Tier."
  }

  Write-PSFMessage -Level Important -Message `
    "HermeticFeed — Tier=$Tier  TargetFeed=$targetFeed  RemovedCount=$($script:_savedHermeticRepos.Count)"
}

# ---------------------------------------------------------------------------
# T-40 / T-43  BuildPSM1 — concatenate source .ps1 files into a single .psm1
# ---------------------------------------------------------------------------
Task BuildPSM1 {
  Build-PSModulePsm1 `
    -ModuleRoot $script:ModuleRoot `
    -OutputPath $script:GeneratedPsm1Path
  Write-PSFMessage -Level Important -Message "BuildPSM1 — wrote '$($script:GeneratedPsm1Path)'"
}

# ---------------------------------------------------------------------------
# T-42  BuildManifest — copy source .psd1 to package staging and stamp NBGV version + exports
# ---------------------------------------------------------------------------
Task BuildManifest {
  $publicDir = Join-Path $script:ModuleRoot 'public'
  [string[]] $publicFunctions = if (Test-Path $publicDir) {
    Get-ChildItem -Path $publicDir -Filter '*.ps1' -File |
      Select-Object -ExpandProperty BaseName
  } else { @() }

  Build-PSModuleManifest `
    -SourceManifestPath $script:meta.ManifestPath `
    -OutputManifestPath $script:GeneratedManifestPath `
    -ModuleVersion $script:verInfo.ModuleVersion `
    -Prerelease $script:verInfo.Prerelease `
    -PublicFunctions $publicFunctions

  Write-PSFMessage -Level Important -Message `
    "BuildManifest — wrote '$($script:GeneratedManifestPath)'  v$($script:verInfo.FullNuGetVersion)"
}

# ---------------------------------------------------------------------------
# T-43  Package — produce a .nupkg under _generated/…/packages/
# ---------------------------------------------------------------------------
Task Package BuildPSM1, BuildManifest, {
  $localRepoName = "LocalBuild_$($script:ModuleName)"
  $localRepoUri = $script:PackagesDir

  # Ensure no stale registration from a previous failed build
  if (Get-PSResourceRepository -Name $localRepoName -ErrorAction SilentlyContinue) {
    Unregister-PSResourceRepository -Name $localRepoName -ErrorAction SilentlyContinue
  }
  Register-PSResourceRepository -Name $localRepoName -Uri $localRepoUri -Trusted

  try {
    Publish-PSResource `
      -Path $script:PackageSrcDir `
      -Repository $localRepoName `
      -SkipDependenciesCheck `
      -Confirm:$false
  } finally {
    Unregister-PSResourceRepository -Name $localRepoName -ErrorAction SilentlyContinue
  }

  # Record the .nupkg path for the Publish task
  $script:NupkgPath = Get-ChildItem -Path $script:PackagesDir -Filter '*.nupkg' -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 -ExpandProperty FullName

  if (-not $script:NupkgPath) {
    throw "Package — no .nupkg found under '$($script:PackagesDir)' after Publish-PSResource."
  }
  Write-PSFMessage -Level Important -Message "Package — created '$($script:NupkgPath)'"
}

# ---------------------------------------------------------------------------
# T-44  Publish — push the .nupkg to the tier-appropriate ProGet feed
# ---------------------------------------------------------------------------
Task Publish Package, {
  if ($SkipPublish) {
    Write-PSFMessage -Level Important -Message `
      "Publish — -SkipPublish set; would push '$($script:NupkgPath)' to Tier=$Tier (skipped)."
    return
  }

  $result = Publish-PSModuleToProGetFeed -NupkgPath $script:NupkgPath -Tier $Tier
  Write-PSFMessage -Level Important -Message "Publish — $($result.ResponseSummary)  Feed=$($result.FeedName)"
}

# ---------------------------------------------------------------------------
# T-45  Test — run Pester with tier-appropriate tag filters
# ---------------------------------------------------------------------------
Task Test {
  $script:TestResult = Invoke-PSModulePesterTests `
    -ModuleRoot $script:ModuleRoot `
    -Tier $Tier `
    -OutputPath $script:TestResultsXmlPath `
    -CoverageOutputPath $script:CoverageXmlPath

  Write-PSFMessage -Level Important -Message `
    "Test — Passed=$($script:TestResult.PassedCount)  Failed=$($script:TestResult.FailedCount)  GatePass=$($script:TestResult.GatePass)"
}

# ---------------------------------------------------------------------------
# T-46  Analyze, GateAck, GateCoverage
# ---------------------------------------------------------------------------

Task Analyze {
  $script:AnalyzerResult = Invoke-PSModulePSScriptAnalyzer `
    -Path $script:ModuleRoot `
    -Tier $Tier `
    -OutputPath $script:AnalyzerResultsPath

  Write-PSFMessage -Level Important -Message `
    "Analyze — Errors=$($script:AnalyzerResult.ErrorCount)  Warnings=$($script:AnalyzerResult.WarningCount)  GatePass=$($script:AnalyzerResult.GatePass)"

  if (-not $script:AnalyzerResult.GatePass) {
    throw "Analyze gate failed: $($script:AnalyzerResult.ErrorCount) error(s), $($script:AnalyzerResult.WarningCount) warning(s) at Tier=$Tier."
  }
}

Task GateAck Test, {
  $script:GateAckResult = Test-FailureAcknowledgedGate `
    -ResultFile $script:TestResultsXmlPath `
    -AcknowledgedFile $script:AcknowledgedFilePath `
    -Tier $Tier

  Write-PSFMessage -Level Important -Message `
    "GateAck — Passed=$($script:GateAckResult.Passed)  Failed=$($script:GateAckResult.Failed)  Acknowledged=$($script:GateAckResult.Acknowledged)  GatePass=$($script:GateAckResult.GatePass)"

  if (-not $script:GateAckResult.GatePass) {
    throw "GateAck failed: $($script:GateAckResult.Unacknowledged) unacknowledged failure(s) at Tier=$Tier."
  }
}

Task GateCoverage Test, {
  $script:GateCoverageResult = Test-CodeCoverageGate `
    -CoverageFile $script:CoverageXmlPath `
    -Tier $Tier

  Write-PSFMessage -Level Important -Message `
    "GateCoverage — Coverage=$($script:GateCoverageResult.CoveragePct)%  Threshold=$($script:GateCoverageResult.Threshold)%  GatePass=$($script:GateCoverageResult.GatePass)  Skipped=$($script:GateCoverageResult.Skipped)"

  if (-not $script:GateCoverageResult.GatePass) {
    throw "GateCoverage failed: $($script:GateCoverageResult.CoveragePct)% below threshold $($script:GateCoverageResult.Threshold)% at Tier=$Tier."
  }
}

# ---------------------------------------------------------------------------
# T-49  BuildSummary — write a structured JSON summary after all gates pass
# ---------------------------------------------------------------------------
Task BuildSummary GateAck, GateCoverage, {
  $commitSha = (& git -C $script:RepoRoot rev-parse --short HEAD 2>&1)
  if ($LASTEXITCODE -ne 0) { $commitSha = 'unknown' }

  $summary = [ordered]@{
    Version      = $script:verInfo.FullNuGetVersion
    Tier         = $Tier
    CommitSha    = [string]$commitSha
    Passed       = $script:GateAckResult.Passed
    Failed       = $script:GateAckResult.Failed
    Acknowledged = $script:GateAckResult.Acknowledged
    CoveragePct  = $script:GateCoverageResult.CoveragePct
  }

  $null = New-Item -ItemType Directory -Force -Path $script:ArtifactsDir
  $summary | ConvertTo-Json -Depth 3 | Set-Content -Path $script:BuildSummaryPath -Encoding UTF8

  Write-PSFMessage -Level Important -Message `
    "BuildSummary — v$($summary.Version)  Tier=$($summary.Tier)  Passed=$($summary.Passed)  Failed=$($summary.Failed)  Ack=$($summary.Acknowledged)  Cov=$($summary.CoveragePct)%"
}

# ---------------------------------------------------------------------------
# T-48  Compress — archive test-results, coverage, and packages into .7z files
# ---------------------------------------------------------------------------
Task Compress {
  Compress-PSModuleArtifacts -OutputRoot $script:OutputRoot
  Write-PSFMessage -Level Important -Message "Compress — artifacts archived under '$($script:ArtifactsDir)'"
}

# ---------------------------------------------------------------------------
# Exit-Build — restore any PSResource repositories removed by HermeticFeed.
# Runs after every build (success or failure) as long as Invoke-Build invoked
# this script.
# ---------------------------------------------------------------------------
Exit-Build {
  foreach ($repo in $script:_savedHermeticRepos) {
    if (-not (Get-PSResourceRepository -Name $repo.Name -ErrorAction SilentlyContinue)) {
      try {
        Register-PSResourceRepository -Name $repo.Name -Uri $repo.Uri -Trusted:$repo.Trusted
        Write-PSFMessage -Level Important -Message "Exit-Build — restored PSResource repository '$($repo.Name)'."
      } catch {
        Write-PSFMessage -Level Warning -Message `
          "Exit-Build — could not restore repository '$($repo.Name)': $($_.Exception.Message)"
      }
    }
  }
}
