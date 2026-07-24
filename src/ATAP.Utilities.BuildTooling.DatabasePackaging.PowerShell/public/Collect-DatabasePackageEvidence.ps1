#Requires -Version 7.0
<#
.SYNOPSIS
    Collects every audit artifact for a database change package run into a
    single evidence folder and writes a summary `evidence-bundle.json`.

.DESCRIPTION
    Collect-DatabasePackageEvidence gathers every artifact that needs to be
    retained for a database change package run — manifest, content
    checksums, Flyway logs, seed loader logs, pre-migration snapshot
    evidence, Pester results, package digest, ProGet feed, actor, source
    commit SHA, and BuildMaster build id — into a single folder under
    `_generated/database-packages/<PackageId>.<Version>/evidence/`.

    Each known source file is copied into the evidence folder. Optional
    sources that are absent are recorded in the summary with a `$null`
    path rather than raising an error: the cmdlet's job is to capture
    what *did* exist for this run, not to enforce that every optional
    artifact must exist.

    The summary `evidence-bundle.json` enumerates every evidence key with
    the relative path of the captured file (or `$null` if the source was
    not present), along with the package digest, ProGet feed, actor,
    source commit SHA, BuildMaster build id, and a UTC capture timestamp.

.PARAMETER PackageId
    The database package id, e.g. `ATAPUtilities.Database`.

.PARAMETER Version
    The package version that produced this evidence, e.g. `1.5.0-experimental.42`.

.PARAMETER NupkgPath
    Path to the `.nupkg` artifact. Used both to compute the package
    digest and to copy the artifact into the evidence folder. Required.

.PARAMETER ManifestPath
    Optional path to `db-release-unit-manifest.json` extracted from the
    package. When present it is copied verbatim into the evidence folder.

.PARAMETER ContentChecksumsPath
    Optional path to a `package-evidence.json` file produced by
    `New-DatabaseChangePackage`. Contains content checksums for every
    file packed into the .nupkg.

.PARAMETER FlywayInfoOutputPath
    Optional path to captured `flyway info` output from the target
    database.

.PARAMETER FlywayMigrationLogPath
    Optional path to the Flyway migration log from the rehearsal run.

.PARAMETER SeedLoaderLogPath
    Optional path to the seed-loader log from the rehearsal run.

