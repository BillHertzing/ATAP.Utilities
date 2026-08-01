#Requires -Version 7.0
<#
.SYNOPSIS
    Validates whether an application package version satisfies the
    `compatibleAppPackageRanges` declared by a database change package's
    manifest.

.DESCRIPTION
    A database change package declares which application package versions
    it is compatible with via the `compatibleAppPackageRanges` array in
    `db-release-unit-manifest.json`. Each entry is a SemVer range string
    in npm/NuGet style — for example:

      `>=1.0.0 <2.0.0`            (npm-style; AND of two comparators)
      `>=1.0.0`                   (open-ended lower bound)
      `<2.0.0`                    (open-ended upper bound)
      `[1.0.0,2.0.0)`             (NuGet-style; inclusive low, exclusive high)
      `(1.0.0,2.0.0]`             (NuGet-style; exclusive low, inclusive high)
      `[1.0.0,2.0.0]`             (NuGet-style; both inclusive)
      `1.0.0`                     (exact match)

    Test-DatabasePackageCompatibility parses every range in the manifest
    and returns `IsCompatible = $true` as soon as one range admits
    `-AppPackageVersion`. If no range admits the version the cmdlet
    returns `IsCompatible = $false` and lists every range it tried.

    Empty `compatibleAppPackageRanges` array means "no constraint" per the
    schema, and the cmdlet returns `IsCompatible = $true`.

    Malformed range strings raise a terminating error — the manifest is
    invalid, and deployment must abort.

.PARAMETER DatabasePackageManifestPath
    Path to `db-release-unit-manifest.json` extracted from the database
    change package. Must exist and parse as JSON.

.PARAMETER AppPackageVersion
    The application package version to validate against the manifest's
    `compatibleAppPackageRanges`. Must be a parseable
    `System.Management.Automation.SemanticVersion` value.

.OUTPUTS
    [PSCustomObject] with:
      - IsCompatible    : $true if any range admitted the version, or if
                          the manifest has no constraint.
      - AppPackageVersion: Echoed input.
      - MatchedRange    : The first range that admitted the version, or
                          $null if none matched.
      - FailedRange     : The last range that was tried but rejected, or
                          $null if a match was found.
      - TriedRanges     : Every range from the manifest, in order tried.

.EXAMPLE
    PS> Test-DatabasePackageCompatibility `
            -DatabasePackageManifestPath './expanded/db-release-unit-manifest.json' `
            -AppPackageVersion '1.5.2'

    Returns IsCompatible = $true and the matching range if the manifest
    permits 1.5.2.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Task: TASKS_V4-DBA2.md DBA2-T06 / V4-E12.

.LINK
    Database-Package-Compatibility.md
#>

