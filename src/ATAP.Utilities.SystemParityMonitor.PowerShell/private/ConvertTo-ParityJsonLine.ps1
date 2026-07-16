function ConvertTo-ParityJsonLine {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object] $InputObject
  )

  begin {
    $fn = 'ConvertTo-ParityJsonLine'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Converting object to compact JSONL payload.'
  }

  process {
    try {
      $InputObject | ConvertTo-Json -Depth 16 -Compress
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to serialize JSONL payload. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
  }
}
