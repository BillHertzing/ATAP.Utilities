#############################################################################
#region Export-DocumentationInventory
<#
.SYNOPSIS
Builds the joined documentation inventory (file facts + git dates) for one or more roots and writes it as CSV and JSONL.

.DESCRIPTION
For each supplied root, runs Get-DocumentationFileInventory (DR-1.1) and one Get-GitFileDates batch
walk (DR-1.2), joins the two on RelativePath, and writes the combined records to
<OutputDirectory>\<BaseName>.csv and <OutputDirectory>\<BaseName>.jsonl with a stable column order:

  RepoName, RelativePath, Extension, SizeBytes, LineCount,
  CreatedNoEarlierThanUtc, CreatedNoLaterThanUtc, CreatedActualUtc,
  LastWriteNoEarlierThanUtc, LastWriteNoLaterThanUtc, LastWriteActualUtc,
  CommitCount, IsTracked

Temporal fields follow the §3a schema of the plan of record: git-derived no-earlier-than /
no-later-than bounds for both Created and LastWrite on every tracked file, plus 'actual' values
from authentic filesystem timestamps where knowable — CreatedActualUtc and LastWriteActualUtc when
the file's first commit is on/after -SprintStartUtc; LastWriteActualUtc alone when only the newest
commit is on/after -SprintStartUtc; both for untracked files (which have no git bounds). Every
datetime is UTC, serialized ISO-8601 with explicit offset (+00:00), so the CSV and JSONL copies are
byte-comparable across runs. IsTracked = False rows are an anomaly the DR-2.2.b sweep reports on.

This is the DR-1.3 building block of the ATAP Documentation Review program
(_Planning\DocumentationReview\DocumentationReview-Plan.md). The Invoke-DocumentationInventory
driver script feeds it the active roots from ReviewConfig.json.

.PARAMETER Root
One or more objects (or hashtables) with RepoName and RootPath properties naming the repositories
to inventory. Each RootPath must be a git work tree.

.PARAMETER OutputDirectory
Directory that receives <BaseName>.csv and <BaseName>.jsonl. Created if absent.

.PARAMETER BaseName
Base file name for the two outputs. Defaults to 'DocumentationInventory'.

.PARAMETER IncludeExtension
Passed through to Get-DocumentationFileInventory. Defaults to that function's DR program list.

.PARAMETER ExcludePathPattern
Passed through to Get-DocumentationFileInventory. Defaults to that function's default.

.PARAMETER SprintStartUtc
Start of the current sprint (UTC). Gates the population of the 'actual' fields per §3a. When
omitted, no tracked file gets 'actual' values (untracked files still do).

.PARAMETER PassThru
Also emit the joined records to the pipeline.

.INPUTS
None.

.OUTPUTS
A summary PSCustomObject: RootCount, FileCount, UntrackedCount, CsvPath, JsonlPath. With -PassThru,
the joined records are emitted first.

.EXAMPLE
Export-DocumentationInventory -Root @(@{ RepoName = 'ATAP.IAC'; RootPath = 'C:\...\ATAP.IAC-wt-15-...' }) -OutputDirectory 'C:\out'

