function Read-ParityJsonLines {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  begin {
    $fn = 'Read-ParityJsonLines'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Reading JSONL file '$Path'."
  }

  process {
    try {
      if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @()
      }

      $items = foreach ($line in Get-Content -LiteralPath $Path) {
        if ([string]::IsNullOrWhiteSpace($line)) {
          continue
        }

        $line | ConvertFrom-Json
      }

      @($items)
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to read JSONL file '$Path'. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
  }
}
