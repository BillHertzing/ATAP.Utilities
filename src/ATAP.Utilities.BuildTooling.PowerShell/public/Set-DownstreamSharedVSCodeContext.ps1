function Set-DownstreamSharedVSCodeContext {
  <#
  .SYNOPSIS
    Applies SharedVSCode settings to the repository containing the workspace files.
  .DESCRIPTION
    Reads workspace context(s), then for each:
    - Sets git local commit.template to the resolved commit template path.
    - Generates and writes a stamped .gitattributes at the repo root.
    - Generates and writes a stamped .gitconfig.shared at the repo root.
    - Sets git local include.path to the generated .gitconfig.shared.
    - Sets git local core.hooksPath to the SharedVSCode hooks directory (if it exists).
  .PARAMETER WorkspaceFiles
    One or more paths to .code-workspace files.
  .PARAMETER GitRoot
    Root directory containing all Git repositories.
  .PARAMETER SharedVSCodeRepoName
    Name of the SharedVSCode repository folder.
  .PARAMETER SharedHooksSubPath
    Relative path under SharedVSCode root where hooks live.
  .PARAMETER CommitTemplateRelativePath
    Relative path under SharedVSCode root for the commit template.
  .EXAMPLE
    Set-DownstreamSharedVSCodeContext -WorkspaceFiles @('.\Planning.code-workspace')
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceFiles,

    [string]$GitRoot = 'C:\dropbox\whertzing\GitHub',
    [string]$SharedVSCodeRepoName = 'SharedVSCode',
    [string]$SharedHooksSubPath = '.githooks',
    [string]$CommitTemplateRelativePath = 'GitTemplates\git.commit.template.txt'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    Assert-GitAvailable
    $workspaceRepoRoots = @(
    $WorkspaceFiles |
      ForEach-Object {
        $resolvedWorkspace = (Resolve-Path -LiteralPath $_ -ErrorAction Stop).ProviderPath
        Split-Path -Path $resolvedWorkspace -Parent
      } |
      Sort-Object -Unique
  )

  if ($workspaceRepoRoots.Count -eq 0) {
    throw 'WorkspaceFiles did not resolve to any downstream repository roots.'
  }
  if ($workspaceRepoRoots.Count -gt 1) {
    throw "WorkspaceFiles span multiple downstream repository roots: $($workspaceRepoRoots -join ', ')"
  }
  $repoRoot = $workspaceRepoRoots[0]

  $contexts = Get-SharedVSCodeContext `
    -WorkspaceFiles $WorkspaceFiles `
    -GitRoot $GitRoot `
    -SharedVSCodeRepoName $SharedVSCodeRepoName `
    -SharedHooksSubPath $SharedHooksSubPath `
    -CommitTemplateRelativePath $CommitTemplateRelativePath

  foreach ($ctx in $contexts) {
    # Set commit template
    $commitTemplateResolved = (Resolve-Path -Path $ctx.CommitTemplate).ProviderPath
    git -C $repoRoot config --local commit.template $commitTemplateResolved | Out-Null

    # Task 16.85: both targets are committed under `text=auto eol=lf`, so they are written
    # LF-only and UTF-8 without BOM. Set-Content used to append a CRLF line terminator after
    # the source's own final LF, leaving Git to report newline-only modifications (Task 16.61).
    # The terminator is kept, as LF, because every committed downstream blob carries that
    # final empty line; dropping it would turn a newline fix into a content change in each
    # repository. Unchanged bytes are not rewritten, so repeated boundaries are no-ops.
    $writeLfFile = {
      param([string]$Path, [string]$Content)
      $normalized = ($Content -replace "`r`n|`r", "`n") + "`n"
      $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($normalized)
      if ((Test-Path -LiteralPath $Path -PathType Leaf) -and
        [System.Linq.Enumerable]::SequenceEqual([byte[]][System.IO.File]::ReadAllBytes($Path), [byte[]]$bytes)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Unchanged: $Path"
        return
      }
      [System.IO.File]::WriteAllBytes($Path, $bytes)
    }

    # Generate and write downstream .gitattributes
    $generatedGitAttributes = New-GeneratedFileContent -SourcePath $ctx.GitAttributes
    $downstreamGitAttributesPath = Join-Path $repoRoot '.gitattributes'
    & $writeLfFile $downstreamGitAttributesPath $generatedGitAttributes

    # Generate and write downstream .gitconfig.shared
    $generatedGitConfig = New-GeneratedFileContent -SourcePath $ctx.GitConfig
    $downstreamSharedGitConfigPath = Join-Path $repoRoot '.gitconfig.shared'
    & $writeLfFile $downstreamSharedGitConfigPath $generatedGitConfig

    # Point git local config to the shared config include
    git -C $repoRoot config --local include.path $downstreamSharedGitConfigPath | Out-Null

    # Set hooks path if the hooks directory exists
    if (Test-Path -Path $ctx.HooksPath) {
      $hooksResolved = (Resolve-Path -Path $ctx.HooksPath).ProviderPath
      git -C $repoRoot config --local core.hooksPath $hooksResolved | Out-Null
    }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
