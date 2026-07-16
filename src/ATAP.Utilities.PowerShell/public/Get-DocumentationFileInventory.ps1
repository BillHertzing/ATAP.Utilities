#############################################################################
#region Get-DocumentationFileInventory
<#
.SYNOPSIS
Enumerates documentation-type files under a root directory and emits one inventory record per file.

.DESCRIPTION
Walks a repository (or worktree) root recursively and returns a PSCustomObject for every file whose
extension is in the documentation extension list, skipping paths that match the exclusion pattern.
Each record carries the repo name, root-relative path, extension, size, line count (text formats
only), and the filesystem creation and last-write times (both UTC [datetimeoffset]).

This is the DR-1.1 building block of the ATAP Documentation Review program
(_Planning\DocumentationReview\DocumentationReview-Plan.md). Filesystem timestamps are raw
observations: for historical files they are unreliable (Dropbox sync, worktree checkouts) and the
authoritative bounds come from git history via Get-GitFileDates (DR-1.2); for files created or
modified in the current sprint they feed the §3a 'actual' fields via Export-DocumentationInventory.
Note that `_generated\` folders are deliberately NOT excluded by default: per the G0 decision of
2026-07-13 their files are inventoried and classed GeneratedOutput downstream.

.PARAMETER RootPath
The directory to inventory. Must exist. Typically a repository or sprint-worktree root.

.PARAMETER RepoName
Name recorded in each record's RepoName field. Defaults to the leaf name of RootPath.

.PARAMETER IncludeExtension
Extensions (with leading dot, case-insensitive) treated as documentation. Defaults to the DR program
list: .md .markdown .html .htm .txt .adoc .rst .docx .doc .pdf .rtf .drawio .svg .puml .mmd .ipynb.

.PARAMETER ExcludePathPattern
Regex applied to each file's root-relative path; matches are skipped. Defaults to
'[\\/](bin|obj|node_modules|\.git|\.vs|packages|TestResults)([\\/]|$)'.

.INPUTS
None. RootPath may be bound from the pipeline by property name.

.OUTPUTS
PSCustomObject with properties: RepoName, RelativePath, Extension, SizeBytes, LineCount,
FileSystemCreated, FileSystemLastWrite (UTC [datetimeoffset]). LineCount is $null for non-text
(binary) documentation formats.

.EXAMPLE
Get-DocumentationFileInventory -RootPath 'C:\Dropbox\whertzing\GitHub\ATAP.IAC-wt-15-Sprint-0012-work-items'

.EXAMPLE
Get-DocumentationFileInventory -RootPath $root -IncludeExtension '.md' |
  Where-Object LineCount -lt 5

.EXAMPLE
$config.ActiveRoots | ForEach-Object { Get-DocumentationFileInventory -RootPath $_.Path -RepoName $_.RepoName }
#>
Function Get-DocumentationFileInventory {
  #region FunctionParameters
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string] $RootPath
    , [parameter(ValueFromPipelineByPropertyName = $true)]
    [string] $RepoName
    , [parameter()]
    [string[]] $IncludeExtension = @(
      '.md', '.markdown', '.html', '.htm', '.txt', '.adoc', '.rst',
      '.docx', '.doc', '.pdf', '.rtf', '.drawio', '.svg', '.puml', '.mmd', '.ipynb'
    )
    , [parameter()]
    [string] $ExcludePathPattern = '[\\/](bin|obj|node_modules|\.git|\.vs|packages|TestResults)([\\/]|$)'
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Entering Function Get-DocumentationFileInventory in module ATAP.Utilities.Powershell' -Tag 'Trace'
    # Binary documentation formats get LineCount = $null; every other included extension is counted.
    $binaryExtensions = @('.docx', '.doc', '.pdf', '.rtf', '.chm', '.odt', '.one')
  }
  #endregion FunctionBeginBlock
  #region FunctionProcessBlock
  ########################################
  PROCESS {
    $resolvedRoot = (Resolve-Path -LiteralPath $RootPath).ProviderPath.TrimEnd('\', '/')
    $effectiveRepoName = if ($RepoName) { $RepoName } else { Split-Path -Path $resolvedRoot -Leaf }
    $includeSet = [System.Collections.Generic.HashSet[string]]::new(
      [string[]]($IncludeExtension | ForEach-Object { $_.ToLowerInvariant() }),
      [System.StringComparer]::OrdinalIgnoreCase)

    Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
      ForEach-Object {
        $extension = $_.Extension.ToLowerInvariant()
        if (-not $includeSet.Contains($extension)) { return }
        $relativePath = $_.FullName.Substring($resolvedRoot.Length).TrimStart('\', '/')
        if ($ExcludePathPattern -and ("\$relativePath" -match $ExcludePathPattern)) { return }

        $lineCount = $null
        if ($binaryExtensions -notcontains $extension) {
          try {
            $lineCount = 0
            foreach ($line in [System.IO.File]::ReadLines($_.FullName)) { $lineCount++ }
          } catch {
            Write-PSFMessage -Level Verbose -Message "LineCount failed for $relativePath : $($_.Exception.Message)" -Tag 'DocumentationReview'
            $lineCount = $null
          }
        }

        [PSCustomObject]@{
          RepoName            = $effectiveRepoName
          RelativePath        = $relativePath
          Extension           = $extension
          SizeBytes           = $_.Length
          LineCount           = $lineCount
          FileSystemCreated   = [datetimeoffset]::new($_.CreationTimeUtc, [timespan]::Zero)
          FileSystemLastWrite = [datetimeoffset]::new($_.LastWriteTimeUtc, [timespan]::Zero)
        }
      }
  }
  #endregion FunctionProcessBlock
  #region FunctionEndBlock
  ########################################
  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function Get-DocumentationFileInventory in module ATAP.Utilities.Powershell' -Tag 'Trace'
  }
  #endregion FunctionEndBlock
}
#endregion Get-DocumentationFileInventory
#############################################################################