.EXAMPLE
$config = Get-Content $configPath -Raw | ConvertFrom-Json
Export-DocumentationInventory -Root $config.activeRoots -OutputDirectory $config.outputs.curatedDirectory
#>
Function Export-DocumentationInventory {
  #region FunctionParameters
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [object[]] $Root
    , [parameter(Mandatory = $true)]
    [string] $OutputDirectory
    , [parameter()]
    [string] $BaseName = 'DocumentationInventory'
    , [parameter()]
    [string[]] $IncludeExtension
    , [parameter()]
    [string] $ExcludePathPattern
    , [parameter()]
    [nullable[datetimeoffset]] $SprintStartUtc
    , [parameter()]
    [switch] $PassThru
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Entering Function Export-DocumentationInventory in module ATAP.Utilities.Powershell' -Tag 'Trace'
    foreach ($helper in 'Get-DocumentationFileInventory', 'Get-GitFileDates') {
      if (-not (Get-Command -Name $helper -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot "$helper.ps1")
      }
    }
    $isoFormat = 'yyyy-MM-ddTHH:mm:sszzz'
    # Serializes a nullable [datetimeoffset] as ISO-8601 UTC with explicit offset, or ''.
    $toUtcString = { param($value) if ($null -ne $value -and $value -ne '') { ([datetimeoffset]$value).ToUniversalTime().ToString($isoFormat) } else { '' } }
  }
  #endregion FunctionBeginBlock
  #region FunctionEndBlock
  ########################################
  END {
    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($rootEntry in $Root) {
      $repoName = $rootEntry.RepoName
      $rootPath = $rootEntry.RootPath
      if (-not ($repoName -and $rootPath)) {
        throw "Export-DocumentationInventory: each -Root entry needs RepoName and RootPath (got: $($rootEntry | ConvertTo-Json -Compress -Depth 2))."
      }
      Write-PSFMessage -Level Verbose -Message "Export-DocumentationInventory: inventorying $repoName at $rootPath" -Tag 'DocumentationReview'

      $inventoryArgs = @{ RootPath = $rootPath; RepoName = $repoName }
      if ($IncludeExtension) { $inventoryArgs.IncludeExtension = $IncludeExtension }
      if ($PSBoundParameters.ContainsKey('ExcludePathPattern')) { $inventoryArgs.ExcludePathPattern = $ExcludePathPattern }
      $inventory = @(Get-DocumentationFileInventory @inventoryArgs)

      $dateMap = @{}
      Get-GitFileDates -RepositoryRoot $rootPath | ForEach-Object { $dateMap[$_.RelativePath] = $_ }

      foreach ($file in $inventory) {
        $dates = $dateMap[$file.RelativePath]
        # §3a 'actual' population: untracked files always (filesystem is all we have);
        # tracked files gated by SprintStartUtc against their git bounds.
        $createdThisSprint = $dates -and $null -ne $SprintStartUtc -and $dates.CreatedNoLaterThan -ge $SprintStartUtc
        $modifiedThisSprint = $dates -and $null -ne $SprintStartUtc -and $dates.LastWriteNoLaterThan -ge $SprintStartUtc
        $createdActual = if ((-not $dates) -or $createdThisSprint) { $file.FileSystemCreated } else { $null }
        $lastWriteActual = if ((-not $dates) -or $modifiedThisSprint) { $file.FileSystemLastWrite } else { $null }
        $records.Add([PSCustomObject]@{
            RepoName                  = $file.RepoName
            RelativePath              = $file.RelativePath
            Extension                 = $file.Extension
            SizeBytes                 = $file.SizeBytes
            LineCount                 = $file.LineCount
            CreatedNoEarlierThanUtc   = & $toUtcString ($dates ? $dates.CreatedNoEarlierThan : $null)
            CreatedNoLaterThanUtc     = & $toUtcString ($dates ? $dates.CreatedNoLaterThan : $null)
            CreatedActualUtc          = & $toUtcString $createdActual
            LastWriteNoEarlierThanUtc = & $toUtcString ($dates ? $dates.LastWriteNoEarlierThan : $null)
            LastWriteNoLaterThanUtc   = & $toUtcString ($dates ? $dates.LastWriteNoLaterThan : $null)
            LastWriteActualUtc        = & $toUtcString $lastWriteActual
            CommitCount               = if ($dates) { $dates.CommitCount } else { 0 }
            IsTracked                 = [bool]$dates
          })
      }
    }

    $sorted = $records | Sort-Object RepoName, RelativePath
    if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
      New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    $csvPath = Join-Path $OutputDirectory "$BaseName.csv"
    $jsonlPath = Join-Path $OutputDirectory "$BaseName.jsonl"
    $sorted | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8
    $sorted | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 3 } | Set-Content -LiteralPath $jsonlPath -Encoding utf8

    $untrackedCount = @($sorted | Where-Object { -not $_.IsTracked }).Count
    Write-PSFMessage -Level Verbose -Message "Export-DocumentationInventory: wrote $($sorted.Count) records ($untrackedCount untracked) to $csvPath and $jsonlPath" -Tag 'DocumentationReview'

    if ($PassThru) { $sorted }
    [PSCustomObject]@{
      RootCount      = $Root.Count
      FileCount      = @($sorted).Count
      UntrackedCount = $untrackedCount
      CsvPath        = $csvPath
      JsonlPath      = $jsonlPath
    }
    Write-PSFMessage -Level Debug -Message 'Leaving Function Export-DocumentationInventory in module ATAP.Utilities.Powershell' -Tag 'Trace'
  }
  #endregion FunctionEndBlock
}
#endregion Export-DocumentationInventory
#############################################################################
