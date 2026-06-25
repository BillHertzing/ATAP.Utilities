function New-SprintEndHandoff {
  <#
  .SYNOPSIS
  Generates the non-interactive SprintEnd HANDOFF.md file.

  .DESCRIPTION
  Writes an atomic handoff with an explicit working directory, safe worktree
  removal order, non-interactive stable synchronization, database-only cleanup,
  BuildMaster variable cleanup, boundary verification, and self-removal.
  Bitwarden secret deletion and SQL-instance removal are deliberately absent.

  .PARAMETER GitRoot
  Parent directory containing stable repositories and sprint worktrees.

  .PARAMETER WorktreePaths
  Sprint worktrees to remove. _Planning is ordered last.

  .PARAMETER OutputPath
  HANDOFF.md path. Defaults to <GitRoot>/HANDOFF.md.

  .OUTPUTS
  FileInfo for the generated handoff, or a planned result under WhatIf.

  .EXAMPLE
  New-SprintEndHandoff -GitRoot C:\Repos -WorktreePaths $paths

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$GitRoot,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorktreePaths,

    [Parameter()]
    [string]$OutputPath
  )

  begin {
    $fn = 'New-SprintEndHandoff'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $gitRootFull = [IO.Path]::GetFullPath($GitRoot)
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
      $OutputPath = Join-Path $gitRootFull 'HANDOFF.md'
    }
    $orderedWorktrees = @($WorktreePaths | Sort-Object {
        $leaf = Split-Path -Path $_ -Leaf
        if ($leaf -like '_Planning*') { 3 }
        elseif ($leaf -like 'SharedVSCode*') { 2 }
        else { 1 }
      }, { Split-Path -Path $_ -Leaf })

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Agent Handoff - Resume SprintEnd')
    $lines.Add('')
    $lines.Add("Run these commands from ``$gitRootFull`` in PowerShell 7 with profiles enabled.")
    $lines.Add('')
    $lines.Add('```powershell')
    $lines.Add("Set-Location -LiteralPath '$gitRootFull'")
    $lines.Add("`$env:GIT_EDITOR = 'true'")
    $lines.Add("`$env:GIT_MERGE_AUTOEDIT = 'no'")
    $lines.Add("Import-Module ATAP.Utilities.BuildTooling.PowerShell -Force")
    $lines.Add('')
    foreach ($worktreePath in $orderedWorktrees) {
      $full = [IO.Path]::GetFullPath($worktreePath)
      $leaf = Split-Path -Path $full -Leaf
      $stableName = $leaf -replace '-wt-\d+-Sprint-\d{4}-work-items$', ''
      $stablePath = Join-Path $gitRootFull $stableName
      $branchName = $leaf.Substring($stableName.Length + 4)
      $lines.Add("# Remove $leaf")
      $lines.Add("git -C '$stablePath' worktree remove '$full' --force")
      $lines.Add("git -C '$stablePath' worktree prune")
      $lines.Add("if (Test-Path -LiteralPath '$full') { throw 'Worktree path remains after removal: $full' }")
      $lines.Add("if (git -C '$stablePath' branch --list '$branchName') { git -C '$stablePath' branch -D '$branchName' }")
      $lines.Add('')
    }
    $lines.Add('# Synchronize stable worktrees without opening an editor.')
    foreach ($worktreePath in $orderedWorktrees) {
      $leaf = Split-Path -Path $worktreePath -Leaf
      $stableName = $leaf -replace '-wt-\d+-Sprint-\d{4}-work-items$', ''
      $stablePath = Join-Path $gitRootFull $stableName
      $lines.Add("Test-SprintEndPullOverlap -RepoPath '$stablePath' -Fetch -ThrowOnOverlap")
      $lines.Add("git -C '$stablePath' pull --ff-only origin main")
    }
    $lines.Add('')
    $lines.Add('# Infrastructure cleanup: databases only; never SQL instances or Bitwarden secrets.')
    $lines.Add("Remove-SprintDatabases -DeveloperNames @(`$env:USERNAME) -Force -Confirm:`$false")
    $lines.Add("Clear-BuildMasterSprintVariables -Confirm:`$false")
    $lines.Add("Set-SprintBoundaryContext -Boundary End -SharedVSCodeWorktreePath (Join-Path '$gitRootFull' 'SharedVSCode') -Confirm:`$false")
    $lines.Add("Test-SprintEndBoundaryState -GitRoot '$gitRootFull' -TestFreshShell -ThrowOnFailure")
    $lines.Add('')
    $lines.Add('# Remove this handoff only after every command above succeeds.')
    $lines.Add("Remove-Item -LiteralPath '$OutputPath' -Force")
    $lines.Add('```')
    $content = $lines -join [Environment]::NewLine

    $changed = -not (Test-Path -LiteralPath $OutputPath -PathType Leaf) -or
      ((Get-Content -Raw -LiteralPath $OutputPath) -ne $content)
    if ($changed -and $PSCmdlet.ShouldProcess($OutputPath, 'Atomically write SprintEnd handoff')) {
      $directory = Split-Path -Path $OutputPath -Parent
      if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
      }
      $tempPath = Join-Path $directory ('.' + [IO.Path]::GetFileName($OutputPath) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
      try {
        [IO.File]::WriteAllText($tempPath, $content, [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $tempPath -Destination $OutputPath -Force
      } finally {
        if (Test-Path -LiteralPath $tempPath) {
          Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
      }
    }

    return [PSCustomObject]@{
      Path             = [IO.Path]::GetFullPath($OutputPath)
      Changed          = $changed
      WorktreeCount    = $orderedWorktrees.Count
      ContainsSecretsDeletion = $false
      ContainsInstanceRemoval = $false
      WorkingDirectory = $gitRootFull
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
