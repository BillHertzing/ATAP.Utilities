function Test-BrokerTaskStartRight {
  <#
  .SYNOPSIS
    Returns $true when a task-SDDL access mask confers the right to RUN the task.

  .DESCRIPTION
    Accepts either an SDDL abbreviation or a hex mask, because Windows canonicalises generic
    rights into a hex mask when it stores the descriptor (see Get-BrokerTaskAceMask). The
    decisive bit for "may start this task" is TASK_EXECUTE (0x20).

  .PARAMETER Mask
    Mask token from the ACE, e.g. '0x1200a9', 'GRGX', 'FA'. $null/empty returns $false.

  .OUTPUTS
    [bool]
  #>
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string] $Mask
  )

  begin {
    $fn = 'Test-BrokerTaskStartRight'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    # Function-local constant: module .ps1 files must not define module-scope state.
    $taskExecuteBit = 0x20
  }

  process {
    if ([string]::IsNullOrWhiteSpace($Mask)) { return $false }

    # Abbreviations that include execute.
    if ($Mask -in @('GRGX', 'GX', 'GA', 'FA')) { return $true }

    if ($Mask -match '^0x[0-9a-fA-F]+$') {
      $value = [Convert]::ToInt32($Mask, 16)
      $grants = (($value -band $taskExecuteBit) -ne 0)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Mask '$Mask' grants start: $grants."
      return $grants
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Unrecognised mask token '$Mask'; treating as no start right."
    return $false
  }

  end {
  }
}
