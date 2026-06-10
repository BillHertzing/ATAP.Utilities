#Requires -Version 7.0
function Test-DatabasePackageManifest {
  <#
.SYNOPSIS
    Validates a db-release-unit-manifest.json object against the v2 schema.

.DESCRIPTION
    Calls Get-DatabasePackageManifest (or accepts a pre-parsed object) and
    validates the required fields and allowed enum values defined by the v2 schema.
    Returns a structured result with IsValid and an Errors list.

.PARAMETER PackagePath
    Path to an expanded database change package folder.

.PARAMETER NupkgPath
    Path to a .nupkg file.

.PARAMETER ManifestObject
    A pre-parsed [PSCustomObject] representing the manifest.

.PARAMETER SchemaPath
    Optional path to db-release-unit.schema.json. Defaults to the canonical location
    relative to this module.

.OUTPUTS
    [PSCustomObject] @{ IsValid = [bool]; Errors = [string[]] }

.EXAMPLE
    Test-DatabasePackageManifest -PackagePath 'C:\packages\ATAPUtilities.Database.1.2.3'
#>
  [CmdletBinding(DefaultParameterSetName = 'FromFolder')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, ParameterSetName = 'FromFolder')]
    [ValidateNotNullOrEmpty()]
    [string]$PackagePath,

    [Parameter(Mandatory = $true, ParameterSetName = 'FromNupkg')]
    [ValidateNotNullOrEmpty()]
    [string]$NupkgPath,

    [Parameter(Mandatory = $true, ParameterSetName = 'FromObject')]
    [ValidateNotNull()]
    [PSCustomObject]$ManifestObject,

    [Parameter(Mandatory = $false)]
    [string]$SchemaPath
  )

  begin {
    $fn = 'Test-DatabasePackageManifest'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'

    if (-not $SchemaPath) {
      # Resolve from module location
      $SchemaPath = Join-Path $PSScriptRoot '..\..\..\..\SolutionDocumentation\schemas\db-release-unit.schema.json' -Resolve -ErrorAction SilentlyContinue
      if (-not $SchemaPath) {
        # Try relative navigation from public/
        $SchemaPath = Join-Path (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName `
          'SolutionDocumentation' 'schemas' 'db-release-unit.schema.json'
      }
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "SchemaPath=$SchemaPath" -Tag 'Config'
  }

  process {
    # Get the manifest object
    $manifest = $null
    if ($PSCmdlet.ParameterSetName -eq 'FromObject') {
      $manifest = $ManifestObject
    } elseif ($PSCmdlet.ParameterSetName -eq 'FromNupkg') {
      if (-not (Get-Command Get-DatabasePackageManifest -CommandType Function -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'Get-DatabasePackageManifest.ps1')
      }
      $manifest = Get-DatabasePackageManifest -NupkgPath $NupkgPath
    } else {
      if (-not (Get-Command Get-DatabasePackageManifest -CommandType Function -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'Get-DatabasePackageManifest.ps1')
      }
      $manifest = Get-DatabasePackageManifest -PackagePath $PackagePath
    }

    $errors = [System.Collections.Generic.List[string]]::new()

    # ── Required top-level fields ─────────────────────────────────────────────
    $requiredFields = @(
      'schemaVersion', 'dbChangeUnit', 'appVersion', 'changeKind',
      'flywayTargetVersion', 'createdUtc', 'createdFromGitTag', 'createdFromGitSha',
      'files', 'expectedRowCounts', 'compatibleAppPackageRanges',
      'requiresPreviousProductionSnapshot', 'rollbackSupported', 'rollbackNotes',
      'evidenceRequirements'
    )
    foreach ($field in $requiredFields) {
      if ($null -eq $manifest.$field -and -not ($manifest.PSObject.Properties.Name -contains $field)) {
        $errors.Add("Missing required field: $field")
      }
    }

    # ── schemaVersion must be 2 ────────────────────────────────────────────────
    if ($null -ne $manifest.schemaVersion -and $manifest.schemaVersion -ne 2) {
      $errors.Add("schemaVersion must be 2; got $($manifest.schemaVersion)")
    }

    # ── changeKind enum ────────────────────────────────────────────────────────
    $validChangeKinds = @('schema', 'data', 'schemaAndData')
    if ($manifest.changeKind -and $manifest.changeKind -notin $validChangeKinds) {
      $errors.Add("changeKind '$($manifest.changeKind)' is not one of: $($validChangeKinds -join ', ')")
    }

    # ── dataKind required when changeKind is data or schemaAndData ─────────────
    if ($manifest.changeKind -in @('data', 'schemaAndData')) {
      if (-not ($manifest.PSObject.Properties.Name -contains 'dataKind') -or -not $manifest.dataKind) {
        $errors.Add("dataKind is required when changeKind is '$($manifest.changeKind)'")
      }
    }
    $validDataKinds = @('staticReference', 'slowlyChangingSeed', 'repeatableLookup', 'fixture', 'migrationData')
    if ($manifest.dataKind -and $manifest.dataKind -notin $validDataKinds) {
      $errors.Add("dataKind '$($manifest.dataKind)' is not one of: $($validDataKinds -join ', ')")
    }

    # ── files array ────────────────────────────────────────────────────────────
    if ($null -ne $manifest.files) {
      $validKinds = @('migration', 'repeatable', 'seed', 'seedLoader')
      $validDestructive = @('none', 'columnDrop', 'tableDrop', 'columnTypeNarrow', 'dataDelete', 'indexDrop', 'constraintDrop')
      $idx = 0
      foreach ($f in $manifest.files) {
        if (-not $f.path) { $errors.Add("files[$idx]: missing 'path'") }
        if (-not $f.kind) { $errors.Add("files[$idx]: missing 'kind'") }
        if (-not $f.checksumSha256) { $errors.Add("files[$idx]: missing 'checksumSha256'") }
        if ($f.kind -and $f.kind -notin $validKinds) {
          $errors.Add("files[$idx]: kind '$($f.kind)' is not valid")
        }
        if ($f.kind -eq 'migration') {
          if (-not ($f.PSObject.Properties.Name -contains 'destructiveChangeKind')) {
            $errors.Add("files[$idx]: migration must have 'destructiveChangeKind'")
          } elseif ($f.destructiveChangeKind -notin $validDestructive) {
            $errors.Add("files[$idx]: destructiveChangeKind '$($f.destructiveChangeKind)' is not valid")
          }
        }
        $idx++
      }
    }

    # ── evidenceRequirements tiers ─────────────────────────────────────────────
    if ($manifest.evidenceRequirements) {
      $requiredTiers = @('experimental', 'development', 'integration', 'qa', 'stable')
      foreach ($tier in $requiredTiers) {
        if (-not ($manifest.evidenceRequirements.PSObject.Properties.Name -contains $tier)) {
          $errors.Add("evidenceRequirements missing tier: $tier")
        }
      }
    }

    $isValid = $errors.Count -eq 0
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Validation complete: IsValid=$isValid Errors=$($errors.Count)" -Tag 'Output'

    Write-Output ([PSCustomObject]@{
        IsValid = $isValid
        Errors  = $errors.ToArray()
      })
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}
