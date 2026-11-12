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
    # stdout and stderr are captured separately: merging them (2>&1) let an intermittent
    # stderr notice (e.g. 'npm notice New major version...') corrupt stdout JSON.
    $errorFile = [System.IO.Path]::GetTempFileName()
    try {
      $output = @(& $Command @ArgumentList 2>$errorFile | ForEach-Object { [string] $_ })
      $exitCode = $LASTEXITCODE
      $errorOutput = @(Get-Content -LiteralPath $errorFile -ErrorAction SilentlyContinue | ForEach-Object { [string] $_ })
    }
    finally {
      Remove-Item -LiteralPath $errorFile -Force -ErrorAction SilentlyContinue
    }
    if ($errorOutput.Count -gt 0) {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Command '$Command' wrote $($errorOutput.Count) stderr line(s)."
    }
    [pscustomobject]@{
      ExitCode = $exitCode
      Output = $output
      ErrorOutput = $errorOutput
    }
  }

  end {
  }
}
