# Shared, read-only test helpers for tests/ATAP.Utilities.Database.Tests (Sprint 0017, plan B1-1).
#
# These replace per-test literals that froze one historical release: package versions (A1), exact migration
# inventories or heads (A2) and raw byte hashes taken before the deliberate LF release (A3). Every fact is read
# at run time from the authoritative package record, Database/Flyway/package-content-allowlist.json, which
# New-DatabaseChangePackage enforces byte-for-byte, and from Database/Flyway/version.json.
#
# Dot-source this file from a test's BeforeAll:
#   . (Join-Path $PSScriptRoot '..\Helpers\DatabasePackageExpectations.ps1')

function Get-DatabasePackageExpectation {
  <#
  .SYNOPSIS
    Returns the current package facts: version, ordered migrations, seeds and head, read from the allowlist.
  .DESCRIPTION
    Fails closed (throws) when version.json and the allowlist disagree, when the allowlist is malformed, or when
    migration versions are not unique and ascending. Migrations are ordered by ordinal file name, which equals
    version order for the five-digit V#####__ convention.
  .PARAMETER RepositoryRoot
    Absolute repository root.
  .OUTPUTS
    [PSCustomObject] PackageId, SourceVersion, Migrations (Name, Path, Version, Sha256, FullPath), Seeds (Name,
    Path, Sha256, FullPath), HeadVersion, FlywayRoot.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$RepositoryRoot)
  begin {}
  process {
    $flywayRoot = Join-Path $RepositoryRoot 'Database/Flyway'
    $version = Get-Content -LiteralPath (Join-Path $flywayRoot 'version.json') -Raw | ConvertFrom-Json
    $allowlist = Get-Content -LiteralPath (Join-Path $flywayRoot 'package-content-allowlist.json') -Raw | ConvertFrom-Json
    if ($version.version -isnot [string] -or [string]::IsNullOrWhiteSpace($version.version)) { throw 'version.json has no version.' }
    if ($allowlist.sourceVersion -cne $version.version) {
      throw "Allowlist sourceVersion '$($allowlist.sourceVersion)' does not equal version.json '$($version.version)'."
    }
    $toEntry = {
      param($File)
      [pscustomobject]@{
        Name = [IO.Path]::GetFileName([string]$File.path); Path = [string]$File.path; Sha256 = [string]$File.sha256
        FullPath = Join-Path $flywayRoot ([string]$File.path)
      }
    }
    $migrations = @($allowlist.files | Where-Object kind -CEQ 'migration' | ForEach-Object { & $toEntry $_ } |
        Sort-Object -Property Name -Culture ([Globalization.CultureInfo]::InvariantCulture) -CaseSensitive)
    $previous = $null
    foreach ($migration in $migrations) {
      $match = [regex]::Match($migration.Name, '\AV(\d{5})__[A-Za-z0-9_]+\.sql\z')
      if (-not $match.Success) { throw "Allowlist migration '$($migration.Name)' is not a V#####__Name.sql file." }
      if ($null -ne $previous -and [string]::CompareOrdinal($match.Groups[1].Value, $previous) -le 0) {
        throw "Allowlist migration versions are not unique and ascending at '$($migration.Name)'."
      }
      $migration | Add-Member -NotePropertyName Version -NotePropertyValue $match.Groups[1].Value
      $previous = $match.Groups[1].Value
    }
    if ($migrations.Count -eq 0) { throw 'Allowlist has no migrations.' }
    [pscustomobject]@{
      PackageId = [string]$allowlist.packageId
      SourceVersion = [string]$version.version
      Migrations = $migrations
      Seeds = @($allowlist.files | Where-Object kind -CEQ 'seed' | ForEach-Object { & $toEntry $_ })
      HeadVersion = $migrations[-1].Version
      FlywayRoot = $flywayRoot
    }
  }
  end {}
}

function Get-DatabasePackageByteDrift {
  <#
  .SYNOPSIS
    Returns every allowlisted package file whose raw SHA-256 on disk differs from the allowlist (empty = bound).
  .PARAMETER Expectation
    Output of Get-DatabasePackageExpectation.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory)][object]$Expectation)
  begin {}
  process {
    foreach ($file in @($Expectation.Migrations) + @($Expectation.Seeds)) {
      $actual = if (Test-Path -LiteralPath $file.FullPath -PathType Leaf) { (Get-FileHash -LiteralPath $file.FullPath -Algorithm SHA256).Hash } else { '<missing>' }
      if ($actual -cne $file.Sha256) { [pscustomobject]@{ Path = $file.Path; Expected = $file.Sha256; Actual = $actual } }
    }
  }
  end {}
}

