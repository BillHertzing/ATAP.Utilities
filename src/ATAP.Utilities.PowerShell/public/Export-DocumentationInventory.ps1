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
  FirstCommitDate, LastCommitDate, CommitCount, IsTracked, FileSystemLastWrite

Dates are serialized as ISO-8601 strings so the CSV and JSONL copies are byte-comparable across
runs. Inventory files not present in git history get IsTracked = False with empty dates — an
anomaly the DR-2.2.b sweep reports on.

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
        $records.Add([PSCustomObject]@{
            RepoName            = $file.RepoName
            RelativePath        = $file.RelativePath
            Extension           = $file.Extension
            SizeBytes           = $file.SizeBytes
            LineCount           = $file.LineCount
            FirstCommitDate     = if ($dates) { $dates.FirstCommitDate.ToString($isoFormat) } else { '' }
            LastCommitDate      = if ($dates) { $dates.LastCommitDate.ToString($isoFormat) } else { '' }
            CommitCount         = if ($dates) { $dates.CommitCount } else { 0 }
            IsTracked           = [bool]$dates
            FileSystemLastWrite = $file.FileSystemLastWrite.ToString($isoFormat)
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
