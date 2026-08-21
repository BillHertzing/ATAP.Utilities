#Requires -Version 7.0
function New-ReleaseManifest {
  <#
.SYNOPSIS
    Generates a deterministic ReleaseBundle manifest v2.
.DESCRIPTION
    Emits an application-only v2 manifest with exact application provenance, a
    path-sorted payload inventory, machine-evaluable compatibility, and a reference
    to a separately promoted database package. No database payload or sidecar is emitted.
.PARAMETER Context
    Build context containing all immutable manifest inputs.
.PARAMETER OutputPath
    Optional output directory or explicit manifest.json path.
.OUTPUTS
    System.IO.FileInfo for the generated manifest.json.
#>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [PSCustomObject]$Context,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
  )

  begin {
    $fn = 'New-ReleaseManifest'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'
  }

  process {
    $getValue = {
      param([AllowNull()]$InputObject, [Parameter(Mandatory = $true)][string[]]$Names)
      foreach ($name in $Names) {
        if ($null -eq $InputObject) { continue }
        if ($InputObject -is [System.Collections.IDictionary]) {
          $key = @($InputObject.Keys | Where-Object { [string]$_ -ieq $name } | Select-Object -First 1)
          if ($key.Count -gt 0) { return $InputObject[$key[0]] }
        } else {
          $property = $InputObject.PSObject.Properties |
            Where-Object { $_.Name -ieq $name } |
            Select-Object -First 1
          if ($null -ne $property) { return $property.Value }
        }
      }
      return $null
    }

    $hasProperty = {
      param([AllowNull()]$InputObject, [Parameter(Mandatory = $true)][string[]]$Names)
      if ($null -eq $InputObject) { return $false }
      foreach ($name in $Names) {
        if ($InputObject -is [System.Collections.IDictionary]) {
          if (@($InputObject.Keys | Where-Object { [string]$_ -ieq $name }).Count -gt 0) { return $true }
        } elseif ($null -ne ($InputObject.PSObject.Properties | Where-Object { $_.Name -ieq $name } | Select-Object -First 1)) {
          return $true
        }
      }
      return $false
    }

    $requireString = {
      param([AllowNull()]$InputObject, [Parameter(Mandatory = $true)][string[]]$Names, [Parameter(Mandatory = $true)][string]$DisplayName)
      $value = & $getValue $InputObject $Names
      if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
        throw "Context is missing required field '$DisplayName'."
      }
      return ([string]$value).Trim()
    }

    $asArray = {
      param([AllowNull()]$Value)
      if ($null -eq $Value) { return @() }
      if ($Value -is [string]) { return @($Value) }
      if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [System.Collections.IDictionary])) { return @($Value) }
      return @($Value)
    }

    $relativePath = {
      param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$FieldName)
      $normalized = $Path.Trim().Replace([char]92, [char]47)
      if ([string]::IsNullOrWhiteSpace($normalized) -or [IO.Path]::IsPathRooted($normalized) -or $normalized -match '(^|/)\.\.(/|$)') {
        throw "Context field '$FieldName' contains unsafe path '$Path'."
      }
      if ($normalized -match '^(?i:db)(/|$)' -or (Split-Path -Leaf $normalized) -ieq 'db-manifest.json') {
        throw "Context field '$FieldName' contains forbidden embedded database payload '$Path'."
      }
      return $normalized
    }

    $requireBoolean = {
      param([AllowNull()]$InputObject, [Parameter(Mandatory = $true)][string[]]$Names, [Parameter(Mandatory = $true)][string]$DisplayName)
      if (-not (& $hasProperty $InputObject $Names)) { throw "Context is missing required field '$DisplayName'." }
      $value = & $getValue $InputObject $Names
      if ($value -is [bool]) { return $value }
      $parsed = $false
      if (-not [bool]::TryParse([string]$value, [ref]$parsed)) { throw "Context field '$DisplayName' must be a boolean." }
      return $parsed
    }

    $sortOrdinal = {
      param([AllowNull()]$Values)
      [string[]]$items = @((& $asArray $Values) | ForEach-Object { [string]$_ })
      [Array]::Sort($items, [StringComparer]::Ordinal)
      return @($items)
    }

    $normalizePackages = {
      param([AllowNull()]$Value, [Parameter(Mandatory = $true)][string]$DisplayName)
      $map = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
      foreach ($item in (& $asArray $Value)) {
        $id = & $requireString $item @('id', 'packageId') "$DisplayName.id"
        $version = & $requireString $item @('version', 'packageVersion') "$DisplayName.version"
        $key = $id + [char]0 + $version
        if (-not $map.TryAdd($key, [ordered]@{ id = $id; version = $version })) {
          throw "Context field '$DisplayName' contains duplicate package '$id' version '$version'."
        }
      }
      [string[]]$keys = @($map.Keys)
      [Array]::Sort($keys, [StringComparer]::Ordinal)
      return @($keys | ForEach-Object { $map[$_] })
    }

    $payloadMap = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in (& $asArray (& $getValue $Context @('PayloadFiles', 'ApplicationPayloadFiles', 'PublishManifest')))) {
      $path = & $relativePath (& $requireString $item @('path') 'PayloadFiles.path') 'PayloadFiles.path'
      $checksum = (& $requireString $item @('checksumSha256', 'checksum', 'hash') 'PayloadFiles.checksumSha256').ToLowerInvariant()
      if ($checksum.StartsWith('sha256:', [StringComparison]::Ordinal)) { $checksum = $checksum.Substring(7) }
      if ($checksum -notmatch '^[0-9a-f]{64}$') { throw "Payload file '$path' has an invalid SHA-256 checksum." }
      $sizeValue = & $getValue $item @('sizeBytes', 'size')
      [long]$sizeBytes = 0
      if ($null -eq $sizeValue -or -not [long]::TryParse([string]$sizeValue, [ref]$sizeBytes) -or $sizeBytes -le 0) {
        throw "Payload file '$path' must declare a positive sizeBytes value."
      }
      if (-not $payloadMap.TryAdd($path, [ordered]@{ path = $path; checksumSha256 = $checksum; sizeBytes = $sizeBytes })) {
        throw "PayloadFiles contains a duplicate or case-colliding path '$path'."
      }
    }
    if ($payloadMap.Count -eq 0) { throw "Context field 'PayloadFiles' must contain at least one file." }
    [string[]]$payloadPaths = @($payloadMap.Keys)
    [Array]::Sort($payloadPaths, [StringComparer]::Ordinal)
    [object[]]$payloadFiles = @($payloadPaths | ForEach-Object { $payloadMap[$_] })

    [string[]]$installerScripts = @((& $asArray (& $getValue $Context @('InstallerScripts'))) | ForEach-Object {
        & $relativePath ([string]$_) 'InstallerScripts'
      })
    [Array]::Sort($installerScripts, [StringComparer]::Ordinal)
    if ($installerScripts.Count -eq 0) { throw "Context field 'InstallerScripts' must contain at least one path." }
    foreach ($path in $installerScripts) {
      if (-not $payloadMap.ContainsKey($path)) { throw "Installer script '$path' is not present in PayloadFiles." }
    }

    $evidenceMap = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($item in (& $asArray (& $getValue $Context @('TestEvidence')))) {
      $kind = & $requireString $item @('kind') 'TestEvidence.kind'
      $path = & $relativePath (& $requireString $item @('path') 'TestEvidence.path') 'TestEvidence.path'
      $checksum = (& $requireString $item @('checksumSha256', 'checksum') 'TestEvidence.checksumSha256').ToLowerInvariant()
      if ($checksum.StartsWith('sha256:', [StringComparison]::Ordinal)) { $checksum = $checksum.Substring(7) }
      if ($checksum -notmatch '^[0-9a-f]{64}$') { throw "Test evidence '$path' has an invalid SHA-256 checksum." }
      if (-not $payloadMap.ContainsKey($path)) { throw "Test evidence '$path' is not present in PayloadFiles." }
      $key = $path + [char]0 + $kind
      if (-not $evidenceMap.TryAdd($key, [ordered]@{ kind = $kind; path = $path; checksumSha256 = $checksum })) {
        throw "TestEvidence contains duplicate kind/path '$kind'/'$path'."
      }
    }
    if ($evidenceMap.Count -eq 0) { throw "Context field 'TestEvidence' must contain at least one entry." }
    [string[]]$evidenceKeys = @($evidenceMap.Keys)
    [Array]::Sort($evidenceKeys, [StringComparer]::Ordinal)
    [object[]]$testEvidence = @($evidenceKeys | ForEach-Object { $evidenceMap[$_] })

    $repoRoot = & $requireString $Context @('RepoRoot', 'RepositoryRoot', 'RootPath') 'RepoRoot'
    $releaseVersion = & $requireString $Context @('ResolvedPackageVersion', 'ReleaseVersion', 'AppPackageVersion') 'ResolvedPackageVersion'
    $sourceTag = & $requireString $Context @('SourceTag', 'ReleaseTag') 'SourceTag'
    $sourceCommit = (& $requireString $Context @('SourceCommit', 'GitSha', 'GitCommit', 'CommitSha') 'SourceCommit').ToLowerInvariant()
    $sourceBranch = & $requireString $Context @('Branch', 'SourceBranch') 'Branch'
    $buildAgent = & $requireString $Context @('BuildAgent') 'BuildAgent'
    $buildUtcText = & $requireString $Context @('BuildUtc') 'BuildUtc'
    [datetimeoffset]$buildUtcValue = [datetimeoffset]::MinValue
    if (-not $buildUtcText.EndsWith('Z', [StringComparison]::Ordinal) -or
        -not [datetimeoffset]::TryParse($buildUtcText, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$buildUtcValue) -or
        $buildUtcValue.Offset -ne [timespan]::Zero) {
      throw "Context field 'BuildUtc' must be an explicit UTC date-time."
    }
    $buildUtc = $buildUtcValue.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ', [Globalization.CultureInfo]::InvariantCulture)

    $application = & $getValue $Context @('ApplicationProvenance')
    if ($null -eq $application) { throw "Context is missing required field 'ApplicationProvenance'." }
    $productId = & $requireString $application @('productId', 'ProductId') 'ApplicationProvenance.productId'
    $normalizeApplicationComponent = {
      param([AllowNull()]$InputObject, [Parameter(Mandatory = $true)][string]$DisplayName)
      if ($null -eq $InputObject) { throw "Context is missing required field '$DisplayName'." }
      $qualityTier = & $requireString $InputObject @('qualityTier', 'QualityTier') "$DisplayName.qualityTier"
      if ($qualityTier -cne 'Production') { throw "Context field '$DisplayName.qualityTier' must be 'Production'." }
      $rawProjectPath = & $requireString $InputObject @('projectPath', 'ProjectPath') "$DisplayName.projectPath"
      if ($rawProjectPath.Contains([char]92)) { throw "Context field '$DisplayName.projectPath' must use forward slashes." }
      return [ordered]@{
        id = & $requireString $InputObject @('id', 'Id') "$DisplayName.id"
        version = & $requireString $InputObject @('version', 'Version') "$DisplayName.version"
        qualityTier = $qualityTier
        projectPath = & $relativePath $rawProjectPath "$DisplayName.projectPath"
      }
    }
    $applicationRoot = & $normalizeApplicationComponent (& $getValue $application @('root', 'Root')) 'ApplicationProvenance.root'
    $componentIdSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $componentPathSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $componentMap = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($item in (& $asArray (& $getValue $application @('components', 'Components')))) {
      $component = & $normalizeApplicationComponent $item 'ApplicationProvenance.components'
      if (-not $componentIdSet.Add([string]$component.id)) { throw "ApplicationProvenance.components contains duplicate id '$($component.id)'." }
      if (-not $componentPathSet.Add([string]$component.projectPath)) { throw "ApplicationProvenance.components contains duplicate or case-colliding projectPath '$($component.projectPath)'." }
      if ([string]$component.id -ieq [string]$applicationRoot.id -or [string]$component.projectPath -ieq [string]$applicationRoot.projectPath) {
        throw "ApplicationProvenance.components duplicates the application root '$($component.id)'/'$($component.projectPath)'."
      }
      $componentKey = [string]$component.projectPath + [char]0 + [string]$component.id
      $componentMap.Add($componentKey, $component)
    }
    [string[]]$componentKeys = @($componentMap.Keys)
    [Array]::Sort($componentKeys, [StringComparer]::Ordinal)
    [object[]]$components = @($componentKeys | ForEach-Object { $componentMap[$_] })
    if (-not (& $hasProperty $application @('runtimeIdentifier', 'RuntimeIdentifier'))) {
      throw "Context is missing required field 'ApplicationProvenance.runtimeIdentifier'; use null for a RID-less publish."
    }
    $runtimeIdentifier = & $getValue $application @('runtimeIdentifier', 'RuntimeIdentifier')
    if ($null -ne $runtimeIdentifier -and [string]::IsNullOrWhiteSpace([string]$runtimeIdentifier)) { $runtimeIdentifier = $null }
    elseif ($null -ne $runtimeIdentifier) { $runtimeIdentifier = [string]$runtimeIdentifier }
    $publishSettings = & $getValue $application @('publishSettings', 'PublishSettings')
    if ($null -eq $publishSettings) { throw "Context is missing required field 'ApplicationProvenance.publishSettings'." }

    $database = & $getValue $Context @('DatabasePackageReference')
    if ($null -eq $database) { $database = $Context }
    $compatibility = & $getValue $Context @('Compatibility')
    if ($null -eq $compatibility) { throw "Context is missing required field 'Compatibility'." }
    $rollback = & $getValue $Context @('Rollback')
    if ($null -eq $rollback) { throw "Context is missing required field 'Rollback'." }
    [string[]]$osFamilies = @(& $sortOrdinal (& $asArray (& $getValue $compatibility @('osFamilies', 'OsFamilies'))))
    if ($osFamilies.Count -eq 0) { throw "Context field 'Compatibility.osFamilies' must contain at least one value." }
    [string[]]$runtimeIdentifiers = @(& $sortOrdinal (& $asArray (& $getValue $compatibility @('runtimeIdentifiers', 'RuntimeIdentifiers'))))

    $manifest = [ordered]@{
      schemaVersion = 2
      releaseVersion = $releaseVersion
      sourceTag = $sourceTag
      sourceCommit = $sourceCommit
      sourceBranch = $sourceBranch
      buildUtc = $buildUtc
      buildAgent = $buildAgent
      applicationProvenance = [ordered]@{
        productId = $productId
        root = $applicationRoot
        components = @($components)
        artifactKind = & $requireString $application @('artifactKind', 'ArtifactKind') 'ApplicationProvenance.artifactKind'
        configuration = & $requireString $application @('configuration', 'Configuration') 'ApplicationProvenance.configuration'
        targetFramework = & $requireString $application @('targetFramework', 'TargetFramework') 'ApplicationProvenance.targetFramework'
        runtimeIdentifier = $runtimeIdentifier
        publishSettings = [ordered]@{
          selfContained = & $requireBoolean $publishSettings @('selfContained', 'SelfContained') 'ApplicationProvenance.publishSettings.selfContained'
          publishSingleFile = & $requireBoolean $publishSettings @('publishSingleFile', 'PublishSingleFile') 'ApplicationProvenance.publishSettings.publishSingleFile'
          publishTrimmed = & $requireBoolean $publishSettings @('publishTrimmed', 'PublishTrimmed') 'ApplicationProvenance.publishSettings.publishTrimmed'
          useAppHost = & $requireBoolean $publishSettings @('useAppHost', 'UseAppHost') 'ApplicationProvenance.publishSettings.useAppHost'
        }
      }
      includedLibraryPackages = @(& $normalizePackages (& $getValue $Context @('IncludedLibraryPackages', 'LibraryPackages')) 'IncludedLibraryPackages')
      includedPowerShellModules = @(& $normalizePackages (& $getValue $Context @('IncludedPowerShellModules', 'PowerShellModules')) 'IncludedPowerShellModules')
      databasePackageReference = [ordered]@{
        id = & $requireString $database @('id', 'DatabasePackageId') 'DatabasePackageReference.id'
        compatibleVersionRange = & $requireString $database @('compatibleVersionRange', 'CompatibleDatabaseVersionRange') 'DatabasePackageReference.compatibleVersionRange'
        pinnedVersion = & $requireString $database @('pinnedVersion', 'DatabasePackageVersion') 'DatabasePackageReference.pinnedVersion'
        lifecycleCeiling = & $requireString $database @('lifecycleCeiling', 'DatabasePackageCeiling') 'DatabasePackageReference.lifecycleCeiling'
      }
      payloadFiles = $payloadFiles
      installerScripts = @($installerScripts)
      testEvidence = $testEvidence
      compatibility = [ordered]@{
        osFamilies = @($osFamilies)
        runtimeIdentifiers = @($runtimeIdentifiers)
        dotnetRuntimeVersion = & $requireString $compatibility @('dotnetRuntimeVersion', 'RequiredDotnet') 'Compatibility.dotnetRuntimeVersion'
      }
      rollback = [ordered]@{
        supported = & $requireBoolean $rollback @('supported', 'Supported') 'Rollback.supported'
        notes = & $requireString $rollback @('notes', 'Notes') 'Rollback.notes'
      }
    }

    $json = ($manifest | ConvertTo-Json -Depth 20).Replace([string]([char]13 + [char]10), [string][char]10) + [char]10
    $schemaPath = & $getValue $Context @('ManifestSchemaPath', 'SchemaPath')
    if ([string]::IsNullOrWhiteSpace([string]$schemaPath)) { $schemaPath = Join-Path $repoRoot 'SolutionDocumentation/schemas/manifest.schema.json' }
    if (Test-Path -LiteralPath $schemaPath -PathType Leaf) {
      $validationErrors = $null
      if (-not (Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction SilentlyContinue -ErrorVariable validationErrors)) {
        $errorText = (@($validationErrors) | ForEach-Object { $_.ToString() }) -join '; '
        throw "Generated manifest does not validate against schema '$schemaPath'. $errorText"
      }
    }

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
      $outputDirectory = Join-Path $repoRoot "_generated/release-manifest/$releaseVersion"
      $outFile = Join-Path $outputDirectory 'manifest.json'
    } elseif ([IO.Path]::GetExtension($OutputPath) -ieq '.json') {
      $outFile = $OutputPath
      $outputDirectory = Split-Path -Parent $outFile
    } else {
      $outputDirectory = $OutputPath
      $outFile = Join-Path $outputDirectory 'manifest.json'
    }

    if (-not $PSCmdlet.ShouldProcess($outFile, 'Write deterministic ReleaseBundle manifest v2')) { return }
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    [IO.File]::WriteAllText($outFile, $json, [Text.UTF8Encoding]::new($false))
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Generated release manifest '$outFile'"
    return Get-Item -LiteralPath $outFile
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}