function Get-LogicalContentSha256 {
  <#
  .SYNOPSIS
    SHA-256 of a text file after normalizing CRLF and CR to LF (stable across line-ending conversion).
  .PARAMETER LiteralPath
    File to hash.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$LiteralPath)
  begin {}
  process {
    $text = [IO.File]::ReadAllText($LiteralPath)
    $normalizedText = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($normalizedText)))
  }
  end {}
}

function Test-LineEndingStableSha256 {
  <#
  .SYNOPSIS
    True when a file's content equals a frozen raw SHA-256 pin in either line-ending form (LF or CRLF).
  .DESCRIPTION
    Several historical pins were taken from a CRLF working-tree copy before the repository's deliberate LF
    normalization. This recomputes the hash of the file's LF form and of its CRLF form and compares both with the
    pin, so any change other than line endings still fails, while the pin itself (often quoted in ADR text) stays
    untouched.
  .PARAMETER LiteralPath
    File to check.
  .PARAMETER ExpectedSha256
    The frozen pin (64 hex digits).
  #>
  [CmdletBinding()]
  [OutputType([bool])]
  param([Parameter(Mandatory)][string]$LiteralPath, [Parameter(Mandatory)][string]$ExpectedSha256)
  begin {}
  process {
    $lf = [IO.File]::ReadAllText($LiteralPath).Replace("`r`n", "`n").Replace("`r", "`n")
    foreach ($form in @($lf, $lf.Replace("`n", "`r`n"))) {
      $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($form)))
      if ([string]::Equals($hash, $ExpectedSha256, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
  }
  end {}
}

function Get-AppliedMigrationLogicalHash {
  <#
  .SYNOPSIS
    Returns the recorded logical SHA-256 of one applied migration from Fixtures/AppliedMigrationLogicalHashes.json.
  .DESCRIPTION
    The fixture records, once per applied migration, the line-ending-normalized hash. It keeps "an applied migration's
    content never changes" checkable after the deliberate LF release, without any package version. Throws when the
    migration is not recorded.
  .PARAMETER Name
    Migration file name, for example V00070__Create_Ace_AISupervisor_Telemetry.sql.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Name)
  begin {}
  process {
    $fixture = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Fixtures\AppliedMigrationLogicalHashes.json') -Raw | ConvertFrom-Json
    $entry = @($fixture.migrations | Where-Object name -CEQ $Name)
    if ($entry.Count -ne 1) { throw "Applied migration '$Name' has no recorded logical hash." }
    [string]$entry[0].logicalSha256
  }
  end {}
}

function Assert-MigrationLineagePosition {
  <#
  .SYNOPSIS
    Position invariant that replaces exact-inventory and exact-head pins (plan B1-1, kind A2).
  .DESCRIPTION
    Proves, for the migration a test owns: (1) it exists exactly once in the package, (2) package versions are unique
    and ascending (already enforced by Get-DatabasePackageExpectation), (3) the named predecessors appear in order
    immediately before it, with nothing inserted between them, and (4) it is the oldest-to-newest successor of its
    predecessors regardless of how many later migrations exist. Throws with a specific message on any violation.
  .PARAMETER Expectation
    Output of Get-DatabasePackageExpectation.
  .PARAMETER Name
    The migration the test owns.
  .PARAMETER Predecessors
    The exact ordered migrations that must immediately precede it (may be empty).
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory)][object]$Expectation, [Parameter(Mandatory)][string]$Name, [string[]]$Predecessors = @())
  begin {}
  process {
    $names = [string[]]@($Expectation.Migrations.Name)
    $hits = @(for ($i = 0; $i -lt $names.Count; $i++) { if ($names[$i] -ceq $Name) { $i } })
    if ($hits.Count -ne 1) { throw "Migration '$Name' must exist exactly once; found $($hits.Count)." }
    $position = $hits[0]
    if ($Predecessors.Count -gt $position) { throw "Migration '$Name' has fewer predecessors than required." }
    $actual = if ($Predecessors.Count) { @($names[($position - $Predecessors.Count)..($position - 1)]) } else { @() }
    if (($actual -join '|') -cne ($Predecessors -join '|')) {
      throw "Migration '$Name' must immediately follow [$($Predecessors -join ', ')]; found [$($actual -join ', ')]."
    }
  }
  end {}
}
