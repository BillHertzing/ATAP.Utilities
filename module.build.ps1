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

  # Local source validation may skip signing only when publication is skipped.
  [switch] $SkipSigning,

  # Public identity of the code-signing certificate. The private key remains in
  # the Windows certificate store and is never passed to the build.
  [string] $CodeSigningCertificateThumbprint,

  # Authenticode timestamp service used for durable signatures.
  [uri] $TimestampServerUri,

  # Folder containing the PowerShell module being built (must hold <Name>.psm1
  # and <Name>.psd1 whose BaseName matches the folder name). Defaults to
  # $BuildRoot for legacy callers that symlink module.build.ps1 into the module
  # folder. Modern callers (Invoke-ModuleBuildWithRetry) pass this explicitly so
  # the source-of-truth module.build.ps1 at the repo root can resolve the right
  # module per invocation.
  [string] $ModuleRoot,

  # Optional approved family member name. When supplied, ModuleRoot is resolved
  # from the checked-in ModuleFamily.psd1 metadata under this repository's src/.
  [string] $ModuleName,

  # Optional generated output root override. When omitted, Resolve-PSModuleMetadata
  # supplies the legacy shared '<RepoRoot>/_generated/psmodules/<ModuleName>/' path.
  # BuildMaster passes a build-id scoped path to avoid concurrent runs sharing a
  # package staging directory.
  [string] $OutputRoot
)

# Load helper functions
# None of this is needed once the modules are built and installed into the psmodulepath, but while we are still running from source code, we need to dot source the helper functions that are not yet in a module. Once the modules are built and installed, all of the helper functions will be available as cmdlets and this block can be removed.
$helpfunctionsneeded = @(
  @{FunctionName = 'Get-RepositoryRoot'; ModuleName = 'ATAP.Utilities.BuildTooling.PowerShell' },
  @{FunctionName = 'Get-ParameterValueFromNeoConfigurationRoot'; ModuleName = 'ATAP.Utilities.PowerShell' }
  #  @{FunctionName = 'Get-ClonedAndModifiedHashtable'; ModuleName = 'ATAP.Utilities.PowerShell' },
)
$resolvedModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'src'
# Source builds must make sibling family modules discoverable while
# Test-ModuleManifest validates RequiredModules. This is process-local and does
# not install or persist any module.
$script:_originalPSModulePath = $env:PSModulePath
$modulePathEntries = @($env:PSModulePath -split [IO.Path]::PathSeparator)
if ($resolvedModulePath -notin $modulePathEntries) {
  $env:PSModulePath = $resolvedModulePath + [IO.Path]::PathSeparator + $env:PSModulePath
}
foreach ($helpfunction in $helpfunctionsneeded) {
  $helperPath = Join-Path -Path $resolvedModulePath -ChildPath (Join-Path -Path $helpfunction.ModuleName -ChildPath (Join-Path -Path 'public' -ChildPath "$($helpfunction.FunctionName).ps1"))
  try {
    if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
      throw "Source helper file not found: $helperPath"
    }
    . $helperPath
  } catch {
    $errorMessage = "Failed to load $($helpfunction.FunctionName) function from source path $helperPath. Exception: $($_.Exception.Message)"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
    throw
  }
}
# This is the end of the help loading block, this and all above can be removed once module autoloading is working and the helper functions are available as cmdlets in the psmodulepath


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
  'Set-PSModuleFileSignature'
  'Test-PSModulePackageSignature'
  'Compress-PSModuleArtifacts'
)

# BuildTooling may already be installed or imported, but bootstrap builds must use
# the functions in this source worktree. Dot-source them every time so stale
# session definitions cannot leak into the package being built.
$script:_bootstrapModuleByCommand = @{
  'Resolve-PSModuleMetadata' = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
  'Get-PSModuleVersionFromNBGV' = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
  'Build-PSModuleManifest' = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
  'Build-PSModulePsm1' = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
  'Invoke-PSModulePSScriptAnalyzer' = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
  'Compress-PSModuleArtifacts' = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
  'Test-FailureAcknowledgedGate' = 'ATAP.Utilities.BuildTooling.AiRendering.PowerShell'
  'Publish-PSModuleToProGetFeed' = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
  'Set-PSModuleFileSignature' = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
  'Test-PSModulePackageSignature' = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
}

