#Requires -Version 7.0
function Test-DatabaseChangePackage {
  <#
.SYNOPSIS
    Full validation of a database change package: manifest, checksums, and ceiling policy.

.DESCRIPTION
    Combines Test-DatabasePackageManifest (structural manifest validation), SHA-256
    checksum re-computation against staged files, and an optional ceiling policy check
    (database-package-ceiling.json). Returns a structured result object.

.PARAMETER PackagePath
    Path to an expanded database change package folder.

.PARAMETER NupkgPath
    Path to a .nupkg file.

.PARAMETER DatabasePackageSourcePath
    Optional path to the Database/<Application>/ source folder. Used to locate
    database-package-ceiling.json when -CheckCeiling is specified.

.PARAMETER CheckCeiling
    When specified, checks the tier ceiling defined in
    database-package-ceiling.json in the source folder.

.OUTPUTS
    [PSCustomObject] @{
        IsValid           = [bool]
        ManifestErrors    = [string[]]
        ChecksumErrors    = [string[]]
        CeilingViolation  = [string]   # null when no violation
    }

.EXAMPLE
    Test-DatabaseChangePackage -PackagePath 'C:\packages\ATAPUtilities.Database.1.2.3'

.EXAMPLE
    Test-DatabaseChangePackage -NupkgPath 'C:\packages\ATAPUtilities.Database.1.2.3.nupkg'
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

    [Parameter(Mandatory = $false)]
    [string]$DatabasePackageSourcePath,

    [Parameter(Mandatory = $false)]
    [switch]$CheckCeiling
  )

  begin {
    $fn = 'Test-DatabaseChangePackage'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'
    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'

    # Dot-source helpers if not already loaded
    foreach ($dep in @('Get-DatabasePackageManifest', 'Test-DatabasePackageManifest')) {
      if (-not (Get-Command $dep -CommandType Function -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot "$dep.ps1")
      }
    }
  }

  process {
    $manifestErrors = @()
    $checksumErrors = [System.Collections.Generic.List[string]]::new()
    $ceilingViolation = $null
    $expandedPath = $null
    $tempDir = $null

    # ── Expand nupkg if needed ────────────────────────────────────────────────
    if ($PSCmdlet.ParameterSetName -eq 'FromNupkg') {
      if (-not (Test-Path $NupkgPath)) {
        throw "Nupkg file not found: '$NupkgPath'."
      }
      $tempDir = Join-Path $env:TEMP "dbpkg-validate-$([System.Guid]::NewGuid().ToString('N'))"
      New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Expanding nupkg to $tempDir" -Tag 'Expand'
      [System.IO.Compression.ZipFile]::ExtractToDirectory($NupkgPath, $tempDir)
      $expandedPath = $tempDir
    } else {
      if (-not (Test-Path $PackagePath)) {
        throw "Package folder not found: '$PackagePath'."
      }
      $expandedPath = $PackagePath
    }

    # ── 1. Validate manifest ──────────────────────────────────────────────────
    $manifestResult = Test-DatabasePackageManifest -PackagePath $expandedPath
    $manifestErrors = $manifestResult.Errors

    if (-not $manifestResult.IsValid) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Manifest validation failed with $($manifestErrors.Count) error(s)." -Tag 'Validation'
      Write-Output ([PSCustomObject]@{
          IsValid          = $false
          ManifestErrors   = $manifestErrors
          ChecksumErrors   = @()
          CeilingViolation = $null
        })
      return
    }

    # ── 2. Recompute checksums ────────────────────────────────────────────────
    $manifest = Get-DatabasePackageManifest -PackagePath $expandedPath
    foreach ($fileEntry in $manifest.files) {
      $filePath = Join-Path $expandedPath ($fileEntry.path -replace '/', [System.IO.Path]::DirectorySeparatorChar)
      if (-not (Test-Path $filePath)) {
        $checksumErrors.Add("File referenced in manifest not found: $($fileEntry.path)")
        continue
      }
      $actualHash = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash.ToLower()
      if ($fileEntry.checksumSha256 -ne '...' -and $actualHash -ne $fileEntry.checksumSha256.ToLower()) {
        $checksumErrors.Add("Checksum mismatch for $($fileEntry.path): expected $($fileEntry.checksumSha256) got $actualHash")
      }
    }

    # ── 3. Ceiling policy check ───────────────────────────────────────────────
    if ($CheckCeiling -and $DatabasePackageSourcePath) {
      $ceilingFile = Join-Path $DatabasePackageSourcePath 'database-package-ceiling.json'
      if (Test-Path $ceilingFile) {
        try {
          $ceiling = Get-Content $ceilingFile -Raw | ConvertFrom-Json
          $packageVersion = $manifest.appVersion
          # If ceiling specifies a maximum tier, check prerelease labels
          if ($ceiling.maximumTier -eq 'Development' -and $packageVersion -notmatch '-') {
            $ceilingViolation = "Ceiling restricts to Development tier but package version '$packageVersion' has no prerelease label."
          } elseif ($ceiling.maximumTier -eq 'Development' -and $packageVersion -notmatch '-(Alpha|Beta|Dev)') {
            $ceilingViolation = "Ceiling restricts to Development tier but version '$packageVersion' prerelease label is not Alpha/Beta/Dev."
          }
        } catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Could not parse ceiling file: $($_.Exception.Message)" -Tag 'Ceiling'
        }
      }
    }

    $isValid = ($manifestErrors.Count -eq 0) -and ($checksumErrors.Count -eq 0) -and ($null -eq $ceilingViolation)
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Package validation: IsValid=$isValid ManifestErrors=$($manifestErrors.Count) ChecksumErrors=$($checksumErrors.Count) CeilingViolation=$ceilingViolation" -Tag 'Output'

    Write-Output ([PSCustomObject]@{
        IsValid          = $isValid
        ManifestErrors   = $manifestErrors
        ChecksumErrors   = $checksumErrors.ToArray()
        CeilingViolation = $ceilingViolation
      })
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}
