function Invoke-ParityNativeCommand {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Command,

    [string[]] $ArgumentList = @()
  )

  begin {
    $fn = 'Invoke-ParityNativeCommand'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Invoking package-manager command '$Command'."
  }

  process {
    $output = @(& $Command @ArgumentList 2>&1 | ForEach-Object { [string] $_ })
    [pscustomobject]@{
      ExitCode = $LASTEXITCODE
      Output = $output
    }
  }

  end {
  }
}
