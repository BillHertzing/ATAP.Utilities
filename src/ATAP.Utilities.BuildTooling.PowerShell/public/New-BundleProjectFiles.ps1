function New-BundleProjectFiles {
  <#
.SYNOPSIS
    Bundles _Planning repository documents into a single Markdown file.

.DESCRIPTION
    Collects a curated set of planning documents and concatenates them into a
    single Markdown file, each file separated by a header and a horizontal rule.
    Useful for creating a project snapshot to share with AI assistants.

    By default the file list is built dynamically at runtime:
      - All *architecture-overview.md files under Repositories\<repo>\
      - All Notebook-SprintWorkSession-NNNN-End.md files under ReplanningNotebooks\
      - Static files: ScopeCreep-Adopted.md, ScopeCreep-Deferred.md,
        ScopeCreep-Process.md, AceCommander-Modernization-Plan.md, TASKS.md, README.md
      - All AceCommander_Project_State_Conversation_Bookmark_NNN.md files (sorted)

    Pass -Include to override the file list with explicit paths or glob patterns.

.PARAMETER Path
    Root directory used when -Include globs are provided. Defaults to the git
    repository root (resolved via 'git rev-parse --show-toplevel').

.PARAMETER OutputFile
    Path to the output Markdown file. Defaults to
    'ProjectBundleForPlanningProject.md' at the repository root.

.PARAMETER Include
    Explicit list of relative file paths (or glob patterns) to bundle.
    Defaults to the dynamically built planning-document list described above.

.OUTPUTS
    PSCustomObject with properties: OutputFile, FileCount, Success.

.EXAMPLE
    New-BundleProjectFiles
    # Bundles the default planning documents into
    # <repoRoot>\ProjectBundleForPlanningProject.md

.EXAMPLE
    New-BundleProjectFiles -OutputFile .\MySnapshot.md -Include 'TASKS.md','README.md'
    # Bundles only TASKS.md and README.md into .\MySnapshot.md

.NOTES
    AI assisted using Powershell.instructions.md as guidelines

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>

  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [Alias()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [string]$Path ,

    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
    [string]$OutputFile,

    [Parameter(Mandatory = $false, Position = 2, ValueFromPipelineByPropertyName = $true)]
    [string[]]$Include
  )

  begin {
    $fn = 'New-BundleProjectFiles'
    $mn = '_Planning'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    # Load required helper functions
    try {
      $UtilitiesRepositoryRoot = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . (Join-Path $UtilitiesRepositoryRoot 'src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1')
      }
    } catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -Level Error -Message $errorMessage
      throw
    }
    # Find the root of the repo (submodule root if in a submodule).
    # git rev-parse --show-toplevel returns forward-slash paths on Windows (e.g. C:/Dropbox/...).
    # Convert-Path normalizes to a proper Windows backslash path so that Join-Path, Test-Path,
    # and Get-ChildItem all agree on the separator.
    $repoRoot = (git rev-parse --show-toplevel).Trim()
    if ($LASTEXITCODE -ne 0) {
      throw 'Failed to determine git repository root. Ensure this script is run within a git repository.'
    }
    $repoRoot = Convert-Path $repoRoot
    # Default: repo root is both the search root and the anchor for relative paths.
    # Get-PVal is intentionally NOT used here — the parameter name 'Path' collides with the
    # top-level settings key that resolves to $env:PATH. $Path defaults to $repoRoot and can
    # only be overridden by passing -Path explicitly on the command line.
    if (-not $PSBoundParameters.ContainsKey('Path')) {
      $Path = $repoRoot
    }

    # Default: ProjectBundleForPlanningProject.md written to the repo root.
    # snippet: "Check and populate simple parameter"
    $OutputFile = Join-Path $repoRoot 'ProjectBundleForPlanningProject.md'
    $OutputFile = Get-PVal -ParameterName 'OutputFile' -originalPSBoundParameters $PSBoundParameters -dottedPath 'NewBundleProjectFiles.OutputFile' -DefaultValue $OutputFile

    # $repoRoot anchors all relative path resolution for the default file list.
    $repoRoot = $repoRoot

    # Dynamic group 1: all replanning notebooks under ReplanningNotebooks\
    # $_.FullName used throughout — Resolve-Path -Relative would be CWD-relative, not $repoRoot-relative
    $replanningNotebooks = Get-ChildItem -Path (Join-Path $repoRoot 'ReplanningNotebooks') `
      -Filter '*.md' -File -ErrorAction SilentlyContinue |
      ForEach-Object { $_.FullName }

    # Dynamic group 2: all *architecture-overview.md files anywhere under Repositories\<repo>\
    $architectureOverviews = Get-ChildItem -Path (Join-Path $repoRoot 'Repositories') `
      -Recurse -Filter '* architecture-overview.md' -File -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match 'Repositories\\[^\\]+\\' } |
      ForEach-Object { $_.FullName }

    # Dynamic group 3: AceCommander_Project_State_Conversation_Bookmark_NNN.md — sorted ascending
    $bookmarkFiles = Get-ChildItem -Path $repoRoot `
      -Filter 'AceCommander_Project_State_Conversation_Bookmark_???.md' -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match 'AceCommander_Project_State_Conversation_Bookmark_\d{3}\.md$' } |
      Sort-Object Name |
      ForEach-Object { $_.FullName }

    # Static group: well-known planning files whose paths do not change; built as absolute paths
    $staticFiles = @(
      (Join-Path $repoRoot 'ScopeCreepManagement\ScopeCreep-Adopted.md')
      (Join-Path $repoRoot 'ScopeCreepManagement\ScopeCreep-Deferred.md')
      (Join-Path $repoRoot 'ScopeCreepManagement\ScopeCreep-Inbox.md')
      (Join-Path $repoRoot 'ScopeCreepManagement\ScopeCreep-Process.md')
      (Join-Path $repoRoot 'AceCommander-Modernization-Plan.md')
      (Join-Path $repoRoot 'TASKS.md')
      (Join-Path $repoRoot 'README.md')
    )

    # Merge all groups; all paths are absolute so Test-Path $_ is sufficient; deduplicate.
    # Order: architecture overviews → session files → static → bookmarks
    $defaultFiles = @($architectureOverviews) +
    @($replanningNotebooks) +
    $staticFiles +
    @($bookmarkFiles) |
      Where-Object { $_ -and (Test-Path $_) } |
      Select-Object -Unique

    # Default: dynamically built list above. Caller may override with explicit paths.
    # snippet: "Check and populate simple parameter as Type"
    # -AsType requires a [System.Type] expression — ([string[]]) not the string literal "[string[]]"
    $Include = Get-PVal -ParameterName 'Include' -originalPSBoundParameters $PSBoundParameters -dottedPath 'NewBundleProjectFiles.Include' -DefaultValue $defaultFiles -AsType ([string[]])

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Path: $Path  OutputFile: $OutputFile  Include: $($Include -join ', ')"
  }

  process {
    $result = [PSCustomObject]@{
      OutputFile = $OutputFile
      FileCount  = 0
      Success    = $false
    }

    # Try-Catch-Finally — snippet: "Try-Catch-Finally"
    try {
      # $Include is a list of absolute file paths (built in BEGIN); resolve each to a FileInfo object.
      # Get-ChildItem -Include cannot match absolute paths — it filters on file name only.
      $files = @($Include | ForEach-Object { Get-Item -Path $_ -ErrorAction SilentlyContinue } | Where-Object { $_ })

      if ($files.Count -eq 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "No files found for the resolved Include list ($($Include.Count) path(s) specified)"
        return $result
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Bundling $($files.Count) file(s) into $OutputFile"

      if ($PSCmdlet.ShouldProcess($OutputFile, 'Write bundle')) {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
        $header = @"
# Planning Repository Bundle

This file is the complete contents of individual files found in the Planning repository.

This file will be changed every time a planning session is started. It is generated
from certain documents in the Planning folder and then uploaded to the planning chat.
It consists of file names and their contents.

Generated: $timestamp
Source: $($files.Count) file(s) from $repoRoot

---

"@

        # Always include the planning-process explainer immediately after the header.
        $explainerPath = Join-Path $repoRoot 'Explainers\0000-planning-process.md'
        $explainerSection = if (Test-Path $explainerPath) {
          "## FILE: $explainerPath`n" + (Get-Content $explainerPath -Raw) + "`n---`n`n"
        } else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Explainer not found: $explainerPath"
          ''
        }

        $fileContent = foreach ($file in $files) {
          "## FILE: $($file.FullName)`n"
          Get-Content $file.FullName -Raw
          "`n---`n"
        }

        ($header + $explainerSection + ($fileContent -join '')) | Set-Content -Path $OutputFile -Encoding UTF8

        $result.FileCount = $files.Count
        $result.Success = $true

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Bundle written to $OutputFile ($($files.Count) files)"
      }
    } catch {
      $errorMessage = "New-BundleProjectFiles failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
    }

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