.PARAMETER PreMigrationSnapshotEvidencePath
    Optional path to the pre-migration snapshot evidence (written by
    DBA1's `New-DatabasePreMigrationSnapshot`). Absence means the
    snapshot step was skipped or not applicable.

.PARAMETER PesterResultsXmlPath
    Optional path to the Pester test result XML from the validation run.

.PARAMETER ProGetFeed
    The ProGet feed name where this package version was published.

.PARAMETER BuildMasterBuildId
    Optional BuildMaster build id; defaults to the value of the
    `BUILDMASTER_BUILD_ID` environment variable when omitted, or
    `(local)` when neither is set.

.PARAMETER OutputRoot
    Root folder beneath which the evidence folder is created. Defaults to
    `_generated/database-packages` under the repository root resolved from
    `$PSScriptRoot`.

.OUTPUTS
    [PSCustomObject] with:
      - EvidenceFolder      : Absolute path to the evidence folder.
      - SummaryJsonPath     : Absolute path to evidence-bundle.json.
      - PackageDigestSha256 : SHA-256 of the .nupkg artifact.
      - Keys                : Hashtable of evidence-key -> captured-relative-path-or-null.

.EXAMPLE
    Collect-DatabasePackageEvidence `
        -PackageId 'ATAPUtilities.Database' `
        -Version '1.5.0-experimental.42' `
        -NupkgPath './out/ATAPUtilities.Database.1.5.0-experimental.42.nupkg' `
        -ProGetFeed 'database-experimental' `
        -BuildMasterBuildId '12345'

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Task: TASKS_V4-DBA2.md DBA2-T07 / V4-E14.
#>
function Collect-DatabasePackageEvidence {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$NupkgPath,

    [Parameter(Mandatory = $false)][AllowNull()][string]$ManifestPath,
    [Parameter(Mandatory = $false)][AllowNull()][string]$ContentChecksumsPath,
    [Parameter(Mandatory = $false)][AllowNull()][string]$FlywayInfoOutputPath,
    [Parameter(Mandatory = $false)][AllowNull()][string]$FlywayMigrationLogPath,
    [Parameter(Mandatory = $false)][AllowNull()][string]$SeedLoaderLogPath,
    [Parameter(Mandatory = $false)][AllowNull()][string]$PreMigrationSnapshotEvidencePath,
    [Parameter(Mandatory = $false)][AllowNull()][string]$PesterResultsXmlPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ProGetFeed,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [string]$BuildMasterBuildId,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [string]$OutputRoot
  )

  begin {
    $fn = 'Collect-DatabasePackageEvidence'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Entering ${fn} (PackageId='$PackageId'; Version='$Version')" -Tag 'Trace'

    if (-not (Test-Path -LiteralPath $NupkgPath -PathType Leaf)) {
      $msg = "${fn}: nupkg artifact not found at '$NupkgPath'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    if ([string]::IsNullOrWhiteSpace($BuildMasterBuildId)) {
      if (-not [string]::IsNullOrWhiteSpace($env:BUILDMASTER_BUILD_ID)) {
        $BuildMasterBuildId = $env:BUILDMASTER_BUILD_ID
      } else {
        $BuildMasterBuildId = '(local)'
      }
    }

    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
      # Walk up from public/ to the repo root.
      $candidate = $PSScriptRoot
      for ($i = 0; $i -lt 4; $i++) {
        $parent = Split-Path -Parent $candidate
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $candidate) { break }
        $candidate = $parent
      }
      $OutputRoot = Join-Path -Path $candidate -ChildPath '_generated/database-packages'
    }
  }

  process {
    $evidenceFolder = Join-Path -Path $OutputRoot -ChildPath ("{0}.{1}/evidence" -f $PackageId, $Version)
    if ($PSCmdlet.ShouldProcess($evidenceFolder, 'Create evidence folder')) {
      New-Item -ItemType Directory -Path $evidenceFolder -Force | Out-Null
    }

    # Copy a source artifact into the evidence folder if it exists; return
    # the relative path captured (or $null if the source was absent).
    function script:Copy-DatabasePackageEvidenceFile {
      param(
        [string]$SourcePath,
        [string]$DestinationFileName,
        [string]$DestinationDirectory,
        [string]$FunctionName,
        [string]$ModuleName
      )
      if ([string]::IsNullOrWhiteSpace($SourcePath)) { return $null }
      if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
        Write-PSFMessage -FunctionName $FunctionName -ModuleName $ModuleName -Level Verbose `
          -Message "Optional evidence source '$SourcePath' is missing; recording null in summary."
        return $null
      }
      $destPath = Join-Path -Path $DestinationDirectory -ChildPath $DestinationFileName
      Copy-Item -LiteralPath $SourcePath -Destination $destPath -Force
      return $DestinationFileName
    }

    $resolvedNupkg = (Resolve-Path -LiteralPath $NupkgPath).ProviderPath
    $nupkgFileName = [System.IO.Path]::GetFileName($resolvedNupkg)
    if ($PSCmdlet.ShouldProcess($evidenceFolder, "Copy nupkg '$nupkgFileName'")) {
      Copy-Item -LiteralPath $resolvedNupkg -Destination (Join-Path $evidenceFolder $nupkgFileName) -Force
    }
    $packageDigest = (Get-FileHash -LiteralPath $resolvedNupkg -Algorithm SHA256).Hash

    $keys = [ordered]@{
      Manifest                 = (Copy-DatabasePackageEvidenceFile -SourcePath $ManifestPath                       -DestinationFileName 'db-release-unit-manifest.json'   -DestinationDirectory $evidenceFolder -FunctionName $fn -ModuleName $mn)
      ContentChecksums         = (Copy-DatabasePackageEvidenceFile -SourcePath $ContentChecksumsPath               -DestinationFileName 'package-evidence.json'           -DestinationDirectory $evidenceFolder -FunctionName $fn -ModuleName $mn)
      FlywayInfoOutput         = (Copy-DatabasePackageEvidenceFile -SourcePath $FlywayInfoOutputPath               -DestinationFileName 'flyway-info.txt'                  -DestinationDirectory $evidenceFolder -FunctionName $fn -ModuleName $mn)
      FlywayMigrationLog       = (Copy-DatabasePackageEvidenceFile -SourcePath $FlywayMigrationLogPath             -DestinationFileName 'flyway-migration.log'             -DestinationDirectory $evidenceFolder -FunctionName $fn -ModuleName $mn)
      SeedLoaderLog            = (Copy-DatabasePackageEvidenceFile -SourcePath $SeedLoaderLogPath                  -DestinationFileName 'seed-loader.log'                  -DestinationDirectory $evidenceFolder -FunctionName $fn -ModuleName $mn)
      PreMigrationSnapshot     = (Copy-DatabasePackageEvidenceFile -SourcePath $PreMigrationSnapshotEvidencePath   -DestinationFileName 'pre-migration-snapshot.json'      -DestinationDirectory $evidenceFolder -FunctionName $fn -ModuleName $mn)
      PesterResultsXml         = (Copy-DatabasePackageEvidenceFile -SourcePath $PesterResultsXmlPath               -DestinationFileName 'pester-results.xml'               -DestinationDirectory $evidenceFolder -FunctionName $fn -ModuleName $mn)
      Nupkg                    = $nupkgFileName
    }

    # Resolve the actor identity.
    $actor = try {
      [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    } catch {
      $env:USERNAME
    }

    # Resolve the source commit SHA via git, if a repo is present.
    $sourceCommitSha = $null
    try {
      $gitOutput = & git rev-parse HEAD 2>$null
      if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitOutput)) {
        $sourceCommitSha = $gitOutput.Trim()
      }
    } catch {
      $sourceCommitSha = $null
    }

    $summary = [ordered]@{
      PackageId           = $PackageId
      Version             = $Version
      PackageDigestSha256 = $packageDigest
      ProGetFeed          = $ProGetFeed
      Actor               = $actor
      SourceCommitSha     = $sourceCommitSha
      BuildMasterBuildId  = $BuildMasterBuildId
      CapturedUtc         = [datetime]::UtcNow.ToString('o')
      EvidenceKeys        = $keys
    }

    $summaryPath = Join-Path -Path $evidenceFolder -ChildPath 'evidence-bundle.json'
    if ($PSCmdlet.ShouldProcess($summaryPath, 'Write evidence-bundle.json')) {
      $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding utf8
    }

    return [PSCustomObject]@{
      EvidenceFolder      = $evidenceFolder
      SummaryJsonPath     = $summaryPath
      PackageDigestSha256 = $packageDigest
      Keys                = $keys
    }
  }
}
