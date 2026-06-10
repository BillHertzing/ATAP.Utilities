#Requires -Version 7.0
function New-ReleaseManifest {
  <#
.SYNOPSIS
    Generates the Release Bundle manifest.json from a build context and DB
    release-unit YAML.

.DESCRIPTION
    New-ReleaseManifest reads the DB release-unit declaration for the
    application/version in the supplied Get-BuildContext output, computes
    SHA-256 checksums for every referenced migration, repeatable, seed, and
    seed-loader file, and writes a schema-valid manifest.json for
    New-ReleaseBundle.

    YAML parsing uses ConvertFrom-Yaml when it is available. When it is not,
    the cmdlet supports the simple documented db/<App>/releases/<version>.yml
    shape from Database-Change-Unit-and-Flyway-Promotion.md section 2. Use
    YamlParserMode to force deterministic parser selection when needed.

.PARAMETER Context
    PSCustomObject build context, normally returned by Get-BuildContext.

.PARAMETER OutputPath
    Optional output directory, or an explicit manifest.json path. Defaults to
    _generated/release-manifest/<Version>/manifest.json under Context.RepoRoot.

.PARAMETER YamlParserMode
    Controls DB release YAML parsing. Auto uses ConvertFrom-Yaml when available
    and falls back to the built-in simple parser. Simple always uses the built-in
    parser. Command requires ConvertFrom-Yaml.

.OUTPUTS
    [System.IO.FileInfo] for the generated manifest.json.
#>
  [CmdletBinding()]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [PSCustomObject]$Context,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Auto', 'Simple', 'Command')]
    [string]$YamlParserMode = 'Auto'
  )

  begin {
    $fn = 'New-ReleaseManifest'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'
  }

  process {
    $getContextValue = {
      param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $InputObject,
        [Parameter(Mandatory = $true)][string[]]$Names
      )

      foreach ($name in $Names) {
        if ($null -eq $InputObject) { continue }
        if ($InputObject -is [System.Collections.IDictionary]) {
          if ($InputObject.Contains($name)) { return $InputObject[$name] }
          $matchingKey = @($InputObject.Keys | Where-Object { [string]$_ -ieq $name } | Select-Object -First 1)
          if ($matchingKey.Count -gt 0) { return $InputObject[$matchingKey[0]] }
          continue
        }

        $property = $InputObject.PSObject.Properties |
          Where-Object { $_.Name -ieq $name } |
          Select-Object -First 1
        if ($null -ne $property) { return $property.Value }
      }

      return $null
    }

    $requireContextValue = {
      param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string[]]$Names,
        [Parameter(Mandatory = $true)][string]$DisplayName
      )

      $value = & $getContextValue $InputObject $Names
      if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
        throw "Context is missing required field '$DisplayName'. New-ReleaseManifest expects the output of Get-BuildContext or equivalent fields."
      }

      return [string]$value
    }

    $stripQuotes = {
      param([AllowNull()][string]$Value)
      if ($null -eq $Value) { return $null }
      $trimmed = $Value.Trim()
      if (($trimmed.StartsWith("'") -and $trimmed.EndsWith("'")) -or
          ($trimmed.StartsWith('"') -and $trimmed.EndsWith('"'))) {
        return $trimmed.Substring(1, $trimmed.Length - 2)
      }
      return $trimmed
    }

    $parseScalar = {
      param([AllowNull()][string]$Value)
      $unquoted = & $stripQuotes $Value
      if ($null -eq $unquoted) { return $null }
      if ($unquoted -match '^-?\d+$') { return [int]$unquoted }
      if ($unquoted -match '^(?i:true|false)$') { return [bool]::Parse($unquoted) }
      return $unquoted
    }

    $parseSimpleYaml = {
      param([Parameter(Mandatory = $true)][string]$Yaml)

      $result = [ordered]@{}
      $arrayKeys = @('migrations', 'repeatables', 'seedFiles', 'seedLoaders')
      $mapKeys = @('expectedRowCounts')
      $currentKey = $null
      $blockKey = $null
      $blockLines = [System.Collections.Generic.List[string]]::new()

      foreach ($rawLine in ($Yaml -split "`r?`n")) {
        if ($null -ne $blockKey) {
          if ($rawLine -match '^\s{2,}(?<text>.*)$') {
            $blockLines.Add($Matches['text'])
            continue
          }
          if ([string]::IsNullOrWhiteSpace($rawLine)) {
            $blockLines.Add('')
            continue
          }

          $result[$blockKey] = ($blockLines -join [Environment]::NewLine).TrimEnd()
          $blockKey = $null
          $blockLines.Clear()
        }

        $line = $rawLine.TrimEnd()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
          continue
        }

        if ($line -match '^(?<key>[A-Za-z][A-Za-z0-9_]*)\s*:\s*(?<value>.*)$') {
          $currentKey = $Matches['key']
          $value = $Matches['value']

          if ($value.Trim() -eq '|') {
            $blockKey = $currentKey
            continue
          }

          if ([string]::IsNullOrWhiteSpace($value)) {
            if ($arrayKeys -contains $currentKey) {
              $result[$currentKey] = @()
            } elseif ($mapKeys -contains $currentKey) {
              $result[$currentKey] = [ordered]@{}
            } else {
              $result[$currentKey] = ''
            }
            continue
          }

          $result[$currentKey] = & $parseScalar $value
          continue
        }

        if ($line -match '^\s*-\s*(?<value>.+)$') {
          if ([string]::IsNullOrWhiteSpace($currentKey)) {
            throw "Unable to parse DB release YAML: list item '$line' appears before a key."
          }

          if (-not $result.Contains($currentKey) -or $null -eq $result[$currentKey]) {
            $result[$currentKey] = @()
          }
          if (-not ($result[$currentKey] -is [System.Collections.IEnumerable]) -or $result[$currentKey] -is [string] -or $result[$currentKey] -is [System.Collections.IDictionary]) {
            throw "Unable to parse DB release YAML: key '$currentKey' is not a list."
          }

          $result[$currentKey] = @($result[$currentKey]) + @((& $parseScalar $Matches['value']))
          continue
        }

        if ($line -match '^\s+(?<key>[^:]+):\s*(?<value>.+)$') {
          if ([string]::IsNullOrWhiteSpace($currentKey)) {
            throw "Unable to parse DB release YAML: nested mapping '$line' appears before a key."
          }
          if (-not $result.Contains($currentKey) -or -not ($result[$currentKey] -is [System.Collections.IDictionary])) {
            $result[$currentKey] = [ordered]@{}
          }

          $nestedKey = (& $stripQuotes $Matches['key'])
          $result[$currentKey][$nestedKey] = & $parseScalar $Matches['value']
          continue
        }

        throw "Unable to parse DB release YAML line: '$rawLine'"
      }

      if ($null -ne $blockKey) {
        $result[$blockKey] = ($blockLines -join [Environment]::NewLine).TrimEnd()
      }

      return [PSCustomObject]$result
    }

    $readDbRelease = {
      param(
        [Parameter(Mandatory = $true)][string]$YamlPath
      )

      $yamlText = Get-Content -LiteralPath $YamlPath -Raw
      if ([string]::IsNullOrWhiteSpace($yamlText)) {
        throw "DB release YAML is empty: '$YamlPath'."
      }

      $convertFromYaml = $null
      if ($YamlParserMode -ne 'Simple') {
        $convertFromYaml = Get-Command -Name 'ConvertFrom-Yaml' -ErrorAction SilentlyContinue
      }

      if ($YamlParserMode -eq 'Command' -and $null -eq $convertFromYaml) {
        throw "YamlParserMode 'Command' requires ConvertFrom-Yaml, but ConvertFrom-Yaml was not found."
      }

      if ($null -ne $convertFromYaml) {
        return (ConvertFrom-Yaml -Yaml $yamlText)
      }

      return (& $parseSimpleYaml $yamlText)
    }

    $asArray = {
      param([AllowNull()]$Value)
      if ($null -eq $Value) { return @() }
      if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
        return @($Value)
      }
      if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [System.Collections.IDictionary])) {
        return @($Value)
      }
      return @($Value)
    }

    $normalizePackageReferences = {
      param([AllowNull()]$Value, [Parameter(Mandatory = $true)][string]$ContextName)
      $references = @()
      foreach ($item in (& $asArray $Value)) {
        $id = & $getContextValue $item @('id', 'Id', 'name', 'Name', 'packageId', 'PackageId')
        $version = & $getContextValue $item @('version', 'Version', 'packageVersion', 'PackageVersion')
        if ([string]::IsNullOrWhiteSpace([string]$id) -or [string]::IsNullOrWhiteSpace([string]$version)) {
          throw "Context field '$ContextName' contains a package reference without both id and version."
        }
        $references += [ordered]@{
          id      = [string]$id
          version = [string]$version
        }
      }
      return @($references)
    }

    $normalizeTestEvidence = {
      param([AllowNull()]$Value, [Parameter(Mandatory = $true)][string]$RepoRoot)
      $evidence = @()
      foreach ($item in (& $asArray $Value)) {
        $kind = & $getContextValue $item @('kind', 'Kind')
        $path = & $getContextValue $item @('path', 'Path')
        $checksum = & $getContextValue $item @('checksumSha256', 'ChecksumSha256', 'checksum', 'Checksum')
        if ([string]::IsNullOrWhiteSpace([string]$kind) -or [string]::IsNullOrWhiteSpace([string]$path)) {
          throw "Context field 'TestEvidence' contains an entry without both kind and path."
        }

        if ([string]::IsNullOrWhiteSpace([string]$checksum)) {
          $candidate = if ([System.IO.Path]::IsPathRooted([string]$path)) { [string]$path } else { Join-Path -Path $RepoRoot -ChildPath ([string]$path) }
          if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw "Test evidence '$path' did not include checksumSha256, and the file was not found at '$candidate'."
          }
          $checksum = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
        }

        $checksumText = [string]$checksum
        if ($checksumText.StartsWith('sha256:', [StringComparison]::OrdinalIgnoreCase)) {
          $checksumText = $checksumText.Substring(7)
        }

        $evidence += [ordered]@{
          kind           = [string]$kind
          path           = ([string]$path).Replace('\', '/')
          checksumSha256 = $checksumText
        }
      }

      if ($evidence.Count -eq 0) {
        $evidence += [ordered]@{
          kind           = 'pending'
          path           = 'tests/release-validation.pending'
          checksumSha256 = '...'
        }
      }

      return @($evidence)
    }

    $normalizeBool = {
      param([AllowNull()]$Value, [bool]$Default)
      if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $Default }
      if ($Value -is [bool]) { return $Value }
      return [bool]::Parse([string]$Value)
    }

    $normalizeRelativePath = {
      param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$FieldName
      )

      $normalized = $Path.Trim().Replace('\', '/')
      if ([string]::IsNullOrWhiteSpace($normalized)) {
        throw "DB release YAML field '$FieldName' contains an empty path."
      }
      if ([System.IO.Path]::IsPathRooted($normalized) -or $normalized -match '(^|/)\.\.(/|$)') {
        throw "DB release YAML field '$FieldName' contains unsafe path '$Path'. Paths must be relative and must not contain '..'."
      }
      return $normalized
    }

    $resolveDbFile = {
      param(
        [Parameter(Mandatory = $true)][string]$Entry,
        [Parameter(Mandatory = $true)][string]$KindSubdirectory,
        [Parameter(Mandatory = $true)][string]$FieldName,
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Application,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$DbApplicationRoot
      )

      $entryPath = & $normalizeRelativePath $Entry $FieldName
      $leafPath = if ($entryPath -match "^db/[^/]+/$KindSubdirectory/(?<rest>.+)$") {
        $Matches['rest']
      } elseif ($entryPath -match "^db/$KindSubdirectory/(?<rest>.+)$") {
        $Matches['rest']
      } elseif ($entryPath -match "^$KindSubdirectory/(?<rest>.+)$") {
        $Matches['rest']
      } elseif ($entryPath -match '^db/(?<rest>.+)$') {
        $Matches['rest']
      } else {
        $entryPath
      }

      $manifestPath = "db/$KindSubdirectory/$leafPath"
      $sourceCandidates = @(
        (Join-Path -Path $DbApplicationRoot -ChildPath (Join-Path -Path $KindSubdirectory -ChildPath $leafPath)),
        (Join-Path -Path $RepoRoot -ChildPath $entryPath)
      )
      $sourcePath = $sourceCandidates[0]
      foreach ($candidate in $sourceCandidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
          $sourcePath = $candidate
          break
        }
      }

      if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Referenced DB file not found for '$FieldName': '$Entry'. Tried '$sourcePath'."
      }

      return [PSCustomObject]@{
        SourcePath   = $sourcePath
        ManifestPath = $manifestPath
        Kind         = $Kind
      }
    }

    $getObjectMap = {
      param([AllowNull()]$Value)

      $map = [ordered]@{}
      if ($null -eq $Value) { return $map }
      if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
          $map[[string]$key] = [int]$Value[$key]
        }
        return $map
      }

      foreach ($property in $Value.PSObject.Properties) {
        if ($property.MemberType -in 'NoteProperty', 'Property') {
          $map[[string]$property.Name] = [int]$property.Value
        }
      }
      return $map
    }

    $repoRoot = & $requireContextValue $Context @('RepoRoot', 'RepositoryRoot', 'RootPath') 'RepoRoot'
    $application = & $requireContextValue $Context @('Application', 'App', 'AppPackageId') 'Application'
    $majorMinorPatch = & $requireContextValue $Context @('MajorMinorPatch', 'AppVersion') 'MajorMinorPatch'
    $releaseVersion = & $requireContextValue $Context @('ResolvedPackageVersion', 'ReleaseVersion', 'AppPackageVersion') 'ResolvedPackageVersion'
    $sourceTag = & $requireContextValue $Context @('SourceTag', 'ReleaseTag') 'SourceTag'
    $sourceCommit = & $requireContextValue $Context @('SourceCommit', 'GitSha', 'GitCommit', 'CommitSha') 'SourceCommit'
    $sourceBranch = & $requireContextValue $Context @('Branch', 'SourceBranch') 'Branch'

    $explicitDbRelease = & $getContextValue $Context @('DbReleaseUnit', 'DbReleaseManifest', 'DbRelease')
    $dbReleaseYamlPath = & $getContextValue $Context @('DbReleaseUnitPath', 'DbReleaseYamlPath', 'DbReleasePath')
    if ([string]::IsNullOrWhiteSpace([string]$dbReleaseYamlPath)) {
      $dbReleaseYamlPath = Join-Path -Path $repoRoot -ChildPath ("db/{0}/releases/{1}.yml" -f $application, $majorMinorPatch)
    }

    $dbApplicationRoot = & $getContextValue $Context @('DbApplicationRootPath', 'DbRootPath')
    if ([string]::IsNullOrWhiteSpace([string]$dbApplicationRoot)) {
      if (-not [string]::IsNullOrWhiteSpace([string]$dbReleaseYamlPath) -and
          ([string]$dbReleaseYamlPath -match '[/\\]releases[/\\][^/\\]+\.ya?ml$')) {
        $dbApplicationRoot = Split-Path -Parent (Split-Path -Parent ([string]$dbReleaseYamlPath))
      } else {
        $dbApplicationRoot = Join-Path -Path $repoRoot -ChildPath ("db/{0}" -f $application)
      }
    }

    if ($null -ne $explicitDbRelease) {
      $dbRelease = $explicitDbRelease
    } elseif (-not [string]::IsNullOrWhiteSpace([string](& $getContextValue $Context @('DbChangeUnit'))) -or
              -not [string]::IsNullOrWhiteSpace([string](& $getContextValue $Context @('FlywayTargetVersion')))) {
      $dbRelease = [PSCustomObject]@{
        appVersion          = $majorMinorPatch
        dbChangeUnit        = & $getContextValue $Context @('DbChangeUnit')
        flywayTargetVersion = & $getContextValue $Context @('FlywayTargetVersion')
        migrations          = & $getContextValue $Context @('Migrations', 'MigrationFiles')
        repeatables         = & $getContextValue $Context @('Repeatables', 'RepeatableFiles')
        seedFiles           = & $getContextValue $Context @('SeedFiles')
        seedLoaders         = & $getContextValue $Context @('SeedLoaders', 'SeedLoaderScripts')
        expectedRowCounts   = & $getContextValue $Context @('ExpectedRowCounts')
        notes               = & $getContextValue $Context @('Notes')
      }
    } else {
      if (-not (Test-Path -LiteralPath $dbReleaseYamlPath -PathType Leaf)) {
        throw "DB release YAML not found: $dbReleaseYamlPath. See Database-Change-Unit-and-Flyway-Promotion.md section 2."
      }
      $dbRelease = & $readDbRelease $dbReleaseYamlPath
    }

    foreach ($field in @('appVersion', 'dbChangeUnit', 'flywayTargetVersion', 'migrations', 'repeatables', 'seedFiles', 'seedLoaders', 'expectedRowCounts', 'notes')) {
      $value = & $getContextValue $dbRelease @($field)
      if ($null -eq $value) {
        throw "DB release data is missing required field '$field'. Source: '$dbReleaseYamlPath'."
      }
    }

    $dbAppVersion = [string](& $getContextValue $dbRelease @('appVersion'))
    if ($dbAppVersion -ne $majorMinorPatch) {
      throw "DB release appVersion '$dbAppVersion' does not match context MajorMinorPatch '$majorMinorPatch'."
    }

    $migrations = @(& $asArray (& $getContextValue $dbRelease @('migrations')))
    $repeatables = @(& $asArray (& $getContextValue $dbRelease @('repeatables')))
    $seedFiles = @(& $asArray (& $getContextValue $dbRelease @('seedFiles')))
    $seedLoaders = @(& $asArray (& $getContextValue $dbRelease @('seedLoaders')))

    $resolvedDbFiles = @()
    foreach ($entry in $migrations) {
      $entryLeaf = (([string]$entry).Replace('\', '/') -split '/')[-1]
      $kind = if ($entryLeaf -like 'R__*') { 'repeatable' } else { 'migration' }
      $resolvedDbFiles += & $resolveDbFile ([string]$entry) 'flyway' 'migrations' $kind $application $repoRoot $dbApplicationRoot
    }
    foreach ($entry in $repeatables) {
      $resolvedDbFiles += & $resolveDbFile ([string]$entry) 'flyway' 'repeatables' 'repeatable' $application $repoRoot $dbApplicationRoot
    }
    foreach ($entry in $seedFiles) {
      $resolvedDbFiles += & $resolveDbFile ([string]$entry) 'seed' 'seedFiles' 'seed' $application $repoRoot $dbApplicationRoot
    }
    foreach ($entry in $seedLoaders) {
      $resolvedDbFiles += & $resolveDbFile ([string]$entry) 'seed' 'seedLoaders' 'seedLoader' $application $repoRoot $dbApplicationRoot
    }

    $checksums = [ordered]@{}
    foreach ($file in $resolvedDbFiles) {
      $hash = (Get-FileHash -LiteralPath $file.SourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
      $checksums[$file.ManifestPath] = "sha256:$hash"
    }

    $defaultInstallerScripts = @(
      'installer/Install-Application.ps1',
      'installer/Update-Application.ps1',
      'installer/Test-InstallPrerequisites.ps1'
    )
    $installerScripts = & $getContextValue $Context @('InstallerScripts', 'InstallScripts')
    if ($null -eq $installerScripts) { $installerScripts = $defaultInstallerScripts }
    [object[]]$installerScripts = @((& $asArray $installerScripts) | ForEach-Object { ([string]$_).Replace('\', '/') })

    [object[]]$libraryPackages = @(& $normalizePackageReferences (& $getContextValue $Context @('IncludedLibraryPackages', 'LibraryPackages')) 'IncludedLibraryPackages')
    [object[]]$powerShellModules = @(& $normalizePackageReferences (& $getContextValue $Context @('IncludedPowerShellModules', 'PowerShellModules')) 'IncludedPowerShellModules')
    [object[]]$testEvidence = @(& $normalizeTestEvidence (& $getContextValue $Context @('TestEvidence', 'Tests')) $repoRoot)

    $compatibilityContext = & $getContextValue $Context @('Compatibility')
    $compatibility = [ordered]@{
      minDbVersion    = $dbAppVersion
      maxDbVersion    = [string](& $getContextValue $dbRelease @('flywayTargetVersion'))
      supportedOs     = @('Windows 10 1809+', 'Windows 11', 'Windows Server 2019+')
      requiredDotnet  = '10.0'
    }
    foreach ($name in @('minDbVersion', 'maxDbVersion', 'supportedOs', 'requiredDotnet')) {
      $value = & $getContextValue $compatibilityContext @($name)
      if ($null -eq $value) { $value = & $getContextValue $Context @($name) }
      if ($null -ne $value) {
        if ($name -eq 'supportedOs') {
          $compatibility[$name] = @(& $asArray $value)
        } else {
          $compatibility[$name] = [string]$value
        }
      }
    }

    $rollbackContext = & $getContextValue $Context @('Rollback')
    $rollbackSupported = & $getContextValue $rollbackContext @('supported', 'Supported')
    if ($null -eq $rollbackSupported) { $rollbackSupported = & $getContextValue $Context @('RollbackSupported') }
    $rollbackNotes = & $getContextValue $rollbackContext @('notes', 'Notes')
    if ([string]::IsNullOrWhiteSpace([string]$rollbackNotes)) { $rollbackNotes = & $getContextValue $Context @('RollbackNotes') }
    if ([string]::IsNullOrWhiteSpace([string]$rollbackNotes)) { $rollbackNotes = 'Rollback is not supported; restore from backup to downgrade.' }

    $buildUtcValue = & $getContextValue $Context @('BuildUtc')
    if ($null -eq $buildUtcValue) {
      $buildUtc = (Get-Date).ToUniversalTime().ToString('o')
    } elseif ($buildUtcValue -is [datetime]) {
      $buildUtc = $buildUtcValue.ToUniversalTime().ToString('o')
    } else {
      $buildUtc = [string]$buildUtcValue
    }

    $buildAgent = & $getContextValue $Context @('BuildAgent')
    if ([string]::IsNullOrWhiteSpace([string]$buildAgent)) {
      $buildAgent = [Environment]::MachineName
    }

    [object[]]$migrationManifestFiles = @($resolvedDbFiles | Where-Object { $_.Kind -in @('migration', 'repeatable') } | ForEach-Object { $_.ManifestPath })
    [object[]]$seedManifestFiles = @($resolvedDbFiles | Where-Object { $_.Kind -eq 'seed' } | ForEach-Object { $_.ManifestPath })
    [object[]]$seedLoaderManifestFiles = @($resolvedDbFiles | Where-Object { $_.Kind -eq 'seedLoader' } | ForEach-Object { $_.ManifestPath })

    $manifest = [ordered]@{
      schemaVersion               = 1
      releaseVersion              = $releaseVersion
      sourceTag                   = $sourceTag
      sourceCommit                = $sourceCommit
      sourceBranch                = $sourceBranch
      buildUtc                    = $buildUtc
      buildAgent                  = [string]$buildAgent
      appPackageId                = $application
      appPackageVersion           = $releaseVersion
      includedLibraryPackages     = $libraryPackages
      includedPowerShellModules   = $powerShellModules
      databasePackageIncluded     = $true
      dbChangeUnit                = [string](& $getContextValue $dbRelease @('dbChangeUnit'))
      flywayTargetVersion         = [string](& $getContextValue $dbRelease @('flywayTargetVersion'))
      migrationFiles              = $migrationManifestFiles
      seedFiles                   = $seedManifestFiles
      seedLoaderScripts           = $seedLoaderManifestFiles
      installerScripts            = $installerScripts
      testEvidence                = $testEvidence
      checksums                   = $checksums
      compatibility               = $compatibility
      rollback                    = [ordered]@{
        supported = & $normalizeBool $rollbackSupported $false
        notes     = [string]$rollbackNotes
      }
    }

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
      $outputDirectory = Join-Path -Path $repoRoot -ChildPath ("_generated/release-manifest/{0}" -f $releaseVersion)
      $outFile = Join-Path -Path $outputDirectory -ChildPath 'manifest.json'
    } elseif ([System.IO.Path]::GetExtension($OutputPath) -ieq '.json') {
      $outFile = $OutputPath
      $outputDirectory = Split-Path -Parent $outFile
    } else {
      $outputDirectory = $OutputPath
      $outFile = Join-Path -Path $outputDirectory -ChildPath 'manifest.json'
    }

    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    $json = $manifest | ConvertTo-Json -Depth 20
    Set-Content -LiteralPath $outFile -Value $json -Encoding UTF8

    $expectedRowCounts = & $getObjectMap (& $getContextValue $dbRelease @('expectedRowCounts'))
    $dbManifestFiles = @(
      foreach ($file in $resolvedDbFiles) {
        $checksum = [string]$checksums[$file.ManifestPath]
        if ($checksum.StartsWith('sha256:', [StringComparison]::OrdinalIgnoreCase)) {
          $checksum = $checksum.Substring(7)
        }
        [ordered]@{
          path           = ($file.ManifestPath -replace '^db/', '')
          kind           = $file.Kind
          checksumSha256 = $checksum
        }
      }
    )

    $dbManifest = [ordered]@{
      schemaVersion      = 1
      dbChangeUnit       = [string](& $getContextValue $dbRelease @('dbChangeUnit'))
      appVersion         = $dbAppVersion
      flywayTargetVersion = [string](& $getContextValue $dbRelease @('flywayTargetVersion'))
      createdUtc         = $buildUtc
      createdFromGitTag  = $sourceTag
      createdFromGitSha  = $sourceCommit
      files              = $dbManifestFiles
      expectedRowCounts  = $expectedRowCounts
      rollbackSupported  = & $normalizeBool $rollbackSupported $false
      rollbackNotes      = [string]$rollbackNotes
    }

    $dbManifestJson = $dbManifest | ConvertTo-Json -Depth 20
    $dbManifestOutFile = Join-Path -Path $outputDirectory -ChildPath 'db-manifest.json'
    Set-Content -LiteralPath $dbManifestOutFile -Value $dbManifestJson -Encoding UTF8

    $schemaPath = & $getContextValue $Context @('ManifestSchemaPath', 'SchemaPath')
    if ([string]::IsNullOrWhiteSpace([string]$schemaPath)) {
      $schemaPath = Join-Path -Path $repoRoot -ChildPath 'SolutionDocumentation/schemas/manifest.schema.json'
    }

    if (Test-Path -LiteralPath $schemaPath -PathType Leaf) {
      $validationErrors = $null
      $valid = Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction SilentlyContinue -ErrorVariable validationErrors
      if (-not $valid) {
        $errorText = (@($validationErrors) | ForEach-Object { $_.ToString() }) -join '; '
        throw "Generated manifest does not validate against schema '$schemaPath'. $errorText"
      }
    }

    $dbManifestSchemaPath = Join-Path -Path (Split-Path -Parent $schemaPath) -ChildPath 'db-manifest.schema.json'
    if (Test-Path -LiteralPath $dbManifestSchemaPath -PathType Leaf) {
      $validationErrors = $null
      $valid = Test-Json -Json $dbManifestJson -SchemaFile $dbManifestSchemaPath -ErrorAction SilentlyContinue -ErrorVariable validationErrors
      if (-not $valid) {
        $errorText = (@($validationErrors) | ForEach-Object { $_.ToString() }) -join '; '
        throw "Generated DB sub-manifest does not validate against schema '$dbManifestSchemaPath'. $errorText"
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Generated release manifest '$outFile'"
    return Get-Item -LiteralPath $outFile
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}
