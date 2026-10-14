function Resolve-WorktreeRootFromPath {
  <#
  .SYNOPSIS
    Normalizes an explicitly supplied worktree root to the record's path form. Does NOT
    infer a root by walking up the directory tree.

  .DESCRIPTION
    Task 15.183.B02 extracted this from the `begin` block of Write-GatherCallRecord AND
    corrected it in the same pass. The correction is the point of the function, so the
    old behaviour is documented here rather than deleted silently.

    WHAT IT USED TO DO, AND WHY THAT WAS WRONG
    ------------------------------------------
    It used to walk up from a starting path to the nearest ancestor containing a `.git`
    entry, and Write-GatherCallRecord called it as a FALLBACK whenever `-WorktreeRoot` was
    not supplied. That is fail-open: an unbound root silently became whatever repository
    the current location happened to sit in. The record field it feeds, `worktreePath`,
    exists precisely to say WHICH repository root a call came from, so a walked-up value
    is an inferred identity that is indistinguishable downstream from a stated one - the
    exact failure mode the whole record format is built to prevent (contract section 3.2,
    and the "absence is recorded as absence, never inferred" rule).

    The C00 gate ratified the fail-closed decision: a missing `-WorktreeRoot` is a
    terminating error at the caller, with no walk-up and no opt-in switch to restore it.
    There is deliberately no `-Walk` parameter here; an escape hatch that reintroduces
    inference is the same defect with a longer name.

    That decision became load-bearing rather than merely tidy at Task 15.183.B02, when the
    write target moved to durable `_Planning` storage. The durable destination is derived
    from the calling worktree root's PARENT (the Git root that holds every worktree side
    by side), so a walked-up root would not just mislabel the record - it would send the
    write to a different repository's sprint worktree. Fail-closed and the durable target
    push in the same direction.

    WHAT IT DOES NOW
    ----------------
    Resolves the path the caller actually stated, and nothing else: absolute form, forward
    slashes, no trailing slash. It performs no filesystem access and does not require the
    path to exist, so a planned or fixture path normalizes exactly like a live one and the
    function stays unit-testable without a real worktree. It never consults `.git`,
    because presence of a `.git` entry is not what makes a stated root correct - the
    caller stating it is.

  .PARAMETER StartPath
    The worktree root as supplied by the caller. Blank yields `$null`, which the caller
    turns into its terminating fail-closed error; this function does not throw, so the
    caller owns the error message and its `.PARAMETER` documentation.

  .OUTPUTS
    [string] - the normalized root, or `$null` when the path is blank or unresolvable.

  .EXAMPLE
    Resolve-WorktreeRootFromPath -StartPath 'C:\Repos\ATAP.Utilities-wt-1-Sprint-0015-work-items\'

    Returns 'C:/Repos/ATAP.Utilities-wt-1-Sprint-0015-work-items'.

  .EXAMPLE
    Resolve-WorktreeRootFromPath -StartPath '   '

    Returns $null. It does not fall back to the current location.

  .NOTES
    Task 15.183.B02 (Sprint 0015, Stream M). Private helper for Write-GatherCallRecord.
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$StartPath
  )

  if ([string]::IsNullOrWhiteSpace($StartPath)) { return $null }

  $full = $null
  try {
    $full = [System.IO.Path]::GetFullPath($StartPath)
  } catch {
    return $null
  }

  return ($full -replace '\\', '/').TrimEnd('/')
}
