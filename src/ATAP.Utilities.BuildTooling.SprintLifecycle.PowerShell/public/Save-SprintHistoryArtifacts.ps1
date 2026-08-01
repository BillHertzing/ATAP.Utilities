function Save-SprintHistoryArtifacts {
  <#
  .SYNOPSIS
  Copies the immutable sprint planning artifact set into SprintHistory.

  .DESCRIPTION
  Archives the dotted Sprint 0010+ planning set and any legacy versioned board
  variants into SprintHistory/SprintNNNN. Existing identical files are accepted;
  an existing different file is never overwritten.

  .PARAMETER PlanningRoot
  Planning sprint worktree containing the active artifacts.

  .PARAMETER SprintNumber
  Closing sprint number.

  .OUTPUTS
  PSCustomObject containing archived files and hashes.

  .EXAMPLE
  Save-SprintHistoryArtifacts -PlanningRoot C:\Repos\_Planning-wt-20-Sprint-0010-work-items -SprintNumber 10

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseSingularNouns',
    '',
    Justification = 'The command archives a required set of multiple sprint artifacts.'
  )]
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$PlanningRoot,

    [Parameter(Mandatory)]
    [ValidateRange(1, 9999)]
    [int]$SprintNumber
  )

  begin {
    $fn = 'Save-SprintHistoryArtifacts'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $planningRootFull = [IO.Path]::GetFullPath($PlanningRoot)
    $sprintText = '{0:D4}' -f $SprintNumber
    $historyRoot = Join-Path $planningRootFull "SprintHistory\Sprint$sprintText"
    $patterns = @(
      "Tasks.Sprint$sprintText.md",
      "Tasks.Sprint$sprintText.html",
      "Tasks.Sprint$sprintText.Accomplished.html",
      "Tasks.Sprint$sprintText.ProceduralDetails.html",
      "Tasks.Sprint${sprintText}_V*.md",
      "Tasks.Sprint${sprintText}_V*.html",
      "TasksSprint${sprintText}_V*.md",
      "TasksSprint${sprintText}_V*.html",
      "TASKS_V*.md",
      "TASKS_V*.html"
    )
    $sources = [System.Collections.Generic.List[IO.FileInfo]]::new()
    foreach ($pattern in $patterns) {
      foreach ($file in @(Get-ChildItem -LiteralPath $planningRootFull -Filter $pattern -File -ErrorAction SilentlyContinue)) {
        if (-not ($sources.FullName -contains $file.FullName)) {
          [void]$sources.Add($file)
        }
      }
    }
    $requiredNames = @(
      "Tasks.Sprint$sprintText.md",
      "Tasks.Sprint$sprintText.html",
      "Tasks.Sprint$sprintText.Accomplished.html",
      "Tasks.Sprint$sprintText.ProceduralDetails.html"
    )
    $missing = @($requiredNames | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $planningRootFull $_) -PathType Leaf)
      })
    if ($missing.Count -gt 0) {
      throw "Required sprint artifact(s) missing: $($missing -join ', ')."
    }

    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($source in $sources) {
      $destination = Join-Path $historyRoot $source.Name
      $sourceHash = (Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash
      $copied = $false
      if (Test-Path -LiteralPath $destination -PathType Leaf) {
        $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        if ($destinationHash -ne $sourceHash) {
          throw "Sprint history target '$destination' already exists with different content."
        }
      } elseif ($PSCmdlet.ShouldProcess($destination, "Archive '$($source.Name)'")) {
        if (-not (Test-Path -LiteralPath $historyRoot -PathType Container)) {
          New-Item -ItemType Directory -Path $historyRoot -Force | Out-Null
        }
        Copy-Item -LiteralPath $source.FullName -Destination $destination
        $copied = $true
      }
      [void]$entries.Add([PSCustomObject]@{
          Source      = $source.FullName
          Destination = $destination
          Sha256      = $sourceHash
          Copied      = $copied
        })
    }

    return [PSCustomObject]@{
      Ok          = ($missing.Count -eq 0)
      SprintNumber = $sprintText
      HistoryRoot = $historyRoot
      Files       = $entries.ToArray()
      Missing     = $missing
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
