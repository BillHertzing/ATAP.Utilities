function New-SprintEndDefectRoute {
  <#
  .SYNOPSIS
    Routes a defect discovered during SprintEnd to the active sprint worktree or
    to a durable next-sprint input, never to a stable worktree.

  .DESCRIPTION
    Task 14.10. Blocking a stable-worktree write is only half of the fix: a
    close that finds a real defect still needs somewhere legal to put it.
    Without an explicit destination the operator's shortest path is exactly the
    prohibited one -- edit the stable checkout, because that is where the broken
    file "really" lives after merge.

    This cmdlet makes the legal destination the easy one. It classifies every
    affected path and chooses a route deterministically:

      - Every affected path is inside a sprint worktree -> 'SprintWorktree'.
        The fix belongs on the sprint branch, in place, before the PR merges.
        No record file is written; the returned object names the worktrees.

      - Any affected path is a stable worktree, is outside GitRoot, or no
        affected path was supplied -> 'NextSprintInput'. The defect is written
        as a durable Markdown record under the _Planning SPRINT worktree, at
        InformationForTheFuture\Sprint<NNNN>\SprintEnd-Defects\<DefectId>.md,
        so it survives sprint-worktree teardown by merging with _Planning
        (repository rule R-38) instead of dying in a _generated folder.

    PlanningRoot is itself gated: it must be a sprint worktree. Writing a
    next-sprint input into the stable _Planning checkout would reintroduce the
    very defect this cmdlet exists to prevent.

    Re-running with identical content is a no-op. Re-running with different
    content preserves the existing record and reports a conflict rather than
    overwriting a human-reviewed defect note; -Force replaces it deliberately.

  .PARAMETER GitRoot
    Root directory that contains every repository and sprint worktree.

  .PARAMETER PlanningRoot
    The active _Planning SPRINT worktree that owns durable next-sprint inputs.

  .PARAMETER SprintNumber
    Sprint number being closed. Used for the record folder and record header.

  .PARAMETER DefectId
    Stable identifier for the defect, used as the record file name.

  .PARAMETER Title
    One-line defect title.

  .PARAMETER Summary
    Description of the defect, its evidence, and what a fix must prove.

  .PARAMETER AffectedPath
    Paths implicated by the defect. Their classification selects the route.

  .PARAMETER DiscoveredBy
    Label for the phase or operator that discovered the defect.

  .PARAMETER Force
    Replace an existing record whose content differs.

  .OUTPUTS
    PSCustomObject with Ok, DefectId, Route, RecordPath, Changed, Conflict,
    SprintWorktreePaths, BlockedPaths, PerPath, and Reason.

  .EXAMPLE
    New-SprintEndDefectRoute -GitRoot 'C:\Repos' -PlanningRoot $planningSprintWorktree `
      -SprintNumber 14 -DefectId 'SE-0014-01' -Title 'Handoff omits WorktreePaths' `
      -Summary 'The generated handoff had nothing to retarget.' `
      -AffectedPath 'C:\Repos\ATAP.Utilities\src\Module\public\New-SprintEndHandoff.ps1' -Confirm:$false

  .NOTES
    AI assisted using ./.claude/rules/Powershell.md as guidelines.

  .LINK
    Test-SprintEndWriteTarget
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$GitRoot,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanningRoot,

    [Parameter(Mandatory)]
    [ValidateRange(1, 9999)]
    [int]$SprintNumber,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$DefectId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Title,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Summary,

    [Parameter()]
    [AllowEmptyCollection()]
    [string[]]$AffectedPath = @(),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$DiscoveredBy = 'SprintEnd',

    [Parameter()]
    [switch]$Force
  )

  begin {
    $fn = 'New-SprintEndDefectRoute'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    if (-not (Get-Command -Name 'Get-SprintWorktreeClassification' -CommandType Function -ErrorAction SilentlyContinue)) {
      $classificationHelperPath = Join-Path $PSScriptRoot '..' 'private' 'Get-SprintWorktreeClassification.ps1'
      if (Test-Path -LiteralPath $classificationHelperPath -PathType Leaf) {
        . $classificationHelperPath
      }
    }

    $planningClassification = Get-SprintWorktreeClassification -Path $PlanningRoot -GitRoot $GitRoot
    if ($planningClassification.Classification -ne 'SprintWorktree') {
      $planningError = "PlanningRoot '$($planningClassification.Path)' is classified as $($planningClassification.Classification). A durable next-sprint input must be written into the _Planning SPRINT worktree so it merges into stable at close; SprintEnd never writes into a stable worktree."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $planningError
      throw $planningError
    }

    $sprintLabel = '{0:D4}' -f $SprintNumber
  }

  process {
    $perPath = @(
      foreach ($candidate in @($AffectedPath)) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
          Get-SprintWorktreeClassification -Path $candidate -GitRoot $GitRoot
        }
      }
    )

    $blockedPaths = @($perPath | Where-Object { $_.Classification -ne 'SprintWorktree' } | Select-Object -ExpandProperty Path)
    $sprintWorktreePaths = @(
      $perPath |
        Where-Object { $_.Classification -eq 'SprintWorktree' } |
        ForEach-Object { Join-Path $_.GitRoot $_.RepositoryFolderName } |
        Select-Object -Unique
    )

    $route = if ($perPath.Count -gt 0 -and $blockedPaths.Count -eq 0) { 'SprintWorktree' } else { 'NextSprintInput' }
    $reason = switch ($route) {
      'SprintWorktree' {
        "Every affected path is inside an active sprint worktree; fix the defect on the sprint branch before its pull request merges."
      }
      default {
        if ($perPath.Count -eq 0) {
          'No affected path was supplied, so the defect cannot be proven fixable inside a sprint worktree; it is recorded as a durable next-sprint input.'
        } else {
          "$($blockedPaths.Count) affected path(s) fall outside every active sprint worktree, so the defect is recorded as a durable next-sprint input instead of being repaired in place."
        }
      }
    }

    $result = [ordered]@{
      Ok                  = $true
      DefectId            = $DefectId
      SprintNumber        = $sprintLabel
      Route               = $route
      RecordPath          = $null
      Changed             = $false
      Conflict            = $false
      SprintWorktreePaths = $sprintWorktreePaths
      BlockedPaths        = $blockedPaths
      PerPath             = $perPath
      Reason              = $reason
    }

    if ($route -eq 'SprintWorktree') {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Defect '$DefectId' routed to the sprint worktree(s): $($sprintWorktreePaths -join ', ')."
      return [PSCustomObject]$result
    }

    $recordDirectory = Join-Path $PlanningRoot 'InformationForTheFuture' |
      Join-Path -ChildPath "Sprint$sprintLabel" |
      Join-Path -ChildPath 'SprintEnd-Defects'
    $recordPath = Join-Path $recordDirectory "$DefectId.md"
    $result.RecordPath = $recordPath

    $affectedLines = if ($perPath.Count -gt 0) {
      @(foreach ($entry in $perPath) { "- ``$($entry.Path)`` - $($entry.Classification)" })
    } else {
      @('- (none recorded)')
    }

    $content = @(
      "# SprintEnd defect $DefectId",
      '',
      "- **Sprint closed:** $sprintLabel",
      "- **Discovered by:** $DiscoveredBy",
      "- **Route:** NextSprintInput",
      '',
      "## $Title",
      '',
      $Summary,
      '',
      '## Affected paths',
      ''
    ) + $affectedLines + @(
      '',
      '## Why this is a next-sprint input',
      '',
      $reason,
      '',
      'SprintEnd does not repair stable worktrees. Stable content is produced by',
      'merging the sprint branch, so a defect that cannot be fixed inside an active',
      'sprint worktree is carried forward as a planning input rather than patched',
      'in place during the close.',
      ''
    ) -join [Environment]::NewLine

    # Set-Content terminates the file with a newline, so a raw read is never
    # byte-identical to the composed content. Compare on trailing-newline-
    # insensitive text; otherwise every re-run would report a false conflict
    # against the record it just wrote itself.
    $existingContent = if (Test-Path -LiteralPath $recordPath -PathType Leaf) {
      (Get-Content -Raw -LiteralPath $recordPath).TrimEnd("`r", "`n")
    } else {
      $null
    }
    $normalizedContent = $content.TrimEnd("`r", "`n")

    if ($null -ne $existingContent -and $existingContent -eq $normalizedContent) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Defect record '$recordPath' is already current."
      return [PSCustomObject]$result
    }

    if ($null -ne $existingContent -and -not $Force) {
      $result.Ok = $false
      $result.Conflict = $true
      $result.Reason = "A different defect record already exists at '$recordPath'. It was preserved. Review it and re-run with -Force to replace it deliberately."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $result.Reason
      return [PSCustomObject]$result
    }

    if ($PSCmdlet.ShouldProcess($recordPath, 'Write durable SprintEnd defect record')) {
      if (-not (Test-Path -LiteralPath $recordDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $recordDirectory -Force | Out-Null
      }
      Set-Content -LiteralPath $recordPath -Value $content -Encoding UTF8
      $result.Changed = $true
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Defect '$DefectId' recorded as a durable next-sprint input at '$recordPath'."
    }

    return [PSCustomObject]$result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
