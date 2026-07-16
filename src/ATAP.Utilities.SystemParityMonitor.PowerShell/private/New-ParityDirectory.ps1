function New-ParityDirectory {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  begin {
    $fn = 'New-ParityDirectory'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Ensuring parity directory '$Path'."
  }

  process {
    try {
      if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        if ($PSCmdlet.ShouldProcess($Path, 'Create parity state directory')) {
          New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
      }
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to ensure parity directory '$Path'. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
  }
}
