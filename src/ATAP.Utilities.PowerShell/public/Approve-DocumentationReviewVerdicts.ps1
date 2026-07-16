#############################################################################
#region Approve-DocumentationReviewVerdicts
<#
.SYNOPSIS
Interactive gate-G4 pass over the Documentation Review findings register: shows each pending verdict with a file preview and records Y/N acceptance.

.DESCRIPTION
Walks the pending rows of the DR program's findings register
(_Planning\DocumentationReview\FindingsRegister-SprintNNNN.csv). For each row it displays:

  - the file name (RepoName\RelativePath),
  - the suggested disposition (Verdict, FindingSummary, Evidence, coordinator notes),
  - the first N lines of the file itself (default 50; skipped for binary/missing files),

then accepts exactly one of 'Y', 'N', 'K', 'D', or 'S' from the console:

  Y — accept the suggested disposition: the row's AcceptanceStatus becomes 'accepted'.
  N — hold the row for another acceptance pass: AcceptanceStatus becomes 'held'.
  K — keep: the file is a thin wrapper that nevertheless contains useful information
      to review later. The file is NOT deleted; the row's Disposition becomes
      'thin-wrapper-useful' and AcceptanceStatus becomes 'accepted'.
  D — delete: the file is a thin wrapper with no useful information. The file is
      DELETED from disk (honors -WhatIf/-Confirm); the row's Disposition becomes
      'thin-wrapper-no-value' and AcceptanceStatus becomes 'accepted'.
  S — skip: no decision. The row is left pending (no disposition, no deletion) and
      will be presented again on the next run.

Any other input re-prompts. The register is rewritten after EVERY decision, so an
interrupted session loses nothing; a later run resumes with the still-pending rows
(rows already 'accepted', or with VerificationStatus containing 'remediated', are
skipped; 'held' rows reappear only when -IncludeHeld is passed; skipped rows always
reappear).

This is the DR-4 gate-G4 HITL tool of the ATAP Documentation Review program
(_Planning\DocumentationReview\DocumentationReview-Plan.md). It is intentionally
interactive (Read-Host) and must be run by a human at a console, not by an agent in a
non-interactive shell.

.PARAMETER RegisterPath
Path to the findings register CSV (append-only, coordinator-written). The function adds
AcceptanceStatus, AcceptedUtc, and Disposition columns if absent.

.PARAMETER ConfigPath
Path to ReviewConfig.json; its activeRoots map RepoName -> rootPath so the file preview
can resolve absolute paths.

.PARAMETER BatchId
Optional filter: only rows whose BatchId is in this list.

.PARAMETER Verdict
Optional filter: only rows whose Verdict is in this list (e.g. review only MAJOR-DRIFT).

.PARAMETER PreviewLineCount
How many leading lines of each file to display. Default 50.

.PARAMETER IncludeHeld
Also re-present rows previously marked 'held'.

.INPUTS
None.

.OUTPUTS
A summary PSCustomObject: Presented, Accepted, Held, Kept, Deleted, Skipped,
RemainingPending.

.EXAMPLE
Approve-DocumentationReviewVerdicts `
  -RegisterPath 'C:\...\_Planning-wt-26-...\DocumentationReview\FindingsRegister-Sprint0012.csv' `
  -ConfigPath   'C:\...\_Planning-wt-26-...\DocumentationReview\ReviewConfig.json'

.EXAMPLE
Approve-DocumentationReviewVerdicts -RegisterPath $reg -ConfigPath $cfg -Verdict 'MAJOR-DRIFT','OBSOLETE-RETIRE'