function Test-DatabasePackageCompatibility {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabasePackageManifestPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AppPackageVersion
  )

  begin {
    $fn = 'Test-DatabasePackageCompatibility'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Entering ${fn} (Manifest='$DatabasePackageManifestPath'; AppVersion='$AppPackageVersion')" -Tag 'Trace'

    # Accept either the manifest file path or the expanded-package folder
    # containing the manifest.
    $resolvedManifestPath = $DatabasePackageManifestPath
    if (Test-Path -LiteralPath $DatabasePackageManifestPath -PathType Container) {
      $resolvedManifestPath = Join-Path -Path $DatabasePackageManifestPath -ChildPath 'db-release-unit-manifest.json'
    }
    if (-not (Test-Path -LiteralPath $resolvedManifestPath -PathType Leaf)) {
      $msg = "${fn}: manifest not found at '$resolvedManifestPath'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    $appVersionParsed = $null
    if (-not [System.Management.Automation.SemanticVersion]::TryParse($AppPackageVersion, [ref]$appVersionParsed)) {
      $msg = "${fn}: AppPackageVersion '$AppPackageVersion' is not a valid SemVer."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }
  }

  process {
    # Compare two SemanticVersions, returning -1/0/+1.
    function script:Compare-DatabasePackageSemVer {
      param(
        [Parameter(Mandatory)][System.Management.Automation.SemanticVersion]$Left,
        [Parameter(Mandatory)][System.Management.Automation.SemanticVersion]$Right
      )
      if ($Left -lt $Right) { return -1 }
      if ($Left -gt $Right) { return 1 }
      return 0
    }

    # Parse a single npm-style comparator (e.g. '>=1.0.0', '<2.0.0', '=1.2.3', '1.2.3').
    # Returns a hashtable @{ Op = '>='; Version = SemVer } or throws on malformed input.
    function script:ConvertFrom-DatabasePackageComparator {
      param([Parameter(Mandatory)][string]$Text)

      $trimmed = $Text.Trim()
      if ([string]::IsNullOrWhiteSpace($trimmed)) {
        throw "Empty SemVer comparator."
      }

      $opMatch = [regex]::Match($trimmed, '^(>=|<=|>|<|=)?\s*(.+)$')
      if (-not $opMatch.Success) {
        throw "Malformed SemVer comparator: '$Text'."
      }
      $op = $opMatch.Groups[1].Value
      if ([string]::IsNullOrEmpty($op)) { $op = '=' }
      $versionText = $opMatch.Groups[2].Value.Trim()

      $parsed = $null
      if (-not [System.Management.Automation.SemanticVersion]::TryParse($versionText, [ref]$parsed)) {
        throw "Malformed SemVer comparator: '$Text' (version '$versionText' is not a valid SemVer)."
      }

      return [pscustomobject]@{ Op = $op; Version = $parsed }
    }

    # Decide whether $candidate satisfies an npm-style range made of one or more
    # AND-joined comparators separated by whitespace, e.g. '>=1.0.0 <2.0.0'.
    function script:Test-DatabasePackageNpmRange {
      param(
        [Parameter(Mandatory)][string]$Range,
        [Parameter(Mandatory)][System.Management.Automation.SemanticVersion]$Candidate
      )

      $comparators = $Range -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
      foreach ($comparatorText in $comparators) {
        $comparator = ConvertFrom-DatabasePackageComparator -Text $comparatorText
        $cmpResult = Compare-DatabasePackageSemVer -Left $Candidate -Right $comparator.Version
        switch ($comparator.Op) {
          '>=' { if ($cmpResult -lt 0) { return $false } }
          '>'  { if ($cmpResult -le 0) { return $false } }
          '<=' { if ($cmpResult -gt 0) { return $false } }
          '<'  { if ($cmpResult -ge 0) { return $false } }
          '='  { if ($cmpResult -ne 0) { return $false } }
          default { throw "Unsupported comparator operator: '$($comparator.Op)'." }
        }
      }
      return $true
    }

    # Decide whether $candidate satisfies a NuGet-style range, e.g. '[1.0.0,2.0.0)'.
    function script:Test-DatabasePackageNuGetRange {
      param(
        [Parameter(Mandatory)][string]$Range,
        [Parameter(Mandatory)][System.Management.Automation.SemanticVersion]$Candidate
      )

      $rangeMatch = [regex]::Match($Range.Trim(), '^([\[\(])\s*([^,\s\]\)]*)\s*,\s*([^,\s\]\)]*)\s*([\]\)])$')
      if (-not $rangeMatch.Success) {
        throw "Malformed NuGet-style version range: '$Range'."
      }
      $lowBracket = $rangeMatch.Groups[1].Value
      $lowText    = $rangeMatch.Groups[2].Value
      $highText   = $rangeMatch.Groups[3].Value
      $highBracket = $rangeMatch.Groups[4].Value

      if (-not [string]::IsNullOrEmpty($lowText)) {
        $lowParsed = $null
        if (-not [System.Management.Automation.SemanticVersion]::TryParse($lowText, [ref]$lowParsed)) {
          throw "Malformed NuGet-style version range: '$Range' (low '$lowText' is not a valid SemVer)."
        }
        $cmp = Compare-DatabasePackageSemVer -Left $Candidate -Right $lowParsed
        if ($lowBracket -eq '[') {
          if ($cmp -lt 0) { return $false }
        } else {
          if ($cmp -le 0) { return $false }
        }
      }
      if (-not [string]::IsNullOrEmpty($highText)) {
        $highParsed = $null
        if (-not [System.Management.Automation.SemanticVersion]::TryParse($highText, [ref]$highParsed)) {
          throw "Malformed NuGet-style version range: '$Range' (high '$highText' is not a valid SemVer)."
        }
        $cmp = Compare-DatabasePackageSemVer -Left $Candidate -Right $highParsed
        if ($highBracket -eq ']') {
          if ($cmp -gt 0) { return $false }
        } else {
          if ($cmp -ge 0) { return $false }
        }
      }
      return $true
    }

    function script:Test-DatabasePackageRangeAdmits {
      param(
        [Parameter(Mandatory)][string]$Range,
        [Parameter(Mandatory)][System.Management.Automation.SemanticVersion]$Candidate
      )
      $trimmed = $Range.Trim()
      if ([string]::IsNullOrWhiteSpace($trimmed)) {
        throw "Empty range string is not a valid SemVer range."
      }
      if ($trimmed.StartsWith('[') -or $trimmed.StartsWith('(')) {
        return (Test-DatabasePackageNuGetRange -Range $trimmed -Candidate $Candidate)
      }
      return (Test-DatabasePackageNpmRange -Range $trimmed -Candidate $Candidate)
    }

    $manifest = Get-Content -LiteralPath $resolvedManifestPath -Raw | ConvertFrom-Json -ErrorAction Stop
    $ranges = @()
    if ($manifest.PSObject.Properties.Name -contains 'compatibleAppPackageRanges' -and
        $null -ne $manifest.compatibleAppPackageRanges) {
      $ranges = @($manifest.compatibleAppPackageRanges)
    }

    if ($ranges.Count -eq 0) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Manifest declares no compatibleAppPackageRanges; treating as no constraint."
      return [PSCustomObject]@{
        IsCompatible      = $true
        AppPackageVersion = $AppPackageVersion
        MatchedRange      = $null
        FailedRange       = $null
        TriedRanges       = @()
      }
    }

    $tried = @()
    $matched = $null
    $lastFailed = $null
    foreach ($range in $ranges) {
      $tried += $range
      $admits = $false
      try {
        $admits = Test-DatabasePackageRangeAdmits -Range $range -Candidate $appVersionParsed
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
          -Message "Malformed range '$range' in manifest '$DatabasePackageManifestPath': $($_.Exception.Message)"
        throw
      }
      if ($admits) {
        $matched = $range
        break
      } else {
        $lastFailed = $range
      }
    }

    return [PSCustomObject]@{
      IsCompatible      = [bool]$matched
      AppPackageVersion = $AppPackageVersion
      MatchedRange      = $matched
      FailedRange       = if ($matched) { $null } else { $lastFailed }
      TriedRanges       = $tried
    }
  }
}
