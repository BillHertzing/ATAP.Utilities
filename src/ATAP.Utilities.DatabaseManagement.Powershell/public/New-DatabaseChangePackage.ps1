#Requires -Version 7.0
function New-DatabaseChangePackage {
  <#
.SYNOPSIS
    Packages a database change unit (migrations, repeatables, seeds, loaders) into a NuGet package.

.DESCRIPTION
    Collects files from the canonical Database/Flyway/ source tree for ATAPUtilities
    (or the legacy Database/<Application>/ source tree for other applications), computes SHA-256 checksums,
    generates a db-release-unit-manifest.json conforming to the v2 schema, and calls
    dotnet pack to produce a .nupkg file. The package identity is
    <Application>.Database (or <Application>.<Stream>.Database when -Stream is provided).

    Repeated runs with identical inputs produce an identical manifest digest because:
    - Checksums are sorted deterministically by relative path.
    - The createdUtc timestamp is sourced from the HEAD git commit date, not Get-Date.

.PARAMETER Application
    Application name (required). ATAPUtilities uses Database/Flyway/; other
    applications use Database/<Application>/. The NuGet package id is
    <Application>.Database.

.PARAMETER Stream
    Optional stream sub-folder. When supplied, source is at Database/<Application>/<Stream>/
    and the package id becomes <Application>.<Stream>.Database.

.PARAMETER RepositoryRoot
    Root of the repository. Defaults to the parent of the module's src/ folder,
    resolved from $PSScriptRoot at runtime.

.PARAMETER PackageVersion
    Optional resolved NuGet package version. BuildMaster supplies this from the
    NBGV build context when version.json contains height tokens.

.PARAMETER ExcludedMigrationFileName
    Optional exact migration file names to omit from this release unit. This is
    intended for explicitly deferred, unapplied future-sprint migrations. Each
    name must identify a file in the canonical migration source folder.

.OUTPUTS
    [string] Absolute path of the produced .nupkg file.

.EXAMPLE
    New-DatabaseChangePackage -Application ATAPUtilities

.EXAMPLE
    New-DatabaseChangePackage -Application ATAPUtilities -Stream Tags
#>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Application,

    [Parameter(Mandatory = $false)]
    [string]$Stream = '',

    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageVersion,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ExcludedMigrationFileName = @()
  )

  begin {
    $fn = 'New-DatabaseChangePackage'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'

    # Resolve repository root from module location if not provided
    if (-not $RepositoryRoot) {
      # Module is at src/ATAP.Utilities.DatabaseManagement.Powershell/public/
      $RepositoryRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "RepositoryRoot=$RepositoryRoot" -Tag 'Config'
  }

  process {
    # ── 1. Determine package id and source path ─────────────────────────────
    $usesCanonicalFlywayLayout = $Application -eq 'ATAPUtilities' -and -not $Stream
    if ($Stream) {
      $DatabasePackageId = "$Application.$Stream.Database"
      $DatabasePackageSourcePath = Join-Path $RepositoryRoot 'Database' $Application $Stream
    } elseif ($usesCanonicalFlywayLayout) {
      $DatabasePackageId = "$Application.Database"
      $DatabasePackageSourcePath = Join-Path $RepositoryRoot 'Database' 'Flyway'
    } else {
      $DatabasePackageId = "$Application.Database"
      $DatabasePackageSourcePath = Join-Path $RepositoryRoot 'Database' $Application
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "PackageId=$DatabasePackageId  Source=$DatabasePackageSourcePath" -Tag 'Config'

    # ── 2. Read version from version.json ────────────────────────────────────
    $DatabaseVersionJsonPath = Join-Path $DatabasePackageSourcePath 'version.json'
    if (-not (Test-Path $DatabaseVersionJsonPath)) {
      $msg = "version.json not found at '$DatabaseVersionJsonPath'. Cannot determine package version."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
      throw $msg
    }
    $versionObj = Get-Content $DatabaseVersionJsonPath -Raw | ConvertFrom-Json
    if (-not $PackageVersion) {
      $PackageVersion = $versionObj.version
    }
    if (-not $PackageVersion) {
      $msg = "version field not found in '$DatabaseVersionJsonPath'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
      throw $msg
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "PackageVersion=$PackageVersion" -Tag 'Config'

    $packageLifeCycleStage = 'Production'
    if ($PackageVersion -match '-(?<label>[A-Za-z]+)') {
      $packageLifeCycleStage = $Matches['label']
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "PackageLifeCycleStage=$packageLifeCycleStage" -Tag 'Config'

    # ── 3. Locate source DB folders ──────────────────────────────────────────
    $migrationsFolder = if ($usesCanonicalFlywayLayout) { Join-Path $DatabasePackageSourcePath 'SQL' } else { Join-Path $DatabasePackageSourcePath 'db' 'migrations' }
    $repeatablesFolder = if ($usesCanonicalFlywayLayout) { Join-Path $DatabasePackageSourcePath 'Repeatable' } else { Join-Path $DatabasePackageSourcePath 'db' 'repeatables' }
    $seedsFolder = if ($usesCanonicalFlywayLayout) { Join-Path $DatabasePackageSourcePath 'Data' } else { Join-Path $DatabasePackageSourcePath 'db' 'seeds' }
    $loadersFolder = if ($usesCanonicalFlywayLayout) { $null } else { Join-Path $DatabasePackageSourcePath 'db' 'loaders' }

    if (-not (Test-Path $migrationsFolder)) {
      $msg = "Migrations folder not found: '$migrationsFolder'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
      throw $msg
    }

    # ── 4. Staging folder ────────────────────────────────────────────────────
    $stagingRoot = Join-Path $RepositoryRoot '_generated' 'database-packages'
    $stagingFolder = Join-Path $stagingRoot "$DatabasePackageId.$PackageVersion"
    $dbFolder = Join-Path $stagingFolder 'db'

    if ($PSCmdlet.ShouldProcess($stagingFolder, 'Create staging folder')) {
      New-Item -ItemType Directory -Path $dbFolder -Force | Out-Null
      '<Project />' | Set-Content -LiteralPath (Join-Path $stagingFolder 'Directory.Build.props') -Encoding UTF8
      '<Project />' | Set-Content -LiteralPath (Join-Path $stagingFolder 'Directory.Build.targets') -Encoding UTF8
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Staging=$stagingFolder" -Tag 'Config'

    # ── 5. Collect files and compute checksums ────────────────────────────────
    $collectedFiles = [System.Collections.Generic.List[hashtable]]::new()

    function Copy-DbFiles {
      param(
        [string]$SourceFolder,
        [string]$RelSubPath,
        [string]$Kind,
        [string[]]$Extensions
      )
      if ([string]::IsNullOrWhiteSpace($SourceFolder) -or
        -not (Test-Path -LiteralPath $SourceFolder -PathType Container)) { return }
      $destSub = Join-Path $dbFolder $RelSubPath
      New-Item -ItemType Directory -Path $destSub -Force | Out-Null
      Get-ChildItem -Path $SourceFolder -File |
        Where-Object { $_.Extension -in $Extensions } |
        Where-Object { $Kind -ne 'migration' -or $_.Name -notin $ExcludedMigrationFileName } |
        ForEach-Object {
        $dest = Join-Path $destSub $_.Name
        Copy-Item $_.FullName $dest -Force
        $sha256 = (Get-FileHash -Path $dest -Algorithm SHA256).Hash.ToLower()
        $collectedFiles.Add(@{
            path           = "db/$RelSubPath/$($_.Name)"
            kind           = $Kind
            checksumSha256 = $sha256
            sourceFile     = $dest
          })
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Staged $Kind : $($_.Name) sha256=$sha256" -Tag 'File'
      }
    }

    foreach ($excludedName in $ExcludedMigrationFileName) {
      $excludedPath = Join-Path $migrationsFolder $excludedName
      if (-not (Test-Path -LiteralPath $excludedPath -PathType Leaf)) {
        throw "Excluded migration '$excludedName' was not found in '$migrationsFolder'."
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Migration excluded from this release unit by exact name: $excludedName" -Tag 'File'
    }

    Copy-DbFiles -SourceFolder $migrationsFolder -RelSubPath 'migrations' -Kind 'migration' -Extensions '.sql'
    Copy-DbFiles -SourceFolder $repeatablesFolder -RelSubPath 'repeatables' -Kind 'repeatable' -Extensions '.sql'
    Copy-DbFiles -SourceFolder $seedsFolder -RelSubPath 'seeds' -Kind 'seed' -Extensions '.csv'
    Copy-DbFiles -SourceFolder $loadersFolder -RelSubPath 'loaders' -Kind 'seedLoader' -Extensions @('.sql', '.ps1')

    if ($collectedFiles.Count -eq 0) {
      $msg = if ($usesCanonicalFlywayLayout) {
        "No files were staged. Check that 'Database/Flyway/SQL/' or 'Database/Flyway/Data/' contain files."
      } else {
        "No files were staged. Check that 'db/migrations/', 'db/repeatables/', 'db/seeds/', or 'db/loaders/' contain files."
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message $msg -Tag 'Warning'
    }

    # A database package is a self-contained Flyway release unit. Its canonical
    # archive layout is db/migrations + db/repeatables + db/seeds, which differs
    # from the source-tree SQL + Repeatable + Data layout. Generate the package
    # configuration from the content actually staged so consumers never fall
    # back to a repository-local flyway.toml.
    $packageLocations = [System.Collections.Generic.List[string]]::new()
    if (($collectedFiles | Where-Object { $_['kind'] -eq 'migration' }).Count -gt 0) {
      $packageLocations.Add('filesystem:./db/migrations')
    }
    if (($collectedFiles | Where-Object { $_['kind'] -eq 'repeatable' }).Count -gt 0) {
      $packageLocations.Add('filesystem:./db/repeatables')
    }
    $locationToml = ($packageLocations | ForEach-Object { '  "' + $_ + '"' }) -join ",`n"
    $packageFlywayTomlPath = Join-Path $stagingFolder 'flyway.toml'
    $packageFlywayToml = @"
[flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true
validateMigrationNaming = true
mixed = true
createSchemas = true
placeholderReplacement = true
locations = [
$locationToml
]
"@
    if ($PSCmdlet.ShouldProcess($packageFlywayTomlPath, 'Write package flyway.toml')) {
      $packageFlywayToml | Set-Content -LiteralPath $packageFlywayTomlPath -Encoding UTF8
    }

    # ── 6. Build sorted checksum list for determinism ─────────────────────────
    $sortedFiles = $collectedFiles | Sort-Object { $_['path'] }

    # ── 7. Get deterministic timestamp from git commit date ───────────────────
    $gitCommitDate = $null
    try {
      $gitDate = & git -C $RepositoryRoot log -1 --format='%cI' 2>&1
      if ($LASTEXITCODE -eq 0 -and $gitDate -match '^\d{4}') {
        $gitCommitDate = [System.DateTimeOffset]::Parse($gitDate).UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
      }
    } catch { $null = $_ }
    if (-not $gitCommitDate) {
      $gitCommitDate = '1970-01-01T00:00:00Z'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message 'Could not retrieve git commit date; using epoch timestamp for determinism.' -Tag 'Warning'
    }

    # ── 8. Classify changeKind ────────────────────────────────────────────────
    $hasMigrations = ($sortedFiles | Where-Object { $_['kind'] -in 'migration', 'repeatable' }).Count -gt 0
    $hasSeeds = ($sortedFiles | Where-Object { $_['kind'] -in 'seed', 'seedLoader' }).Count -gt 0
    $changeKind = if ($hasMigrations -and $hasSeeds) { 'schemaAndData' }
    elseif ($hasMigrations) { 'schema' }
    else { 'data' }

    # ── 8b. Derive flywayTargetVersion from the highest versioned migration ───
    # Unified version-numbering scheme (Sprint 0009 Task 9.12): the packaged
    # change unit uses the SAME canonical dotted, zero-padded Flyway version
    # scheme as the consolidated authoritative set in Database/Flyway/SQL
    # (V00.0X.NNNNNN). The target version is therefore the maximum migration
    # version actually present in db/migrations, compared with Flyway's
    # part-by-part numeric semantics (each dot-separated component as an integer),
    # NOT a hard-coded literal. Data-only packages (no versioned migration) keep
    # '0' to signal "no schema target".
    $migrationVersions = foreach ($f in ($sortedFiles | Where-Object { $_['kind'] -eq 'migration' })) {
      $migName = Split-Path -Leaf $f['path']
      if ($migName -match '^[Vv](?<ver>[0-9]+(?:\.[0-9]+)*)__') { $Matches['ver'] }
    }
    $migrationVersions = @($migrationVersions)
    $flywayTargetVersion = if ($migrationVersions.Count -gt 0) {
      $migrationVersions |
        Sort-Object -Property @{ Expression = { ($_ -split '\.' | ForEach-Object { $_.PadLeft(12, '0') }) -join '.' } } |
        Select-Object -Last 1
    } else {
      '0'
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "flywayTargetVersion=$flywayTargetVersion (derived from $($migrationVersions.Count) versioned migration(s))" -Tag 'Config'

    # ── 9. Build manifest object ──────────────────────────────────────────────
    $gitTag = ''
    try {
      $gitTag = (& git -C $RepositoryRoot describe --tags --exact-match HEAD 2>&1).Trim()
      if ($LASTEXITCODE -ne 0) { $gitTag = "$Application/$PackageVersion" }
    } catch { $gitTag = "$Application/$PackageVersion" }

    $gitSha = ''
    try {
      $gitSha = (& git -C $RepositoryRoot rev-parse HEAD 2>&1).Trim()
      if ($LASTEXITCODE -ne 0) { $gitSha = '...' }
    } catch { $gitSha = '...' }

    $filesArray = $sortedFiles | ForEach-Object {
      $entry = [ordered]@{
        path           = $_['path']
        kind           = $_['kind']
        checksumSha256 = $_['checksumSha256']
      }
      if ($_['kind'] -eq 'migration') {
        $entry['destructiveChangeKind'] = 'none'
      }
      $entry
    }

    $manifest = [ordered]@{
      schemaVersion                      = 2
      dbChangeUnit                       = $DatabasePackageId
      appVersion                         = $PackageVersion
      changeKind                         = $changeKind
      flywayTargetVersion                = $flywayTargetVersion
      createdUtc                         = $gitCommitDate
      createdFromGitTag                  = $gitTag
      createdFromGitSha                  = $gitSha
      files                              = @($filesArray)
      expectedRowCounts                  = @{}
      compatibleAppPackageRanges         = @()
      requiresPreviousProductionSnapshot = $false
      rollbackSupported                  = $true
      rollbackNotes                      = 'Auto-generated manifest. Review and update before promoting past Experimental.'
      evidenceRequirements               = [ordered]@{
        experimental = @{ flywayRehearsalRequired = $true; rowCountValidationRequired = $false; snapshotBackupRequired = $false; approvalRequired = $false }
        development  = @{ flywayRehearsalRequired = $true; rowCountValidationRequired = $false; snapshotBackupRequired = $false; approvalRequired = $false }
        integration  = @{ flywayRehearsalRequired = $true; rowCountValidationRequired = $false; snapshotBackupRequired = $true; approvalRequired = $false }
        qa           = @{ flywayRehearsalRequired = $true; rowCountValidationRequired = $true; snapshotBackupRequired = $true; approvalRequired = $true }
        stable       = @{ flywayRehearsalRequired = $true; rowCountValidationRequired = $true; snapshotBackupRequired = $true; approvalRequired = $true }
      }
    }
    if ($hasSeeds) {
      $manifest['dataKind'] = 'fixture'
    }

    $manifestPath = Join-Path $stagingFolder 'db-release-unit-manifest.json'
    if ($PSCmdlet.ShouldProcess($manifestPath, 'Write db-release-unit-manifest.json')) {
      $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath -Encoding UTF8
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Manifest written to $manifestPath" -Tag 'Output'
    }

    # ── 10. Write package-evidence.json ──────────────────────────────────────
    $evidenceEntries = $sortedFiles | ForEach-Object {
      [ordered]@{
        relativePath   = $_['path']
        kind           = $_['kind']
        checksumSha256 = $_['checksumSha256']
      }
    }
    $evidenceObj = [ordered]@{
      packageId      = $DatabasePackageId
      packageVersion = $PackageVersion
      createdUtc     = $gitCommitDate
      fileCount      = $sortedFiles.Count
      files          = @($evidenceEntries)
    }
    $evidencePath = Join-Path $stagingFolder 'package-evidence.json'
    if ($PSCmdlet.ShouldProcess($evidencePath, 'Write package-evidence.json')) {
      $evidenceObj | ConvertTo-Json -Depth 10 | Set-Content -Path $evidencePath -Encoding UTF8
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Evidence written to $evidencePath" -Tag 'Output'
    }

    # ── 11. Generate or locate .csproj and run dotnet pack ───────────────────
    $csprojSourcePath = Join-Path $DatabasePackageSourcePath "$Application.Database.csproj"
    $csprojStagingPath = Join-Path $stagingFolder "$DatabasePackageId.csproj"

    if (Test-Path $csprojSourcePath) {
      Copy-Item $csprojSourcePath $csprojStagingPath -Force
    } else {
      # Generate a minimal NuGet packaging csproj
      $csprojContent = @"
<Project Sdk="Microsoft.Build.NoTargets/3.7.0">
  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>
    <PackageId>$DatabasePackageId</PackageId>
    <Version>$PackageVersion</Version>
    <PackageVersion>$PackageVersion</PackageVersion>
    <PackageLifeCycleStage>$packageLifeCycleStage</PackageLifeCycleStage>
    <Description>Database change package for $Application</Description>
    <NoWarn>NU5128</NoWarn>
  </PropertyGroup>
  <ItemGroup>
    <Content Include="db\**\*" Pack="true" PackagePath="db\%(RecursiveDir)%(Filename)%(Extension)" />
    <Content Include="flyway.toml" Pack="true" PackagePath="flyway.toml" />
    <Content Include="db-release-unit-manifest.json" Pack="true" PackagePath="db-release-unit-manifest.json" />
    <Content Include="package-evidence.json" Pack="true" PackagePath="package-evidence.json" />
  </ItemGroup>
</Project>
"@
      if ($PSCmdlet.ShouldProcess($csprojStagingPath, 'Write generated .csproj')) {
        $csprojContent | Set-Content -Path $csprojStagingPath -Encoding UTF8
      }
    }

    $nupkgOutputDir = Join-Path $stagingFolder 'nupkg'
    New-Item -ItemType Directory -Path $nupkgOutputDir -Force | Out-Null
    Get-ChildItem -Path $nupkgOutputDir -Filter '*.nupkg' -File -ErrorAction SilentlyContinue |
      Remove-Item -Force

    if ($PSCmdlet.ShouldProcess("dotnet pack $csprojStagingPath", 'Pack database NuGet package')) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Running: dotnet pack $csprojStagingPath -o $nupkgOutputDir -p:PackageVersion=$PackageVersion -p:PackageLifeCycleStage=$packageLifeCycleStage" -Tag 'Pack'
      $packOutput = & dotnet pack $csprojStagingPath -o $nupkgOutputDir --nologo "-p:PackageVersion=$PackageVersion" "-p:PackageLifeCycleStage=$packageLifeCycleStage" 2>&1
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "dotnet pack output: $($packOutput -join ' | ')" -Tag 'Pack'
      if ($LASTEXITCODE -ne 0) {
        $msg = "dotnet pack failed (exit $LASTEXITCODE). Output: $($packOutput -join [System.Environment]::NewLine)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
        throw $msg
      }
    }

    $nupkgFile = Get-ChildItem -Path $nupkgOutputDir -Filter '*.nupkg' | Select-Object -First 1
    if (-not $nupkgFile) {
      $msg = "dotnet pack succeeded but no .nupkg was found in '$nupkgOutputDir'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
      throw $msg
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Package created: $($nupkgFile.FullName)" -Tag 'Output'
    Write-Output $nupkgFile.FullName
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}