foreach ($cmdletName in $script:_bootstrapCmdlets) {
  $bootstrapModuleName = if ($script:_bootstrapModuleByCommand.ContainsKey($cmdletName)) {
    $script:_bootstrapModuleByCommand[$cmdletName]
  } else {
    'ATAP.Utilities.BuildTooling.PowerShell'
  }
  $bootstrapPublicDir = Join-Path -Path $resolvedModulePath -ChildPath (
    Join-Path -Path $bootstrapModuleName -ChildPath 'public'
  )
  $candidatePath = Join-Path $bootstrapPublicDir "$cmdletName.ps1"
  if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
    . $candidatePath
  } else {
    throw "Bootstrap cmdlet '$cmdletName' not found at '$candidatePath'."
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
  if (-not [string]::IsNullOrWhiteSpace($ModuleName) -and -not [string]::IsNullOrWhiteSpace($ModuleRoot)) {
    throw 'Specify either ModuleName or ModuleRoot, not both.'
  }
  if (-not [string]::IsNullOrWhiteSpace($ModuleName)) {
    $familyPath = Join-Path $PSScriptRoot 'ModuleFamily.psd1'
    if (-not (Test-Path -LiteralPath $familyPath -PathType Leaf)) {
      throw "ModuleFamily.psd1 was not found at '$familyPath'."
    }
    $family = Import-PowerShellDataFile -LiteralPath $familyPath
    if (@($family.Members | Where-Object { $_.Name -eq $ModuleName }).Count -ne 1) {
      throw "ModuleName '$ModuleName' is not an approved ModuleFamily member."
    }
    $script:EffectiveModuleRoot = Join-Path $PSScriptRoot (Join-Path 'src' $ModuleName)
  } elseif ([string]::IsNullOrEmpty($ModuleRoot)) {
    $script:EffectiveModuleRoot = $BuildRoot
  } else {
    $script:EffectiveModuleRoot = $ModuleRoot
  }

  # T-41: Resolve module metadata (read-only; OutputRoot is never created here)
  $script:meta = Resolve-PSModuleMetadata -StartPath $script:EffectiveModuleRoot
  $script:ModuleName = $script:meta.ModuleName
  $script:ModuleRoot = $script:meta.ModuleRoot
  $script:RepoRoot = $script:meta.RepoRoot
  $candidateFamilyPath = Join-Path $PSScriptRoot 'ModuleFamily.psd1'
  $script:ModuleFamilyPath = ''
  if (Test-Path -LiteralPath $candidateFamilyPath -PathType Leaf) {
    $candidateFamily = Import-PowerShellDataFile -LiteralPath $candidateFamilyPath
    if (@($candidateFamily.Members | Where-Object { $_.Name -eq $script:ModuleName }).Count -eq 1) {
      $script:ModuleFamilyPath = $candidateFamilyPath
    }
  }
  if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $script:OutputRoot = $script:meta.OutputRoot
  } else {
    $resolvedOutputRoot = if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
      [System.IO.Path]::GetFullPath($OutputRoot)
    } else {
      [System.IO.Path]::GetFullPath($OutputRoot, $script:RepoRoot)
    }
    $script:OutputRoot = ($resolvedOutputRoot -replace '\\', '/').TrimEnd('/')
  }

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
  $sourceManifestData = Import-PowerShellDataFile -LiteralPath $script:meta.ManifestPath
  [string[]] $physicalPublicFunctions = if (Test-Path $publicDir) {
    Get-ChildItem -Path $publicDir -Filter '*.ps1' -File |
      Select-Object -ExpandProperty BaseName
  } else { @() }
  # The parent BuildTooling module creates compatibility proxies for extracted
  # child-module commands in module.preamble.ps1. Those functions have no
  # physical public/*.ps1 files, so retain the source manifest's explicit
  # exports alongside the functions discovered from physical source files.
  [string[]] $publicFunctions = @(
    $physicalPublicFunctions
    $sourceManifestData.FunctionsToExport
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
    Sort-Object -Unique

  # Preserve aliases explicitly declared in the source manifest, then add aliases
  # declared by [Alias()] on each matching public function. Set-Alias/New-Alias
  # command sites inside function bodies are runtime implementation details, not
  # module export metadata, and must never be promoted into AliasesToExport.
  [string[]] $sourceAliases = @(
    $sourceManifestData.AliasesToExport |
      Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
  )

  [string[]] $functionAliases = if (Test-Path $publicDir) {
    $collected = foreach ($ps1 in (Get-ChildItem -Path $publicDir -Filter '*.ps1' -File)) {
      $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $ps1.FullName, [ref]$null, [ref]$null)

      $matchingFunctions = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq $ps1.BaseName
      }, $false)

      foreach ($functionAst in $matchingFunctions) {
        if ($null -eq $functionAst.Body.ParamBlock) {
          continue
        }
        $aliasAttributes = @(
          $functionAst.Body.ParamBlock.Attributes |
            Where-Object { $_.TypeName.Name -eq 'Alias' }
        )
        foreach ($attribute in $aliasAttributes) {
          foreach ($argument in $attribute.PositionalArguments) {
            if (-not [string]::IsNullOrWhiteSpace([string]$argument.Value)) {
              $argument.Value
            }
          }
        }
      }
    }
    @($sourceAliases + $collected | Where-Object { $_ } | Select-Object -Unique)
  } else {
    $sourceAliases
  }

  Build-PSModuleManifest `
    -SourceManifestPath $script:meta.ManifestPath `
    -OutputManifestPath $script:GeneratedManifestPath `
    -ModuleVersion $script:verInfo.ModuleVersion `
    -Prerelease $script:verInfo.Prerelease `
    -ModuleRoot $script:ModuleRoot `
    -ModuleFamilyPath $script:ModuleFamilyPath `
    -PublicFunctions $publicFunctions `
    -Aliases $functionAliases

  Write-PSFMessage -Level Important -Message `
    "BuildManifest — wrote '$($script:GeneratedManifestPath)'  v$($script:verInfo.FullNuGetVersion)"
}

# ---------------------------------------------------------------------------
# Stream E  StageContent — copy optional static payload before signing.
# ---------------------------------------------------------------------------
Task StageContent BuildPSM1, BuildManifest, {
  $moduleContentDirectories = @('scripts', 'Documentation', 'Profiles', 'CertificateRequestConfigurations')
  foreach ($contentDirectoryName in $moduleContentDirectories) {
    $sourceContentDirectory = Join-Path $script:ModuleRoot $contentDirectoryName
    if (Test-Path -LiteralPath $sourceContentDirectory -PathType Container) {
      Copy-Item -LiteralPath $sourceContentDirectory -Destination $script:PackageSrcDir `
        -Recurse -Force -ErrorAction Stop
    }
  }

  Write-PSFMessage -Level Important -Message 'StageContent — copied optional static module payload.'
}

