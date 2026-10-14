function ConvertTo-ContentSummaryHarvestError {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^CS-[A-Z]+-[0-9]{3}$')]
    [string] $Code,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Message,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9.-]+$')]
    [string] $ReasonCode,

    [bool] $Retryable = $false
  )

  begin {
    $fn = 'ConvertTo-ContentSummaryHarvestError'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'
  }

  process {
    $diagnosticMaterial = $Code + [char]0x001f + $ReasonCode
    [pscustomobject][ordered]@{
      code = $Code
      message = $Message
      retryable = $Retryable
      diagnosticHash = Get-ContentSummarySha256 -Text $diagnosticMaterial
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}