.EXAMPLE
Approve-DocumentationReviewVerdicts -RegisterPath $reg -ConfigPath $cfg -BatchId 'DR-Batch-007' -IncludeHeld
#>
Function Approve-DocumentationReviewVerdicts {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess)]
  param (
    [parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $RegisterPath
    , [parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $ConfigPath
    , [parameter()]
    [string[]] $BatchId
    , [parameter()]
    [string[]] $Verdict
    , [parameter()]
    [ValidateRange(1, 500)]
    [int] $PreviewLineCount = 50
    , [parameter()]
    [switch] $IncludeHeld
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Entering Function Approve-DocumentationReviewVerdicts in module ATAP.Utilities.Powershell' -Tag 'Trace'
    $binaryExtensions = @('.docx', '.doc', '.pdf', '.rtf', '.chm', '.odt', '.one')
  }
  #endregion FunctionBeginBlock
  #region FunctionEndBlock
  ########################################
  END {
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $rootByRepo = @{}
    foreach ($r in $config.activeRoots) { $rootByRepo[$r.repoName] = $r.rootPath }

    # Ensure every row carries the acceptance columns (older registers lack them).
    $rows = @(Import-Csv -LiteralPath $RegisterPath) | ForEach-Object {
      if (-not $_.PSObject.Properties['AcceptanceStatus']) { $_ | Add-Member -NotePropertyName AcceptanceStatus -NotePropertyValue '' }
      if (-not $_.PSObject.Properties['AcceptedUtc']) { $_ | Add-Member -NotePropertyName AcceptedUtc -NotePropertyValue '' }
      if (-not $_.PSObject.Properties['Disposition']) { $_ | Add-Member -NotePropertyName Disposition -NotePropertyValue '' }
      $_
    }

    $pending = $rows | Where-Object {
      $_.VerificationStatus -notlike '*remediated*' -and
      $_.AcceptanceStatus -ne 'accepted' -and
      ($IncludeHeld -or $_.AcceptanceStatus -ne 'held') -and
      ((-not $BatchId) -or ($BatchId -contains $_.BatchId)) -and
      ((-not $Verdict) -or ($Verdict -contains $_.Verdict))
    }

    $presented = 0; $accepted = 0; $held = 0; $kept = 0; $deleted = 0; $skipped = 0
    foreach ($row in $pending) {
      $presented++
      Write-Host ''
      Write-Host ('=' * 78) -ForegroundColor Cyan
      Write-Host "[$($row.BatchId)]  $($row.RepoName)\$($row.RelativePath)" -ForegroundColor Cyan
      Write-Host ('-' * 78) -ForegroundColor Cyan
      Write-Host "Suggested disposition : $($row.Verdict)" -ForegroundColor Yellow
      Write-Host "Finding               : $($row.FindingSummary)"
      Write-Host "Evidence              : $($row.Evidence)"
      if ($row.CoordinatorNote) { Write-Host "Coordinator note      : $($row.CoordinatorNote)" }
      Write-Host ('-' * 78) -ForegroundColor Cyan

      $root = $rootByRepo[$row.RepoName]
      $absolutePath = if ($root) { Join-Path $root $row.RelativePath } else { $null }
      $extension = [System.IO.Path]::GetExtension($row.RelativePath).ToLowerInvariant()
      if (-not ($absolutePath -and (Test-Path -LiteralPath $absolutePath))) {
        Write-Host "(file not present on disk — no preview)" -ForegroundColor DarkGray
      } elseif ($binaryExtensions -contains $extension) {
        Write-Host "(binary format '$extension' — no text preview)" -ForegroundColor DarkGray
      } else {
        Get-Content -LiteralPath $absolutePath -TotalCount $PreviewLineCount | ForEach-Object { Write-Host "  | $_" }
      }
      Write-Host ('-' * 78) -ForegroundColor Cyan

      $answer = ''
      while ($answer -notin 'Y', 'N', 'K', 'D', 'S') {
        $answer = (Read-Host "Accept suggested disposition '$($row.Verdict)'? [Y] accept  [N] hold  [K] keep thin-wrapper-useful  [D] delete thin-wrapper-no-value  [S] skip").Trim().ToUpperInvariant()
      }
      switch ($answer) {
        'Y' {
          $row.AcceptanceStatus = 'accepted'
          $row.AcceptedUtc = [datetimeoffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss+00:00')
          $accepted++
        }
        'N' {
          $row.AcceptanceStatus = 'held'
          $row.AcceptedUtc = ''
          $held++
        }
        'K' {
          $row.Disposition = 'thin-wrapper-useful'
          $row.AcceptanceStatus = 'accepted'
          $row.AcceptedUtc = [datetimeoffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss+00:00')
          $kept++
        }
        'D' {
          if ($absolutePath -and (Test-Path -LiteralPath $absolutePath)) {
            if ($PSCmdlet.ShouldProcess($absolutePath, 'Delete thin-wrapper file')) {
              try {
                Remove-Item -LiteralPath $absolutePath -Force -Confirm:$false
                Write-PSFMessage -Level Important -Message "Deleted thin-wrapper file '$absolutePath'" -Tag 'DocumentationReview'
              } catch {
                Write-PSFMessage -Level Error -Message "Failed to delete '$absolutePath': $($_.Exception.Message)" -Tag 'DocumentationReview'
                Write-Host "Delete failed: $($_.Exception.Message) — row left pending." -ForegroundColor Red
                $skipped++
                continue
              }
            } else {
              # -WhatIf (or Confirm declined): no deletion, no marking — behaves as skip.
              $skipped++
              continue
            }
          }
          $row.Disposition = 'thin-wrapper-no-value'
          $row.AcceptanceStatus = 'accepted'
          $row.AcceptedUtc = [datetimeoffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss+00:00')
          $deleted++
        }
        'S' {
          # No decision recorded; row stays pending and reappears next run.
          $skipped++
          continue
        }
      }
      # Persist after every decision so an interrupted session loses nothing.
      $rows | Export-Csv -LiteralPath $RegisterPath -NoTypeInformation -Encoding utf8
    }

    $remaining = @($rows | Where-Object {
        $_.VerificationStatus -notlike '*remediated*' -and $_.AcceptanceStatus -notin 'accepted', 'held'
      }).Count
    Write-PSFMessage -Level Verbose -Message "Approve-DocumentationReviewVerdicts: presented=$presented accepted=$accepted held=$held kept=$kept deleted=$deleted skipped=$skipped remaining=$remaining" -Tag 'DocumentationReview'
    [PSCustomObject]@{
      Presented        = $presented
      Accepted         = $accepted
      Held             = $held
      Kept             = $kept
      Deleted          = $deleted
      Skipped          = $skipped
      RemainingPending = $remaining
    }
    Write-PSFMessage -Level Debug -Message 'Leaving Function Approve-DocumentationReviewVerdicts in module ATAP.Utilities.Powershell' -Tag 'Trace'
  }
  #endregion FunctionEndBlock
}
#endregion Approve-DocumentationReviewVerdicts
#############################################################################
