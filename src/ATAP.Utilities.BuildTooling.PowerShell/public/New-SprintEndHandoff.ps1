function New-SprintEndHandoff {
  <#
  .SYNOPSIS
  Generates the non-interactive SprintEnd handoff file.

  .DESCRIPTION
  Writes an atomic, sprint-specific handoff with an explicit working directory,
  safe worktree removal order, non-interactive stable synchronization,
  database-only cleanup, BuildMaster variable cleanup, boundary verification,
  and self-removal. Bitwarden secret deletion and SQL-instance removal are
  deliberately absent.

  .PARAMETER GitRoot
  Parent directory containing stable repositories and sprint worktrees.

  .PARAMETER WorktreePaths
  Sprint worktrees to remove. _Planning is ordered last.

  .PARAMETER SprintNumber
  Closing sprint number. Defaults from WorktreePaths when omitted.

  .PARAMETER OutputPath
  Handoff path. Defaults to <GitRoot>/HANDOFF.SprintNNNN.md.

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
    [ValidatePattern('^\d{1,4}$')]
    [string]$SprintNumber,

    [Parameter()]
    [string]$OutputPath
  )

  begin {
    $fn = 'New-SprintEndHandoff'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    function ConvertTo-SprintEndHandoffSingleQuotedLiteral {
      param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
      )
      return "'" + ($Value -replace "'", "''") + "'"
    }

    $gitRootFull = [IO.Path]::GetFullPath($GitRoot)
    if ([string]::IsNullOrWhiteSpace($SprintNumber)) {
      $sprintNumbers = @($WorktreePaths | ForEach-Object {
          $leaf = Split-Path -Path $_ -Leaf
          if ($leaf -match '-Sprint-(\d{4})-work-items$') { $Matches[1] }
        } | Select-Object -Unique)
      if ($sprintNumbers.Count -eq 1) {
        $SprintNumber = $sprintNumbers[0]
      } elseif ($sprintNumbers.Count -gt 1) {
        throw "WorktreePaths contain multiple sprint numbers: $($sprintNumbers -join ', '). Pass -SprintNumber explicitly."
      } elseif ([string]::IsNullOrWhiteSpace($OutputPath)) {
        throw 'Could not infer SprintNumber from WorktreePaths. Pass -SprintNumber or -OutputPath.'
      }
    }
    if (-not [string]::IsNullOrWhiteSpace($SprintNumber)) {
      $SprintNumber = '{0:D4}' -f [int]$SprintNumber
    }
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
      $OutputPath = Join-Path $gitRootFull "HANDOFF.Sprint$SprintNumber.md"
    }
    $outputPathFull = [IO.Path]::GetFullPath($OutputPath)
    $gitRootLiteral = ConvertTo-SprintEndHandoffSingleQuotedLiteral -Value $gitRootFull
    $outputPathLiteral = ConvertTo-SprintEndHandoffSingleQuotedLiteral -Value $outputPathFull
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
    $lines.Add("Set-Location -LiteralPath $gitRootLiteral")
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
      $fullLiteral = ConvertTo-SprintEndHandoffSingleQuotedLiteral -Value $full
      $stablePathLiteral = ConvertTo-SprintEndHandoffSingleQuotedLiteral -Value $stablePath
      $branchNameLiteral = ConvertTo-SprintEndHandoffSingleQuotedLiteral -Value $branchName
      $remainingPathMessageLiteral = ConvertTo-SprintEndHandoffSingleQuotedLiteral -Value "Worktree path remains after removal: $full"
      $lines.Add("# Remove $leaf")
      $lines.Add("git -C $stablePathLiteral worktree remove $fullLiteral --force")
      $lines.Add("git -C $stablePathLiteral worktree prune")
      $lines.Add("if (Test-Path -LiteralPath $fullLiteral) { throw $remainingPathMessageLiteral }")
      $lines.Add("if (git -C $stablePathLiteral branch --list $branchNameLiteral) { git -C $stablePathLiteral branch -D $branchNameLiteral }")
      $lines.Add('')
    }
    $lines.Add('# Synchronize stable worktrees without opening an editor.')
    foreach ($worktreePath in $orderedWorktrees) {
      $leaf = Split-Path -Path $worktreePath -Leaf
      $stableName = $leaf -replace '-wt-\d+-Sprint-\d{4}-work-items$', ''
      $stablePath = Join-Path $gitRootFull $stableName
      $stablePathLiteral = ConvertTo-SprintEndHandoffSingleQuotedLiteral -Value $stablePath
      $lines.Add("Test-SprintEndPullOverlap -RepoPath $stablePathLiteral -Fetch -ThrowOnOverlap")
      $lines.Add("git -C $stablePathLiteral pull --ff-only origin main")
    }
    $lines.Add('')
    $lines.Add('# Infrastructure cleanup: databases only; never SQL instances or Bitwarden secrets.')
    $lines.Add("Remove-SprintDatabases -DeveloperNames @(`$env:USERNAME) -Force -Confirm:`$false")
    $lines.Add("Clear-BuildMasterSprintVariables -Confirm:`$false")
    $lines.Add('$boundaryParams = @{')
    $lines.Add("  Boundary = 'End'")
    $lines.Add("  SharedVSCodeWorktreePath = Join-Path $gitRootLiteral 'SharedVSCode'")
    $lines.Add('  Confirm = $false')
    $lines.Add('}')
    $lines.Add('Set-SprintBoundaryContext @boundaryParams')
    $lines.Add('$boundaryTestParams = @{')
    $lines.Add("  GitRoot = $gitRootLiteral")
    $lines.Add('  TestFreshShell = $true')
    $lines.Add('  ThrowOnFailure = $true')
    $lines.Add('}')
    $lines.Add('Test-SprintEndBoundaryState @boundaryTestParams')
    $lines.Add('')
    $lines.Add('# Remove this handoff only after every command above succeeds.')
    $lines.Add('$handoffRemovalParams = @{')
    $lines.Add("  LiteralPath = $outputPathLiteral")
    $lines.Add('  Force = $true')
    $lines.Add('}')
    $lines.Add('Remove-Item @handoffRemovalParams')
    $lines.Add('```')
    $content = $lines -join [Environment]::NewLine

    $changed = -not (Test-Path -LiteralPath $outputPathFull -PathType Leaf) -or
      ((Get-Content -Raw -LiteralPath $outputPathFull) -ne $content)
    if ($changed -and $PSCmdlet.ShouldProcess($outputPathFull, 'Atomically write SprintEnd handoff')) {
      $directory = Split-Path -Path $outputPathFull -Parent
      if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
      }
      $tempPath = Join-Path $directory ('.' + [IO.Path]::GetFileName($outputPathFull) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
      try {
        [IO.File]::WriteAllText($tempPath, $content, [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $tempPath -Destination $outputPathFull -Force
      } finally {
        if (Test-Path -LiteralPath $tempPath) {
          Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
      }
    }

    return [PSCustomObject]@{
      Path             = $outputPathFull
      Changed          = $changed
      SprintNumber     = $SprintNumber
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
