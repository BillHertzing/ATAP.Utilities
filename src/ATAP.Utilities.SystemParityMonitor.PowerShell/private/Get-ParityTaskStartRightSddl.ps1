function Get-ParityTaskStartRightSddl {
  <#
  .SYNOPSIS
    Returns a scheduled-task SDDL that grants one SID start-only rights (GRGX).

  .DESCRIPTION
    Pure SDDL computation with no Task Scheduler access, so the grant rule is unit-testable.
    Start-only means generic read + generic execute: the grantee can run the task as defined but
    cannot change, delete, or re-point it. Task Scheduler stores that grant canonicalized as
    0x1200a9, so both spellings count as already granted.

    Fail-closed: if the SID already holds any OTHER explicit allow mask on the task, the function
    throws rather than widening, narrowing, or duplicating an unknown grant. A descriptor without
    a DACL is refused rather than synthesized.

  .PARAMETER Sddl
    Current task security descriptor (at least the DACL part).

  .PARAMETER Sid
    String SID of the identity to grant start rights to.

  .OUTPUTS
    PSCustomObject with Sddl (the resulting descriptor) and Changed (bool).
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Sddl,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^S-1-\d+(-\d+)+$')]
    [string] $Sid
  )

  begin {
    $fn = 'Get-ParityTaskStartRightSddl'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
  }

  process {
    if ($Sddl -notmatch 'D:') {
      throw "Task security descriptor has no DACL; refusing to synthesize one. SDDL: $Sddl"
    }
    $acePattern = '\(A;([^;]*);([^;]+);;;' + [regex]::Escape($Sid) + '\)'
    # Only explicit ACEs on the task count; ACEs inherited from the task folder carry the ID flag.
    $existing = @([regex]::Matches($Sddl, $acePattern) | Where-Object { $_.Groups[1].Value -notmatch 'ID' })
    $startOnlyMasks = @('GRGX', '0x1200a9', '0x1200A9')
    foreach ($match in $existing) {
      $flags = $match.Groups[1].Value
      $mask = $match.Groups[2].Value
      if ([string]::IsNullOrEmpty($flags) -and $mask -in $startOnlyMasks) {
        Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "SID $Sid already holds start-only rights ($mask)."
        return [pscustomobject]@{ Sddl = $Sddl; Changed = $false }
      }
    }
    if ($existing.Count -gt 0) {
      $masks = ($existing | ForEach-Object { "flags='$($_.Groups[1].Value)' mask='$($_.Groups[2].Value)'" }) -join ', '
      throw "SID $Sid already holds a different explicit task grant ($masks); refusing to change an unknown grant."
    }
    $newSddl = $Sddl + "(A;;GRGX;;;$Sid)"
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Computed start-only grant for SID $Sid."
    [pscustomobject]@{ Sddl = $newSddl; Changed = $true }
  }

  end {
  }
}
