function Read-ParityJsonFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  begin {
    $fn = 'Read-ParityJsonFile'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Reading JSON file '$Path'."
  }

  process {
    try {
      if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
      }

      Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to read JSON file '$Path'. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
  }
}
