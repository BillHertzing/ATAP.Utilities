function Read-RehearsalBoundaryContract {
  <#
  .SYNOPSIS
    Loads and validates a database rehearsal boundary contract (RehearsalBoundaries.json).
  .DESCRIPTION
    Private, read-only source seam for Invoke-DatabasePackageRehearsal and Invoke-FlywayRehearsal.
    The contract replaces migration-boundary literals in code: which Flyway targets a fixture
    rehearsal admits, which migrations each boundary adds, which clone baselines are admitted,
    and which pinned verifier proves each boundary. Every check fails closed (throws).

    Structural checks: exact property names, schemaVersion 1, nonempty packageId and
    sourceDatabaseName, a floor (version + migration count), strictly ascending five-digit
    boundary versions above the floor, known kinds (Plain, LoginDecrypt, BeforeAfter), the
    verifier roles each kind needs, unique session-context keys, contiguous newMigrations
    whose last entry is the boundary itself, and admitted baselines that are the floor or a
    boundary. Every verifier path is relative, stays inside the contract folder, exists, and
    matches its SHA-256 pin before any SQL runs; its text is decoded as strict UTF-8.

    When MigrationNames is supplied (the package's ordered migration file names), the
    function also proves the package matches the contract exactly: unique ascending
    versions, exactly floor.migrationCount migrations up to the floor, and above the floor
    exactly the ordered newMigrations of every boundary up to the package head. The head
    must be a boundary; it is returned as TargetVersion.
  .PARAMETER Path
    Absolute, trim-exact path to the contract JSON file.
  .PARAMETER MigrationNames
    Optional package migration file names (for example V00010__Name.sql), in any order.
  .OUTPUTS
    [PSCustomObject] Path, PackageId, SourceDatabaseName, FloorVersion, FloorMigrationCount,
    Boundaries (Version, Kind, PhaseTag, SessionContextKey, NewMigrations, Verifiers with Role,
    Path, Sha256, Text), AdmittedBaselines; with MigrationNames also MigrationNames,
    MigrationVersions and TargetVersion.
  .EXAMPLE
    Read-RehearsalBoundaryContract -Path "$repo\Database\Verify\RehearsalBoundaries.json" -MigrationNames $names
  .NOTES
    Plan: _Planning Sprint0017 senior1-rehearsal-plan/Plan.md r2 section 2 (Impl-Rehearsal-Parameterize).
  .LINK
    ../public/Invoke-FlywayRehearsal.ps1
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
    [string[]]$MigrationNames
  )
  begin {
    $fn = 'Read-RehearsalBoundaryContract'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'
    if ($Path -cne $Path.Trim() -or -not [IO.Path]::IsPathFullyQualified($Path)) {
      throw 'Rehearsal boundary contract path must be absolute and trim-exact.'
    }
    if ($PSBoundParameters.ContainsKey('MigrationNames') -and @($MigrationNames).Count -eq 0) {
      throw 'Rehearsal boundary contract migration names must be nonempty when supplied.'
    }
  }
  process {
    $versionPattern = '\A[0-9]{5}\z'
    $migrationPattern = '\AV([0-9]{5})__[A-Za-z0-9_]+\.sql\z'
    $kinds = @('Plain', 'LoginDecrypt', 'BeforeAfter')
    function assertProperties([object]$Object, [string[]]$Required, [string[]]$Optional, [string]$Where) {
      if ($null -eq $Object -or $Object -isnot [Management.Automation.PSCustomObject]) { throw "Rehearsal boundary contract: $Where must be an object." }
      $names = @($Object.PSObject.Properties.Name)
      foreach ($name in $names) {
        if ($name -cnotin ($Required + $Optional)) { throw "Rehearsal boundary contract: $Where has unknown property '$name'." }
      }
      foreach ($name in $Required) {
        if ($name -cnotin $names) { throw "Rehearsal boundary contract: $Where is missing '$name'." }
      }
    }
    function assertText([object]$Value, [string]$Where) {
      if ($Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value) -or $Value -cne $Value.Trim()) {
        throw "Rehearsal boundary contract: $Where must be a nonempty trim-exact string."
      }
    }
    function migrationVersion([string]$Name, [string]$Where) {
      $match = [regex]::Match($Name, $migrationPattern)
      if (-not $match.Success) { throw "Rehearsal boundary contract: $Where '$Name' is not a versioned migration file name." }
      return $match.Groups[1].Value
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Rehearsal boundary contract not found: '$Path'." }
    $contractRoot = [IO.Path]::GetFullPath([IO.Path]::GetDirectoryName($Path))
    try { $raw = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false, $true)) }
    catch { throw "Rehearsal boundary contract is not readable strict UTF-8: '$Path'." }
    try { $contract = $raw | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Rehearsal boundary contract is not valid JSON: '$Path'." }

    assertProperties $contract @('schemaVersion', 'packageId', 'sourceDatabaseName', 'floor', 'boundaries', 'admittedBaselines') @('$comment') 'root'
    if ($contract.schemaVersion -isnot [long] -and $contract.schemaVersion -isnot [int]) { throw 'Rehearsal boundary contract: schemaVersion must be the integer 1.' }
    if ($contract.schemaVersion -ne 1) { throw 'Rehearsal boundary contract: schemaVersion must be the integer 1.' }
    assertText $contract.packageId 'packageId'
    assertText $contract.sourceDatabaseName 'sourceDatabaseName'
    if ($contract.sourceDatabaseName -cnotmatch '\A[A-Za-z0-9_-]{1,64}\z') { throw 'Rehearsal boundary contract: sourceDatabaseName must be a safe exact catalog name.' }

    assertProperties $contract.floor @('version', 'migrationCount') @() 'floor'
    assertText $contract.floor.version 'floor.version'
    if ($contract.floor.version -cnotmatch $versionPattern) { throw 'Rehearsal boundary contract: floor.version must be five digits.' }
    if (($contract.floor.migrationCount -isnot [long] -and $contract.floor.migrationCount -isnot [int]) -or $contract.floor.migrationCount -lt 1) {
      throw 'Rehearsal boundary contract: floor.migrationCount must be a positive integer.'
    }
    $floorVersion = [string]$contract.floor.version

    $rawBoundaries = @($contract.boundaries)
    if ($contract.boundaries -isnot [object[]] -or $rawBoundaries.Count -eq 0) { throw 'Rehearsal boundary contract: boundaries must be a nonempty array.' }
    $boundaries = [Collections.Generic.List[object]]::new()
    $previousVersion = $floorVersion
    $sessionKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $verifierPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    for ($index = 0; $index -lt $rawBoundaries.Count; $index++) {
      $entry = $rawBoundaries[$index]
      $where = "boundaries[$index]"
      assertProperties $entry @('version', 'kind', 'newMigrations') @('phaseTag', 'sessionContextKey', 'verifiers') $where
      assertText $entry.version "$where.version"
      if ($entry.version -cnotmatch $versionPattern) { throw "Rehearsal boundary contract: $where.version must be five digits." }
      if ([string]::CompareOrdinal($entry.version, $previousVersion) -le 0) {
        throw "Rehearsal boundary contract: $where.version must be above the floor and strictly ascending."
      }
      assertText $entry.kind "$where.kind"
      if ($entry.kind -cnotin $kinds) { throw "Rehearsal boundary contract: $where.kind '$($entry.kind)' is not a known kind." }

      $newMigrations = @($entry.newMigrations)
      if ($entry.newMigrations -isnot [object[]] -or $newMigrations.Count -eq 0) { throw "Rehearsal boundary contract: $where.newMigrations must be a nonempty array." }
      $lastMigrationVersion = $previousVersion
      foreach ($name in $newMigrations) {
        assertText $name "$where.newMigrations entry"
        $migrationVersionText = migrationVersion $name "$where.newMigrations entry"
        if ([string]::CompareOrdinal($migrationVersionText, $lastMigrationVersion) -le 0 -or
            [string]::CompareOrdinal($migrationVersionText, $entry.version) -gt 0) {
          throw "Rehearsal boundary contract: $where.newMigrations must ascend within (previous boundary, $($entry.version)]."
        }
        $lastMigrationVersion = $migrationVersionText
      }
      if ($lastMigrationVersion -cne $entry.version) { throw "Rehearsal boundary contract: $where.newMigrations must end with the boundary migration $($entry.version)." }

      $phaseTag = ([int]$entry.version).ToString([Globalization.CultureInfo]::InvariantCulture)
      if ($entry.PSObject.Properties.Name -ccontains 'phaseTag') {
        assertText $entry.phaseTag "$where.phaseTag"
        if ($entry.phaseTag -cnotmatch '\A[A-Za-z0-9]{1,8}\z') { throw "Rehearsal boundary contract: $where.phaseTag must be 1-8 letters or digits." }
        $phaseTag = $entry.phaseTag
      }
      $requiredRoles = switch ($entry.kind) { 'Plain' { @() } 'LoginDecrypt' { @('Login', 'Decrypt') } 'BeforeAfter' { @('BeforeAfter') } }
      $sessionKey = $null
      if ($entry.kind -ceq 'BeforeAfter') {
        if ($entry.PSObject.Properties.Name -cnotcontains 'sessionContextKey') { throw "Rehearsal boundary contract: $where (BeforeAfter) requires sessionContextKey." }
        assertText $entry.sessionContextKey "$where.sessionContextKey"
        if ($entry.sessionContextKey -cnotmatch '\AATAP\.[A-Za-z0-9]{1,64}\.ExpectedCatalog\z') {
          throw "Rehearsal boundary contract: $where.sessionContextKey must match ATAP.<Name>.ExpectedCatalog."
        }
        if (-not $sessionKeys.Add($entry.sessionContextKey)) { throw "Rehearsal boundary contract: $where.sessionContextKey is not unique." }
        $sessionKey = $entry.sessionContextKey
      }
      elseif ($entry.PSObject.Properties.Name -ccontains 'sessionContextKey') {
        throw "Rehearsal boundary contract: $where.sessionContextKey is only valid for BeforeAfter boundaries."
      }

      $verifiers = [Collections.Generic.List[object]]::new()
      $rawVerifiers = if ($entry.PSObject.Properties.Name -ccontains 'verifiers') { @($entry.verifiers) } else { @() }
      if ($entry.PSObject.Properties.Name -ccontains 'verifiers' -and $entry.verifiers -isnot [object[]]) {
        throw "Rehearsal boundary contract: $where.verifiers must be an array."
      }
      $roles = @($rawVerifiers | ForEach-Object { $_.role })
      if (($roles -join '|') -cne ($requiredRoles -join '|')) {
        throw "Rehearsal boundary contract: $where ($($entry.kind)) requires verifier roles [$($requiredRoles -join ', ')] in that order."
      }
      for ($verifierIndex = 0; $verifierIndex -lt $rawVerifiers.Count; $verifierIndex++) {
        $verifier = $rawVerifiers[$verifierIndex]
        $verifierWhere = "$where.verifiers[$verifierIndex]"
        assertProperties $verifier @('role', 'path', 'sha256') @() $verifierWhere
        assertText $verifier.path "$verifierWhere.path"
        assertText $verifier.sha256 "$verifierWhere.sha256"
        if ($verifier.sha256 -cnotmatch '\A[0-9A-F]{64}\z') { throw "Rehearsal boundary contract: $verifierWhere.sha256 must be 64 uppercase hex digits." }
        if ([IO.Path]::IsPathRooted($verifier.path) -or $verifier.path -match '(^|[\\/])\.\.?([\\/]|$)' -or $verifier.path -match ':') {
          throw "Rehearsal boundary contract: $verifierWhere.path must be a plain relative path inside the contract folder."
        }
        $fullPath = [IO.Path]::GetFullPath([IO.Path]::Combine($contractRoot, $verifier.path))
        if (-not $fullPath.StartsWith($contractRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
          throw "Rehearsal boundary contract: $verifierWhere.path escapes the contract folder."
        }
        if (-not $verifierPaths.Add($fullPath)) { throw "Rehearsal boundary contract: $verifierWhere.path is used more than once." }
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "Rehearsal boundary contract: verifier '$($verifier.path)' is missing." }
        [byte[]]$bytes = [IO.File]::ReadAllBytes($fullPath)
        $actual = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
        if (-not [string]::Equals($actual, $verifier.sha256, [StringComparison]::Ordinal)) {
          throw "Rehearsal boundary contract: verifier '$($verifier.path)' does not match its SHA-256 pin."
        }
        try { $text = $utf8.GetString($bytes) } catch { throw "Rehearsal boundary contract: verifier '$($verifier.path)' is not strict UTF-8." }
        if ([string]::IsNullOrWhiteSpace($text)) { throw "Rehearsal boundary contract: verifier '$($verifier.path)' is empty." }
        $verifiers.Add([PSCustomObject]@{ Role = [string]$verifier.role; Path = $fullPath; Sha256 = $actual; Text = $text })
      }

      $boundaries.Add([PSCustomObject]@{
          Version = [string]$entry.version; Kind = [string]$entry.kind; PhaseTag = $phaseTag
          SessionContextKey = $sessionKey; NewMigrations = [string[]]@($newMigrations); Verifiers = $verifiers.ToArray()
        })
      $previousVersion = $entry.version
    }

    $baselines = @($contract.admittedBaselines)
    if ($contract.admittedBaselines -isnot [object[]] -or $baselines.Count -eq 0) { throw 'Rehearsal boundary contract: admittedBaselines must be a nonempty array.' }
    $baselineSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $knownBaselines = @($floorVersion) + @($boundaries | ForEach-Object Version)
    foreach ($baseline in $baselines) {
      assertText $baseline 'admittedBaselines entry'
      if ($baseline -cnotin $knownBaselines) { throw "Rehearsal boundary contract: admitted baseline '$baseline' is neither the floor nor a boundary." }
      if (-not $baselineSet.Add($baseline)) { throw "Rehearsal boundary contract: admitted baseline '$baseline' is duplicated." }
    }

    $result = [ordered]@{
      Path = [IO.Path]::GetFullPath($Path); PackageId = [string]$contract.packageId
      SourceDatabaseName = [string]$contract.sourceDatabaseName
      FloorVersion = $floorVersion; FloorMigrationCount = [int]$contract.floor.migrationCount
      Boundaries = $boundaries.ToArray(); AdmittedBaselines = [string[]]@($baselines | Sort-Object { $_ } -Culture ([Globalization.CultureInfo]::InvariantCulture))
    }

    if ($PSBoundParameters.ContainsKey('MigrationNames')) {
      $ordered = [string[]]@($MigrationNames)
      foreach ($name in $ordered) { assertText $name 'package migration name' }
      [Array]::Sort($ordered, [StringComparer]::Ordinal)
      $versions = [Collections.Generic.List[string]]::new()
      foreach ($name in $ordered) {
        $versionText = migrationVersion $name 'package migration'
        if ($versions.Count -gt 0 -and [string]::CompareOrdinal($versionText, $versions[$versions.Count - 1]) -le 0) {
          throw "Rehearsal boundary contract: package migration versions must be unique and ascending ('$name')."
        }
        $versions.Add($versionText)
      }
      $floorNames = @(for ($i = 0; $i -lt $ordered.Count; $i++) { if ([string]::CompareOrdinal($versions[$i], $floorVersion) -le 0) { $ordered[$i] } })
      if ($floorNames.Count -ne $result.FloorMigrationCount -or $versions -cnotcontains $floorVersion) {
        throw "Rehearsal boundary contract: the package must hold exactly $($result.FloorMigrationCount) migrations through the floor $floorVersion."
      }
      $aboveFloor = @($ordered | Select-Object -Skip $floorNames.Count)
      $head = $versions[$versions.Count - 1]
      $headBoundary = @($boundaries | Where-Object { $_.Version -ceq $head })
      if ($headBoundary.Count -ne 1) {
        throw "Rehearsal boundary contract: package head $head is not a contract boundary; selected fixture rehearsal does not support this manifest migration boundary."
      }
      $expectedAbove = @($boundaries | Where-Object { [string]::CompareOrdinal($_.Version, $head) -le 0 } | ForEach-Object { $_.NewMigrations })
      if (($aboveFloor -join '|') -cne ($expectedAbove -join '|')) {
        throw 'Rehearsal boundary contract: package migrations above the floor are not exactly the contract boundary migrations (extra, missing, renamed or reordered file).'
      }
      $result.MigrationNames = $ordered
      $result.MigrationVersions = $versions.ToArray()
      $result.TargetVersion = $head
    }
    [PSCustomObject]$result
  }
  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}
