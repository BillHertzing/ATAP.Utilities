function Write-ParityJsonLine {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path,

    [Parameter(Mandatory = $true)]
    [object] $InputObject
  )

  begin {
    $fn = 'Write-ParityJsonLine'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Appending JSONL payload to '$Path'."
  }

  process {
    try {
      $parent = Split-Path -Path $Path -Parent
      if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
      }

      $line = ConvertTo-ParityJsonLine -InputObject $InputObject
      if ($PSCmdlet.ShouldProcess($Path, 'Append parity JSONL line')) {
        Add-Content -LiteralPath $Path -Value $line -Encoding utf8
      }
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to append JSONL payload to '$Path'. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
  }
}
