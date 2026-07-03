function Get-SprintHistoryReconstruction {
  <#
  .SYNOPSIS
    Reconstructs the latest completed sprint from Planning lifecycle artifacts.
  .DESCRIPTION
    Scans a Planning worktree for sprint lifecycle evidence across retrospective
    notebooks, sprint-history folders, task artifact sets, snapshots, and Git
    close commits. The cmdlet returns the highest sprint number supported by the
    evidence and records disagreements as structured warnings so SprintStart can
    avoid trusting a single weak signal.
  .PARAMETER PlanningRoot
    Root path of the _Planning repository or worktree.
  .OUTPUTS
    PSCustomObject with LastCompletedSprintNumber, Evidence, Warnings, and
    Disagreements.
  .EXAMPLE
    Get-SprintHistoryReconstruction -PlanningRoot C:\Dropbox\whertzing\GitHub\_Planning
  .NOTES
    Used by SprintStart Stage 1 as a recovery-friendly lifecycle signal.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanningRoot
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    $resolvedPlanningRoot = (Resolve-Path -LiteralPath $PlanningRoot -ErrorAction SilentlyContinue)?.Path
    if ([string]::IsNullOrWhiteSpace($resolvedPlanningRoot)) {
      throw "PlanningRoot was not found: $PlanningRoot"
    }

    $evidence = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()

    function Add-SprintHistoryEvidence {
      param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [int]$SprintNumber,
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [string]$Detail
      )

      $evidence.Add([PSCustomObject]@{
          Source       = $Source
          SprintNumber = $SprintNumber
          Path         = $Path
          Detail       = $Detail
        })
    }

    $retroRoot = Join-Path $resolvedPlanningRoot 'SprintRetrospective'
    if (Test-Path -LiteralPath $retroRoot -PathType Container) {
      Get-ChildItem -LiteralPath $retroRoot -Filter 'Notebook-SprintWorkSession-*-End.md' -File -ErrorAction SilentlyContinue |
        ForEach-Object {
          if ($_.Name -match 'SprintWorkSession-(?<Sprint>\d{4})-End') {
            Add-SprintHistoryEvidence -Source 'RetrospectiveNotebook' -SprintNumber ([int]$Matches['Sprint']) -Path $_.FullName -Detail $_.Name
          }
        }
    }

    $historyRoot = Join-Path $resolvedPlanningRoot 'SprintHistory'
    if (Test-Path -LiteralPath $historyRoot -PathType Container) {
      Get-ChildItem -LiteralPath $historyRoot -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
          if ($_.Name -match '^Sprint(?<Sprint>\d{4})$') {
            Add-SprintHistoryEvidence -Source 'SprintHistoryFolder' -SprintNumber ([int]$Matches['Sprint']) -Path $_.FullName -Detail $_.Name
          }
        }
    }

    $snapshotsRoot = Join-Path $resolvedPlanningRoot 'Snapshots'
    if (Test-Path -LiteralPath $snapshotsRoot -PathType Container) {
      Get-ChildItem -LiteralPath $snapshotsRoot -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
          if ($_.Name -match '^(?<Sprint>\d{4})$') {
            Add-SprintHistoryEvidence -Source 'SnapshotFolder' -SprintNumber ([int]$Matches['Sprint']) -Path $_.FullName -Detail $_.Name
          }
        }
    }

    Get-ChildItem -LiteralPath $resolvedPlanningRoot -File -ErrorAction SilentlyContinue |
      ForEach-Object {
        foreach ($pattern in @(
            '^TASKS\.Sprint(?<Sprint>\d{4})\.md$',
            '^TASKS\.Sprint(?<Sprint>\d{4})\.html$',
            '^TASKS\.Sprint(?<Sprint>\d{4})\.Accomplished\.html$',
            '^TASKS\.Sprint(?<Sprint>\d{4})\.ProceduralDetails\.html$',
            '^Tasks\.Sprint(?<Sprint>\d{4})\.md$',
            '^Tasks\.Sprint(?<Sprint>\d{4})\.html$',
            '^Tasks\.Sprint(?<Sprint>\d{4})\.Accomplished\.html$',
            '^Tasks\.Sprint(?<Sprint>\d{4})\.ProceduralDetails\.html$',
            '^TasksSprint(?<Sprint>\d{4})\.md$',
            '^TasksSprint(?<Sprint>\d{4})\.html$'
          )) {
          if ($_.Name -match $pattern) {
            Add-SprintHistoryEvidence -Source 'TaskArtifact' -SprintNumber ([int]$Matches['Sprint']) -Path $_.FullName -Detail $_.Name
            break
          }
        }
      }

    $gitRoot = Join-Path $resolvedPlanningRoot '.git'
    if (Test-Path -LiteralPath $gitRoot) {
      try {
        $gitLines = @(git -C $resolvedPlanningRoot log --max-count 200 --pretty=format:'%H%x09%s' 2>$null)
        foreach ($line in $gitLines) {
          if ($line -match '^(?<Sha>[0-9a-f]{7,40})\t(?<Subject>.+)$') {
            $sha = $Matches['Sha']
            $subject = $Matches['Subject']
            if ($subject -match '(?i)(close|complete|end|archive).{0,40}sprint[^\d]*(?<Sprint>\d{4})') {
              Add-SprintHistoryEvidence -Source 'GitCloseCommit' -SprintNumber ([int]$Matches['Sprint']) -Path $sha -Detail $subject
            }
          }
        }
      } catch {
        $warnings.Add([PSCustomObject]@{
            Source = 'GitCloseCommit'
            Code   = 'GitLogFailed'
            Detail = $_.Exception.Message
          })
      }
    }

    $lastCompleted = if ($evidence.Count -gt 0) {
      [int]($evidence | Measure-Object -Property SprintNumber -Maximum).Maximum
    } else {
      0
    }

    $bySource = $evidence |
      Group-Object -Property Source |
      ForEach-Object {
        [PSCustomObject]@{
          Source              = $_.Name
          MaxSprintNumber     = [int](($_.Group | Measure-Object -Property SprintNumber -Maximum).Maximum)
          EvidenceRecordCount = $_.Count
        }
      }

    $disagreements = @(
      $bySource |
        Where-Object { $_.MaxSprintNumber -ne $lastCompleted } |
        ForEach-Object {
          [PSCustomObject]@{
            Source              = $_.Source
            SourceMaxSprint     = $_.MaxSprintNumber
            SelectedSprint      = $lastCompleted
            EvidenceRecordCount = $_.EvidenceRecordCount
            Detail              = 'Source max does not match the selected highest observed sprint.'
          }
        }
    )

    foreach ($disagreement in $disagreements) {
      $warnings.Add([PSCustomObject]@{
          Source = $disagreement.Source
          Code   = 'SprintNumberDisagreement'
          Detail = $disagreement.Detail
        })
    }

    return [PSCustomObject]@{
      PlanningRoot              = $resolvedPlanningRoot
      LastCompletedSprintNumber = $lastCompleted
      Evidence                  = $evidence.ToArray()
      SourceSummary             = @($bySource)
      Disagreements             = $disagreements
      Warnings                  = $warnings.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
