function Resolve-GatherCallStoreDirectory {
  <#
  .SYNOPSIS
    Resolves the `gather-calls` directory a gather-call record is written to, for either
    the durable `_Planning` target or the legacy `_generated` target.

  .DESCRIPTION
    Task 15.183.B02. The write-target decision lives here, in one testable place, rather
    than as a buried constant in Write-GatherCallRecord, because it is a decision the
    operator expects to REVERSE later rather than a fact about the format.

    WHY DURABLE IS THE DEFAULT
    --------------------------
    Task 15.183 was rescoped on 2026-08-26. The handoff-correlation half was parked, and
    what remains - these records - are no longer point-in-time verification evidence. They
    are seed data for the Tags database and the initial prompt-to-tag associations, which
    makes them information for the FUTURE and therefore R-38 material: `_generated/` under
    an ephemeral sprint worktree is git-ignored and deleted at sprint end, so records
    written there would not survive the sprint that produced them.

    `gather-call-record.contract.v1.md` section 6.2 still shows the `_generated` layout,
    but that section is headed "File layout (proposed)" and its stated rationale - "this
    is point-in-time evidence" - is the premise the rescope overturned. Section 6.2 also
    defers the durable artifact to `correlated-corpus.contract.v1.md`, and that correlated
    half is exactly what got parked, so there is no longer a downstream durable artifact
    for these records to feed. Nothing in the NORMATIVE format sections (3, 4, 5, 9) says
    anything about location, so moving the directory changes where records live and not
    what a record looks like.

    THE TARGET IS A SWITCH, NOT A CONSTANT
    --------------------------------------
    The operator's stated intent is that durable storage is correct FOR NOW and the
    records move back under `_generated` once the bugs are worked out. `-StoreTarget`
    makes that a one-argument, caller-visible, documented decision. Neither path is
    hardcoded at a call site: both are composed here from resolved sprint context.

    ROOT RESOLUTION IS FAIL-CLOSED THROUGHOUT
    -----------------------------------------
    Nothing here walks up a directory tree looking for a `.git` ancestor. `-WorktreeRoot`
    is stated by the caller (Write-GatherCallRecord makes an unbound root a terminating
    error). The Git root defaults to that root's PARENT - the directory holding every
    repository and sprint worktree side by side - which is a derivation from a stated
    value, not an inference from ambient state. The `_Planning` sprint worktree is then
    located by the sprint-worktree folder grammar the module already uses
    (`<repo>-wt-<issue>-Sprint-<nnnn>-work-items`, see Get-SprintWorktreeClassification),
    matched against the resolved sprint number so a stale worktree from another sprint
    cannot be selected.

    An ambiguous match - two `_Planning` sprint worktrees for one sprint - is reported as
    a failure naming both candidates rather than resolved by picking one. Silently
    choosing would scatter a sprint's seed data across two stores.

    FAILURE MODE
    ------------
    Unresolvable context returns `Ok = $false` with an actionable `Error` rather than
    throwing, because a store-resolution failure is a WRITE fault and contract section
    6.4 requires write faults to be non-terminating: a recorder must never fail the gather
    call or the worker. The one exception is an explicitly supplied but malformed
    `-SprintNumber`, which is a caller bug and throws, matching the recorder's existing
    treatment of argument faults.

  .PARAMETER StoreTarget
    `Durable` writes under the `_Planning` sprint worktree so the records merge to stable
    at sprint end. `Generated` writes the legacy contract section 6.2 layout under the
    calling worktree's `_generated` tree.

  .PARAMETER WorktreeRoot
    The CALLING worktree root, normalized. Used to derive the Git root and, for
    `Generated`, as the store's parent. This is the worktree the call ran in; it is not
    necessarily the worktree written to, and under `Durable` it is not.

  .PARAMETER SprintNumber
    Four-digit sprint number. When omitted it is parsed from the worktree folder grammar.

  .PARAMETER Stream
    Stream folder segment, e.g. `StreamM`.

  .PARAMETER TaskFolder
    Task folder segment under the stream folder, used only by `Durable`. It matches the
    folder that already holds this record type's contract in `_Planning`.

  .PARAMETER PlanningRoot
    The `_Planning` sprint worktree. Supplying it skips discovery entirely, which is how a
    test points the resolver at a fixture.

  .PARAMETER GitRoot
    The directory holding every repository and sprint worktree. Defaults to the parent of
    `-WorktreeRoot`.

  .OUTPUTS
    [PSCustomObject] with `Ok`, `Directory`, `Error`, `SprintNumber`, `PlanningRoot`, and
    `StoreTarget`.

  .EXAMPLE
    Resolve-GatherCallStoreDirectory -StoreTarget 'Durable' `
      -WorktreeRoot 'C:/GitHub/ATAP.Utilities-wt-137-Sprint-0015-work-items' `
      -Stream 'StreamM' -TaskFolder 'Task15.183'

    Discovers `C:/GitHub/_Planning-wt-<n>-Sprint-0015-work-items` and returns its
    `InformationForTheFuture/Sprint0015/StreamM/Task15.183/gather-calls` directory.

  .EXAMPLE
    Resolve-GatherCallStoreDirectory -StoreTarget 'Generated' `
      -WorktreeRoot $root -SprintNumber '0015' -Stream 'StreamM'

    Returns `<root>/_generated/Sprint0015/StreamM/gather-calls`, the layout contract
    section 6.2 proposes.

  .NOTES
    Task 15.183.B02 (Sprint 0015, Stream M). Private helper for Write-GatherCallRecord.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Durable', 'Generated')]
    [string]$StoreTarget,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$WorktreeRoot,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$SprintNumber,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Stream = 'StreamM',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$TaskFolder = 'Task15.183',

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$PlanningRoot,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$GitRoot
  )

  $fn = 'Resolve-GatherCallStoreDirectory'
  $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

  $result = [ordered]@{
    Ok           = $false
    Directory    = $null
    Error        = $null
    SprintNumber = $null
    PlanningRoot = $null
    StoreTarget  = $StoreTarget
  }

  # --- sprint number -------------------------------------------------------------
  # An explicitly supplied but malformed value is a caller bug and throws; an
  # unresolvable one is a write fault and returns.
  $sprint = if ([string]::IsNullOrWhiteSpace($SprintNumber)) { $null } else { $SprintNumber }
  if ($null -ne $sprint -and $sprint -notmatch '^\d{4}$') {
    $msg = "SprintNumber '$sprint' is not four digits."
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'GatherCallRecord', 'Argument'
    throw [System.ArgumentException]::new($msg, 'SprintNumber')
  }
  if ($null -eq $sprint -and $WorktreeRoot -match '-[Ss]print-(\d{4})-work-items') {
    $sprint = $Matches[1]
  }
  if ($null -eq $sprint) {
    $result.Error = "Could not resolve a sprint number from worktree '$WorktreeRoot'. Supply -SprintNumber or -StoreRoot."
    return [PSCustomObject]$result
  }
  $result.SprintNumber = $sprint

  if ($StoreTarget -eq 'Generated') {
    $result.Directory = Join-Path $WorktreeRoot '_generated' |
      Join-Path -ChildPath "Sprint$sprint" |
      Join-Path -ChildPath $Stream |
      Join-Path -ChildPath 'gather-calls'
    $result.Ok = $true
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Generated store resolved to '$($result.Directory)'" -Tag 'GatherCallRecord'
    return [PSCustomObject]$result
  }

  # --- durable: locate the _Planning sprint worktree ------------------------------
  $planning = if ([string]::IsNullOrWhiteSpace($PlanningRoot)) { $null } else { $PlanningRoot }

  if ($null -eq $planning) {
    $root = if ([string]::IsNullOrWhiteSpace($GitRoot)) { Split-Path -Path $WorktreeRoot -Parent } else { $GitRoot }
    if ([string]::IsNullOrWhiteSpace($root)) {
      $result.Error = "Could not derive a Git root from worktree '$WorktreeRoot'. Supply -GitRoot, -PlanningRoot, or -StoreRoot."
      return [PSCustomObject]$result
    }
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
      $result.Error = "Git root '$root' does not exist, so the _Planning sprint worktree for Sprint $sprint cannot be located. Supply -PlanningRoot or -StoreRoot."
      return [PSCustomObject]$result
    }

    # The sprint-worktree folder grammar the module already relies on, pinned to THIS
    # sprint so a leftover worktree from another sprint cannot be selected.
    $pattern = '^_Planning-wt-\d+-[Ss]print-' + $sprint + '-work-items$'
    $candidates = @(
      Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $pattern } |
        Sort-Object -Property Name
    )

    if ($candidates.Count -eq 0) {
      $result.Error = "No _Planning sprint worktree for Sprint $sprint was found beneath Git root '$root'. Supply -PlanningRoot or -StoreRoot, or use -StoreTarget Generated."
      return [PSCustomObject]$result
    }
    if ($candidates.Count -gt 1) {
      # Choosing one would scatter a sprint's seed data across two stores.
      $names = ($candidates | ForEach-Object { $_.Name }) -join ', '
      $result.Error = "Ambiguous _Planning sprint worktree for Sprint $sprint beneath '$root': $names. Supply -PlanningRoot to state which one."
      return [PSCustomObject]$result
    }

    $planning = $candidates[0].FullName
  }

  $result.PlanningRoot = $planning
  $result.Directory = Join-Path $planning 'InformationForTheFuture' |
    Join-Path -ChildPath "Sprint$sprint" |
    Join-Path -ChildPath $Stream |
    Join-Path -ChildPath $TaskFolder |
    Join-Path -ChildPath 'gather-calls'
  $result.Ok = $true

  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
    -Message "Durable store resolved to '$($result.Directory)'" -Tag 'GatherCallRecord'
  return [PSCustomObject]$result
}
