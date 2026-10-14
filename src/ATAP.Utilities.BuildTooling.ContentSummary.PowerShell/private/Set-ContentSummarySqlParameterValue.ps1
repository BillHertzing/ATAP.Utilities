function Set-ContentSummarySqlParameterValue {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object] $Parameter,

    [AllowNull()]
    [object] $Value
  )

  begin {
    $fn = 'Set-ContentSummarySqlParameterValue'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'
  }

  process {
    if ($null -eq $Value) {
      $Parameter.Value = [DBNull]::Value
    } else {
      $Parameter.Value = $Value
    }
    $Parameter
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}