# ---------------------------------------------------------------------------
# Stream E  Sign — Authenticode-sign the exact staged files that are packed.
# ---------------------------------------------------------------------------
Task Sign StageContent, {
  if ($SkipSigning) {
    if (-not $SkipPublish) {
      throw '-SkipSigning is permitted only with -SkipPublish. Published packages must be signed.'
    }
    Write-PSFMessage -Level Important -Message 'Sign — skipped for a local non-publishing build.'
    return
  }

  $effectiveThumbprint = $CodeSigningCertificateThumbprint
  if ([string]::IsNullOrWhiteSpace($effectiveThumbprint)) {
    $effectiveThumbprint = [Environment]::GetEnvironmentVariable(
      'ATAP_CODESIGNING_CERTIFICATE_THUMBPRINT',
      [EnvironmentVariableTarget]::User
    )
  }
  if ([string]::IsNullOrWhiteSpace($effectiveThumbprint)) {
    throw 'A CodeSigningCertificateThumbprint or User-scope ATAP_CODESIGNING_CERTIFICATE_THUMBPRINT is required.'
  }

  $effectiveTimestampServerUri = $TimestampServerUri
  if ($null -eq $effectiveTimestampServerUri) {
    $timestampValue = [Environment]::GetEnvironmentVariable(
      'ATAP_CODESIGNING_TIMESTAMP_SERVER_URI',
      [EnvironmentVariableTarget]::User
    )
    if (-not [string]::IsNullOrWhiteSpace($timestampValue)) {
      $effectiveTimestampServerUri = [uri]$timestampValue
    }
  }
  if ($null -eq $effectiveTimestampServerUri -or -not $effectiveTimestampServerUri.IsAbsoluteUri) {
    throw 'An absolute TimestampServerUri or User-scope ATAP_CODESIGNING_TIMESTAMP_SERVER_URI is required.'
  }

  $signingWorkerPath = Join-Path $resolvedModulePath 'ATAP.Utilities.BuildTooling.ProGet.PowerShell\scripts\Invoke-PSModuleFileSigningWorker.ps1'
  if (-not (Test-Path -LiteralPath $signingWorkerPath -PathType Leaf)) {
    throw "The Authenticode signing worker was not found at '$signingWorkerPath'."
  }
  $workerOutput = @(& pwsh -File $signingWorkerPath `
      -Path $script:PackageSrcDir `
      -CertificateThumbprint $effectiveThumbprint `
      -TimestampServerUri $effectiveTimestampServerUri.AbsoluteUri 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "Authenticode signing worker failed: $($workerOutput -join [Environment]::NewLine)"
  }
  $resultLine = $workerOutput | Where-Object { [string]$_ -like 'ATAP_SIGNING_RESULT:*' } | Select-Object -Last 1
  if ($null -eq $resultLine) {
    throw 'Authenticode signing worker did not return structured signing metadata.'
  }
  $script:SigningResult = ([string]$resultLine).Substring('ATAP_SIGNING_RESULT:'.Length) | ConvertFrom-Json
  Write-PSFMessage -Level Important -Message "Sign — signed $($script:SigningResult.SignedCount) staged PowerShell files."
}

# ---------------------------------------------------------------------------
# T-43  Package — produce a .nupkg under _generated/…/packages/
# ---------------------------------------------------------------------------
Task Package Sign, {
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
  if (-not $SkipSigning) {
    $signatureResultsPath = Join-Path $script:OutputRoot 'signature-verification'
    $script:PackageSignatureResult = Test-PSModulePackageSignature `
      -NupkgPath $script:NupkgPath `
      -ResultsPath $signatureResultsPath `
      -RequireTimestamp
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
  $env:PSModulePath = $script:_originalPSModulePath
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
